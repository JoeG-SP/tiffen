#import "TFNCPUNormalizer.h"
#include <math.h>

@implementation TFNNormalizationParams {
    float *_scaleStorage;
    float *_offsetStorage;
}

- (instancetype)initWithChannelCount:(NSUInteger)channelCount
                               scale:(const float *)scale
                              offset:(const float *)offset {
    self = [super init];
    if (self) {
        _channelCount = channelCount;
        _scaleStorage = calloc(channelCount, sizeof(float));
        _offsetStorage = calloc(channelCount, sizeof(float));
        memcpy(_scaleStorage, scale, channelCount * sizeof(float));
        memcpy(_offsetStorage, offset, channelCount * sizeof(float));
    }
    return self;
}

- (void)dealloc {
    free(_scaleStorage);
    free(_offsetStorage);
}

- (const float *)scale {
    return _scaleStorage;
}

- (const float *)offset {
    return _offsetStorage;
}

+ (instancetype)paramsWithBaseRange:(TFNExposureRange *)baseRange
                        sourceRange:(TFNExposureRange *)sourceRange {
    NSUInteger channels = baseRange.channelCount;
    float *scale = calloc(channels, sizeof(float));
    float *offset = calloc(channels, sizeof(float));

    for (NSUInteger c = 0; c < channels; c++) {
        float srcMin = sourceRange.minValues[c];
        float srcMax = sourceRange.maxValues[c];
        float baseMin = baseRange.minValues[c];
        float baseMax = baseRange.maxValues[c];

        float srcRange = srcMax - srcMin;
        if (srcRange == 0.0f) {
            // Degenerate: flat exposure — map all to base_min
            scale[c] = 0.0f;
            offset[c] = baseMin;
        } else {
            scale[c] = (baseMax - baseMin) / srcRange;
            offset[c] = baseMin - srcMin * scale[c];
        }
    }

    TFNNormalizationParams *params =
        [[TFNNormalizationParams alloc] initWithChannelCount:channels
                                                       scale:scale
                                                      offset:offset];
    free(scale);
    free(offset);
    return params;
}

@end

@implementation TFNCPUNormalizer

+ (void)normalizePixelData:(void *)pixelData
               pixelCount:(NSUInteger)pixelCount
             channelCount:(NSUInteger)channelCount
                 bitDepth:(NSUInteger)bitDepth
                  isFloat:(BOOL)isFloat
                   params:(TFNNormalizationParams *)params {
    const float *scale = params.scale;
    const float *offset = params.offset;

    for (NSUInteger i = 0; i < pixelCount; i++) {
        for (NSUInteger c = 0; c < channelCount; c++) {
            NSUInteger idx = i * channelCount + c;
            float val;

            // Read
            if (isFloat && bitDepth == 32) {
                val = ((float *)pixelData)[idx];
            } else if (bitDepth == 8) {
                val = (float)((uint8_t *)pixelData)[idx];
            } else if (bitDepth == 16) {
                val = (float)((uint16_t *)pixelData)[idx];
            } else if (bitDepth == 32) {
                val = (float)((uint32_t *)pixelData)[idx];
            } else {
                continue;
            }

            // Normalize: out = in * scale + offset
            val = val * scale[c] + offset[c];

            // Write back with clamping for integer types
            if (isFloat && bitDepth == 32) {
                ((float *)pixelData)[idx] = val;
            } else if (bitDepth == 8) {
                val = roundf(val);
                if (val < 0.0f) val = 0.0f;
                if (val > 255.0f) val = 255.0f;
                ((uint8_t *)pixelData)[idx] = (uint8_t)val;
            } else if (bitDepth == 16) {
                val = roundf(val);
                if (val < 0.0f) val = 0.0f;
                if (val > 65535.0f) val = 65535.0f;
                ((uint16_t *)pixelData)[idx] = (uint16_t)val;
            } else if (bitDepth == 32) {
                val = roundf(val);
                if (val < 0.0f) val = 0.0f;
                if (val > 4294967295.0f) val = 4294967295.0f;
                ((uint32_t *)pixelData)[idx] = (uint32_t)val;
            }
        }
    }
}

@end
