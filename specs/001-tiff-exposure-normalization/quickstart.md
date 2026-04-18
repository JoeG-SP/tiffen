# Quickstart: Tiffen

## Prerequisites

- macOS 14+ on Apple Silicon
- Xcode 15+ (for Metal compiler and XCTest)
- libtiff (`brew install libtiff`)

## Build

```bash
# Clone and build
git clone <repo-url> tiffen
cd tiffen
xcodebuild -scheme tiffen -configuration Release

# Binary location
BUILD_DIR=$(xcodebuild -scheme tiffen -showBuildSettings | grep -m1 BUILT_PRODUCTS_DIR | awk '{print $3}')
```

## Basic Usage

```bash
# Normalize all TIFFs in photos/ to match base.tiff
tiffen base.tiff photos/

# Output goes to photos/normalized/ by default (includes base file)
ls photos/normalized/

# Specify custom output directory
tiffen base.tiff photos/ --output ~/Desktop/normalized/

# Overwrite originals (destructive — use with caution)
tiffen base.tiff photos/ --in-place

# Verbose output (per-file timing breakdown)
tiffen base.tiff photos/ -v

# Quiet mode (errors only)
tiffen base.tiff photos/ -q
```

## Concurrency Control

Files are processed in parallel by default. Concurrency is the
minimum of 90% of CPU cores and 90% of RAM (at 1 GB per file).

```bash
# Limit to 50% CPU and memory usage
tiffen base.tiff photos/ --cpu-percent 50 --mem-percent 50

# Hard cap at 4 parallel workers
tiffen base.tiff photos/ --jobs 4

# All flags act as caps — final concurrency is the minimum of all
tiffen base.tiff photos/ --cpu-percent 75 --mem-percent 80 --jobs 10
```

## Output

Default mode shows progress and a timing summary:

```
Normalizing 65 files to match base: base.tiff
  [1/65] photo_002.tiff → normalized/photo_002.tiff
  ...
  [65/65] photo_066.tiff → normalized/photo_066.tiff

Done: 65 normalized, 0 errors, 0 skipped

Timing (cumulative across 21 concurrent workers):
  Read/decompress:   170.14s  ( 9.0%)
  Range (GPU):         1.44s  ( 0.1%)
  Normalize (GPU):     0.91s  ( 0.0%)
  Write/compress:   1721.19s  (90.9%)
  Wall clock:        123.94s
  Avg per file:       29.13s  (wall: 1.91s)
```

Verbose mode (`-v`) adds per-file timing and concurrency info:

```
Metal GPU: available
Concurrency: 21 (CPU cores: 24, RAM: 128 GB)
  [1/65] photo_002.tiff → normalized/photo_002.tiff  (29.08s: read 2.65, range 0.021, norm 0.025, write 26.13)
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All files processed successfully |
| 1 | One or more files failed (partial success) |
| 2 | Fatal error (invalid arguments, missing base TIFF) |

## Run Tests

```bash
xcodebuild test -scheme tiffenTests -destination 'platform=macOS'
```

## Verify Installation

```bash
# Should print version
tiffen --version

# Should print usage
tiffen --help
```
