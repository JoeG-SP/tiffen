# CLI Interface Contract: tiffen

## Synopsis

```
tiffen <base-tiff> <input-directory> [options]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<base-tiff>` | Yes | Path to the reference TIFF file whose exposure range all others will match |
| `<input-directory>` | Yes | Path to directory containing TIFF files to normalize |

## Options

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--output <dir>` | `-o` | `<input-directory>/normalized/` | Output directory for normalized files |
| `--in-place` | | off | Overwrite original files instead of writing to output directory |
| `--verbose` | `-v` | off | Print detailed progress for each file |
| `--quiet` | `-q` | off | Suppress all stdout output except errors |
| `--cpu-percent <N>` | | 90 | Max CPU core usage percent (1–100) |
| `--mem-percent <N>` | | 90 | Max memory usage percent (1–100) |
| `--jobs <N>` | `-j` | auto | Hard cap on number of parallel workers |
| `--help` | `-h` | | Print usage information and exit |
| `--version` | | | Print version and exit |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All files processed successfully |
| 1 | One or more files failed (partial success, errors on stderr) |
| 2 | Fatal error (invalid arguments, base TIFF unreadable, etc.) |

## Output Behavior

**stdout** (default mode):
```
Normalizing 47 files to match base: photo_001.tiff
  [1/47] photo_002.tiff → normalized/photo_002.tiff
  [2/47] photo_003.tiff → normalized/photo_003.tiff
  ...
  [46/47] photo_047.tiff → normalized/photo_047.tiff
  Skipped: 1 (non-TIFF)

Done: 46 normalized, 0 errors, 1 skipped

Timing (cumulative across 21 concurrent workers):
  Read/decompress:   120.50s  ( 9.0%)
  Range (GPU):         0.95s  ( 0.1%)
  Normalize (GPU):     0.60s  ( 0.0%)
  Write/compress:   1215.00s  (90.9%)
  Wall clock:         65.00s
  Avg per file:       29.05s  (wall: 1.41s)
```

The base file (`photo_001.tiff`) is copied as-is into the output
directory so it contains the complete set.

**`--verbose` mode** adds per-file timing breakdown:
```
  [1/47] photo_002.tiff → normalized/photo_002.tiff  (29.08s: read 2.65, range 0.021, norm 0.025, write 26.13)
```

**stderr** (errors):
```
Error: photo_025.tiff: corrupt TIFF header (skipping)
```

**`--in-place` mode**:
```
Normalizing 47 files to match base: photo_001.tiff (in-place)
  [1/47] photo_002.tiff (overwritten)
  ...
```

## Concurrency

Default concurrency = `min(CPU_cores * 0.9, RAM_GB * 0.9)`.
`--cpu-percent`, `--mem-percent`, and `--jobs` all act as caps —
the final concurrency is the minimum of all applicable limits.

## Constraints

- `--in-place` and `--output` are mutually exclusive (error if both provided, exit code 2)
- `--verbose` and `--quiet` are mutually exclusive (error if both provided, exit code 2)
- `<base-tiff>` MUST exist and be a valid TIFF (exit code 2 if not)
- `<input-directory>` MUST exist and be a directory (exit code 2 if not)
- If `<base-tiff>` is inside `<input-directory>`, it is not re-normalized but is copied as-is to the output directory (skipped in `--in-place` mode)

## Warnings (stderr)

- Flat exposure: when a target TIFF channel has `min == max`, a warning
  is emitted: `Warning: photo.tiff: channel N has flat exposure (mapped to base_min)`
