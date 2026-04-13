# iOS Migration Summary

This document summarizes the changes made to convert the macOS-only app into a single codebase supporting both macOS and iOS.

## Build Settings (`project.pbxproj`)

- Added `IPHONEOS_DEPLOYMENT_TARGET = 16.0`
- Changed `SDKROOT` from `macosx` to `auto`
- Added `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`
- Added proper `NSPhotoLibraryUsageDescription` and `NSLocationWhenInUseUsageDescription` strings

## Platform Abstraction

A `PlatformImage` typealias was added in `ContentView.swift` (`NSImage` on macOS, `UIImage` on iOS) and used throughout all views. Helper functions convert `PlatformImage` to SwiftUI `Image` via `Image(nsImage:)` or `Image(uiImage:)` as appropriate.

## Files Modified

### `CheckrSpotApp.swift`

Wrapped the About panel, `NSApplication` calls, and `.commands` modifier in `#if os(macOS)`.

### `ContentView.swift`

- `HSplitView` → `NavigationSplitView` on iOS
- `Table` with `TableColumn` → `List` on iOS (Table with sortable columns isn't well-supported on iPhone)
- `NSSavePanel` → `UIActivityViewController` share sheet on iOS
- `NSPasteboard` → `UIPasteboard` on iOS
- CGImage extraction uses platform-conditional `let` binding instead of split `guard` statements
- HTTP server code (`startServerIfNeeded`, `viewInBrowser`) wrapped in `#if os(macOS)`
- Added `LabelWebView` and `LabelWebViewRepresentable` for iOS — a `WKWebView`-based view that loads the bundled HTML/CSS/JS with JSON data injected inline, replacing the `fetch('/specimens.json')` call with `Promise.resolve()`

### `EditPhotoView.swift`

- `NSImage` → `PlatformImage`
- Platform-conditional background colors via computed properties (`photoBackground`, `formBackground`)
- Helper function `platformImage(_:)` for `Image(nsImage:)` / `Image(uiImage:)`
- `.menuStyle(.borderlessButton)` macOS-only
- `.frame(minWidth:minHeight:)` macOS-only

### `ThumbnailView.swift`

- `NSImage` → `PlatformImage`
- `NSScreen.main?.backingScaleFactor` → `UIScreen.main.scale` on iOS
- `.onHover` macOS-only
- `.help()` tooltip macOS-only
- Edit button visible on selection (not just hover) for iOS, since there is no hover on touch devices

### `HTTPServer.swift`

Entire file wrapped in `#if os(macOS)` / `#endif`. Not used on iOS at all.

## iOS Label Viewing Approach

On macOS, labels are viewed by opening a browser pointed at the embedded HTTP server (`localhost:8000`).

On iOS, labels are viewed in an in-app `WKWebView` sheet. The bundled `index.html`, `styles.css`, and `script.js` are loaded with:

1. CSS inlined into a `<style>` tag replacing the `<link>` tag
2. JS inlined into a `<script>` tag replacing the `<script src>` tag
3. The `fetch('/specimens.json')` call replaced with `Promise.resolve(...)` containing the JSON data directly

## Prerequisites for iOS Build

The iOS simulator platform must be downloaded from **Xcode → Settings → Components** before building for an iOS destination.
