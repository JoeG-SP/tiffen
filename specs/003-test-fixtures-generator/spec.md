# Feature Specification: Test TIFF Fixtures Generator

**Feature Branch**: `003-test-fixtures-generator`
**Created**: 2026-04-19
**Status**: Implemented
**Input**: Need for a set of TIFF test images with known characteristics to visually verify the Tiffen GUI — varying exposure ranges, bit depths, channel counts, patterns, and edge cases.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate Test Images for UI Validation (Priority: P1)

A developer or tester runs a single command to generate a directory of
TIFF files with predetermined exposure ranges and visual patterns. They
then use these files with the Tiffen GUI to visually verify normalization
behavior, histogram display, and edge case handling.

**Why this priority**: Without test images with known characteristics,
visual testing of the GUI is ad-hoc and unreliable. Generated fixtures
provide repeatable, documented inputs.

**Independent Test**: Run the generator script, verify all files are
created, open each in Preview to confirm visual content matches the
expected pattern.

**Acceptance Scenarios**:

1. **Given** the generator script is run, **When** no output directory
   is specified, **Then** files are created in `test-images/` at the
   repo root.
2. **Given** the generator script is run with a custom path, **When**
   the path is provided as an argument, **Then** files are created in
   the specified directory.
3. **Given** all files are generated, **When** the user counts them,
   **Then** 28 TIFF files exist covering all documented categories.
4. **Given** the generated files, **When** a user selects
   `BASE_reference.tiff` as the base and the output directory as input
   in the Tiffen GUI, **Then** all files normalize without errors
   (except `uniform_128.tiff` which triggers a flat exposure warning).

---

### User Story 2 - Cover All Bit Depths and Channel Counts (Priority: P1)

The generator produces files across all bit depths supported by Tiffen
(8-bit, 16-bit, 32-bit float) and both grayscale (1 channel) and RGB
(3 channels) to ensure the normalization engine handles all code paths.

**Why this priority**: Tiffen supports multiple bit depths. Each has
different normalization math and histogram binning. All must be tested.

**Independent Test**: Inspect generated files with `tiffinfo` or similar;
verify bit depth, sample format, and channel count match documentation.

**Acceptance Scenarios**:

1. **Given** generated files, **When** inspected, **Then** 8-bit, 16-bit,
   and 32-bit float files are all present.
2. **Given** generated files, **When** inspected, **Then** both
   grayscale (1 spp) and RGB (3 spp) files are present.

---

### User Story 3 - Include Edge Cases (Priority: P2)

The generator produces files that exercise edge cases: uniform pixel
values (flat exposure), very small dimensions, and large dimensions.

**Why this priority**: Edge cases reveal bugs in normalization (division
by zero), UI layout (table with many files), and performance (large files).

**Independent Test**: Process edge case files through the CLI and verify
correct behavior (flat exposure warning, successful output).

**Acceptance Scenarios**:

1. **Given** `uniform_128.tiff`, **When** normalized, **Then** a flat
   exposure warning is emitted and the file is processed.
2. **Given** `tiny_32x32.tiff`, **When** normalized, **Then** it
   completes without error.
3. **Given** `large_2048x2048.tiff`, **When** normalized, **Then** it
   completes within reasonable time.

---

### Edge Cases

- What happens if the output directory already exists? The script
  writes into it, overwriting any existing files with the same names.
- What happens if libtiff is not installed? The compilation step fails
  with a clear linker error.
- What happens if the script is run from a different working directory?
  It uses `$SCRIPT_DIR` to locate the source file, so it works from
  any directory.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a shell script (`tools/generate-test-tiffs.sh`)
  that compiles and runs the generator.
- **FR-002**: System MUST accept an optional output directory argument
  (default: `test-images/` at repo root).
- **FR-003**: System MUST generate a designated base reference file
  (`BASE_reference.tiff`) — 8-bit RGB with moderate exposure range.
- **FR-004**: System MUST generate 8-bit grayscale files with varying
  exposure ranges: dark, normal, bright, full range, narrow.
- **FR-005**: System MUST generate 8-bit grayscale pattern files:
  checkerboards (high/low contrast), sine waves (dark/bright).
- **FR-006**: System MUST generate 8-bit RGB files with varying exposure:
  dark, bright, red-heavy, blue-heavy, vignettes.
- **FR-007**: System MUST generate 16-bit files: grayscale (dark, normal,
  bright) and RGB (wide range, narrow range).
- **FR-008**: System MUST generate 32-bit float files: dark, normal,
  bright, and HDR (0–5 range).
- **FR-009**: System MUST generate edge case files: uniform (flat exposure),
  tiny (32x32), and large (2048x2048).
- **FR-010**: All generated TIFFs MUST use Deflate compression.
- **FR-011**: The generator MUST be written in Objective-C and compiled
  with clang linking libtiff. No additional dependencies.
- **FR-012**: Generated test images MUST be gitignored (`test-images/`).
- **FR-013**: System MUST print a summary of generated files and usage
  instructions to stdout.

### Key Entities

- **Base reference file**: `BASE_reference.tiff` — the file users select
  as the normalization target in the Tiffen GUI.
- **Test categories**: grayscale 8-bit, patterns 8-bit, RGB 8-bit,
  16-bit, 32-bit float, edge cases.
- **Shell wrapper**: `tools/generate-test-tiffs.sh` — compiles, runs,
  and cleans up the generator binary.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running the script produces exactly 28 TIFF files.
- **SC-002**: All generated files are valid TIFFs readable by libtiff,
  Preview.app, and the Tiffen CLI.
- **SC-003**: Processing all generated files with the Tiffen CLI using
  `BASE_reference.tiff` as base completes with 0 errors (1 warning
  for `uniform_128.tiff`).
- **SC-004**: The generator compiles and runs in under 5 seconds.

## Assumptions

- libtiff is installed via Homebrew at `/opt/homebrew`.
- The user has Xcode command-line tools (clang) available.
- Generated images are for testing only and do not need to be
  photographic or visually realistic — patterns and gradients suffice.
- 512x512 is the default image size; this is large enough to see
  histogram detail but small enough for fast generation.
