#import <Foundation/Foundation.h>
#import "TFNExposureRange.h"

NS_ASSUME_NONNULL_BEGIN

/// Precomputed per-channel normalization parameters.
@interface TFNNormalizationParams : NSObject

@property (nonatomic, readonly) NSUInteger channelCount;
@property (nonatomic, readonly) const float *scale;
@property (nonatomic, readonly) const float *offset;

/// Compute params from base and source exposure ranges.
/// Handles degenerate case (src_max == src_min): scale=0, offset=base_min.
+ (instancetype)paramsWithBaseRange:(TFNExposureRange *)baseRange
                        sourceRange:(TFNExposureRange *)sourceRange;

@end

/// CPU reference normalizer. Applies out = in * scale + offset per channel.
@interface TFNCPUNormalizer : NSObject

/// Normalize pixel buffer in place using precomputed params.
+ (void)normalizePixelData:(void *)pixelData
               pixelCount:(NSUInteger)pixelCount
             channelCount:(NSUInteger)channelCount
                 bitDepth:(NSUInteger)bitDepth
                  isFloat:(BOOL)isFloat
                   params:(TFNNormalizationParams *)params;

@end

NS_ASSUME_NONNULL_END
