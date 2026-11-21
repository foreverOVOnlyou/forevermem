import Foundation

public protocol MemoryStore {
    func load(conversationID: UUID) -> MemoryDocument
    func save(_ document: MemoryDocument, conversationID: UUID)
    func delete(conversationID: UUID)
}

/// File-backed memory store. One atomic JSON document per conversation, with a
/// previous-version backup and one-time migration from the old UserDefaults key.
public final class FileMemoryStore: MemoryStore {
    public static let currentSchemaVersion = 2

    private let directory: URL
    private let defaults: UserDefaults?
    private let legacyPrefix = "companion.memory.v1."
    private let fileManager = FileManager.default
    private var cache: [UUID: MemoryDocument] = [:]

    public private(set) var lastError: String?

    public init(directory: URL? = nil, defaults: UserDefaults? = nil) {
        self.defaults = defaults
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent("Memory", isDirectory: true)
        }
    }

    // MARK: MemoryStore

    public func load(conversationID: UUID) -> MemoryDocument {
        if let cached = cache[conversationID] { return cached }

        if let data = try? Data(contentsOf: fileURL(conversationID)),
           let document = decode(data) {
            return adopt(document, conversationID: conversationID, persistUpgrade: true)
        }

        // A corrupt primary file should not lose the previous good version.
        if let backup = try? Data(contentsOf: backupURL(conversationID)),
           let document = decode(backup) {
            #if os(iOS)
            try? backup.write(to: fileURL(conversationID), options: [.atomic, .completeFileProtection])
            #else
            try? backup.write(to: fileURL(conversationID), options: [.atomic])
            #endif
            return adopt(document, conversationID: conversationID, persistUpgrade: true)
        }

        // One-time migration from the pre-file store.
        if let defaults,
           let legacy = defaults.data(forKey: legacyKey(conversationID)),
           let document = decode(legacy) {
            var migrated = document
            migrated.schemaVersion = Self.currentSchemaVersion
            save(migrated, conversationID: conversationID)
            return migrated
        }

        let empty = MemoryDocument()
        cache[conversationID] = empty
        return empty
    }

    public func save(_ document: MemoryDocument, conversationID: UUID) {
        var value = document
        value.schemaVersion = max(Self.currentSchemaVersion, value.schemaVersion)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = fileURL(conversationID)
            if fileManager.fileExists(atPath: url.path) {
                let backup = backupURL(conversationID)
                try? fileManager.removeItem(at: backup)
                try? fileManager.copyItem(at: url, to: backup)
                #if os(iOS)
                try? fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: backup.path
                )
                #endif
            }
            let data = try JSONEncoder().encode(value)
            #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: url, options: [.atomic])
            #endif
            cache[conversationID] = value
            lastError = nil
        } catch {
            // Keep the in-memory copy so the current session is not lost.
            cache[conversationID] = value
            lastError = "记忆文件写入失败，请检查本机存储空间。"
        }
    }

    public func delete(conversationID: UUID) {
        try? fileManager.removeItem(at: fileURL(conversationID))
        try? fileManager.removeItem(at: backupURL(conversationID))
        defaults?.removeObject(forKey: legacyKey(conversationID))
        cache.removeValue(forKey: conversationID)
    }

    // MARK: Private

    private func adopt(
        _ document: MemoryDocument,
        conversationID: UUID,
        persistUpgrade: Bool
    ) -> MemoryDocument {
        var value = document
        if value.schemaVersion < Self.currentSchemaVersion {
            value.schemaVersion = Self.currentSchemaVersion
            if persistUpgrade {
                save(value, conversationID: conversationID)
            }
        }
        cache[conversationID] = value
        return value
    }

    private func decode(_ data: Data) -> MemoryDocument? {
        try? JSONDecoder().decode(MemoryDocument.self, from: data)
    }

    private func fileURL(_ id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func backupURL(_ id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json.bak")
    }

    private func legacyKey(_ id: UUID) -> String {
        legacyPrefix + id.uuidString
    }
}
