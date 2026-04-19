# Implementation Plan: Test TIFF Fixtures Generator

**Branch**: `003-test-fixtures-generator` | **Date**: 2026-04-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification for a TIFF test image generator for visual UI testing.

## Summary

A standalone Objective-C tool that generates 28 TIFF files with known
exposure ranges, patterns, and edge cases for visual testing of the
Tiffen GUI. Compiled and run via a shell script (`tools/generate-test-tiffs.sh`).
No Xcode target — just clang + libtiff.

## Technical Context

**Language/Version**: Objective-C (standalone, compiled with clang)
**Primary Dependencies**: libtiff (already required by the project)
**Storage**: Filesystem (writes TIFF files to a configurable output directory)
**Testing**: Manual visual verification + CLI processing validation
**Target Platform**: macOS (same as Tiffen)
**Project Type**: Developer tool (not a shipping target)
**Constraints**: Must not add Xcode targets or build system complexity

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Data Safety | N/A | Generator only creates new files; never modifies existing data. |
| II. Correctness | PASS | Generated files have documented pixel values; verifiable by inspection. |
| III. CLI-First | PASS | Invoked via shell script with optional argument. |
| IV. Simplicity | PASS | Standalone file + shell script. No build system integration. |
| V. Testability | PASS | Generated files are the test inputs for the Tiffen app. SC-003 validates them end-to-end. |

## Project Structure

### Source Code

```
tools/
  generate-test-tiffs.m        Objective-C generator source
  generate-test-tiffs.sh        Shell wrapper: compile, run, cleanup

test-images/                    Generated output (gitignored)
  BASE_reference.tiff           Base file for normalization
  gray_dark.tiff                8-bit grayscale, range 0–80
  gray_normal.tiff              8-bit grayscale, range 30–200
  gray_bright.tiff              8-bit grayscale, range 150–255
  gray_full_range.tiff          8-bit grayscale, range 0–255
  gray_narrow.tiff              8-bit grayscale, range 100–130
  checker_high_contrast.tiff    8-bit checkerboard, 15/240
  checker_low_contrast.tiff     8-bit checkerboard, 110/130
  sine_dark.tiff                8-bit sine wave, range 0–100
  sine_bright.tiff              8-bit sine wave, range 128–255
  rgb_dark.tiff                 8-bit RGB, low exposure
  rgb_bright.tiff               8-bit RGB, high exposure
  rgb_red_heavy.tiff            8-bit RGB, red channel dominant
  rgb_blue_heavy.tiff           8-bit RGB, blue channel dominant
  vignette_bright.tiff          8-bit RGB, bright center, dark edges
  vignette_dark.tiff            8-bit RGB, medium center, very dark edges
  gray16_dark.tiff              16-bit grayscale, range 0–8000
  gray16_normal.tiff            16-bit grayscale, range 5000–55000
  gray16_bright.tiff            16-bit grayscale, range 40000–65535
  rgb16_wide.tiff               16-bit RGB, wide range
  rgb16_narrow.tiff             16-bit RGB, narrow range
  float_dark.tiff               32-bit float, range 0.0–0.3
  float_normal.tiff             32-bit float, range 0.1–0.8
  float_bright.tiff             32-bit float, range 0.6–1.0
  float_hdr.tiff                32-bit float, range 0.0–5.0
  uniform_128.tiff              8-bit all pixels = 128 (flat exposure)
  tiny_32x32.tiff               8-bit grayscale, 32x32 pixels
  large_2048x2048.tiff          8-bit RGB, 2048x2048 pixels
```

## Complexity Tracking

No constitution violations. Single-purpose tool with minimal scope.
