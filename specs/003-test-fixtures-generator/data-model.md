# Data Model: Test TIFF Fixtures Generator

**Date**: 2026-04-19
**Feature**: 003-test-fixtures-generator

## Entities

### Generated TIFF File

Each generated file has these attributes determined at generation time:

| Field | Type | Description |
|-------|------|-------------|
| filename | string | Descriptive name (e.g., `gray_dark.tiff`) |
| width | uint32 | Image width in pixels (default 512) |
| height | uint32 | Image height in pixels (default 512) |
| bitDepth | uint16 | Bits per sample: 8, 16, or 32 |
| channelCount | uint16 | Samples per pixel: 1 (grayscale) or 3 (RGB) |
| isFloat | bool | YES for 32-bit float, NO for integer |
| compression | uint16 | TIFF compression: Deflate for all files |
| minValue | float | Minimum pixel value in the generated data |
| maxValue | float | Maximum pixel value in the generated data |
| pattern | enum | gradient, checkerboard, sine, vignette, or uniform |

### File Categories

| Category | Count | Bit Depth | Channels | Purpose |
|----------|-------|-----------|----------|---------|
| Base reference | 1 | 8 | 3 (RGB) | Normalization target |
| Grayscale 8-bit | 5 | 8 | 1 | Varying exposure ranges |
| Patterns 8-bit | 4 | 8 | 1 | Histogram shape variety |
| RGB 8-bit | 6 | 8 | 3 | Per-channel exposure testing |
| 16-bit | 5 | 16 | 1 or 3 | High bit depth testing |
| 32-bit float | 4 | 32 | 1 | Float normalization + HDR |
| Edge cases | 3 | 8 | 1 or 3 | Flat exposure, tiny, large |
| **Total** | **28** | | | |

## Relationships

```
generate-test-tiffs.sh  --compiles-->  generate-test-tiffs.m
generate-test-tiffs.m   --links-->     libtiff
generate-test-tiffs.m   --writes-->    28 TIFF files
BASE_reference.tiff     --used-by-->   Tiffen GUI as base file
all other files         --used-by-->   Tiffen GUI as input directory
```
