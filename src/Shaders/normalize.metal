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

struct MinMaxResult {
    float mins[4];  // per-channel min (max 4 channels)
    float maxs[4];  // per-channel max
};

kernel void minmax_uint8(
    device const uint8_t *pixelData [[buffer(0)]],
    device MinMaxResult *results [[buffer(1)]],
    constant NormalizeParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]],
    uint tgSize [[threads_per_threadgroup]])
{
    uint channels = params.channelCount;
    threadgroup float localMins[4][256];
    threadgroup float localMaxs[4][256];

    // Initialize
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
        }
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Tree reduction
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

// --- Normalization kernels ---

kernel void normalize_uint8(
    device uint8_t *pixelData [[buffer(0)]],
    constant NormalizeParams &params [[buffer(1)]],
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
    }
}

kernel void normalize_uint16(
    device uint16_t *pixelData [[buffer(0)]],
    constant NormalizeParams &params [[buffer(1)]],
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
    }
}

kernel void normalize_uint32(
    device uint32_t *pixelData [[buffer(0)]],
    constant NormalizeParams &params [[buffer(1)]],
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
    }
}

kernel void normalize_float32(
    device float *pixelData [[buffer(0)]],
    constant NormalizeParams &params [[buffer(1)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.pixelCount) return;

    uint channels = params.channelCount;
    uint base = gid * channels;

    for (uint c = 0; c < channels; c++) {
        float val = pixelData[base + c];
        val = val * params.scale[c] + params.offset[c];
        pixelData[base + c] = val;
    }
}
