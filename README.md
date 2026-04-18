# Tiffen

A macOS CLI tool that normalizes the exposure range of TIFF files in a directory to match a user-specified base TIFF. Designed for photographers, scientists, and imaging professionals working with batches of TIFF images captured under varying exposure conditions.

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

# Build the release binary
xcodebuild -scheme tiffen -configuration Release
```

Run tests:

```bash
xcodebuild test -scheme tiffenTests -destination 'platform=macOS'
```

## Usage

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

| Component | Purpose |
|---|---|
| `main.m` | CLI entry point and argument parsing |
| `TFNExposureRange` | Per-channel min/max computation |
| `TFNNormalizer` | Orchestrator: directory enumeration, parallel dispatch |
| `TFNMetalNormalizer` | GPU-accelerated normalization via Metal |
| `TFNCPUNormalizer` | CPU reference implementation (fallback) |
| `TFNTIFFReader` / `TFNTIFFWriter` | TIFF I/O via libtiff |
| `normalize.metal` | Metal compute kernels for parallel reduction and normalization |

The Metal path leverages Apple Silicon's unified memory architecture to avoid CPU-GPU copy overhead. Concurrency defaults to 90% of available CPU cores and RAM.

Supports 8-bit, 16-bit, and 32-bit (integer and float) TIFF files.

## License

This project is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE) for details.
