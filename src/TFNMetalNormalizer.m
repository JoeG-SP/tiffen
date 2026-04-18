#import "TFNMetalNormalizer.h"
#import "TFNHistogramData.h"
#include <mach-o/dyld.h>
#include <limits.h>

NSString *const TFNMetalNormalizerErrorDomain = @"TFNMetalNormalizerErrorDomain";

/// Must match the struct in normalize.metal
typedef struct {
    float scale[4];
    float offset[4];
    uint32_t channelCount;
    uint32_t bitDepth;
    uint32_t isFloat;
    uint32_t pixelCount;
} MetalNormalizeParams;

/// Must match MinMaxResult in normalize.metal
typedef struct {
    float mins[4];
    float maxs[4];
} MetalMinMaxResult;

@implementation TFNMetalNormalizer {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _library;
    id<MTLComputePipelineState> _pipelineUint8;
    id<MTLComputePipelineState> _pipelineUint16;
    id<MTLComputePipelineState> _pipelineUint32;
    id<MTLComputePipelineState> _pipelineFloat32;
    id<MTLComputePipelineState> _minmaxUint8;
    id<MTLComputePipelineState> _minmaxUint16;
    id<MTLComputePipelineState> _minmaxUint32;
    id<MTLComputePipelineState> _minmaxFloat32;
}

@synthesize beforeHistogram = _beforeHistogram;
@synthesize afterHistogram = _afterHistogram;

- (nullable instancetype)init {
    self = [super init];
    if (self) {
        _device = MTLCreateSystemDefaultDevice();
        if (!_device) return nil;

        _commandQueue = [_device newCommandQueue];
        if (!_commandQueue) return nil;

        NSError *libError = nil;

        // Load metallib from the TiffenCore framework bundle.
        // This works for both CLI (framework embedded beside executable)
        // and GUI (framework embedded in app bundle).
        NSBundle *frameworkBundle = [NSBundle bundleForClass:[self class]];
        NSString *bundlePath = [frameworkBundle pathForResource:@"default"
                                                        ofType:@"metallib"];
        if (bundlePath) {
            NSURL *libURL = [NSURL fileURLWithPath:bundlePath];
            _library = [_device newLibraryWithURL:libURL error:&libError];
        }
        if (!_library) {
            // Fallback: default library (works in test bundles)
            _library = [_device newDefaultLibrary];
        }
        if (!_library) {
            // Last resort: find metallib next to executable
            char pathBuf[PATH_MAX];
            uint32_t pathSize = sizeof(pathBuf);
            if (_NSGetExecutablePath(pathBuf, &pathSize) == 0) {
                char realBuf[PATH_MAX];
                if (realpath(pathBuf, realBuf)) {
                    NSString *exePath = [NSString stringWithUTF8String:realBuf];
                    NSString *libPath = [[exePath stringByDeletingLastPathComponent]
                                          stringByAppendingPathComponent:@"default.metallib"];
                    NSURL *libURL = [NSURL fileURLWithPath:libPath];
                    _library = [_device newLibraryWithURL:libURL error:&libError];
                }
            }
        }
        if (!_library) return nil;

        // Create pipelines for each bit depth
        _pipelineUint8 = [self pipelineForFunction:@"normalize_uint8"];
        _pipelineUint16 = [self pipelineForFunction:@"normalize_uint16"];
        _pipelineUint32 = [self pipelineForFunction:@"normalize_uint32"];
        _pipelineFloat32 = [self pipelineForFunction:@"normalize_float32"];

        if (!_pipelineUint8 || !_pipelineUint16 ||
            !_pipelineUint32 || !_pipelineFloat32) {
            return nil;
        }

        // Create min/max reduction pipelines
        _minmaxUint8 = [self pipelineForFunction:@"minmax_uint8"];
        _minmaxUint16 = [self pipelineForFunction:@"minmax_uint16"];
        _minmaxUint32 = [self pipelineForFunction:@"minmax_uint32"];
        _minmaxFloat32 = [self pipelineForFunction:@"minmax_float32"];

        if (!_minmaxUint8 || !_minmaxUint16 ||
            !_minmaxUint32 || !_minmaxFloat32) {
            return nil;
        }
    }
    return self;
}

- (nullable id<MTLComputePipelineState>)pipelineForFunction:(NSString *)name {
    id<MTLFunction> function = [_library newFunctionWithName:name];
    if (!function) return nil;
    NSError *error = nil;
    id<MTLComputePipelineState> pipeline =
        [_device newComputePipelineStateWithFunction:function error:&error];
    return pipeline;
}

- (nullable TFNExposureRange *)computeExposureRangeForImage:(TFNTIFFImage *)image
                                                      error:(NSError **)error {
    NSUInteger pixelCount = image.width * image.height;

    // Select minmax pipeline
    id<MTLComputePipelineState> pipeline;
    if (image.isFloat && image.bitDepth == 32) {
        pipeline = _minmaxFloat32;
    } else if (image.bitDepth == 8) {
        pipeline = _minmaxUint8;
    } else if (image.bitDepth == 16) {
        pipeline = _minmaxUint16;
    } else if (image.bitDepth == 32) {
        pipeline = _minmaxUint32;
    } else {
        if (error) {
            *error = [NSError errorWithDomain:TFNMetalNormalizerErrorDomain
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         @"Unsupported bit depth for minmax"}];
        }
        return nil;
    }

    // Wrap pixel data
    id<MTLBuffer> pixelBuffer =
        [_device newBufferWithBytesNoCopy:image.pixelData
                                  length:image.pixelDataLength
                                 options:MTLResourceStorageModeShared
                             deallocator:nil];
    if (!pixelBuffer) {
        pixelBuffer = [_device newBufferWithBytes:image.pixelData
                                           length:image.pixelDataLength
                                          options:MTLResourceStorageModeShared];
    }
    if (!pixelBuffer) {
        if (error) {
            *error = [NSError errorWithDomain:TFNMetalNormalizerErrorDomain
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         @"Failed to create Metal buffer for minmax"}];
        }
        return nil;
    }

    // Threadgroup size for reduction — must be power of 2 for tree reduction
    NSUInteger tgSize = 256;
    NSUInteger numGroups = (pixelCount + tgSize - 1) / tgSize;

    // Allocate results buffer — one MinMaxResult per threadgroup
    id<MTLBuffer> resultsBuffer =
        [_device newBufferWithLength:numGroups * sizeof(MetalMinMaxResult)
                             options:MTLResourceStorageModeShared];
    if (!resultsBuffer) {
        if (error) {
            *error = [NSError errorWithDomain:TFNMetalNormalizerErrorDomain
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         @"Failed to create results buffer"}];
        }
        return nil;
    }

    // Prepare params
    MetalNormalizeParams metalParams = {0};
    metalParams.channelCount = (uint32_t)image.channelCount;
    metalParams.bitDepth = (uint32_t)image.bitDepth;
    metalParams.isFloat = image.isFloat ? 1 : 0;
    metalParams.pixelCount = (uint32_t)pixelCount;

    // Allocate histogram buffer for "before" histogram (fused into minmax pass).
    // For float32, histogram is deferred until after range is known.
    NSUInteger channels = MIN(image.channelCount, 4u);
    NSUInteger histBufSize = channels * TFN_HISTOGRAM_BIN_COUNT * sizeof(uint32_t);
    id<MTLBuffer> histBuffer =
        [_device newBufferWithLength:histBufSize
                             options:MTLResourceStorageModeShared];
    memset(histBuffer.contents, 0, histBufSize);

    // Dispatch
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];

    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:pixelBuffer offset:0 atIndex:0];
    [encoder setBuffer:resultsBuffer offset:0 atIndex:1];
    [encoder setBytes:&metalParams length:sizeof(metalParams) atIndex:2];
    [encoder setBuffer:histBuffer offset:0 atIndex:3];

    MTLSize threadsPerGroup = MTLSizeMake(tgSize, 1, 1);
    MTLSize gridSize = MTLSizeMake(numGroups * tgSize, 1, 1);

    [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadsPerGroup];
    [encoder endEncoding];

    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    if (commandBuffer.error) {
        if (error) *error = commandBuffer.error;
        return nil;
    }

    // Final reduction on CPU over threadgroup results
    MetalMinMaxResult *gpuResults = (MetalMinMaxResult *)resultsBuffer.contents;
    float mins[4], maxs[4];
    for (NSUInteger c = 0; c < channels; c++) {
        mins[c] = FLT_MAX;
        maxs[c] = -FLT_MAX;
    }

    for (NSUInteger g = 0; g < numGroups; g++) {
        for (NSUInteger c = 0; c < channels; c++) {
            if (gpuResults[g].mins[c] < mins[c]) mins[c] = gpuResults[g].mins[c];
            if (gpuResults[g].maxs[c] > maxs[c]) maxs[c] = gpuResults[g].maxs[c];
        }
    }

    // Build before histogram from GPU atomic counts.
    // For integer types, the histogram was fused into the minmax pass.
    // For float32, compute on CPU since we needed the range first.
    if (image.isFloat && image.bitDepth == 32) {
        // CPU histogram for float32 using now-known range
        uint32_t *cpuCounts = calloc(channels * TFN_HISTOGRAM_BIN_COUNT, sizeof(uint32_t));
        const float *pixels = (const float *)image.pixelData;
        for (NSUInteger i = 0; i < pixelCount; i++) {
            for (NSUInteger c = 0; c < channels; c++) {
                float val = pixels[i * channels + c];
                float range = maxs[c] - mins[c];
                uint32_t bin = 0;
                if (range > 0) {
                    float t = (val - mins[c]) / range;
                    bin = (uint32_t)fminf(fmaxf(t * 255.0f, 0.0f), 255.0f);
                }
                cpuCounts[c * TFN_HISTOGRAM_BIN_COUNT + bin]++;
            }
        }
        _beforeHistogram = [TFNHistogramData histogramFromRawCounts:cpuCounts
                                                       channelCount:channels
                                                        totalPixels:pixelCount];
        free(cpuCounts);
    } else {
        _beforeHistogram = [TFNHistogramData histogramFromRawCounts:histBuffer.contents
                                                       channelCount:channels
                                                        totalPixels:pixelCount];
    }

    return [[TFNExposureRange alloc] initWithChannelCount:channels
                                                minValues:mins
                                                maxValues:maxs];
}

- (BOOL)normalizeImage:(TFNTIFFImage *)image
            withParams:(TFNNormalizationParams *)params
                 error:(NSError **)error {
    NSUInteger pixelCount = image.width * image.height;

    // Select pipeline based on bit depth
    id<MTLComputePipelineState> pipeline;
    if (image.isFloat && image.bitDepth == 32) {
        pipeline = _pipelineFloat32;
    } else if (image.bitDepth == 8) {
        pipeline = _pipelineUint8;
    } else if (image.bitDepth == 16) {
        pipeline = _pipelineUint16;
    } else if (image.bitDepth == 32) {
        pipeline = _pipelineUint32;
    } else {
        if (error) {
            *error = [NSError errorWithDomain:TFNMetalNormalizerErrorDomain
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         @"Unsupported bit depth"}];
        }
        return NO;
    }

    // Wrap pixel data in shared MTLBuffer (no copy on Apple Silicon unified memory)
    id<MTLBuffer> pixelBuffer =
        [_device newBufferWithBytesNoCopy:image.pixelData
                                  length:image.pixelDataLength
                                 options:MTLResourceStorageModeShared
                             deallocator:nil];
    if (!pixelBuffer) {
        // Fallback: buffer with copy (length may not be page-aligned)
        pixelBuffer = [_device newBufferWithBytes:image.pixelData
                                           length:image.pixelDataLength
                                          options:MTLResourceStorageModeShared];
        if (!pixelBuffer) {
            if (error) {
                *error = [NSError errorWithDomain:TFNMetalNormalizerErrorDomain
                                             code:2
                                         userInfo:@{NSLocalizedDescriptionKey:
                                             @"Failed to create Metal buffer"}];
            }
            return NO;
        }
    }

    // Prepare params
    MetalNormalizeParams metalParams = {0};
    NSUInteger channels = MIN(params.channelCount, 4u);
    for (NSUInteger c = 0; c < channels; c++) {
        metalParams.scale[c] = params.scale[c];
        metalParams.offset[c] = params.offset[c];
    }
    metalParams.channelCount = (uint32_t)image.channelCount;
    metalParams.bitDepth = (uint32_t)image.bitDepth;
    metalParams.isFloat = image.isFloat ? 1 : 0;
    metalParams.pixelCount = (uint32_t)pixelCount;

    // Allocate after-histogram buffer
    NSUInteger histBufSize = channels * TFN_HISTOGRAM_BIN_COUNT * sizeof(uint32_t);
    id<MTLBuffer> afterHistBuffer =
        [_device newBufferWithLength:histBufSize
                             options:MTLResourceStorageModeShared];
    memset(afterHistBuffer.contents, 0, histBufSize);

    // Dispatch compute
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];

    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:pixelBuffer offset:0 atIndex:0];
    [encoder setBytes:&metalParams length:sizeof(metalParams) atIndex:1];
    [encoder setBuffer:afterHistBuffer offset:0 atIndex:2];

    NSUInteger threadGroupSize = pipeline.maxTotalThreadsPerThreadgroup;
    if (threadGroupSize > pixelCount) {
        threadGroupSize = pixelCount;
    }
    MTLSize threadsPerGroup = MTLSizeMake(threadGroupSize, 1, 1);
    MTLSize gridSize = MTLSizeMake(pixelCount, 1, 1);

    [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadsPerGroup];
    [encoder endEncoding];

    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    if (commandBuffer.error) {
        if (error) {
            *error = commandBuffer.error;
        }
        return NO;
    }

    // If we used a copy buffer, copy data back
    if (pixelBuffer.contents != image.pixelData) {
        memcpy(image.pixelData, pixelBuffer.contents, image.pixelDataLength);
    }

    // Build after histogram.
    // For float32, the normalize kernel doesn't compute histogram (needs range info).
    // Compute on CPU from the output buffer.
    if (image.isFloat && image.bitDepth == 32) {
        uint32_t *cpuCounts = calloc(channels * TFN_HISTOGRAM_BIN_COUNT, sizeof(uint32_t));
        const float *pixels = (const float *)image.pixelData;
        // After normalization, pixels are in base range. Use params to reconstruct range.
        // base_min = offset[c] (when src_min=0 for the base itself, but generally
        // we need the actual base range). For simplicity, scan for actual min/max.
        float outMins[4], outMaxs[4];
        for (NSUInteger c = 0; c < channels; c++) {
            outMins[c] = FLT_MAX;
            outMaxs[c] = -FLT_MAX;
        }
        for (NSUInteger i = 0; i < pixelCount; i++) {
            for (NSUInteger c = 0; c < channels; c++) {
                float v = pixels[i * channels + c];
                if (v < outMins[c]) outMins[c] = v;
                if (v > outMaxs[c]) outMaxs[c] = v;
            }
        }
        for (NSUInteger i = 0; i < pixelCount; i++) {
            for (NSUInteger c = 0; c < channels; c++) {
                float val = pixels[i * channels + c];
                float range = outMaxs[c] - outMins[c];
                uint32_t bin = 0;
                if (range > 0) {
                    float t = (val - outMins[c]) / range;
                    bin = (uint32_t)fminf(fmaxf(t * 255.0f, 0.0f), 255.0f);
                }
                cpuCounts[c * TFN_HISTOGRAM_BIN_COUNT + bin]++;
            }
        }
        _afterHistogram = [TFNHistogramData histogramFromRawCounts:cpuCounts
                                                      channelCount:channels
                                                       totalPixels:pixelCount];
        free(cpuCounts);
    } else {
        _afterHistogram = [TFNHistogramData histogramFromRawCounts:afterHistBuffer.contents
                                                      channelCount:channels
                                                       totalPixels:pixelCount];
    }

    return YES;
}

@end
