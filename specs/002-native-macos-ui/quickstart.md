# Quickstart: Tiffen macOS App

## Prerequisites

- macOS 14+ on Apple Silicon
- Xcode 15+ (for Metal compiler and XCTest)
- libtiff (`brew install libtiff`)
- XcodeGen (`brew install xcodegen`)

## Build

```bash
# Generate Xcode project (three targets: TiffenCore, tiffen, tiffenApp)
xcodegen generate

# Build the GUI app (automatically builds TiffenCore framework)
xcodebuild -scheme tiffenApp -configuration Release

# Build the CLI tool (automatically builds TiffenCore framework)
xcodebuild -scheme tiffen -configuration Release
```

## Run the App

```bash
# Open in Xcode and run
open tiffen.xcodeproj
# Select "tiffenApp" scheme, then ⌘R

# Or run the built app directly
open "$(xcodebuild -scheme tiffenApp -showBuildSettings | grep -m1 BUILT_PRODUCTS_DIR | awk '{print $3}')/Tiffen.app"
```

## Basic Usage

1. **Select base TIFF**: Click "Browse..." next to "Base TIFF" or press ⌘O.
   Choose the reference image whose exposure range others will match.

2. **Select input directory**: Click "Browse..." next to "Input Dir" or
   press ⇧⌘O. Choose the directory containing TIFFs to normalize.

3. **Configure output** (optional): The output directory defaults to
   `<input-dir>/normalized/`. Click "Browse..." to change it, or enable
   "Overwrite originals" in Settings (⌘,) for in-place mode.

4. **Click Normalize** (or press ⌘R): Processing begins. The file list
   populates with real-time status and timing for each file.

5. **View histograms**: Click any completed file in the list to see
   before/after per-channel histograms showing the exposure shift.

## Settings (⌘,)

| Setting | Default | Description |
|---------|---------|-------------|
| CPU usage limit | 90% | Max percentage of CPU cores for parallel workers |
| Memory usage limit | 90% | Max percentage of RAM for parallel workers |
| Max parallel jobs | Auto (0) | Hard cap on concurrency (0 = compute from CPU/memory) |
| Overwrite originals | Off | Enable in-place mode (destructive) |
| Show per-file timing | On | Display per-step timing columns in file list |

All settings persist between launches via NSUserDefaults.

## Project Architecture

```
┌────────────────────────────────────────┐
│         TiffenCore.framework           │
│  (src/ — normalization engine, Metal)  │
│  TFNNormalizer, TFNExposureRange,      │
│  TFNTIFFReader/Writer, Metal shaders,  │
│  TFNHistogramData                      │
└──────────┬─────────────┬───────────────┘
           │             │
     ┌─────┴────┐  ┌─────┴──────────┐
     │  tiffen  │  │   tiffenApp    │
     │  (cli/)  │  │   (app/)       │
     │  CLI     │  │   AppKit GUI   │
     └──────────┘  └────────────────┘
```

Both targets link and embed `TiffenCore.framework`. The framework
compiles the engine once and bundles the Metal shader.

## Run Tests

```bash
# Framework + CLI tests
xcodebuild test -scheme tiffenTests -destination 'platform=macOS'

# App-specific tests
xcodebuild test -scheme tiffenAppTests -destination 'platform=macOS'
```

## File Layout

```
src/                          # TiffenCore framework sources
cli/                          # CLI entry point (main.m)
app/                          # AppKit GUI (Objective-C)
├── main.m
├── TFNAppDelegate.h/m
├── TFNMainWindowController.h/m
├── TFNPreferencesWindowController.h/m
├── TFNFileListDataSource.h/m
├── TFNHistogramView.h/m
├── TFNProcessingEngine.h/m
├── TFNProcessedFileInfo.h/m
└── TFNHistogramData.h/m
tests/                        # Unit + integration tests
tests/app/                    # App-specific tests
```
