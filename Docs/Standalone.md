# Standalone repository

`Packages/Forevermem` is already structured as a standalone Swift Package.

## Extract

```bash
cp -R Packages/Forevermem /tmp/Forevermem
cd /tmp/Forevermem
```

## Verify

```bash
swift test
swift run ForevermemCLI
```

## Publish

```bash
git init
git add .
git commit -m "Forevermem 0.1.0"
git remote add origin git@github.com:foreverOVOnlyou/forevermem.git
git branch -M main
git push -u origin main
git tag -a 0.1.0 -m "Forevermem 0.1.0"
git push origin 0.1.0
```

The package's `.github/workflows/ci.yml` runs `swift test` and the CLI from the repository root.

## Switch the host app

Replace the local package reference with a remote one:

```swift
.package(url: "https://github.com/foreverOVOnlyou/forevermem.git", from: "0.1.0")
```

Keep the local copy until the remote package resolves and the app builds.
