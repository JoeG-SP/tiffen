#include <metal_stdlib>
using namespace metal;

/// Per-channel normalization parameters.
/// Kernel applies: out = in * scale + offset
struct NormalizeParams {
    float scale[4];   // per-channel scale (max 4 channels)
    float offset[4];  // per-channel offset
    uint channelCount;
    uint bitDepth;     // 8, 16, or 32
    uint isFloat;      // 1 for float32, 0 for integer
    uint pixelCount;   // total pixels (width * height)
};

// --- Min/Max parallel reduction kernels ---
// Each threadgroup reduces its chunk to a single min/max per channel,
// written to the output buffer. CPU does the final reduction over
// threadgroup results.
// Histogram bins are atomically incremented per-pixel (fused, no extra pass).

struct MinMaxResult {
    float mins[4];  // per-channel min (max 4 channels)
    float maxs[4];  // per-channel max
};

// Helper: compute histogram bin index for a float value at a given bit depth.
// Layout: histogram buffer has channelCount * 256 contiguous uint32 entries.
inline uint histBinUint8(float val) {
    return clamp(uint(val), 0u, 255u);
}

inline uint histBinUint16(float val) {
    return clamp(uint(val * 255.0f / 65535.0f), 0u, 255u);
}

inline uint histBinUint32(float val) {
    return clamp(uint(val * 255.0f / 4294967295.0f), 0u, 255u);
}

inline uint histBinFloat(float val, float rangeMin, float rangeMax) {
    if (rangeMax <= rangeMin) return 0;
    float t = (val - rangeMin) / (rangeMax - rangeMin);
    return clamp(uint(t * 255.0f), 0u, 255u);
}

// --- MinMax + Histogram kernels ---
// buffer(3) = histogram: channelCount * 256 atomic_uint entries.
// For float32, we need min/max to compute bins, but we don't have them yet
// during the minmax pass. For float32, histogram is deferred — we use the
// same kernel signature but the caller may pass a null-length buffer to skip.

kernel void minmax_uint8(
    device const uint8_t *pixelData [[buffer(0)]],
    device MinMaxResult *results [[buffer(1)]],
    constant NormalizeParams &params [[buffer(2)]],
    device atomic_uint *histogram [[buffer(3)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]],
    uint tgSize [[threads_per_threadgroup]])
{
    uint channels = params.channelCount;
    threadgroup float localMins[4][256];
    threadgroup float localMaxs[4][256];

    for (uint c = 0; c < channels; c++) {
        localMins[c][tid] = FLT_MAX;
        localMaxs[c][tid] = -FLT_MAX;
    }

    if (gid < params.pixelCount) {
        uint base = gid * channels;
        for (uint c = 0; c < channels; c++) {
            float val = float(pixelData[base + c]);
            localMins[c][tid] = val;
            localMaxs[c][tid] = val;
            // Fused histogram: 8-bit direct mapping
            uint bin = histBinUint8(val);
            atomic_fetch_add_explicit(&histogram[c * 256 + bin], 1, memory_order_relaxed);
        }
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            for (uint c = 0; c < channels; c++) {
                localMins[c][tid] = min(localMins[c][tid], localMins[c][tid + stride]);
                localMaxs[c][tid] = max(localMaxs[c][tid], localMaxs[c][tid + stride]);
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        for (uint c = 0; c < channels; c++) {
            results[tgid].mins[c] = localMins[c][0];
            results[tgid].maxs[c] = localMaxs[c][0];
        }
    }
}

kernel void minmax_uint16(
    device const uint16_t *pixelData [[buffer(0)]],
    device MinMaxResult *results [[buffer(1)]],
    constant NormalizeParams &params [[buffer(2)]],
    device atomic_uint *histogram [[buffer(3)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]],
    uint tgSize [[threads_per_threadgroup]])
{
    uint channels = params.channelCount;
    threadgroup float localMins[4][256];
    threadgroup float localMaxs[4][256];

    for (uint c = 0; c < channels; c++) {
        localMins[c][tid] = FLT_MAX;
        localMaxs[c][tid] = -FLT_MAX;
    }

    if (gid < params.pixelCount) {
        uint base = gid * channels;
        for (uint c = 0; c < channels; c++) {
            float val = float(pixelData[base + c]);
            localMins[c][tid] = val;
            localMaxs[c][tid] = val;
            uint bin = histBinUint16(val);
            atomic_fetch_add_explicit(&histogram[c * 256 + bin], 1, memory_order_relaxed);
        }
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            for (uint c = 0; c < channels; c++) {
                localMins[c][tid] = min(localMins[c][tid], localMins[c][tid + stride]);
                localMaxs[c][tid] = max(localMaxs[c][tid], localMaxs[c][tid + stride]);
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        for (uint c = 0; c < channels; c++) {
            results[tgid].mins[c] = localMins[c][0];
            results[tgid].maxs[c] = localMaxs[c][0];
        }
    }
}

kernel void minmax_uint32(
    device const uint32_t *pixelData [[buffer(0)]],
    device MinMaxResult *results [[buffer(1)]],
    constant NormalizeParams &params [[buffer(2)]],
    device atomic_uint *histogram [[buffer(3)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]],
    uint tgSize [[threads_per_threadgroup]])
{
    uint channels = params.channelCount;
    threadgroup float localMins[4][256];
    threadgroup float localMaxs[4][256];

    for (uint c = 0; c < channels; c++) {
        localMins[c][tid] = FLT_MAX;
        localMaxs[c][tid] = -FLT_MAX;
    }

    if (gid < params.pixelCount) {
        uint base = gid * channels;
        for (uint c = 0; c < channels; c++) {
            float val = float(pixelData[base + c]);
            localMins[c][tid] = val;
            localMaxs[c][tid] = val;
            uint bin = histBinUint32(val);
            atomic_fetch_add_explicit(&histogram[c * 256 + bin], 1, memory_order_relaxed);
        }
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            for (uint c = 0; c < channels; c++) {
                localMins[c][tid] = min(localMins[c][tid], localMins[c][tid + stride]);
                localMaxs[c][tid] = max(localMaxs[c][tid], localMaxs[c][tid + stride]);
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        for (uint c = 0; c < channels; c++) {
            results[tgid].mins[c] = localMins[c][0];
            results[tgid].maxs[c] = localMaxs[c][0];
        }
    }
}

kernel void minmax_float32(
    device const float *pixelData [[buffer(0)]],
    device MinMaxResult *results [[buffer(1)]],
    constant NormalizeParams &params [[buffer(2)]],
    device atomic_uint *histogram [[buffer(3)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]],
    uint tgSize [[threads_per_threadgroup]])
{
    uint channels = params.channelCount;
    threadgroup float localMins[4][256];
    threadgroup float localMaxs[4][256];

    for (uint c = 0; c < channels; c++) {
        localMins[c][tid] = FLT_MAX;
        localMaxs[c][tid] = -FLT_MAX;
    }

    if (gid < params.pixelCount) {
        uint base = gid * channels;
        for (uint c = 0; c < channels; c++) {
            float val = pixelData[base + c];
            localMins[c][tid] = val;
            localMaxs[c][tid] = val;
            // For float32, we cannot compute histogram during minmax because
            // we need the range (min/max) first. The histogram for float32
            // "before" is computed in a separate lightweight pass after minmax
            // completes. This is still cheaper than a full CPU traversal.
        }
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            for (uint c = 0; c < channels; c++) {
                localMins[c][tid] = min(localMins[c][tid], localMins[c][tid + stride]);
                localMaxs[c][tid] = max(localMaxs[c][tid], localMaxs[c][tid + stride]);
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        for (uint c = 0; c < channels; c++) {
            results[tgid].mins[c] = localMins[c][0];
            results[tgid].maxs[c] = localMaxs[c][0];
        }
    }
}

// --- Normalization + After-Histogram kernels ---
// buffer(2) = histogram: channelCount * 256 atomic_uint entries for after-normalization histogram.

kernel void normalize_uint8(
    device uint8_t *pixelData [[buffer(0)]],
    constant NormalizeParams &params [[buffer(1)]],
    device atomic_uint *histogram [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.pixelCount) return;

    uint channels = params.channelCount;
    uint base = gid * channels;

    for (uint c = 0; c < channels; c++) {
        float val = float(pixelData[base + c]);
        val = val * params.scale[c] + params.offset[c];
        val = round(val);
        val = clamp(val, 0.0f, 255.0f);
        pixelData[base + c] = uint8_t(val);
        // Fused after-histogram
        uint bin = histBinUint8(val);
        atomic_fetch_add_explicit(&histogram[c * 256 + bin], 1, memory_order_relaxed);
    }
}

kernel void normalize_uint16(
    device uint16_t *pixelData [[buffer(0)]],
    constant NormalizeParams &params [[buffer(1)]],
    device atomic_uint *histogram [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.pixelCount) return;

    uint channels = params.channelCount;
    uint base = gid * channels;

    for (uint c = 0; c < channels; c++) {
        float val = float(pixelData[base + c]);
        val = val * params.scale[c] + params.offset[c];
        val = round(val);
        val = clamp(val, 0.0f, 65535.0f);
        pixelData[base + c] = uint16_t(val);
        uint bin = histBinUint16(val);
        atomic_fetch_add_explicit(&histogram[c * 256 + bin], 1, memory_order_relaxed);
    }
}

kernel void normalize_uint32(
    device uint32_t *pixelData [[buffer(0)]],
    constant NormalizeParams &params [[buffer(1)]],
    device atomic_uint *histogram [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.pixelCount) return;

    uint channels = params.channelCount;
    uint base = gid * channels;

    for (uint c = 0; c < channels; c++) {
        float val = float(pixelData[base + c]);
        val = val * params.scale[c] + params.offset[c];
        val = round(val);
        val = clamp(val, 0.0f, 4294967295.0f);
        pixelData[base + c] = uint32_t(val);
        uint bin = histBinUint32(val);
        atomic_fetch_add_explicit(&histogram[c * 256 + bin], 1, memory_order_relaxed);
    }
}

kernel void normalize_float32(
    device float *pixelData [[buffer(0)]],
    constant NormalizeParams &params [[buffer(1)]],
    device atomic_uint *histogram [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.pixelCount) return;

    uint channels = params.channelCount;
    uint base = gid * channels;

    for (uint c = 0; c < channels; c++) {
        float val = pixelData[base + c];
        val = val * params.scale[c] + params.offset[c];
        pixelData[base + c] = val;
        // After-histogram for float: use scale/offset to map back to 0-255 bins
        // The output range is [base_min, base_max], map linearly to bins
        // offset = base_min - src_min * scale, so base_min = offset + src_min * scale
        // For the after histogram, val is already in [base_min, base_max] range
        // We use params.offset[c] as base_min proxy and compute base_max from scale
        // Simpler: just map output val to 0-255 using the base range from params
        // The base range isn't directly in params, but val is in that range.
        // We'll bin relative to all output values — the caller will pass
        // base min/max as additional info. For now, use a simple approach:
        // bin = clamp((val - offset) / (scale != 0 ? 1.0/scale : 1.0) * 255 / maxVal, 0, 255)
        // Actually, the simplest correct approach: the after histogram for floats
        // is computed on CPU from the output buffer, since we need the base range.
        // For integer types, the range is implicit (0-255, 0-65535, 0-4294967295).
        // For float32 after-histogram, we skip GPU and do CPU.
    }
}
