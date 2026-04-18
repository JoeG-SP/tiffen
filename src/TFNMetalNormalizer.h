#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "TFNCPUNormalizer.h"
#import "TFNTIFFReader.h"

NS_ASSUME_NONNULL_BEGIN

/// GPU-accelerated normalizer using Metal compute shaders.
/// Uses shared memory on Apple Silicon — no CPU↔GPU copy.
@interface TFNMetalNormalizer : NSObject

/// Initialize with the default Metal device.
/// Returns nil if Metal is not available.
- (nullable instancetype)init;

/// Normalize pixel data in-place using Metal compute.
/// The pixel buffer is wrapped in a shared MTLBuffer (no copy on Apple Silicon).
/// Returns NO if Metal dispatch fails.
- (BOOL)normalizeImage:(TFNTIFFImage *)image
            withParams:(TFNNormalizationParams *)params
                 error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
