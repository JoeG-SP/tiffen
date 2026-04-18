# Tasks: Native macOS UI

**Input**: Design documents from `/specs/002-native-macos-ui/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ui-contract.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Exact file paths included in descriptions

---

## Phase 1: Setup

**Purpose**: Create directory structure and configure build system for three-target layout

- [ ] T001 Create `cli/` directory and move `src/main.m` to `cli/main.m`
- [ ] T002 Create `app/` directory structure per plan.md
- [ ] T003a Update `project.yml`: add `TiffenCore` framework target compiling `src/` (exclude `**/*.metal`), linking libtiff (`-ltiff`, `-lz`) and Metal framework, with `DEFINES_MODULE: YES` and public headers: `TFNNormalizer.h`, `TFNExposureRange.h`, `TFNTIFFReader.h`, `TFNTIFFWriter.h`, `TFNMetalNormalizer.h`, `TFNCPUNormalizer.h`
- [ ] T003b Update `project.yml`: update `tiffen` CLI tool target to compile `cli/` only, add `TiffenCore` as embedded dependency, remove direct libtiff/Metal linking (framework provides these)
- [ ] T003c Update `project.yml`: add `tiffenApp` application target compiling `app/`, add `TiffenCore` as embedded dependency, set bundle ID `com.tiffen.app`, link AppKit
- [ ] T004 Add Metal shader pre-build script to `TiffenCore` target in `project.yml` and update shader loading in `TFNMetalNormalizer.m` to load `default.metallib` from `[NSBundle bundleForClass:]` instead of main bundle
- [ ] T005 Run `xcodegen generate` and verify all three targets build successfully with `xcodebuild`

---

## Phase 2: Foundational — Shared Framework Extraction (US5)

**Purpose**: Extract engine into `TiffenCore.framework`. MUST complete before any app work.

**⚠️ CRITICAL**: No GUI work can begin until this phase is complete.

- [ ] T006 [US5] Verify framework public headers are importable: build CLI with `#import <TiffenCore/TFNNormalizer.h>` etc. and confirm no missing-header errors; add any result type headers (e.g., `TFNNormalizationResult.h`) missed in T003a
- [ ] T007 [US5] Update `cli/main.m` to import TiffenCore framework headers (`#import <TiffenCore/TFNNormalizer.h>` etc.) instead of local includes
- [ ] T008 [US5] Retarget existing tests in `tests/unit/` and `tests/integration/` to link against `TiffenCore` framework instead of compiling `src/` sources directly; update `project.yml` `tiffenTests` target accordingly
- [ ] T009 [US5] Build CLI (`xcodebuild -scheme tiffen`) and run full test suite (`xcodebuild test -scheme tiffenTests`) to verify byte-identical output (SC-001)
- [ ] T010 [P] [US5] Create `src/TFNHistogramData.h` and `src/TFNHistogramData.m` — model class with `bins` (float**), `channelCount`, `totalPixels` fields and `+histogramFromRawCounts:channelCount:totalPixels:` class method per data-model.md
- [ ] T011 [US5] Add histogram `device uint*` buffer arguments to range kernel in `src/Shaders/normalize.metal` — atomic bin increment (`atomic_fetch_add_explicit`) fused into min/max reduction per research.md R3
- [ ] T012 [US5] Add histogram `device uint*` buffer arguments to normalize kernel in `src/Shaders/normalize.metal` — atomic bin increment after writing output pixel per research.md R3
- [ ] T013 [US5] Update `TFNMetalNormalizer.m` to allocate histogram `MTLBuffer` (channelCount * 256 * sizeof(uint32)), pass to range and normalize dispatches, and construct `TFNHistogramData` from raw counts after each pass
- [ ] T014 [US5] Update `TFNCPUNormalizer.m` to compute histograms inline during range scan (before) and normalization loop (after), producing `TFNHistogramData` per data-model.md CPU fallback spec
- [ ] T015 [US5] Expose before/after `TFNHistogramData` on normalization result returned by `TFNNormalizer` so consumers (CLI, GUI) can access them
- [ ] T016 [US5] Add `TFNHistogramData.h` to framework public headers in `project.yml`

### Tests for Framework & Histograms (US5)

- [ ] T050 [P] [US5] Create `tests/unit/TFNHistogramDataTests.m` — test `+histogramFromRawCounts:channelCount:totalPixels:` with known uint32 counts; verify normalized bins sum to 1.0 per channel; verify 256 bins per channel; test edge cases (all zeros, single spike, uniform distribution)
- [ ] T051 [US5] Create `tests/unit/TFNHistogramGPUTests.m` — process a known 8-bit test fixture through Metal normalizer; compare before histogram bins against expected distribution computed independently; verify GPU and CPU histogram outputs match within tolerance
- [ ] T052 [US5] Create `tests/unit/TFNHistogramBitDepthTests.m` — test histogram bin calculation for 8-bit (direct mapping), 16-bit (quantized to 256), and 32-bit float (range-mapped) TIFFs; verify bin indices are correct for known pixel values
- [ ] T053 [US5] Create `tests/integration/TFNFrameworkIdentityTests.m` — process the same test directory via `TFNNormalizer` linked from framework; diff output files byte-by-byte against reference output from pre-refactor CLI (SC-001 verification)
- [ ] T054 [US5] Add histogram round-trip test in `tests/unit/TFNHistogramGPUTests.m` — normalize a file to a base, then re-normalize to itself; verify before and after histograms are identical within precision (Constitution Principle II + V: round-trip correctness)

**Checkpoint**: Framework extracted, CLI works identically, histogram data available and tested. Run `xcodebuild test -scheme tiffenTests` to verify.

---

## Phase 3: User Story 1 — Select Files and Normalize (Priority: P1) 🎯 MVP

**Goal**: Main window with file selection, normalization control, progress, and cancellation

**Independent Test**: Launch app, select fixtures, click Normalize, verify output files exist and match CLI output

### Implementation for User Story 1

- [ ] T017 [P] [US1] Create `app/main.m` with `NSApplicationMain` entry point
- [ ] T018 [P] [US1] Create `app/TFNProcessedFileInfo.h` and `app/TFNProcessedFileInfo.m` — per-file result model with `TFNProcessingStatus` enum, timing fields, histogram refs, and exposure ranges per data-model.md
- [ ] T019 [P] [US1] Create `app/TFNProcessingEngine.h` and `app/TFNProcessingEngine.m` — wraps `TFNNormalizer`, manages `NSMutableArray<TFNProcessedFileInfo*>`, posts `TFNProcessingDidStartNotification`, `TFNProcessingFileDidUpdateNotification`, `TFNProcessingDidFinishNotification` on main queue per data-model.md; reads concurrency settings from `NSUserDefaults`; supports cancellation (stops dispatching new files)
- [ ] T020 [US1] Create `app/TFNAppDelegate.h` and `app/TFNAppDelegate.m` — sets up main window via `TFNMainWindowController`, creates menu bar (Tiffen, File, Processing menus per ui-contract.md), registers default NSUserDefaults values
- [ ] T021 [US1] Create `app/TFNMainWindowController.h` and `app/TFNMainWindowController.m` — programmatic window (900x600, min 700x500) with: three path `NSTextField` fields (read-only) + Browse `NSButton` pairs for base TIFF / input dir / output dir, Normalize/Stop `NSButton`, `NSProgressIndicator` (determinate), `NSTableView` for file list, summary `NSTextField` per ui-contract.md layout
- [ ] T022 [US1] Implement `NSOpenPanel` Browse actions in `TFNMainWindowController.m` — base TIFF filters `.tiff`/`.tif`, input/output use directory mode; save selected paths to `NSUserDefaults` on selection
- [ ] T023 [US1] Implement drag-and-drop on path `NSTextField` fields in `TFNMainWindowController.m` — `registerForDraggedTypes:` with `NSPasteboardTypeFileURL`, validate file vs directory per field, update path and save to `NSUserDefaults`
- [ ] T024 [US1] Implement Normalize/Stop button logic in `TFNMainWindowController.m` — disabled until base + input selected; starts `TFNProcessingEngine`; toggles to "Stop" while running; on Stop, cancels engine
- [ ] T025 [US1] Implement cancellation dialog in `TFNMainWindowController.m` — on cancellation with written files, show `NSAlert` with "Keep Files" / "Delete Files" buttons per ui-contract.md Cancellation Dialog; delete removes only batch-written files
- [ ] T026 [US1] Create `app/TFNFileListDataSource.h` and `app/TFNFileListDataSource.m` — conforms to `NSTableViewDataSource` and `NSTableViewDelegate`; columns: File, Status, Total Time; updates via `TFNProcessingFileDidUpdateNotification` calling `reloadDataForRowIndexes:columnIndexes:`; status icons (checkmark, spinner, error, pending)
- [ ] T027a [US1] Add cumulative timing computation to `TFNProcessingEngine.m` — on each file completion, accumulate read/range/normalize/write totals and wall clock time into inline properties (per data-model.md TFNCumulativeTiming); expose via readonly properties for summary bar display
- [ ] T027b [US1] Wire `TFNMainWindowController` to observe `TFNProcessingEngine` notifications — update progress bar, summary label (including cumulative timing), and file list on each file update; update summary on finish
- [ ] T028 [US1] Implement path restoration on launch in `TFNAppDelegate.m` — read last base TIFF, input dir, output dir from `NSUserDefaults` and populate `TFNMainWindowController` path fields; validate paths still exist (disable Normalize if stale)
- [ ] T029 [US1] Implement keyboard shortcuts — ⌘O (browse base), ⇧⌘O (browse input), ⌘R (start/stop normalize), ⌘. (stop) via menu item key equivalents in `TFNAppDelegate.m`

### Tests for User Story 1

- [ ] T055 [P] [US1] Create `tests/app/TFNProcessingEngineTests.m` — test engine lifecycle: start posts `TFNProcessingDidStartNotification`, file updates post `TFNProcessingFileDidUpdateNotification` with correct index, finish posts `TFNProcessingDidFinishNotification` with summary; test cancellation stops new file dispatch; verify all notifications arrive on main queue
- [ ] T056 [P] [US1] Create `tests/app/TFNProcessedFileInfoTests.m` — test status transitions (Pending→Processing→Completed, Pending→Skipped, Processing→Error); verify timing fields are -1 until set; verify errorMessage only non-nil for Error status
- [ ] T057 [US1] Create `tests/integration/TFNGUICLIOutputMatchTests.m` — process same test fixtures directory via `TFNProcessingEngine` (GUI path) and `TFNNormalizer` (CLI path); diff all output files byte-by-byte to verify SC-002 (GUI matches CLI output)

**Checkpoint**: App launches, user can select files (browse + drag-and-drop), run normalization with progress, cancel with cleanup dialog. Output matches CLI. Tests verify engine notifications and GUI/CLI output parity.

---

## Phase 4: User Story 2 — Persistent Preferences (Priority: P1)

**Goal**: Preferences window with all settings, persisted via NSUserDefaults + Cocoa Bindings

**Independent Test**: Change preferences, quit, relaunch — all values retained. In-place toggle disables output field.

### Implementation for User Story 2

- [ ] T030 [US2] Create `app/TFNPreferencesWindowController.h` and `app/TFNPreferencesWindowController.m` — programmatic window with: CPU `NSSlider` (1–100) + value label, Memory `NSSlider` (1–100) + value label, Max Jobs `NSTextField` + `NSStepper` (0–64), In-place `NSButton` checkbox, Per-file timing `NSButton` checkbox per ui-contract.md Preferences layout
- [ ] T031 [US2] Bind all preferences controls to `NSUserDefaultsController` via Cocoa Bindings — keys: `TFNCPUPercent`, `TFNMemPercent`, `TFNMaxJobs`, `TFNInPlace`, `TFNShowPerFileTiming` per data-model.md TFNAppSettings
- [ ] T032 [US2] Add Settings menu item (⌘,) in `TFNAppDelegate.m` that opens `TFNPreferencesWindowController`
- [ ] T033 [US2] Observe `TFNInPlace` default in `TFNMainWindowController.m` — when toggled, disable/enable output directory field and Browse button; show "(in-place)" placeholder text when disabled
- [ ] T034 [US2] Wire `TFNProcessingEngine` to read `TFNCPUPercent`, `TFNMemPercent`, `TFNMaxJobs`, `TFNInPlace` from `NSUserDefaults` at normalization start and pass to `TFNNormalizer`

### Tests for User Story 2

- [ ] T058 [US2] Create `tests/app/TFNAppSettingsTests.m` — write each preference key to `NSUserDefaults`, read back via standard defaults, verify all values round-trip correctly (SC-004 verification); test clamping: set cpuPercent to 0 and 150, verify clamped to 1 and 100; test mutual exclusion: set inPlace=YES, verify outputDirectoryOverride is ignored by engine

**Checkpoint**: All settings persist across quit/relaunch, validated by tests. In-place mode disables output field. Concurrency settings affect processing.

---

## Phase 5: User Story 3 — View Processing Stats (Priority: P2)

**Goal**: Detailed per-file timing columns with sortable table

**Independent Test**: Process a directory, verify all timing columns populated, click headers to sort.

### Implementation for User Story 3

- [ ] T035 [US3] Add per-step timing columns to `TFNFileListDataSource.m` — Read, Range, Normalize, Write columns alongside existing File, Status, Total Time; format as seconds with 2 decimal places
- [ ] T036 [US3] Implement column visibility toggle in `TFNFileListDataSource.m` — observe `TFNShowPerFileTiming` user default; show/hide Read, Range, Normalize, Write columns dynamically via `setHidden:` on `NSTableColumn`
- [ ] T037 [US3] Implement column sorting in `TFNFileListDataSource.m` — set `sortDescriptorPrototype` on each `NSTableColumn`; implement `tableView:sortDescriptorsDidChange:` to re-sort `files` array and reload table
- [ ] T038 [US3] Add error/warning tooltips in `TFNFileListDataSource.m` — error rows show `NSImageNameCaution` icon in status column with `errorMessage` as tooltip; flat-exposure warnings show warning icon with channel info

### Tests for User Story 3

- [ ] T059 [US3] Create `tests/app/TFNFileListDataSourceTests.m` — test sort descriptors: populate data source with known file infos with varying times, apply sort by each column (name, status, totalTime, readTime, writeTime), verify order is correct; test column visibility toggle: set `TFNShowPerFileTiming` to NO, verify per-step columns report hidden

**Checkpoint**: File list shows all timing data, sorting works on all columns, errors show tooltips. Tests verify sort correctness and column toggling.

---

## Phase 6: User Story 4 — Before/After Histograms (Priority: P2)

**Goal**: Popover with side-by-side per-channel histograms on row click

**Independent Test**: Process a known TIFF, click its row, verify before/after histograms appear with correct channel colors and range labels.

### Implementation for User Story 4

- [ ] T039 [P] [US4] Create `app/TFNHistogramView.h` and `app/TFNHistogramView.m` — custom `NSView` subclass; `drawRect:` renders 256-bin histogram using `CGContextBeginPath`/`CGContextAddLineToPoint`/`CGContextFillPath` with per-channel semi-transparent colors (R=1,0,0,0.4; G=0,1,0,0.4; B=0,0,1,0.4; Gray=0.5,0.5,0.5,0.6) per ui-contract.md; accepts `TFNHistogramData*` via setter; `accessibilityLabel` describes data range
- [ ] T040 [US4] Create histogram popover view controller in `app/TFNMainWindowController.m` — `NSPopover` with `NSPopoverBehaviorTransient`, 480x300 pt content view containing: file name label, two `TFNHistogramView` instances (before/after) in `NSStackView`, channel color legend, range label (`[min, max] → [min, max]`), metadata label (bit depth, channels) per ui-contract.md Histogram Popover
- [ ] T041 [US4] Wire row click in `TFNFileListDataSource.m` to show histogram popover — on `tableViewSelectionDidChange:`, if selected file has `status == TFNProcessingStatusCompleted`, show popover anchored to selected row rect with `NSRectEdgeMaxY`; if not completed, do nothing
- [ ] T042 [US4] Populate `TFNProcessedFileInfo` histogram fields from `TFNProcessingEngine` — after each file completes, extract `beforeHistogram` and `afterHistogram` from framework normalization result and assign to the file info

### Tests for User Story 4

- [ ] T060 [US4] Create `tests/app/TFNHistogramViewTests.m` — instantiate `TFNHistogramView` with known `TFNHistogramData` (single channel, uniform distribution); call `drawRect:` into a bitmap context; verify pixels at expected positions are non-transparent (histogram area is drawn); test with nil data produces empty view; verify accessibilityLabel is non-empty when data is set
- [ ] T061 [US4] Create `tests/integration/TFNHistogramAccuracyTests.m` — process a known 8-bit test fixture with predetermined pixel distribution; extract `beforeHistogram` from result; verify specific bin values match expected counts (SC-006 verification); repeat for 16-bit and 32-bit float fixtures

**Checkpoint**: Clicking a completed row shows popover with before/after histograms, correct colors, range labels. Clicking away dismisses. Tests verify histogram rendering and bin accuracy across bit depths.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final integration, edge cases, accessibility, performance validation

- [ ] T043 Implement edge case: stale NSUserDefaults paths — in `TFNMainWindowController.m`, on launch validate restored paths exist; if not, show stale path but keep Normalize disabled
- [ ] T044 Implement edge case: empty directory — in `TFNProcessingEngine.m`, if no TIFF files found, post finish notification immediately with "0 files to process" summary
- [ ] T045 Implement edge case: fatal errors — in `TFNMainWindowController.m`, before starting engine validate base TIFF exists and is readable, input directory exists; show `NSAlert` with `NSAlertStyleCritical` if not
- [ ] T046 [P] Add accessibility labels to all controls in `TFNMainWindowController.m` and `TFNPreferencesWindowController.m` via `setAccessibilityLabel:`
- [ ] T047 [P] Add app icon and `Info.plist` configuration in `project.yml` for `tiffenApp` target — bundle ID `com.tiffen.app`, display name "Tiffen"
- [ ] T048 Update `README.md` to document both CLI and GUI usage, build instructions for all three targets
- [ ] T049 Run quickstart.md validation — build all targets, launch app, process test fixtures, verify output
- [ ] T062 [P] Create `tests/app/TFNResponsivenessTests.m` — start normalization on a directory of 100+ test fixtures; use `XCTMeasureBlock` to verify main thread is never blocked >100ms during processing (SC-003 validation); verify `NSProgressIndicator` updates arrive within 200ms of file completion
- [ ] T063 [P] Create `tests/app/TFNHistogramRenderingPerfTests.m` — instantiate `TFNHistogramView` with 4-channel histogram data; render into bitmap context inside `XCTMeasureBlock`; verify single `drawRect:` completes in <16ms (SC-005 validation, 60fps capable)
- [ ] T064 Verify no Swift files in project — run `find app/ cli/ src/ -name "*.swift"` and assert empty result; ensure `project.yml` has no Swift-related settings (FR-014 enforcement)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all GUI work
- **US1 (Phase 3)**: Depends on Phase 2 — core GUI functionality
- **US2 (Phase 4)**: Depends on Phase 2 — can run in parallel with US1 but preferences wire into main window
- **US3 (Phase 5)**: Depends on US1 (extends file list from Phase 3)
- **US4 (Phase 6)**: Depends on US1 (needs file list) + Phase 2 (needs histogram data from framework)
- **Polish (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

- **US5 (Framework)**: Phase 2 — foundational, blocks everything
- **US1 (Normalize)**: After Phase 2 — independent
- **US2 (Preferences)**: After Phase 2 — independent, but integrates with US1 main window
- **US3 (Stats)**: After US1 — extends file list table
- **US4 (Histograms)**: After US1 + Phase 2 — needs file list + framework histogram data

### Within Each User Story

- Models/data types before engine/services
- Engine before window controllers
- Window controllers before wiring/integration

### Parallel Opportunities

- T017, T018, T019 can run in parallel (app entry, models, engine — different files)
- T010 can run in parallel with T006–T009 (histogram model vs framework config)
- T050, T051, T052 (histogram tests) can run in parallel — different test files
- T011, T012 touch the same shader file — must be sequential
- T055, T056 (US1 tests) can run in parallel — different test files
- T035–T038 (US3) can start as soon as US1 file list exists
- T039 (histogram view) can run in parallel with T040–T042
- T062, T063 (perf tests) can run in parallel — different test files

---

## Parallel Example: Phase 2 (Framework)

```
# These touch different files and can run in parallel:
T010: Create TFNHistogramData.h/m in src/
T006: Configure public headers in project.yml

# These must be sequential (same shader file):
T011: Add histogram to range kernel in normalize.metal
T012: Add histogram to normalize kernel in normalize.metal (after T011)
T013: Update TFNMetalNormalizer.m (after T011, T012)
```

## Parallel Example: User Story 1

```
# Launch models + entry point together:
T017: Create app/main.m
T018: Create TFNProcessedFileInfo.h/m
T019: Create TFNProcessingEngine.h/m

# Then sequential UI wiring:
T020: TFNAppDelegate (depends on T017)
T021: TFNMainWindowController (depends on T018, T019)
T022-T029: Wiring (depends on T021)
```

---

## Implementation Strategy

### MVP First (US5 + US1)

1. Complete Phase 1: Setup (T001–T005)
2. Complete Phase 2: Framework + Histograms + Tests (T006–T016, T050–T054)
3. Complete Phase 3: Main window + normalization + Tests (T017–T029, T055–T057)
4. **STOP and VALIDATE**: Run all tests green; app launches, processes files, output matches CLI
5. This delivers a functional GUI with file selection, progress, cancellation, and verified correctness

### Incremental Delivery

1. Setup + Framework + Tests → CLI still works, histograms available and tested
2. Add US1 + Tests → App runs normalizations, GUI/CLI parity verified → **MVP!**
3. Add US2 + Tests → Preferences persist, validated by tests → Quality of life
4. Add US3 + Tests → Detailed stats, sort correctness verified → Power user feature
5. Add US4 + Tests → Histograms, bin accuracy verified → Visual verification
6. Polish + Perf tests → Edge cases, accessibility, SC-003/SC-005 validation

---

## Notes

- All code MUST be Objective-C — no Swift files
- Framework loads Metal shader from its own bundle, not main bundle
- Cocoa Bindings handle preferences persistence — no manual NSUserDefaults sync code in preferences window
- Histogram computation is in the framework (GPU-fused) — app only displays the data
- CLI target is unchanged except for import paths (framework headers vs local)
