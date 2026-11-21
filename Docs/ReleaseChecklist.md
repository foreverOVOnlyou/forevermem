# Release checklist — 0.1.0

## Before creating the repository

- [ ] Confirm `Copyright (c) 2026 foreverOVOnlyou` and the X profile link in `LICENSE`.
- [ ] Confirm the repository name and URL (`foreverOVOnlyou/foreverloom`).
- [ ] Confirm no app-specific secrets, chat exports or API keys are present.
- [ ] Confirm `THIRD_PARTY_NOTICES.md` still matches the source.
- [ ] Run `swift test` (5 tests).
- [ ] Run `swift run ForeverloomCLI`.
- [ ] Build the host app against the package (monorepo only).
- [ ] Confirm `.build/` and `.swiftpm/` are not committed.
- [ ] Check CI workflow path:
  - monorepo: root `.github/workflows/foreverloom.yml`
  - standalone repo: package `.github/workflows/ci.yml`

## Create the standalone repository

Do not initialize a nested git repo inside the existing app checkout. Copy the package out first:

```bash
cp -R Packages/Foreverloom /tmp/Foreverloom
cd /tmp/Foreverloom
git init
git add .
git commit -m "Foreverloom 0.1.0"
```

Create the remote repository, then:

```bash
git remote add origin git@github.com:foreverOVOnlyou/foreverloom.git
git branch -M main
git push -u origin main
git tag -a 0.1.0 -m "Foreverloom 0.1.0"
git push origin 0.1.0
```

## After publishing

- [ ] CI is green.
- [ ] GitHub release notes copy `CHANGELOG.md` 0.1.0.
- [ ] Verify the standalone README commands from the new repository root.
- [ ] Optionally switch the app from local path to remote package:
      `.package(url: "https://github.com/foreverOVOnlyou/foreverloom.git", from: "0.1.0")`
- [ ] Keep `Packages/Foreverloom` in the app repo until the remote package is verified.

## Versioning

- 0.x: API may change.
- Document storage/schema changes in `CHANGELOG.md`.
- Do not publish user data or real conversation fixtures.
