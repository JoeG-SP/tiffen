#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "TFNCPUNormalizer.h"
#import "TFNTIFFReader.h"
#import "TFNHistogramData.h"

NS_ASSUME_NONNULL_BEGIN

/// GPU-accelerated normalizer using Metal compute shaders.
/// Uses shared memory on Apple Silicon — no CPU↔GPU copy.
@interface TFNMetalNormalizer : NSObject

/// Initialize with the default Metal device.
/// Returns nil if Metal is not available.
- (nullable instancetype)init;

/// Compute per-channel min/max exposure range on the GPU.
/// Also computes the "before" histogram for integer types (fused into the same pass).
/// For float32, the before histogram is computed on CPU after the range is known.
/// Returns nil on failure.
- (nullable TFNExposureRange *)computeExposureRangeForImage:(TFNTIFFImage *)image
                                                      error:(NSError **)error;

/// Normalize pixel data in-place using Metal compute.
/// Also computes the "after" histogram (fused into the same pass) for integer types.
/// Returns NO if Metal dispatch fails.
- (BOOL)normalizeImage:(TFNTIFFImage *)image
            withParams:(TFNNormalizationParams *)params
                 error:(NSError **)error;

/// The "before" histogram from the most recent computeExposureRangeForImage: call.
/// Nil if no range computation has been performed.
@property (nonatomic, readonly, nullable) TFNHistogramData *beforeHistogram;

/// The "after" histogram from the most recent normalizeImage:withParams: call.
/// Nil if no normalization has been performed.
@property (nonatomic, readonly, nullable) TFNHistogramData *afterHistogram;

@end

NS_ASSUME_NONNULL_END
