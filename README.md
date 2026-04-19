# Tiffen (TIFF Exposure Normalizer)

A macOS tool that normalizes the exposure range of TIFF files in a directory to match a user-specified base TIFF. Available as both a native macOS GUI application and a CLI tool. Designed for photographers, scientists, and imaging professionals working with batches of TIFF images captured under varying exposure conditions.

Tiffen performs linear per-channel pixel remapping so that all images in a batch share the same exposure range as a chosen reference image, while preserving original bit depth, channel count, and compression.

## Prerequisites

- macOS 14+ on Apple Silicon
- Xcode 15+
- libtiff (`brew install libtiff`)

## Build

Generate the Xcode project (if needed) and build:

```bash
# Install XcodeGen if you haven't already
brew install xcodegen

# Generate the Xcode project from project.yml
xcodegen generate

# Build the GUI app
xcodebuild -scheme tiffenApp -configuration Release

# Build the CLI tool
xcodebuild -scheme tiffen -configuration Release
```

Run tests:

```bash
xcodebuild test -scheme tiffenTests -destination 'platform=macOS'
```

## GUI Application

The Tiffen app provides a native macOS interface for batch normalization:

1. **Select a base TIFF** — the reference image whose exposure range all others will match
2. **Select an input directory** — containing the TIFFs to normalize
3. **Click Normalize** — processing runs in the background with a live progress bar

The results table shows per-file status, timing breakdown (read/range/normalize/write), and any errors or warnings. Click a row to view before/after histograms in a popover.

Processing options (CPU/memory limits, max parallel jobs, in-place mode) are available in the Preferences window.

## CLI Usage

```
tiffen <base-tiff> <input-directory> [options]
```

**Arguments:**

| Argument | Description |
|---|---|
| `<base-tiff>` | Reference TIFF whose exposure range all others will match |
| `<input-directory>` | Directory containing TIFFs to normalize |

**Options:**

| Option | Description |
|---|---|
| `-o, --output <dir>` | Output directory (default: `<input-dir>/normalized/`) |
| `--in-place` | Overwrite originals (mutually exclusive with `-o`) |
| `-v, --verbose` | Per-file timing breakdown and GPU info |
| `-q, --quiet` | Suppress stdout (errors still go to stderr) |
| `--cpu-percent <N>` | Max percentage of CPU cores to use |
| `--mem-percent <N>` | Max percentage of available RAM to use |
| `-j, --jobs <N>` | Explicit concurrency limit |
| `-h, --help` | Show help |
| `--version` | Show version |

**Examples:**

```bash
# Normalize all TIFFs in ./captures to match reference.tiff
tiffen reference.tiff ./captures

# Normalize in-place with verbose output
tiffen reference.tiff ./captures --in-place -v

# Write to a specific output directory, limit to 4 concurrent files
tiffen reference.tiff ./captures -o ./output -j 4
```

**Exit codes:**

| Code | Meaning |
|---|---|
| `0` | All files normalized successfully |
| `1` | Partial success (some files failed) |
| `2` | Fatal error (bad arguments, missing base TIFF, etc.) |

## How It Works

1. **Read** the base TIFF and compute its per-channel min/max exposure range
2. **Enumerate** all TIFF files in the input directory
3. **For each file** (processed in parallel):
   - Compute per-channel exposure range
   - Calculate linear remapping parameters (scale and offset)
   - Apply `out = in * scale + offset` to every pixel
   - Write the normalized TIFF preserving compression and metadata
4. **Copy** the base TIFF to the output directory for a complete file set
5. **Report** summary statistics (files processed, errors, timing)

## Architecture

Tiffen is written in Objective-C and uses Metal compute shaders on Apple Silicon for GPU-accelerated processing.

The project is organized into three Xcode targets defined in `project.yml`:

- **TiffenCore** — shared framework used by both the CLI and GUI
- **tiffen** — CLI tool linking TiffenCore
- **tiffenApp** — macOS application linking TiffenCore

| Component | Purpose |
|---|---|
| `cli/main.m` | CLI entry point and argument parsing |
| `app/` | GUI application (AppDelegate, main window, preferences, file list, histogram view) |
| `TFNExposureRange` | Per-channel min/max computation |
| `TFNNormalizer` | Orchestrator: directory enumeration, parallel dispatch |
| `TFNMetalNormalizer` | GPU-accelerated normalization via Metal |
| `TFNCPUNormalizer` | CPU reference implementation (fallback) |
| `TFNHistogramData` | GPU-fused histogram computation |
| `TFNTIFFReader` / `TFNTIFFWriter` | TIFF I/O via libtiff |
| `normalize.metal` | Metal compute kernels for parallel reduction and normalization |

The Metal path leverages Apple Silicon's unified memory architecture to avoid CPU-GPU copy overhead. Concurrency defaults to 90% of available CPU cores and RAM.

Supports 8-bit, 16-bit, and 32-bit (integer and float) TIFF files.

## Generating Test Images

A test fixture generator is included to create 28 TIFF files with known characteristics for testing:

```bash
# Generate test images to test-images/ at the repo root
./tools/generate-test-tiffs.sh

# Generate to a custom directory
./tools/generate-test-tiffs.sh /path/to/output
```

The generated files cover a range of formats and patterns:

| Category | Files |
|---|---|
| Base reference | `BASE_reference.tiff` (8-bit RGB, moderate exposure) |
| 8-bit grayscale | Dark, normal, bright, full-range, and narrow-range exposures |
| 8-bit patterns | Checkerboards (high/low contrast), sine waves (dark/bright) |
| 8-bit RGB | Dark, bright, red-heavy, blue-heavy, vignettes |
| 16-bit | Grayscale (dark, normal, bright) and RGB (wide/narrow range) |
| 32-bit float | Dark, normal, bright, HDR (0–5 range) |
| Edge cases | Uniform pixel values, tiny (32x32), large (2048x2048) |

Files use a mix of compression schemes (Deflate, LZW, PackBits, None). The generated files are gitignored.

## License

This project is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE) for details.
