# CLI Interface Contract: generate-test-tiffs

## Synopsis

```
./tools/generate-test-tiffs.sh [output-directory]
```

## Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `output-directory` | No | `test-images/` (repo root) | Directory to write generated TIFF files |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All files generated successfully |
| non-zero | Compilation failed (missing libtiff or clang) |

## Output

**stdout**:
```
Compiling generator...

Generating test TIFFs in test-images/

Base file (use this as the reference):
  Created: BASE_reference.tiff

8-bit grayscale (varying exposure):
  Created: gray_dark.tiff
  Created: gray_normal.tiff
  ...

Done! 28 files generated.

To test:
  1. Open the Tiffen app
  2. Select BASE_reference.tiff as the base file
  3. Select test-images/ as the input directory
  4. Click Normalize
  5. Click completed files to view before/after histograms
```

**stderr**: Only on error (e.g., cannot create file).

## Generated Files

Files use a mix of compression schemes (Deflate, LZW, None, PackBits) to verify that Tiffen preserves original compression in normalized output.

| File | Dimensions | Depth | Channels | Compression | Exposure Range | Pattern |
|------|-----------|-------|----------|-------------|----------------|---------|
| BASE_reference.tiff | 512x512 | 8 | RGB | Deflate | R:40-220, G:30-200, B:50-210 | Gradient |
| gray_dark.tiff | 512x512 | 8 | Gray | Deflate | 0-80 | Gradient |
| gray_normal.tiff | 512x512 | 8 | Gray | LZW | 30-200 | Gradient |
| gray_bright.tiff | 512x512 | 8 | Gray | None | 150-255 | Gradient |
| gray_full_range.tiff | 512x512 | 8 | Gray | PackBits | 0-255 | Gradient |
| gray_narrow.tiff | 512x512 | 8 | Gray | Deflate | 100-130 | Gradient |
| checker_high_contrast.tiff | 512x512 | 8 | Gray | LZW | 15, 240 | Checkerboard 32px |
| checker_low_contrast.tiff | 512x512 | 8 | Gray | None | 110, 130 | Checkerboard 32px |
| sine_dark.tiff | 512x512 | 8 | Gray | PackBits | 0-100 | Sine 4x |
| sine_bright.tiff | 512x512 | 8 | Gray | Deflate | 128-255 | Sine 6x |
| rgb_dark.tiff | 512x512 | 8 | RGB | LZW | R:0-60, G:0-50, B:0-70 | Gradient |
| rgb_bright.tiff | 512x512 | 8 | RGB | None | R:180-255, G:160-250, B:170-255 | Gradient |
| rgb_red_heavy.tiff | 512x512 | 8 | RGB | Deflate | R:100-255, G:10-80, B:10-60 | Gradient |
| rgb_blue_heavy.tiff | 512x512 | 8 | RGB | PackBits | R:10-60, G:10-80, B:100-255 | Gradient |
| vignette_bright.tiff | 512x512 | 8 | RGB | LZW | center:230, edge:40 | Radial |
| vignette_dark.tiff | 512x512 | 8 | RGB | None | center:120, edge:10 | Radial |
| gray16_dark.tiff | 512x512 | 16 | Gray | Deflate | 0-8000 | Gradient |
| gray16_normal.tiff | 512x512 | 16 | Gray | LZW | 5000-55000 | Gradient |
| gray16_bright.tiff | 512x512 | 16 | Gray | None | 40000-65535 | Gradient |
| rgb16_wide.tiff | 512x512 | 16 | RGB | PackBits | R:1k-60k, G:2k-58k, B:500-62k | Gradient |
| rgb16_narrow.tiff | 512x512 | 16 | RGB | Deflate | R:30k-35k, G:28k-34k, B:31k-36k | Gradient |
| float_dark.tiff | 512x512 | 32f | Gray | Deflate | 0.0-0.3 | Gradient |
| float_normal.tiff | 512x512 | 32f | Gray | LZW | 0.1-0.8 | Gradient |
| float_bright.tiff | 512x512 | 32f | Gray | None | 0.6-1.0 | Gradient |
| float_hdr.tiff | 512x512 | 32f | Gray | PackBits | 0.0-5.0 | Gradient |
| uniform_128.tiff | 512x512 | 8 | Gray | None | 128-128 (flat) | Uniform |
| tiny_32x32.tiff | 32x32 | 8 | Gray | PackBits | 20-180 | Gradient |
| large_2048x2048.tiff | 2048x2048 | 8 | RGB | LZW | R:10-245, G:5-240, B:15-250 | Gradient |
