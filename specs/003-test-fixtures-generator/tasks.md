# Tasks: Test TIFF Fixtures Generator

**Input**: Design documents from `/specs/003-test-fixtures-generator/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [x] T001 Create `tools/` directory at repo root
- [x] T002 Add `test-images/` to `.gitignore`

---

## Phase 2: Generator Implementation (US1, US2)

- [x] T003 [US1] Create `tools/generate-test-tiffs.m` — standalone Objective-C source with `writeTIFF()` helper that wraps libtiff for creating TIFF files with arbitrary bit depth, channels, and compression
- [x] T004 [P] [US1] Implement 8-bit grayscale gradient generator — `generateGrayscaleGradient8()` producing horizontal gradient from minVal to maxVal
- [x] T005 [P] [US1] Implement 8-bit RGB gradient generator — `generateRGBGradient8()` producing 2D gradient (R=horizontal, G=vertical, B=diagonal)
- [x] T006 [P] [US1] Implement checkerboard generator — `generateCheckerboard8()` with configurable block size and light/dark values
- [x] T007 [P] [US1] Implement sine wave generator — `generateSineWave8()` with configurable frequency and range
- [x] T008 [P] [US1] Implement vignette generator — `generateVignette8()` with radial falloff from center to edge, RGB output
- [x] T009 [P] [US2] Implement 16-bit grayscale gradient generator — `generateGrayscaleGradient16()`
- [x] T010 [P] [US2] Implement 16-bit RGB gradient generator — `generateRGBGradient16()`
- [x] T011 [P] [US2] Implement 32-bit float gradient generator — `generateGrayscaleGradientFloat()`
- [x] T012 [US1] Implement `main()` — create output directory, generate all 28 files across categories, print summary and usage instructions

---

## Phase 3: Shell Wrapper

- [x] T013 [US1] Create `tools/generate-test-tiffs.sh` — compile `generate-test-tiffs.m` with `clang -fobjc-arc -framework Foundation -ltiff -lz`, run binary with output directory argument, clean up temporary binary
- [x] T014 [US1] Make shell script executable (`chmod +x`)

---

## Phase 4: Edge Cases (US3)

- [x] T015 [US3] Generate `uniform_128.tiff` — all pixels set to 128 (flat exposure, triggers warning)
- [x] T016 [P] [US3] Generate `tiny_32x32.tiff` — 32x32 8-bit grayscale gradient
- [x] T017 [P] [US3] Generate `large_2048x2048.tiff` — 2048x2048 8-bit RGB gradient

---

## Phase 5: Validation

- [x] T018 Run `./tools/generate-test-tiffs.sh` and verify 28 files created
- [x] T019 Process all generated files with Tiffen CLI using `BASE_reference.tiff` as base — verify 0 errors, 1 flat exposure warning
- [x] T020 Verify generated files open correctly in Preview.app

---

## Dependencies & Execution Order

- **Phase 1**: No dependencies
- **Phase 2**: Depends on Phase 1; T004–T011 parallelizable; T012 depends on all generators
- **Phase 3**: Depends on Phase 2
- **Phase 4**: Depends on T003 (writeTIFF helper) + T012 (main function)
- **Phase 5**: Depends on all previous phases

## Implementation Strategy

All tasks completed in a single pass. The generator is a self-contained
tool with no dependencies on the Tiffen build system.

---

## Notes

- All code is Objective-C — no Swift files
- Generator binary is compiled to `/tmp/` and deleted after run
- Generated images are gitignored and must be regenerated locally
- Default image size is 512x512 except for edge cases
