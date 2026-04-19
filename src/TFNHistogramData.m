#import "TFNHistogramData.h"

@implementation TFNHistogramData {
    float *_bins; // channelCount * TFN_HISTOGRAM_BIN_COUNT floats
}

- (void)dealloc {
    free(_bins);
}

- (const float *)binsForChannel:(NSUInteger)channel {
    NSAssert(channel < _channelCount, @"Channel %lu out of range (max %lu)",
             (unsigned long)channel, (unsigned long)_channelCount);
    return _bins + (channel * TFN_HISTOGRAM_BIN_COUNT);
}

+ (instancetype)histogramFromRawCounts:(const uint32_t *)rawCounts
                          channelCount:(NSUInteger)channelCount
                           totalPixels:(NSUInteger)totalPixels {
    NSParameterAssert(rawCounts != NULL);
    NSParameterAssert(channelCount > 0);
    NSParameterAssert(totalPixels > 0);

    TFNHistogramData *hist = [[TFNHistogramData alloc] init];
    hist->_channelCount = channelCount;
    hist->_totalPixels = totalPixels;

    NSUInteger totalBins = channelCount * TFN_HISTOGRAM_BIN_COUNT;
    hist->_bins = calloc(totalBins, sizeof(float));

    float invTotal = 1.0f / (float)totalPixels;
    for (NSUInteger i = 0; i < totalBins; i++) {
        hist->_bins[i] = (float)rawCounts[i] * invTotal;
    }

    return hist;
}

@end
