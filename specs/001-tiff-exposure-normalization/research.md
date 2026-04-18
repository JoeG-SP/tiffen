# Research: TIFF Exposure Normalization

**Date**: 2026-04-17
**Feature**: 001-tiff-exposure-normalization

## R1: TIFF I/O on macOS with Objective-C

**Decision**: Use libtiff via direct C API calls from Objective-C.

**Rationale**: libtiff is the de facto standard for TIFF reading/writing.
It supports all bit depths (8, 16, 32-bit int and float), strips and
tiles, multi-channel images, and every TIFF compression format. It is a
lightweight C library with no transitive dependencies beyond zlib.
Apple ships it in the SDK but linking against Homebrew or vendored
libtiff gives version control.

**Alternatives considered**:
- **ImageIO.framework (CGImageSource/CGImageDestination)**: Higher-level
  Apple API. Handles common TIFF cases but abstracts away direct pixel
  access at specific bit depths. Converting through CGImage normalizes
  to premultiplied alpha and 8/16-bit, losing 32-bit float fidelity.
  Rejected for precision reasons.
- **vImage (Accelerate.framework)**: Good for pixel transforms but
  still requires ImageIO for TIFF decode. Same precision limitations.
- **OpenImageIO**: Full-featured but heavy dependency. Overkill for
  TIFF-only use case.

## R2: Metal Compute for Pixel Remapping

**Decision**: Use a single Metal compute shader that performs linear
per-channel remapping: `out = (in - src_min) / (src_max - src_min) * (base_max - base_min) + base_min`.

**Rationale**: The normalization operation is embarrassingly parallel —
each pixel is independent. A Metal compute kernel maps directly to this
workload. On Apple Silicon, unified memory means the pixel buffer can
be shared between CPU (libtiff decode) and GPU (Metal compute) without
an explicit copy, using `MTLResourceStorageModeShared`.

**Key design decisions**:
- Pixel data is decoded by libtiff into a contiguous buffer.
- The buffer is wrapped in an `MTLBuffer` with shared storage (no copy
  on Apple Silicon unified memory).
- The compute kernel operates on the buffer in-place (in GPU memory,
  not in the source file).
- The kernel receives precomputed per-channel scale and offset
  uniforms. Each pixel is normalized via `out = in * scale + offset`
  — a single multiply-add with no branching or division.
- After the kernel completes, libtiff writes the buffer back to disk.
- For integer types (uint8, uint16), the kernel works in float32 and
  rounds/clamps on output.
- For float32 TIFFs, the kernel operates natively.

**Alternatives considered**:
- **CPU-only (vDSP/Accelerate)**: Would work and avoid Metal complexity.
  Rejected as user explicitly requested Metal/GPU solution. However,
  the CPU path is retained as a reference for test verification.
- **MPS (MetalPerformanceShaders)**: No built-in kernel for arbitrary
  linear remapping. Would still need a custom compute shader.

## R3: Exposure Range Computation

**Decision**: Compute min/max per channel using a two-pass approach:
first pass computes base TIFF range, second pass normalizes each target.

**Rationale**: Computing min/max requires reading all pixels. For the
base TIFF this is a single scan. For target TIFFs, the min/max scan
and normalization can be fused into a single Metal dispatch using
a parallel reduction for min/max followed by the remap kernel, or
kept as two separate dispatches for clarity.

**Implementation approach**:
- Base range: CPU scan via libtiff (single file, done once).
- Target range: Metal parallel reduction per channel, then remap.
- For simplicity in v1, target min/max can also be computed on CPU
  during the libtiff decode pass, avoiding a reduction kernel.
  The remap kernel then only needs the four values (src_min, src_max,
  base_min, base_max) as uniforms.

**Two-pass approach per target file**:
- **Pass 1 (min/max scan)**: Read all pixels and compute per-channel
  min and max. This can be a Metal parallel reduction or a CPU scan
  during the libtiff decode (since we touch every pixel anyway).
- **Precompute scale+offset**: Once both base and target ranges are
  known, compute per-channel: `scale = (base_max - base_min) / (src_max - src_min)`
  and `offset = base_min - src_min * scale`. These are scalar values.
- **Pass 2 (normalize)**: The compute kernel applies
  `out = in * scale + offset` per channel. No min/max lookup, no
  branching, no division — just a multiply-add. This makes the
  normalization kernel extremely cheap (ALU-bound, single MAD
  per pixel per channel).

**Decision for v1**: Compute target min/max on CPU during the libtiff
decode pass (single scan through pixel data anyway). Precompute
scale and offset on CPU. The Metal kernel only performs the
multiply-add, keeping it minimal and fast.

**Degenerate case — flat exposure (src_max == src_min)**:
When a target image has uniform pixel values on a channel, the
scale computation divides by zero. Behavior: set scale=0 and
offset=base_min for that channel. This maps all pixels to
base_min, which is the only mathematically consistent result
(a zero-range source cannot be stretched). The file is still
processed (not skipped), and a warning is emitted to stderr.

## R4: Build System

**Decision**: Xcode project with a command-line tool target.

**Rationale**: Xcode natively compiles Metal shaders (`.metal` files)
and links the Metal framework. Objective-C compilation, libtiff
linking, and XCTest integration are all first-class. A Makefile
alternative is feasible (`xcrun metal` for shaders, `clang` for
Objective-C) but adds maintenance burden for no benefit on a
macOS-only project.

**Alternatives considered**:
- **Makefile + xcrun**: Works but duplicates what Xcode does
  natively. Harder to manage Metal shader compilation and XCTest.
- **CMake**: Cross-platform benefit not needed (macOS-only).
- **Swift Package Manager**: Does not support Metal shader
  compilation or Objective-C XCTest targets cleanly.

## R5: Test Strategy — CPU Reference Path

**Decision**: Implement a pure CPU normalizer (`TFNCPUNormalizer`)
that performs identical math to the Metal kernel. Tests run both
paths and compare output buffers within precision tolerance.

**Rationale**: Metal compute results can vary slightly due to GPU
floating-point implementation. A CPU reference path with known
IEEE 754 behavior provides a deterministic baseline. Tests verify
that Metal output matches CPU output within:
- Integer types: exact match (both round to nearest integer)
- Float32: tolerance of 1e-6 (relative)

This satisfies Constitution Principle V (Testability) without
requiring GPU availability in CI (CPU path can run headless).
