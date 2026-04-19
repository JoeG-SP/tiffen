# Quickstart: Test TIFF Fixtures Generator

## Prerequisites

- macOS with Xcode command-line tools (clang)
- libtiff (`brew install libtiff`)

## Generate Test Images

```bash
./tools/generate-test-tiffs.sh
```

This creates 28 TIFF files in `test-images/` at the repo root.

To generate in a custom location:

```bash
./tools/generate-test-tiffs.sh /path/to/output
```

## Test with the Tiffen GUI

1. Build and run the GUI: select the `tiffenApp` scheme in Xcode, press ⌘R
2. Click "Browse..." next to Base TIFF, select `test-images/BASE_reference.tiff`
3. Click "Browse..." next to Input Dir, select `test-images/`
4. Click "Normalize"
5. Watch the file list populate with processing status
6. Click any completed row to see before/after histograms
7. Click the expand button to open a resizable histogram window

## Test with the Tiffen CLI

```bash
BUILD_DIR=$(xcodebuild -scheme tiffen -showBuildSettings | grep -m1 BUILT_PRODUCTS_DIR | awk '{print $3}')
$BUILD_DIR/tiffen test-images/BASE_reference.tiff test-images/ -v
```

## What to Look For

- **Gradients**: Histograms should shift from the original range to the base range
- **Checkerboards**: Before histogram shows two spikes; after shows two spikes at the base range
- **Sine waves**: Before shows a smooth bell curve; after shows the same shape shifted
- **Vignettes**: Before shows a skewed distribution; after is shifted
- **Uniform (flat)**: Should trigger a "flat exposure" warning, mapped to base_min
- **Narrow range**: Before histogram is compressed; after is stretched to base range
- **16-bit / 32-bit float**: Should normalize identically to 8-bit (same math, different precision)

## Regenerate

The files are gitignored. To regenerate after changes to the generator:

```bash
rm -rf test-images/
./tools/generate-test-tiffs.sh
```
