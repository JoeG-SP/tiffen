# Feature Specification: Native macOS UI

**Feature Branch**: `002-native-macos-ui`
**Created**: 2026-04-18
**Status**: Draft
**Input**: User description: "Add a UI that includes all existing settings. Base file and directory selection on main page. Options in preferences dialog, persisted between runs. Last selected directories persist. Scrollable processed file list with stats. Before/after histogram view. Core functionality in a shared dylib used by both CLI and GUI. Objective-C only."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Select Files and Normalize (Priority: P1)

A user launches the Tiffen app, selects a base TIFF file and an input
directory via Browse dialogs, and clicks Normalize. The app processes
all TIFF files in the directory using the shared TiffenCore framework,
showing real-time progress in a file list table. Normalized files are
written to the output directory.

**Why this priority**: Core reason the GUI exists — visual file selection
and progress monitoring replace CLI arguments and terminal output.

**Independent Test**: Launch app, select known test fixtures via
NSOpenPanel, click Normalize, verify output files match expected
normalization results.

**Acceptance Scenarios**:

1. **Given** the app is launched, **When** the user selects a base TIFF
   and input directory, **Then** the Normalize button becomes enabled.
2. **Given** valid selections, **When** the user clicks Normalize,
   **Then** the file list populates with all TIFF files showing real-time
   status transitions (Pending → Processing → Completed).
3. **Given** processing is running, **When** the user clicks Stop (⌘.),
   **Then** in-flight files complete but no new files are started.
4. **Given** the user cancels a batch with files already written,
   **When** cancellation completes, **Then** a dialog asks whether to
   keep or delete the already-written output files.

---

### User Story 2 - Persistent Preferences (Priority: P1)

A user opens Settings (⌘,), adjusts CPU limit to 50%, memory limit to
75%, and enables in-place mode. They close and relaunch the app. All
settings are preserved. The main window reflects in-place mode (output
directory field disabled).

**Why this priority**: Persistence is a core requirement — users should
not re-enter settings each session.

**Independent Test**: Set preferences, quit app, relaunch, verify all
values match via NSUserDefaults reads.

**Acceptance Scenarios**:

1. **Given** the user changes any preference, **When** the app is
   relaunched, **Then** the preference retains its last value.
2. **Given** in-place mode is enabled, **When** the main window is
   displayed, **Then** the output directory field is disabled.
3. **Given** the user selects a base TIFF and input directory, **When**
   the app is relaunched, **Then** the last-used paths are restored.

---

### User Story 3 - View Processing Stats (Priority: P2)

A user processes a directory and scrolls through the file list to
review per-file timing stats. They can sort by any column (name,
status, total time, read, write) by clicking column headers.

**Why this priority**: Visibility into processing performance is
important for users tuning concurrency or diagnosing slow files.

**Independent Test**: Process a directory with known files, verify all
timing columns are populated and sorting works correctly.

**Acceptance Scenarios**:

1. **Given** processing completes, **When** the user views the file list,
   **Then** each completed file shows total time, read, range, normalize,
   and write durations.
2. **Given** the file list is populated, **When** the user clicks a
   column header, **Then** rows sort by that column (ascending/descending
   toggle).
3. **Given** a file fails, **When** the user views its row, **Then**
   the status shows an error icon and the tooltip displays the error
   message.

---

### User Story 4 - Before/After Histograms (Priority: P2)

A user selects a completed file in the file list. A histogram panel
appears showing side-by-side before and after per-channel histograms
with channel color coding and exposure range labels.

**Why this priority**: Visual verification that normalization shifted
the exposure range correctly. Key differentiator over CLI.

**Independent Test**: Process a known test TIFF, select it in the list,
verify histogram bin values match expected distribution.

**Acceptance Scenarios**:

1. **Given** a completed file is selected, **When** the histogram panel
   appears, **Then** it shows before and after histograms side by side.
2. **Given** an RGB TIFF, **When** histograms are displayed, **Then**
   each channel is rendered in its representative color (R/G/B) with
   semi-transparent overlay.
3. **Given** a file with status other than Completed, **When** selected,
   **Then** the histogram popover does not appear.

---

### User Story 5 - Shared Framework Architecture (Priority: P1)

The normalization engine is extracted into `TiffenCore.framework`. Both
the CLI tool and the GUI app link and embed the framework. The CLI
continues to work identically — this is a transparent refactor.

**Why this priority**: Architectural prerequisite for the GUI. Ensures
single source of truth for normalization logic.

**Independent Test**: Build and run the CLI tool linked against the
framework. Verify output is byte-identical to the pre-refactor CLI.

**Acceptance Scenarios**:

1. **Given** the framework is built, **When** the CLI tool runs a
   normalization, **Then** output files are identical to pre-refactor.
2. **Given** the framework is built, **When** the GUI app runs the same
   normalization, **Then** output files match the CLI output.
3. **Given** Metal shaders are embedded in the framework bundle, **When**
   the CLI or GUI loads the framework, **Then** GPU normalization works
   without additional shader files alongside the binary.

---

### Edge Cases

- What happens when the user selects a non-existent path restored from
  NSUserDefaults? The path field shows the stale path; the Normalize
  button remains disabled. No error until the user clicks Normalize.
- What happens when the user resizes the window below minimum size?
  The window enforces a minimum size of 700 x 500 pt.
- What happens when the user starts a second normalization while one
  is running? The Normalize button shows "Stop" while running; clicking
  it cancels the current batch. A new normalization cannot start until
  the current one finishes or is cancelled.
- What happens when no TIFF files exist in the selected directory?
  Processing completes immediately with "0 files to process" in the
  summary bar. No error.
- What happens when the histogram popover is shown but the user clicks
  outside it? The popover dismisses (standard NSPopover behavior).

## Clarifications

### Session 2026-04-18

- Q: On batch cancellation, keep partial output or clean up? → A: Ask the user via dialog whether to keep or delete already-written files.
- Q: Support drag-and-drop for file/directory selection? → A: Yes, support drag-and-drop onto path fields in addition to Browse buttons.
- Q: Where should the histogram panel live? → A: Popover attached to the selected row (appears on click, dismissed on click-away).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a macOS application with a single main
  window for file selection, normalization control, and results display.
- **FR-002**: System MUST provide Browse dialogs (NSOpenPanel) for
  selecting the base TIFF file (.tiff/.tif filter), input directory,
  and output directory. Path fields MUST also accept drag-and-drop
  of files and folders (via `registerForDraggedTypes:`).
- **FR-003**: System MUST persist the last selected base TIFF path,
  input directory, and output directory in NSUserDefaults and restore
  them on launch.
- **FR-004**: System MUST provide a Preferences window (⌘,) with
  controls for CPU percent, memory percent, max jobs, in-place mode,
  and per-file timing display. All values persist via NSUserDefaults.
- **FR-005**: System MUST display a scrollable NSTableView of processed
  files with columns: filename, status, total time, and per-step timing
  (read, range, normalize, write). Per-step columns are toggleable via
  preferences.
- **FR-006**: System MUST support column sorting in the file list by
  clicking column headers.
- **FR-007**: System MUST display a progress bar and file count during
  processing.
- **FR-008**: System MUST display before/after per-channel histograms
  in a popover attached to the selected file list row. The popover
  appears on row click and is dismissed on click-away. Histograms are
  computed on the GPU fused into existing Metal passes (before during
  range, after during normalize).
- **FR-009**: System MUST render histograms using Core Graphics in a
  custom NSView with per-channel color coding and semi-transparent
  overlay.
- **FR-010**: System MUST extract normalization engine into
  `TiffenCore.framework` shared by CLI and GUI targets.
- **FR-011**: System MUST move CLI entry point from `src/main.m` to
  `cli/main.m` and add GUI entry point in `app/main.m`.
- **FR-012**: System MUST embed the Metal shader (`default.metallib`)
  in the framework bundle.
- **FR-013**: System MUST support cancellation — clicking Stop (⌘.)
  halts the batch after in-flight files complete. On cancellation,
  the system MUST present a dialog asking whether to keep or delete
  already-written output files.
- **FR-014**: All code MUST be Objective-C. No Swift or SwiftUI.

### Key Entities

- **TiffenCore.framework**: Shared dynamic framework containing
  TFNNormalizer, TFNExposureRange, TFNTIFFReader/Writer,
  TFNMetalNormalizer, TFNCPUNormalizer, TFNHistogramData, and
  Metal shaders.
- **TFNHistogramData**: Per-channel 256-bin histogram computed on
  GPU (fused into range and normalize passes).
- **TFNProcessingEngine**: App-side wrapper around TFNNormalizer
  that posts NSNotifications for UI updates.
- **TFNProcessedFileInfo**: Per-file result model with timing,
  status, histograms, and exposure ranges.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: CLI output is byte-identical before and after framework
  extraction (verified by processing the same test directory).
- **SC-002**: GUI produces identical normalized output files as CLI
  for the same inputs.
- **SC-003**: UI remains responsive (< 100ms main thread blocking)
  during batch processing of 1,000+ files.
- **SC-004**: All preferences persist across app quit and relaunch.
- **SC-005**: Histogram rendering completes in < 16ms per frame
  (60 fps capable).
- **SC-006**: Before/after histogram bin values match expected
  distributions for known test fixtures.

## Assumptions

- Users are photographers, scientists, or imaging professionals
  on macOS with Apple Silicon.
- The app is a single-user desktop tool, not a server or service.
- The existing CLI test suite validates engine correctness; GUI tests
  focus on UI behavior and integration.
- Histograms are for visual inspection, not pixel-exact analysis —
  256 bins is sufficient resolution.
- The app does not need document-based architecture (no Open/Save
  document model).
