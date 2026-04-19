# Implementation Plan: Native macOS UI

**Branch**: `002-native-macos-ui` | **Date**: 2026-04-18 | **Spec**: [spec.md](spec.md)
**Input**: User description: "Add a UI that includes all existing settings. Base file and directory selection on main page. Options in preferences dialog, persisted between runs. Last selected directories persist. Scrollable processed file list with stats. Before/after histogram view. Core functionality in a shared dylib used by both CLI and GUI."

## Summary

Refactor the existing Objective-C normalization engine into a shared
framework (`TiffenCore.framework`) and add a native macOS GUI application
alongside the existing CLI tool. Both the CLI and GUI link against the
shared framework. The app wraps the engine in an AppKit interface — all
in Objective-C. Users select a base TIFF and input directory on the main
window, configure processing options in a preferences dialog, and view
results in a scrollable NSTableView with per-file stats and before/after
histogram charts rendered with Core Graphics. Histograms are computed on
the GPU by fusing atomic binning into the existing Metal passes — the
before histogram during range reduction, the after histogram during
normalization — avoiding any extra data traversals.

## Technical Context

**Language/Version**: Objective-C (Clang/Apple toolchain, macOS 14+ SDK)
**Primary Dependencies**: AppKit, Metal framework, libtiff, Core Graphics (histogram rendering)
**Storage**: NSUserDefaults for preferences; filesystem for TIFF I/O
**Testing**: XCTest (unit for framework + app; integration for CLI + window lifecycle)
**Target Platform**: macOS 14+ on Apple Silicon
**Project Type**: Framework + CLI tool + desktop application (three targets)
**Performance Goals**: UI remains responsive during batch processing; histogram rendering < 16ms (60 fps)
**Constraints**: Apple Silicon only; Objective-C only; single shared framework for core logic
**Scale/Scope**: Single-window app with preferences dialog; handles directories of 1–10,000 files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Data Safety | PASS | Same defaults as CLI: output to separate directory. In-place requires explicit toggle in preferences. |
| II. Correctness First | PASS | Single compiled copy of normalization engine in shared framework. CLI and GUI use identical code paths. |
| III. CLI-First | PASS with justification | CLI remains fully functional and unchanged (links framework instead of compiling sources directly). GUI is an additional interface, not a replacement. |
| IV. Simplicity | PASS with justification | Constitution says "no GUI layers unless explicitly requested." User has explicitly requested a GUI. Framework extraction is justified by eliminating duplicate compilation and enforcing API boundary. Minimal dependencies — AppKit and Core Graphics are system frameworks. Single language (Objective-C) throughout. |
| V. Testability | PASS | Framework is independently testable. Processing engine wrapper is testable. Histogram computation is pure function. |

No unresolved violations. Gate passed.

**Post-Phase 1 re-check**: Constitution principles remain satisfied. The
framework extraction improves correctness (single code path) and
testability (framework tests independent of CLI/GUI). Single language
maintained throughout.

## Project Structure

### Documentation (this feature)

```text
specs/002-native-macos-ui/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── ui-contract.md   # Window layout, preferences schema, histogram spec
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```
src/                                    TiffenCore framework (shared engine)
  TFNExposureRange.h/m                  Public: per-channel min/max
  TFNNormalizer.h/m                     Public: orchestrator, parallel dispatch
  TFNMetalNormalizer.h/m                Public: GPU-accelerated normalization
  TFNCPUNormalizer.h/m                  Public: CPU reference implementation
  TFNTIFFReader.h/m                     Public: TIFF I/O (read)
  TFNTIFFWriter.h/m                     Public: TIFF I/O (write)
  TFNHistogramData.h/m                  Public: per-channel 256-bin histogram (GPU-fused)
  Shaders/
    normalize.metal                     Embedded in framework bundle

cli/                                    CLI tool target
  main.m                                Entry point, argument parsing (moved from src/)

app/                                    AppKit application target (Objective-C)
  main.m                                NSApplicationMain entry point
  TFNAppDelegate.h/m                    App delegate, window setup, menu
  TFNMainWindowController.h/m           Main window: file pickers, run, file list
  TFNPreferencesWindowController.h/m    Preferences window with Cocoa Bindings
  TFNFileListDataSource.h/m             NSTableView data source and delegate
  TFNHistogramView.h/m                  Custom NSView, Core Graphics drawing
  TFNProcessingEngine.h/m              Observable wrapper around TFNNormalizer
  TFNProcessedFileInfo.h/m              Per-file result model

tests/                                  Existing tests (retargeted to framework)
  unit/
    TFNExposureRangeTests.m
    TFNCPUNormalizerTests.m
    TFNMetalNormalizerTests.m
    TFNHistogramDataTests.m             NEW: histogram model tests
    TFNHistogramGPUTests.m              NEW: GPU vs CPU histogram comparison
    TFNHistogramBitDepthTests.m         NEW: bin calculation per bit depth
  integration/
    TFNEndToEndTests.m
    TFNInPlaceTests.m
    TFNCLITests.m
    TFNEdgeCaseTests.m
    TFNProgressTests.m
    TFNFrameworkIdentityTests.m         NEW: byte-identical output (SC-001)
    TFNGUICLIOutputMatchTests.m         NEW: GUI matches CLI (SC-002)
    TFNHistogramAccuracyTests.m         NEW: bin accuracy (SC-006)
  app/                                  NEW: App-specific tests
    TFNProcessingEngineTests.m
    TFNProcessedFileInfoTests.m
    TFNAppSettingsTests.m
    TFNFileListDataSourceTests.m
    TFNHistogramViewTests.m
    TFNResponsivenessTests.m            NEW: main thread <100ms (SC-003)
    TFNHistogramRenderingPerfTests.m    NEW: drawRect <16ms (SC-005)
  fixtures/
```

**Structure Decision**: Three-target layout. `TiffenCore.framework` compiles
the engine once and bundles the Metal shader. Both `tiffen` (CLI) and
`tiffenApp` (GUI) link and embed the framework. CLI entry point moves from
`src/main.m` to `cli/main.m`. All Objective-C, no bridging headers.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| GUI layer (Principle IV) | User explicitly requested a native macOS UI | N/A — constitution permits GUI when explicitly requested |
| 3 targets instead of 1 | Shared framework eliminates duplicate compilation, enforces API boundary | Compiling same sources into 2 targets risks divergence and doubles build time |
