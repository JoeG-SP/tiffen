# Research: Native macOS UI

**Date**: 2026-04-18
**Feature**: 002-native-macos-ui

## R1: AppKit for macOS 14+ (Objective-C)

**Decision**: Pure AppKit in Objective-C. No Swift or SwiftUI.

**Rationale**: The entire existing codebase is Objective-C. Using AppKit
keeps the project in a single language with no bridging headers, no
mixed compilation, and no Swift runtime dependency. AppKit on macOS 14+
is mature and fully capable for this use case: `NSWindow`, `NSTableView`,
`NSOpenPanel`, `NSUserDefaults`, and custom `NSView` drawing.

**Key AppKit components**:
- `NSWindow` + `NSViewController` for main window
- `NSTableView` with `NSTableViewDiffableDataSource` for file list
- `NSOpenPanel` for file/directory selection
- `NSToolbar` for top-level actions
- `NSUserDefaultsController` + Cocoa Bindings for preferences persistence
- Custom `NSView` with Core Graphics for histogram rendering
- `NSProgressIndicator` for batch progress

**Alternatives considered**:
- **SwiftUI + bridging header**: Adds a second language, bridging
  complexity, and Swift runtime. No benefit for a tool with an existing
  Objective-C codebase. Rejected for consistency.
- **SwiftUI with ObjC @main**: Not supported — SwiftUI requires Swift.

## R2: Shared Framework (TiffenCore.framework)

**Decision**: Extract all core normalization logic into a shared dynamic
library (`libtiffen.dylib`) that both the CLI and GUI targets link against.

**Rationale**: Both the CLI and GUI need identical normalization behavior.
Compiling the same `.m` files into two separate targets creates duplicate
object code and risks divergence if one target accidentally gets different
compile flags. A shared dylib ensures a single compiled copy of the engine
and enforces a clean API boundary between core logic and UI/CLI layers.

**Key design decisions**:
- Library type: `framework` target in XcodeGen (produces `TiffenCore.framework`).
  Frameworks are the idiomatic macOS way to package shared Objective-C code
  with headers. Easier to manage than a raw `.dylib` with manual header
  search paths.
- Public headers: `TFNNormalizer.h`, `TFNExposureRange.h`, `TFNTIFFReader.h`,
  `TFNTIFFWriter.h`, `TFNMetalNormalizer.h`, `TFNCPUNormalizer.h`,
  `TFNNormalizationResult.h`. These form the public API.
- The framework links libtiff and Metal — consumers (CLI, GUI) do not
  link these directly.
- Metal shader (`default.metallib`) is embedded in the framework bundle
  and loaded at runtime via `[NSBundle bundleForClass:]`.
- Both CLI and GUI targets depend on and embed `TiffenCore.framework`.

**Alternatives considered**:
- **Static library (.a)**: Would still compile once, but doesn't bundle
  headers or resources (Metal shader). Consumers would need manual header
  search paths and shader copying. More fragile.
- **Raw dylib**: Works but requires manual `install_name_tool`, header
  paths, and shader bundling. Framework handles all of this.
- **Shared source compilation (current approach)**: Both targets compile
  all `.m` files independently. Doubles compile time, risks flag divergence,
  no enforced API boundary. Rejected.

## R3: GPU-Fused Histogram Computation

**Decision**: Compute histograms on the GPU by fusing them into the
existing Metal passes — before histogram during the range reduction
pass, after histogram during the normalization pass. Render with
Core Graphics in a custom `NSView`.

**Rationale**: The pixel buffer is already traversed twice on the GPU:
once for min/max range computation, once for normalization. Adding
histogram binning to these existing passes avoids extra data traversals.
On Apple Silicon unified memory, the histogram output buffers are shared
with no copy overhead.

**GPU implementation**:
- **Before histogram (range pass)**: Each thread reads a pixel, computes
  the bin index, and increments the per-channel bin using
  `atomic_fetch_add_explicit` on a shared `device uint` histogram buffer.
  This runs in the same kernel invocation as the min/max parallel
  reduction. The histogram buffer has `channelCount * 256` uint32 entries.
- **After histogram (normalize pass)**: After applying
  `out = in * scale + offset`, each thread bins the output pixel value
  into a second histogram buffer using the same atomic approach. Runs
  in the same kernel as normalization — no additional dispatch.
- **CPU fallback**: The CPU reference path (`TFNCPUNormalizer`) computes
  histograms inline during its range scan and normalization loops.
- **Normalization**: After the kernel completes, the framework normalizes
  raw counts to 0–1 floats on CPU (dividing by total pixel count). This
  is trivial (256 * channels divisions).

**Metal shader changes**:
- `normalize.metal` gets two additional `device uint*` buffer arguments
  for before/after histograms.
- Range kernel: add `atomic_fetch_add_explicit(&hist[channel * 256 + bin], 1, memory_order_relaxed)`
  per pixel per channel after computing min/max.
- Normalize kernel: same atomic increment after writing the output pixel.
- Bin index calculation:
  - 8-bit: `bin = pixel_value` (direct mapping)
  - 16-bit: `bin = (uint)(pixel_value * 255.0f / 65535.0f)`
  - 32-bit float: `bin = clamp((uint)((value - range_min) / (range_max - range_min) * 255.0f), 0u, 255u)`

**Rendering** (unchanged from display perspective):
- Custom `TFNHistogramView` (`NSView` subclass) renders with Core
  Graphics path drawing (`CGContextBeginPath` / `CGContextAddLineToPoint`)
- Per-channel overlay with alpha blending (R=red, G=green, B=blue,
  Gray=gray)
- Before and after histograms displayed side by side
- Rendering is < 1ms per histogram (256 points, trivial geometry)

**Alternatives considered**:
- **Separate CPU pass after GPU**: Would require reading the pixel buffer
  back on CPU after each GPU pass. Adds a full-buffer traversal per file
  (2x for before+after). Rejected — fusing into existing passes is free.
- **Separate GPU dispatch for histograms**: Avoids atomic contention in
  the main kernels but adds dispatch overhead and extra buffer management.
  Atomic contention on 256 bins is negligible with relaxed ordering.
- **Swift Charts for rendering**: Requires Swift. Rejected per language
  constraint.

## R4: Preferences Persistence

**Decision**: `NSUserDefaults` with Cocoa Bindings in the preferences
window. Standard `NSUserDefaultsController` for binding UI controls
to persisted values.

**Rationale**: NSUserDefaults is the native Objective-C persistence
mechanism for app preferences. Cocoa Bindings eliminate manual
synchronization code — sliders, checkboxes, and text fields bind
directly to user defaults keys. Values survive app restarts and are
stored in `~/Library/Preferences/com.tiffen.app.plist`.

**Persisted settings**:
- Last selected base file path (`NSString`)
- Last selected input directory path (`NSString`)
- Last selected output directory path (`NSString`)
- CPU percent (`NSInteger`, default 90)
- Memory percent (`NSInteger`, default 90)
- Max jobs (`NSInteger`, default 0 = auto)
- In-place mode (`BOOL`, default NO)
- Show per-file timing (`BOOL`, default YES)

**Registration**: All defaults registered in `+[NSApp initialize]` or
`applicationDidFinishLaunching:` via `registerDefaults:`.

**Alternatives considered**:
- **Property list file**: Manual serialization. NSUserDefaults is simpler
  and standard for preferences.
- **Core Data**: Massive overkill for flat key-value settings.

## R5: Project Structure (XcodeGen)

**Decision**: Three targets in `project.yml`: `TiffenCore` (framework),
`tiffen` (CLI tool), and `tiffenApp` (GUI application). Core engine
code lives in `src/`, CLI entry point in `cli/`, GUI code in `app/`.

**Rationale**: The framework target compiles all engine code once and
bundles it with the Metal shader. Both the CLI and GUI link and embed
the framework. This enforces a clean API boundary — the CLI and GUI
only see public headers, not internal implementation details.

**XcodeGen target layout**:
```yaml
targets:
  TiffenCore:
    type: framework
    platform: macOS
    sources:
      - path: src
        excludes:
          - "**/*.metal"
    # Links libtiff, Metal; embeds default.metallib

  tiffen:
    type: tool
    platform: macOS
    sources:
      - path: cli
    dependencies:
      - target: TiffenCore
        embed: true

  tiffenApp:
    type: application
    platform: macOS
    sources:
      - path: app
    dependencies:
      - target: TiffenCore
        embed: true
```

**Alternatives considered**:
- **Separate Xcode project per target**: Adds workspace management
  overhead. Single project with multiple targets is simpler.
- **Embedding CLI as subprocess from GUI**: Loses access to in-memory
  pixel data for histograms. Rejected.

## R6: NSTableView for File List

**Decision**: `NSTableView` with `NSTableViewDiffableDataSource` (macOS 13+)
for the scrollable file list.

**Rationale**: NSTableView is the standard AppKit control for columnar
data with sorting. `NSTableViewDiffableDataSource` provides automatic
animated updates as files transition through processing states. Columns:
file name, status, total time, read/range/normalize/write breakdowns.
Sortable by clicking column headers (NSTableView handles this natively
with sort descriptors).

**Key details**:
- Data source updates dispatched to main queue from processing callbacks
- Row selection triggers histogram panel update
- Status column uses attributed strings or image+text cells for icons
- Performance: NSTableView handles 10,000+ rows efficiently with
  cell reuse

**Alternatives considered**:
- **NSOutlineView**: No hierarchy needed. Overkill.
- **NSCollectionView**: Grid layout not needed; table is the right fit.
