# Research: Test TIFF Fixtures Generator

**Date**: 2026-04-19
**Feature**: 003-test-fixtures-generator

## R1: Generator Implementation Approach

**Decision**: Standalone Objective-C source file compiled by a shell
script using clang + libtiff. No Xcode target needed.

**Rationale**: The generator is a developer tool, not a shipping product.
It only needs to run once to produce files. A standalone `.m` file
compiled with `clang -framework Foundation -ltiff` is the simplest
approach — no build system integration, no new Xcode target, no
additional dependencies. The shell script handles compilation, execution,
and cleanup of the temporary binary.

**Alternatives considered**:
- **Xcode target**: Adds permanent build complexity for a tool run
  occasionally. Rejected.
- **Python script with Pillow/tifffile**: Would require pip dependencies.
  Rejected — libtiff is already available from the project.
- **Using TFNTestFixtures from the test suite**: Those fixtures are
  designed for automated testing (small, simple). Visual testing needs
  larger images with recognizable patterns. Different requirements.

## R2: Image Content Design

**Decision**: Use gradients, checkerboards, sine waves, and vignettes
as test patterns. Each file targets a specific exposure range.

**Rationale**: Gradients produce predictable histograms (roughly uniform
distribution within the range) that are easy to verify visually. Patterns
like checkerboards produce bimodal histograms (two spikes). Sine waves
produce smooth bell-curve-like distributions. Vignettes produce
center-weighted distributions. Together these exercise the full histogram
rendering code path.

**Exposure range strategy**:
- Dark files (low min, low max): test normalization stretching upward
- Bright files (high min, high max): test normalization compressing downward
- Narrow range files: test extreme stretching
- Full range files: test identity-like normalization
- Channel-biased RGB: test per-channel normalization independence

## R3: File Naming Convention

**Decision**: Prefix base file with `BASE_` and use descriptive names
for all others: `{type}_{characteristic}.tiff`.

**Rationale**: The base file must be easily identifiable in a file
browser. Descriptive names let testers know what to expect without
opening the file. The naming convention groups files by type when
sorted alphabetically.
