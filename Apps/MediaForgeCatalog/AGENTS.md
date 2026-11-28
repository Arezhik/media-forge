# MediaForgeCatalog

Internal developer catalog for MediaForge. Not shipped. Not part of `.github/workflows/release.yml`.

## Layout

- `Package.swift` — `MediaForgeCatalogKit`, product `MediaForgeCatalogCore`. Static pages, the used-in table, and search. No AppKit or SwiftUI, so Linux `swift test` covers it.
- `App/` — SwiftUI app `MediaForgeCatalog.xcodeproj`. Depends on `MediaForgeCatalogCore` and MediaUI. Does not link MediaTesting (that pulls XCTest). MediaTesting pages are static rows in the core table.
- `App/CatalogUITests` — three smoke tests. CI builds them (`build-for-testing`) and does not run them.
- `Sources/MediaForgeCatalogCore/CatalogIndex.swift` — hand-maintained used-in table. Update it when an app adopts or drops a type.

## Rules

- Never hand-edit `App/MediaForgeCatalog.xcodeproj/project.pbxproj`. Edit `App/project.yml` and regenerate with `./scripts/verify-linux.sh` from `Apps/MediaForgeCatalog`, or `./scripts/verify-linux.sh mediaforgecatalog` from the repo root.
- Don't rename the package to `MediaForgeCatalog`. The Xcode project uses that name.
- Debug does not set `ARCHS` (`ONLY_ACTIVE_ARCH=YES`). Release is arm64 and x86_64.
- The commit in the Overview footer and the About panel is `MFCatalogCommit`, written into the built Info.plist by the post-build script in `project.yml`.
- Version with `scripts/bump-version.sh mediaforgecatalog` from the repo root. This app is not released.
