# UI Contract: Tiffen macOS App

## Windows

### Main Window

**Title**: "Tiffen"
**Minimum size**: 700 x 500 pt
**Default size**: 900 x 600 pt

#### Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Base TIFF:  [/path/to/base.tiff          ] [Browse...]     │
│  Input Dir:  [/path/to/input/             ] [Browse...]     │
│  Output:     [/path/to/input/normalized/  ] [Browse...]     │
│                                                             │
│  [▶ Normalize]                    Processing: 12/65 (18%)   │
│  ─────────────────── Progress Bar ────────────────────────  │
├─────────────────────────────────────────────────────────────┤
│  File                │ Status    │ Time   │ Read  │ Write   │
│  ────────────────────┼───────────┼────────┼───────┼──────── │
│  photo_002.tiff      │ ✓ Done    │ 1.91s  │ 0.26s │ 1.62s  │
│  photo_003.tiff      │ ✓ Done    │ 2.04s  │ 0.28s │ 1.73s  │
│  photo_004.tiff      │ ⟳ Running │ —      │ —     │ —      │
│  photo_005.tiff      │ ○ Pending │ —      │ —     │ —      │
│  corrupt.tiff        │ ✗ Error   │ —      │ —     │ —      │
│  ...                 │           │        │       │        │
├─────────────────────────────────────────────────────────────┤
│  Summary: 64 done, 1 error, 0 skipped │ Wall: 2m 03s       │
└─────────────────────────────────────────────────────────────┘
```

#### Controls

- **Path fields**: `NSTextField` (read-only, displays truncated path).
  Full path shown via tooltip (`setToolTip:`). Accepts drag-and-drop of
  files/folders via `registerForDraggedTypes:` (`NSPasteboardTypeFileURL`).
  Validates dropped item type (file for base TIFF, directory for input/output).
- **Browse buttons**: `NSButton` triggering `NSOpenPanel`. Base TIFF
  filters to `.tiff`/`.tif` file types. Input/Output use directory
  selection mode (`setCanChooseDirectories:YES`).
- **Normalize button**: `NSButton`. Disabled until both base TIFF and
  input directory are selected. Title changes to "Stop" while processing.
- **Progress bar**: `NSProgressIndicator` (determinate). Max value =
  total files. Updated per completed file.
- **File list**: `NSTableView` with sortable columns. Data provided by
  `TFNFileListDataSource` (conforms to `NSTableViewDataSource` and
  `NSTableViewDelegate`). Clicking a row updates the histogram view.
- **Summary bar**: `NSTextField` (read-only) at the bottom showing
  aggregate counts and wall clock time.

#### Behaviors

- **Output field**: Auto-populated as `<input-dir>/normalized/` by default.
  Disabled when in-place mode is enabled in preferences.
- **Path persistence**: Last selected base TIFF, input directory, and
  output directory are saved to `NSUserDefaults` on selection and restored
  on next launch via `applicationDidFinishLaunching:`.
- **Table updates**: `TFNProcessingEngine` posts
  `TFNProcessingFileDidUpdateNotification`. The window controller observes
  this and calls `reloadDataForRowIndexes:columnIndexes:` for the changed
  row.

### Preferences Window

Accessed via **Tiffen > Settings...** (⌘,). Implemented as
`TFNPreferencesWindowController` with Cocoa Bindings to
`NSUserDefaultsController`.

#### Layout

```
┌─────────────────────────────────────────────┐
│  Processing                                  │
│  ──────────────────────────────────────────  │
│  CPU usage limit:    [====90%====] slider    │
│  Memory usage limit: [====90%====] slider    │
│  Max parallel jobs:  [  0  ] stepper         │
│                                              │
│  Output                                      │
│  ──────────────────────────────────────────  │
│  ☐ Overwrite originals (in-place)            │
│                                              │
│  Display                                     │
│  ──────────────────────────────────────────  │
│  ☑ Show per-file timing details              │
└──────────────────────────────────────────────┘
```

#### Controls

- **CPU/Memory sliders**: `NSSlider` (continuous, 1–100). Value label
  (`NSTextField`) beside each slider shows current value as percentage.
  Bound to `NSUserDefaultsController` keys `TFNCPUPercent` / `TFNMemPercent`.
- **Max parallel jobs**: `NSTextField` + `NSStepper`. Range 0–64.
  0 = automatic. Bound to `TFNMaxJobs`.
- **In-place checkbox**: `NSButton` (checkbox style). When checked,
  output directory field in main window is disabled. Bound to `TFNInPlace`.
- **Per-file timing checkbox**: `NSButton` (checkbox style). Toggles
  visibility of Read/Range/Norm/Write columns in the file list table.
  Bound to `TFNShowPerFileTiming`.

#### Behaviors

- All controls use Cocoa Bindings — changes persist immediately to
  `NSUserDefaults` with no save button.
- Closing and reopening the preferences window reflects current values.

### Histogram Popover

Displayed as an `NSPopover` anchored to the selected file list row.
Appears on row click for completed files; dismissed on click-away
(standard `NSPopoverBehaviorTransient`).

#### Layout

```
┌─────────────────────────────────────────────┐
│  photo_002.tiff — Histogram                  │
│                                              │
│  Before                    After             │
│  ┌──────────────┐         ┌──────────────┐  │
│  │   ▄▅█▇▅▃▂   │         │  ▃▅█▇▅▃▂▁   │  │
│  │  ▃████████▃  │         │ ▃████████▃   │  │
│  │ ▂██████████▂ │         │▂██████████▂  │  │
│  └──────────────┘         └──────────────┘  │
│  R ── G ── B ── (channel legend)            │
│                                              │
│  Range: [12, 240] → [0, 255]                │
│  Bit depth: 16-bit │ Channels: 3            │
└──────────────────────────────────────────────┘
```

**Popover size**: 480 x 300 pt (fixed). Anchored to the bottom edge
of the selected row, preferred edge `NSRectEdgeMaxY`.

#### Implementation

- **NSPopover** with `behavior = NSPopoverBehaviorTransient` (auto-dismiss
  on click-away).
- **Content view controller** contains two `TFNHistogramView` instances
  side by side (before/after) in an `NSStackView`.
- **TFNHistogramView**: Custom `NSView` subclass. Overrides `drawRect:`
  to render histograms using Core Graphics.
- **Drawing**: For each channel, build a `CGMutablePath` from 256 bin
  values, fill with semi-transparent channel color using
  `CGContextSetRGBFillColor` + `CGContextFillPath`.
- **Channel colors**: Red=(1,0,0,0.4), Green=(0,1,0,0.4),
  Blue=(0,0,1,0.4), Gray=(0.5,0.5,0.5,0.6) for single-channel.
- **Range label**: `NSTextField` showing per-channel [min, max] → [min, max].
- **Metadata label**: `NSTextField` showing bit depth and channel count.
- Popover only shown for files with status `Completed`. Clicking a
  non-completed row does nothing (no popover).

## Menu Bar

```
Tiffen
├── About Tiffen
├── ─────────
├── Settings... (⌘,)
├── ─────────
├── Quit Tiffen (⌘Q)

File
├── Open Base TIFF... (⌘O)
├── Open Input Directory... (⇧⌘O)
├── ─────────
├── Close Window (⌘W)

Processing
├── Start Normalization (⌘R)
├── Stop Normalization (⌘.)
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Browse for base TIFF |
| ⇧⌘O | Browse for input directory |
| ⌘R | Start normalization |
| ⌘. | Stop normalization |
| ⌘, | Open preferences |
| ⌘W | Close window |
| ⌘Q | Quit application |

## Cancellation Dialog

When the user cancels a running batch (⌘. or Stop button) and output
files have already been written, an `NSAlert` is presented:

- **Style**: `NSAlertStyleInformational`
- **Message**: "Processing cancelled. N files were already written to
  the output directory."
- **Buttons**: "Keep Files" (default), "Delete Files"
- **Delete behavior**: Removes all files written during this batch from
  the output directory. Does not remove pre-existing files.
- If no files were written yet, no dialog is shown.

## Error Display

- **File-level errors**: Shown inline in the file list with error icon
  (NSImageNameCaution). Tooltip on the row shows the error message.
- **Fatal errors** (bad base TIFF, missing directory): `NSAlert` with
  `NSAlertStyleCritical`, description, and OK button. Processing does
  not start.
- **Warnings** (flat exposure): Warning icon in status column. Tooltip
  shows the warning message.

## Accessibility

- All controls have accessibility labels via `setAccessibilityLabel:`.
- NSTableView supports VoiceOver navigation natively.
- TFNHistogramView provides `accessibilityLabel` describing the data range.
- Keyboard navigation via standard AppKit tab ordering.
