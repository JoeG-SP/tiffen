# Feature Specification: TIFF Exposure Normalization

**Feature Branch**: `001-tiff-exposure-normalization`
**Created**: 2026-04-17
**Status**: Draft
**Input**: User description: "Make a series of TIFF files in a directory have the same exposure range as a user-specified base TIFF"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Normalize Directory to Base TIFF (Priority: P1)

A user has a directory of TIFF images captured under varying exposure
conditions. They select one image as the "base" reference and run
Tiffen against the directory. Every other TIFF in the directory is
re-mapped so its exposure range matches the base file. The normalized
files are written to an output location, leaving originals untouched.

**Why this priority**: This is the entire core purpose of Tiffen.
Without this, the tool has no value.

**Independent Test**: Can be fully tested by providing a directory
of TIFFs with known differing exposure ranges, running the tool,
and verifying output files match the base exposure range.

**Acceptance Scenarios**:

1. **Given** a directory with 5 TIFF files and a designated base TIFF,
   **When** the user runs Tiffen with the base file and directory as
   arguments, **Then** 4 normalized TIFF files are written to the
   output location with exposure ranges matching the base.
2. **Given** a directory containing the base TIFF itself,
   **When** normalization runs, **Then** the base file is skipped
   (not re-processed) or output unchanged.
3. **Given** a base TIFF and directory with mixed bit depths (8-bit
   and 16-bit), **When** normalization runs, **Then** each output
   retains its original bit depth while matching the base exposure
   range.

---

### User Story 2 - In-Place Normalization (Priority: P2)

A user wants to normalize files and overwrite the originals to save
disk space. They pass an explicit flag (e.g., `--in-place`) to
indicate consent. Tiffen overwrites each source file with its
normalized version.

**Why this priority**: Convenience feature for users who do not need
to preserve originals. Builds on the core normalization from US1.

**Independent Test**: Run with `--in-place` on a copy of test files,
verify originals are replaced with normalized versions.

**Acceptance Scenarios**:

1. **Given** the `--in-place` flag is provided, **When** normalization
   runs, **Then** each source TIFF is overwritten with its normalized
   version.
2. **Given** the `--in-place` flag is NOT provided, **When**
   normalization runs, **Then** original files are never modified.

---

### User Story 3 - Progress and Error Reporting (Priority: P3)

A user runs Tiffen on a large directory (hundreds of files). They see
progress output on stdout indicating which file is being processed
and a summary on completion. If any file cannot be processed (corrupt,
unsupported format), the tool reports the error on stderr and
continues processing remaining files.

**Why this priority**: Usability for real-world workloads. Without
feedback, users cannot tell if the tool is working or stalled.

**Independent Test**: Run on a directory containing one corrupt file
among valid TIFFs, verify progress output appears and the corrupt
file is reported on stderr while valid files are normalized.

**Acceptance Scenarios**:

1. **Given** a directory with 100 TIFF files, **When** normalization
   runs, **Then** stdout shows progress for each file processed.
2. **Given** a directory containing a corrupt TIFF, **When**
   normalization encounters it, **Then** an error is reported on
   stderr, the file is skipped, and processing continues.
3. **Given** all files are processed, **When** the tool finishes,
   **Then** a summary line reports total files processed, skipped,
   and any errors.

---

### Edge Cases

- What happens when the directory contains non-TIFF files?
  They MUST be silently skipped (not treated as errors).
- What happens when the base TIFF does not exist or is unreadable?
  The tool MUST exit with a non-zero code and a clear error message.
- What happens when the directory is empty or contains only the base
  file? The tool MUST exit successfully with a message indicating
  no files to process.
- What happens when the output directory does not exist?
  The tool MUST create it automatically.
- What happens when a TIFF has a different number of channels than
  the base? The tool MUST normalize per-channel exposure ranges
  independently.
- What happens when a target TIFF has uniform pixel values (flat
  exposure, min == max) on one or more channels? The tool MUST
  map those channels to base_min, emit a warning on stderr, and
  continue processing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST accept a base TIFF file path and a target
  directory as input arguments.
- **FR-002**: System MUST compute the exposure range (min/max pixel
  values per channel) of the base TIFF.
- **FR-003**: System MUST re-map pixel values in each target TIFF so
  the output exposure range matches the base TIFF range.
- **FR-004**: System MUST write normalized files to an output
  directory, preserving original filenames.
- **FR-005**: System MUST preserve the original bit depth and channel
  count of each input TIFF in the output.
- **FR-006**: System MUST skip non-TIFF files in the target directory
  without error.
- **FR-007**: System MUST support an `--in-place` flag to overwrite
  originals instead of writing to a separate output location.
- **FR-008**: System MUST report progress to stdout and errors to
  stderr.
- **FR-009**: System MUST exit with code 0 on success and non-zero
  on failure.
- **FR-010**: System MUST support 8-bit, 16-bit, and 32-bit (integer
  and floating point) TIFF files.

### Key Entities

- **Base TIFF**: The reference image whose exposure range all other
  files are normalized to. Key attributes: file path, per-channel
  min/max pixel values, bit depth, channel count.
- **Target TIFF**: An input image to be normalized. Same attributes
  as Base TIFF plus its computed output pixel mapping.
- **Exposure Range**: A per-channel pair of (min, max) pixel values
  representing the dynamic range of an image.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All output files have per-channel min/max pixel values
  matching the base TIFF within documented precision (e.g., +/- 1
  for integer types, +/- 1e-6 for floating point).
- **SC-002**: A directory of 1,000 TIFF files is processed without
  the user experiencing an unreasonable wait (linear time scaling).
- **SC-003**: Original files are never modified unless `--in-place`
  is explicitly provided.
- **SC-004**: 100% of corrupt or unsupported files are reported on
  stderr without halting the batch.

## Assumptions

- Users are photographers, scientists, or imaging professionals
  working with TIFF files on macOS.
- Input directories contain predominantly TIFF files; non-TIFF files
  are incidental and should be ignored.
- Exposure normalization means linear re-mapping of pixel values to
  match the base range, not histogram equalization or perceptual
  tone mapping.
- The base TIFF is always a valid, readable TIFF file.
- Output directory defaults to a subdirectory (e.g., `./normalized/`)
  alongside the input directory if not explicitly specified.
