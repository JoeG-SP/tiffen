# Data Model: Native macOS UI

**Date**: 2026-04-18
**Feature**: 002-native-macos-ui

## Entities

### TiffenCore Framework (shared, existing entities)

These entities already exist in `src/` and become the public API of
`TiffenCore.framework`. No changes to their interfaces — they are
documented here for reference.

- **TFNExposureRange** — per-channel min/max pixel values
- **TFNTIFFImage** — loaded TIFF with metadata and pixel buffer
- **TFNNormalizationParams** — precomputed per-channel scale/offset
- **TFNNormalizer** — orchestrator: enumerate, dispatch, report results

See `specs/001-tiff-exposure-normalization/data-model.md` for full
field definitions.

### TFNHistogramData (new, in TiffenCore framework)

Per-channel histogram computed on the GPU as a byproduct of existing
Metal passes. Lives in the framework because it is produced by the
Metal normalizer and consumed by both GUI (display) and tests.

| Field | Type | Description |
|-------|------|-------------|
| bins | float** | Array of channelCount pointers, each to 256 floats (normalized 0–1) |
| channelCount | NSUInteger | Number of channels |
| totalPixels | NSUInteger | Total pixel count (width * height), used for normalization |

**Class methods**:
- `+histogramFromRawCounts:channelCount:totalPixels:` — normalizes
  raw uint32 GPU counts to 0–1 floats. Called by the framework after
  each Metal pass completes.

**Validation rules**:
- Each channel MUST have exactly 256 bins
- Bin values MUST be normalized to 0–1 (fraction of total pixels)

**GPU computation** (fused into existing Metal passes):
- **Before histogram**: Computed during the range reduction pass. The
  Metal kernel atomically increments `device uint` bins while scanning
  for min/max. No extra data traversal.
- **After histogram**: Computed during the normalization pass. The
  Metal kernel atomically increments bins after writing each output
  pixel. No extra data traversal.
- GPU buffer layout: `channelCount * 256` contiguous `uint32` entries
  in a `MTLBuffer` with shared storage mode.
- After the kernel completes, the framework reads the raw counts from
  the shared buffer and normalizes to 0–1 floats (divides each bin
  by totalPixels). This is trivial — 256 * channels divisions on CPU.

**Bin index calculation** (in Metal shader):
- 8-bit: `bin = pixel_value` (direct 1:1 mapping)
- 16-bit: `bin = (uint)(pixel_value * 255.0f / 65535.0f)`
- 32-bit float: `bin = clamp((uint)((value - range_min) / (range_max - range_min) * 255.0f), 0u, 255u)`

**CPU fallback**: `TFNCPUNormalizer` computes histograms inline during
its range scan and normalization loops using the same bin calculations.

**Memory management**: Bins allocated with `calloc`, freed in `dealloc`.
GPU histogram buffers are allocated per-file and reused across channels.

---

### App-Only Entities (in `app/`)

### TFNAppSettings

Convenience accessors over `NSUserDefaults`. Not a persisted object
itself — reads/writes go directly to NSUserDefaults.

| Field | Type | Default | UserDefaults Key | Description |
|-------|------|---------|------------------|-------------|
| lastBaseTIFFPath | NSString* | @"" | `TFNLastBaseTIFFPath` | Last selected base TIFF file path |
| lastInputDirectory | NSString* | @"" | `TFNLastInputDirectory` | Last selected input directory |
| lastOutputDirectory | NSString* | @"" | `TFNLastOutputDirectory` | Last selected output directory |
| cpuPercent | NSInteger | 90 | `TFNCPUPercent` | Max CPU core usage (1–100) |
| memPercent | NSInteger | 90 | `TFNMemPercent` | Max memory usage (1–100) |
| maxJobs | NSInteger | 0 | `TFNMaxJobs` | Hard concurrency cap (0 = auto) |
| inPlace | BOOL | NO | `TFNInPlace` | Overwrite originals |
| showPerFileTiming | BOOL | YES | `TFNShowPerFileTiming` | Show timing breakdown columns |

**Validation rules**:
- cpuPercent MUST be clamped to 1–100
- memPercent MUST be clamped to 1–100
- maxJobs MUST be >= 0 (0 means automatic)
- inPlace and custom output directory are mutually exclusive in the UI

**Implementation**: Preferences window uses Cocoa Bindings to
`NSUserDefaultsController` for automatic two-way sync. Defaults
registered in `TFNAppDelegate applicationDidFinishLaunching:`.

### TFNProcessedFileInfo

Per-file processing result displayed in the file list table.

| Field | Type | Description |
|-------|------|-------------|
| fileName | NSString* | Base filename (e.g., "photo_002.tiff") |
| filePath | NSString* | Absolute path to source file |
| status | TFNProcessingStatus | Current state enum |
| readTime | NSTimeInterval | Read/decompress duration (-1 if not yet completed) |
| rangeTime | NSTimeInterval | Exposure range computation duration |
| normalizeTime | NSTimeInterval | Normalization duration |
| writeTime | NSTimeInterval | Write/compress duration |
| totalTime | NSTimeInterval | Total per-file processing time |
| errorMessage | NSString* | Error description (nil if no error) |
| sourceRange | TFNExposureRange* | Original exposure range |
| normalizedRange | TFNExposureRange* | Post-normalization exposure range |
| beforeHistogram | TFNHistogramData* | Pre-normalization histogram |
| afterHistogram | TFNHistogramData* | Post-normalization histogram |
| bitDepth | NSUInteger | Bits per sample (8, 16, 32) |
| channelCount | NSUInteger | Number of channels |
| isFloat | BOOL | Whether the TIFF uses float samples |

**Validation rules**:
- Timing fields are -1 until that processing step completes
- Histogram fields are nil until computed
- errorMessage is non-nil only when status == TFNProcessingStatusError

### TFNProcessingStatus (Enum)

```objc
typedef NS_ENUM(NSInteger, TFNProcessingStatus) {
    TFNProcessingStatusPending,
    TFNProcessingStatusProcessing,
    TFNProcessingStatusCompleted,
    TFNProcessingStatusError,
    TFNProcessingStatusSkipped
};
```

### TFNProcessingEngine

Wraps `TFNNormalizer` (from TiffenCore) for use by the UI. Posts
notifications for state changes.

| Field | Type | Description |
|-------|------|-------------|
| baseTIFFPath | NSString* | Selected base TIFF for this session |
| inputDirectory | NSString* | Selected input directory |
| outputDirectory | NSString* | Resolved output directory |
| files | NSMutableArray<TFNProcessedFileInfo*>* | All discovered files |
| isRunning | BOOL | Whether processing is in progress |
| totalFiles | NSUInteger | Total files to process |
| completedFiles | NSUInteger | Files finished (completed + error + skipped) |
| startTime | NSDate* | When processing began |

**Notifications posted** (on main queue):
- `TFNProcessingDidStartNotification` — batch started
- `TFNProcessingFileDidUpdateNotification` — file changed state (userInfo: file info + index)
- `TFNProcessingDidFinishNotification` — batch complete (userInfo: summary stats)

**Thread safety**: File array mutations and notification posting are
dispatched to the main queue. The underlying TFNNormalizer runs on
its own GCD queues.

### TFNCumulativeTiming

Aggregate timing across all processed files.

| Field | Type | Description |
|-------|------|-------------|
| readTotal | NSTimeInterval | Sum of all read/decompress times |
| rangeTotal | NSTimeInterval | Sum of all range computation times |
| normalizeTotal | NSTimeInterval | Sum of all normalization times |
| writeTotal | NSTimeInterval | Sum of all write/compress times |
| wallClock | NSTimeInterval | Total wall clock time |

## Relationships

```text
TiffenCore.framework
├── TFNNormalizer ──uses──> TFNTIFFReader, TFNTIFFWriter, TFNMetalNormalizer
├── TFNHistogramData ──computed-from──> TFNTIFFImage pixel buffer
└── TFNExposureRange ──computed-by──> TFNMetalNormalizer or TFNCPUNormalizer

cli/main.m ──links──> TiffenCore.framework
    └── calls TFNNormalizer directly

app/
├── TFNProcessingEngine ──wraps──> TFNNormalizer (from framework)
├── TFNProcessedFileInfo ──has──> TFNHistogramData (0..2: before/after)
├── TFNProcessedFileInfo ──has──> TFNExposureRange (0..2: source/normalized)
├── TFNProcessedFileInfo ──has──> TFNProcessingStatus (1:1)
└── NSUserDefaults ──read-by──> TFNProcessingEngine
```

## State Transitions

### TFNProcessedFileInfo lifecycle

```text
Pending → Processing → Completed
                    → Error (at any step)
Pending → Skipped (non-TIFF or base file)
```

### TFNProcessingEngine lifecycle

```text
Idle → Ready (base + directory selected) → Running → Finished
                                                   → Cancelled (user stops)
                                         → Error (fatal: bad base TIFF)
```

### App-level state

```text
Launch → Restore last paths from NSUserDefaults
      → User selects base TIFF + directory → Ready to run
      → User clicks Normalize → TFNProcessingEngine starts
      → Processing completes → NSTableView populated with results
      → User selects a row → TFNHistogramView shows before/after
```
