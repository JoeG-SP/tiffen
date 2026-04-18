# Tasks: TIFF Exposure Normalization

**Input**: Design documents from `specs/001-tiff-exposure-normalization/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included — the spec requires correctness verification via CPU reference path and the constitution mandates testability.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Xcode project initialization and base structure

- [ ] T001 Create Xcode command-line tool project with Metal and libtiff linking
- [ ] T002 Create directory structure: `src/`, `src/Shaders/`, `tests/unit/`, `tests/integration/`, `tests/fixtures/`
- [ ] T003 [P] Generate test fixtures: `tests/fixtures/base_8bit.tiff`, `tests/fixtures/base_16bit.tiff`, `tests/fixtures/base_32int.tiff`, `tests/fixtures/base_32float.tiff`, `tests/fixtures/dark_8bit.tiff`, `tests/fixtures/bright_16bit.tiff`, `tests/fixtures/uniform_8bit.tiff`, `tests/fixtures/multichannel.tiff`, `tests/fixtures/corrupt.tiff`, `tests/fixtures/not_a_tiff.png`
- [ ] T004 [P] Configure XCTest target with access to `tests/fixtures/`

**Checkpoint**: Project builds and test target runs (empty tests pass).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core TIFF I/O and exposure range computation that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T005 Implement `TFNTIFFReader` in `src/TFNTIFFReader.h` and `src/TFNTIFFReader.m` — read TIFF via libtiff, populate TFNTIFFImage struct (width, height, channelCount, bitDepth, isFloat, pixelData). Support 8-bit, 16-bit, 32-bit int, and 32-bit float.
- [ ] T006 Implement `TFNTIFFWriter` in `src/TFNTIFFWriter.h` and `src/TFNTIFFWriter.m` — write pixel buffer to TIFF via libtiff, preserving original bit depth, channel count, and compression.
- [ ] T007 Implement `TFNExposureRange` in `src/TFNExposureRange.h` and `src/TFNExposureRange.m` — compute per-channel min/max from a TFNTIFFImage pixel buffer. Handle flat exposure degenerate case (min == max).
- [ ] T008 [P] Write unit tests for `TFNTIFFReader` in `tests/unit/TFNTIFFReaderTests.m` — verify reading all fixture bit depths, channel counts, and that corrupt.tiff returns an error.
- [ ] T009 [P] Write unit tests for `TFNTIFFWriter` in `tests/unit/TFNTIFFWriterTests.m` — verify round-trip (read → write → read) preserves pixel data, bit depth, and channel count.
- [ ] T010 [P] Write unit tests for `TFNExposureRange` in `tests/unit/TFNExposureRangeTests.m` — verify per-channel min/max for known fixtures, verify flat exposure returns min == max.

**Checkpoint**: Can read any fixture TIFF, compute its exposure range, and write it back losslessly.

---

## Phase 3: User Story 1 — Normalize Directory to Base TIFF (Priority: P1) MVP

**Goal**: Given a base TIFF and a directory of TIFFs, write normalized copies to an output directory with exposure ranges matching the base.

**Independent Test**: Provide a directory of TIFFs with known differing exposure ranges, run the tool, verify each output file's per-channel min/max matches the base.

### Tests for User Story 1

- [ ] T011 [P] [US1] Write unit tests for `TFNCPUNormalizer` in `tests/unit/TFNCPUNormalizerTests.m` — verify `out = in * scale + offset` for 8-bit, 16-bit, 32-bit int, 32-bit float buffers. Verify rounding/clamping for integer types. Verify flat exposure handling (scale=0, offset=base_min).
- [ ] T012 [P] [US1] Write unit tests for `TFNMetalNormalizer` in `tests/unit/TFNMetalNormalizerTests.m` — verify Metal kernel output matches CPU reference output within tolerance (exact for int, 1e-6 for float). Test all bit depths.
- [ ] T013 [P] [US1] Write integration tests in `tests/integration/TFNEndToEndTests.m` — run full pipeline on fixture directory: verify output files exist, exposure ranges match base, originals untouched, base file skipped, bit depths preserved, mixed bit depth directory handled correctly.

### Implementation for User Story 1

- [ ] T014 [US1] Implement `TFNCPUNormalizer` in `src/TFNCPUNormalizer.h` and `src/TFNCPUNormalizer.m` — given a pixel buffer and TFNNormalizationParams (scale/offset), apply `out = in * scale + offset` per channel. Handle all bit depths with float32 intermediate math. Round and clamp for integer output. Handle flat exposure: scale=0, offset=base_min.
- [ ] T015 [US1] Implement Metal compute kernel in `src/Shaders/normalize.metal` — kernel receives pixel buffer (MTLBuffer, shared storage), per-channel scale and offset as uniforms, and pixel count. Apply `out = in * scale + offset`. Support uint8, uint16, uint32, and float32 pixel formats via kernel variants or runtime type dispatch.
- [ ] T016 [US1] Implement `TFNMetalNormalizer` in `src/TFNMetalNormalizer.h` and `src/TFNMetalNormalizer.m` — create MTLDevice, MTLCommandQueue, load compute pipeline from normalize.metal. Wrap pixel buffer as MTLBuffer with MTLResourceStorageModeShared. Set scale/offset uniforms. Dispatch compute and wait for completion.
- [ ] T017 [US1] Implement `TFNNormalizer` orchestrator in `src/TFNNormalizer.h` and `src/TFNNormalizer.m` — accept base TIFF path and input directory. Enumerate directory for TIFF files (skip non-TIFF by extension). Read base TIFF and compute its exposure range. For each target TIFF: read, compute range, derive scale/offset params, normalize via Metal, write to output directory. Skip base file if found in input directory. Create output directory if it does not exist.
- [ ] T018 [US1] Implement CLI entry point in `src/main.m` — parse `<base-tiff>` and `<input-directory>` positional args, `--output`/`-o` option (default: `<input-directory>/normalized/`), `--help`/`-h`, `--version`. Validate args (exit code 2 on failure). Instantiate TFNNormalizer and run. Exit code 0 on full success.

**Checkpoint**: `tiffen base.tiff photos/` normalizes all TIFFs in photos/ to photos/normalized/. All US1 tests pass. CPU and Metal output match.

---

## Phase 4: User Story 2 — In-Place Normalization (Priority: P2)

**Goal**: Add `--in-place` flag that overwrites originals instead of writing to an output directory.

**Independent Test**: Run with `--in-place` on a copy of fixture files, verify originals are replaced with normalized versions and exposure ranges match the base.

### Tests for User Story 2

- [ ] T019 [P] [US2] Write integration tests in `tests/integration/TFNInPlaceTests.m` — run with `--in-place` on a temp copy of fixtures: verify originals overwritten, exposure ranges match base. Verify without `--in-place` originals are untouched. Verify `--in-place` + `--output` together produces exit code 2 error.

### Implementation for User Story 2

- [ ] T020 [US2] Add `--in-place` flag parsing to `src/main.m` — mutually exclusive with `--output` (exit code 2 if both). Pass mode to TFNNormalizer.
- [ ] T021 [US2] Update `TFNNormalizer` in `src/TFNNormalizer.m` — when in-place mode, write normalized buffer back to original file path instead of output directory.

**Checkpoint**: `tiffen base.tiff photos/ --in-place` overwrites originals. All US2 tests pass. `--in-place` + `--output` rejected.

---

## Phase 5: User Story 3 — Progress and Error Reporting (Priority: P3)

**Goal**: Show per-file progress on stdout, report errors on stderr, print summary on completion. Support `--verbose` and `--quiet` flags.

**Independent Test**: Run on directory with a corrupt TIFF among valid files. Verify progress appears on stdout, error on stderr, valid files still normalized, summary printed.

### Tests for User Story 3

- [ ] T022 [P] [US3] Write integration tests in `tests/integration/TFNProgressTests.m` — capture stdout/stderr: verify progress lines for each file, error line for corrupt.tiff, summary line with counts. Verify `--quiet` suppresses stdout. Verify `--verbose` shows detailed output. Verify `--verbose` + `--quiet` together produces exit code 2 error.

### Implementation for User Story 3

- [ ] T023 [US3] Add `--verbose`/`-v` and `--quiet`/`-q` flag parsing to `src/main.m` — mutually exclusive (exit code 2 if both). Pass verbosity to TFNNormalizer.
- [ ] T024 [US3] Update `TFNNormalizer` in `src/TFNNormalizer.m` — emit progress to stdout (`[N/M] filename → output`), errors to stderr, flat exposure warnings to stderr. Track counts (normalized, errors, skipped). Print summary line on completion. Respect quiet/verbose modes. Return exit code 1 if any files errored (partial success).

**Checkpoint**: Progress, errors, and summary display correctly. Exit code 1 on partial failure. All US3 tests pass.

---

## Phase 6: Edge Cases and CLI Validation

**Purpose**: Cover all edge cases and CLI contract validation

### Tests

- [ ] T025 [P] Write integration tests in `tests/integration/TFNEdgeCaseTests.m` — test: non-TIFF files silently skipped (not_a_tiff.png), base TIFF missing returns exit 2, empty directory returns exit 0 with message, output dir auto-created, base inside input dir is skipped, multichannel TIFF normalized per-channel independently, uniform_8bit.tiff triggers flat exposure warning and maps to base_min.
- [ ] T026 [P] Write integration tests in `tests/integration/TFNCLITests.m` — test: `--help` prints usage and exits 0, `--version` prints version and exits 0, missing required args exits 2, invalid base TIFF path exits 2, non-directory as input exits 2.

### Implementation

- [ ] T027 Add edge case handling to `TFNNormalizer` in `src/TFNNormalizer.m` — emit flat exposure warning to stderr when scale=0 for a channel. Handle empty directory gracefully (exit 0 with message). Validate input directory exists.
- [ ] T028 Add CLI validation to `src/main.m` — validate base TIFF exists and is readable (exit 2), validate input directory is a directory (exit 2), print help text for `--help`, print version for `--version`.

**Checkpoint**: All edge cases and CLI validation tests pass. Full contract compliance.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and documentation

- [ ] T029 [P] Run full test suite and verify all tests pass
- [ ] T030 [P] Verify quickstart.md instructions work end-to-end (build, run, test)
- [ ] T031 Code cleanup: remove dead code, ensure consistent naming, verify no compiler warnings with `-Wall -Werror`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — core normalization, MVP
- **US2 (Phase 4)**: Depends on Phase 3 (builds on TFNNormalizer)
- **US3 (Phase 5)**: Depends on Phase 3 (adds output to TFNNormalizer)
- **Edge Cases (Phase 6)**: Depends on Phase 5 (needs all features in place)
- **Polish (Phase 7)**: Depends on all prior phases

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (P2)**: Depends on US1 (modifies TFNNormalizer write path)
- **US3 (P3)**: Depends on US1 (adds progress output to TFNNormalizer loop)
- **US2 and US3** touch different parts of TFNNormalizer and could be parallelized with care, but sequential is safer

### Within Each User Story

- Tests written FIRST, verified to FAIL before implementation
- Models/entities before services
- Services before orchestrator integration
- Core logic before CLI integration
- Story complete before moving to next priority

### Parallel Opportunities

- T003 and T004 can run in parallel (fixtures + test config)
- T008, T009, T010 can run in parallel (unit tests for different classes)
- T011, T012, T013 can run in parallel (US1 test files)
- T025 and T026 can run in parallel (edge case + CLI test files)
- T029, T030 can run in parallel (verification tasks)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test US1 independently — `tiffen base.tiff dir/` works end-to-end
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Test → MVP: core normalization works
3. Add US2 → Test → In-place mode available
4. Add US3 → Test → Progress/error reporting
5. Add Edge Cases → Test → Robust CLI
6. Polish → Ship

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Metal kernel is intentionally simple (single MAD) — complexity is in I/O and orchestration
- CPU normalizer mirrors Metal kernel exactly for deterministic test comparison
