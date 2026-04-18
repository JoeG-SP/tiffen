#import "TFNExposureRange.h"

@implementation TFNExposureRange {
    float *_minStorage;
    float *_maxStorage;
}

- (instancetype)initWithChannelCount:(NSUInteger)channelCount
                           minValues:(const float *)minValues
                           maxValues:(const float *)maxValues {
    self = [super init];
    if (self) {
        _channelCount = channelCount;
        _minStorage = calloc(channelCount, sizeof(float));
        _maxStorage = calloc(channelCount, sizeof(float));
        memcpy(_minStorage, minValues, channelCount * sizeof(float));
        memcpy(_maxStorage, maxValues, channelCount * sizeof(float));
    }
    return self;
}

- (void)dealloc {
    free(_minStorage);
    free(_maxStorage);
}

- (const float *)minValues {
    return _minStorage;
}

- (const float *)maxValues {
    return _maxStorage;
}

+ (nullable instancetype)rangeFromPixelData:(const void *)pixelData
                                      width:(NSUInteger)width
                                     height:(NSUInteger)height
                               channelCount:(NSUInteger)channelCount
                                   bitDepth:(NSUInteger)bitDepth
                                    isFloat:(BOOL)isFloat {
    if (!pixelData || width == 0 || height == 0 || channelCount == 0) {
        return nil;
    }

    NSUInteger pixelCount = width * height;
    float *mins = calloc(channelCount, sizeof(float));
    float *maxs = calloc(channelCount, sizeof(float));

    // Initialize to extreme values
    for (NSUInteger c = 0; c < channelCount; c++) {
        mins[c] = FLT_MAX;
        maxs[c] = -FLT_MAX;
    }

    for (NSUInteger i = 0; i < pixelCount; i++) {
        for (NSUInteger c = 0; c < channelCount; c++) {
            NSUInteger idx = i * channelCount + c;
            float val;

            if (isFloat && bitDepth == 32) {
                val = ((const float *)pixelData)[idx];
            } else if (bitDepth == 8) {
                val = (float)((const uint8_t *)pixelData)[idx];
            } else if (bitDepth == 16) {
                val = (float)((const uint16_t *)pixelData)[idx];
            } else if (bitDepth == 32) {
                val = (float)((const uint32_t *)pixelData)[idx];
            } else {
                free(mins);
                free(maxs);
                return nil;
            }

            if (val < mins[c]) mins[c] = val;
            if (val > maxs[c]) maxs[c] = val;
        }
    }

    TFNExposureRange *range = [[TFNExposureRange alloc] initWithChannelCount:channelCount
                                                                   minValues:mins
                                                                   maxValues:maxs];
    free(mins);
    free(maxs);
    return range;
}

@end
