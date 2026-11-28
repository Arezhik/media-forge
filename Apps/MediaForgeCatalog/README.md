# MediaForgeCatalog

Internal developer catalog for the MediaForge library. It is not shipped and has no release tag.

- **MediaUI** pages call the real helpers: `FileDrop`, `FilePanels`, `Reveal`, and `DebugLogExport`.
- **MediaTesting** pages are static reference for the XCUITest types. The app does not link MediaTesting.

Open `Apps/MediaForgeCatalog/App/MediaForgeCatalog.xcodeproj`. The package `MediaForgeCatalogKit` (module `MediaForgeCatalogCore`) holds the hand-maintained used-in table and search index. Version 0.1.0 (build 1). Workflow: `.github/workflows/mediaforgecatalog.yml`.

The used-in table in `Sources/MediaForgeCatalogCore/CatalogIndex.swift` is updated by hand when an app adopts or drops a type.
