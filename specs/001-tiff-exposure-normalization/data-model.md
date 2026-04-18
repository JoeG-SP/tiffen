# Data Model: TIFF Exposure Normalization

**Date**: 2026-04-17
**Feature**: 001-tiff-exposure-normalization

## Entities

### TFNExposureRange

Represents the per-channel exposure range of a TIFF image.

| Field | Type | Description |
|-------|------|-------------|
| channelCount | NSUInteger | Number of channels (e.g., 1 for grayscale, 3 for RGB, 4 for RGBA) |
| minValues | float[] | Minimum pixel value per channel |
| maxValues | float[] | Maximum pixel value per channel |

**Validation rules**:
- channelCount MUST be >= 1
- minValues[i] MUST be <= maxValues[i] for all channels
- For integer bit depths, values are stored as float but represent the integer range (e.g., 0–255 for 8-bit)

### TFNTIFFImage

Represents a loaded TIFF image in memory.

| Field | Type | Description |
|-------|------|-------------|
| filePath | NSString* | Absolute path to the source TIFF file |
| width | NSUInteger | Image width in pixels |
| height | NSUInteger | Image height in pixels |
| channelCount | NSUInteger | Samples per pixel |
| bitDepth | NSUInteger | Bits per sample (8, 16, or 32) |
| isFloat | BOOL | YES for 32-bit float, NO for integer types |
| pixelData | void* | Raw pixel buffer (row-major, interleaved channels) |
| pixelDataLength | NSUInteger | Length of pixelData in bytes |
| exposureRange | TFNExposureRange* | Computed min/max per channel |

**Validation rules**:
- pixelDataLength MUST equal width * height * channelCount * (bitDepth / 8)
- bitDepth MUST be one of: 8, 16, 32
- If bitDepth is 32 and isFloat is NO, treat as 32-bit integer

### TFNNormalizationParams

Precomputed per-channel scale and offset passed to the Metal kernel
(or CPU normalizer). Computed on CPU after both base and target
exposure ranges are known.

| Field | Type | Description |
|-------|------|-------------|
| scale | float[] | Per-channel: `(base_max - base_min) / (src_max - src_min)` |
| offset | float[] | Per-channel: `base_min - src_min * scale` |
| channelCount | NSUInteger | Number of channels |

**Derived from**: base TFNExposureRange + target TFNExposureRange.

**Degenerate case**: If `src_max == src_min` for a channel (flat
exposure), set `scale = 0` and `offset = base_min` for that channel.
This maps all pixels to `base_min` and avoids division by zero.

The kernel applies `out = in * scale + offset` — a single
multiply-add per pixel per channel with no branching or division.

## Relationships

```text
TFNTIFFImage --has--> TFNExposureRange (1:1, computed on load)
TFNNormalizationParams --derived-from--> TFNExposureRange (base) + TFNExposureRange (target)
```

## State Transitions

A target TIFF moves through these states:

```text
Discovered → Loading → Loaded → Computing Range → Normalizing → Writing → Done
                                                                       → Error (at any step)
```

- **Discovered**: File path found during directory enumeration
- **Loading**: libtiff is reading the file into a TFNTIFFImage
- **Loaded**: Pixel data in memory, metadata populated
- **Computing Range**: Min/max scan in progress
- **Normalizing**: Metal kernel (or CPU fallback) remapping pixels
- **Writing**: libtiff writing normalized buffer to output path
- **Done**: Output file written successfully
- **Error**: Any step failed; error logged to stderr, file skipped
