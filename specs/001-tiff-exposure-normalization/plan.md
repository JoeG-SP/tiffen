# Implementation Plan: TIFF Exposure Normalization

**Branch**: `001-tiff-exposure-normalization` | **Date**: 2026-04-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-tiff-exposure-normalization/spec.md`

## Summary

Normalize the exposure range of all TIFF files in a directory to match
a user-specified base TIFF. Built as a macOS CLI tool in Objective-C
with Metal compute shaders for GPU-accelerated pixel remapping on
Apple Silicon (unified memory). A CPU reference implementation is
provided for test verification and correctness validation.

## Technical Context

**Language/Version**: Objective-C (Clang/Apple toolchain, macOS 14+ SDK)
**Primary Dependencies**: Metal framework, MetalPerformanceShaders (optional), libtiff (TIFF I/O)
**Storage**: Filesystem (TIFF files read/written directly)
**Testing**: XCTest (unit + integration), CPU reference path for Metal output verification
**Target Platform**: macOS 14+ on Apple Silicon (unified memory architecture)
**Project Type**: CLI tool
**Performance Goals**: Linear scaling with file count; GPU should process a single TIFF faster than CPU for images >1MP
**Constraints**: Apple Silicon only (unified memory assumption); no x86 fallback required
**Scale/Scope**: Directories of 1–10,000 TIFF files, individual files up to 100MP+

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Data Safety | PASS | Default writes to output dir; `--in-place` requires explicit flag |
| II. Correctness First | PASS | CPU reference path verifies Metal output; precision bounds documented per bit depth |
| III. CLI-First | PASS | All functionality via CLI args; stdout/stderr conventions followed |
| IV. Simplicity | PASS | Single-purpose tool; Metal + libtiff are minimal, justified dependencies |
| V. Testability | PASS | CPU path enables deterministic comparison against Metal output; XCTest fixtures |

No violations. Gate passed.

## Project Structure

### Documentation (this feature)

```text
specs/001-tiff-exposure-normalization/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
src/
├── main.m               # CLI entry point, argument parsing
├── TFNExposureRange.h/m # Exposure range computation (CPU)
├── TFNNormalizer.h/m    # Orchestrator: enumerate files, dispatch GPU/CPU
├── TFNMetalNormalizer.h/m # Metal compute pipeline setup + dispatch
├── TFNTIFFReader.h/m    # TIFF I/O via libtiff (read)
├── TFNTIFFWriter.h/m    # TIFF I/O via libtiff (write)
├── TFNCPUNormalizer.h/m # CPU reference normalizer (for tests)
└── Shaders/
    └── normalize.metal  # Compute kernel: out = in * scale + offset

tests/
├── unit/
│   ├── TFNExposureRangeTests.m
│   ├── TFNCPUNormalizerTests.m
│   └── TFNMetalNormalizerTests.m
├── integration/
│   ├── TFNEndToEndTests.m
│   ├── TFNInPlaceTests.m
│   ├── TFNCLITests.m          # Exit codes, --help, --version, arg validation
│   ├── TFNEdgeCaseTests.m     # Non-TIFF skip, empty dir, missing base, etc.
│   └── TFNProgressTests.m     # stdout/stderr output validation
└── fixtures/
    ├── base_8bit.tiff
    ├── base_16bit.tiff
    ├── base_32int.tiff         # 32-bit integer TIFF
    ├── base_32float.tiff
    ├── dark_8bit.tiff
    ├── bright_16bit.tiff
    ├── uniform_8bit.tiff       # All pixels same value (flat exposure)
    ├── multichannel.tiff
    ├── corrupt.tiff
    └── not_a_tiff.png          # Non-TIFF file for skip testing
```

**Structure Decision**: Single project layout. Objective-C sources in `src/`,
XCTest suites in `tests/`, Metal shader in `src/Shaders/`. Build via
Xcode project or Makefile with `xcrun metal` for shader compilation.

## Complexity Tracking

No constitution violations to justify.
