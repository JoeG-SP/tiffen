#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Number of bins per channel in a histogram.
#define TFN_HISTOGRAM_BIN_COUNT 256

/// Per-channel histogram data. Each channel has TFN_HISTOGRAM_BIN_COUNT bins
/// with values normalized to 0–1 (fraction of total pixels).
@interface TFNHistogramData : NSObject

/// Number of channels in this histogram.
@property (nonatomic, readonly) NSUInteger channelCount;

/// Total number of pixels used to compute this histogram.
@property (nonatomic, readonly) NSUInteger totalPixels;

/// Returns a pointer to the bin array for the given channel.
/// The array contains TFN_HISTOGRAM_BIN_COUNT floats, each in [0, 1].
- (const float *)binsForChannel:(NSUInteger)channel;

/// Creates a histogram from raw uint32 counts produced by GPU or CPU.
/// @param rawCounts Contiguous array of channelCount * TFN_HISTOGRAM_BIN_COUNT uint32 values.
///                  Layout: channel 0 bins [0..255], channel 1 bins [0..255], ...
/// @param channelCount Number of channels.
/// @param totalPixels Total pixel count for normalization (width * height).
+ (instancetype)histogramFromRawCounts:(const uint32_t *)rawCounts
                          channelCount:(NSUInteger)channelCount
                           totalPixels:(NSUInteger)totalPixels;

@end

NS_ASSUME_NONNULL_END
