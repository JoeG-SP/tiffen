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
