#import "TFNMetalNormalizer.h"

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

@implementation TFNMetalNormalizer {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _library;
    id<MTLComputePipelineState> _pipelineUint8;
    id<MTLComputePipelineState> _pipelineUint16;
    id<MTLComputePipelineState> _pipelineUint32;
    id<MTLComputePipelineState> _pipelineFloat32;
}

- (nullable instancetype)init {
    self = [super init];
    if (self) {
        _device = MTLCreateSystemDefaultDevice();
        if (!_device) return nil;

        _commandQueue = [_device newCommandQueue];
        if (!_commandQueue) return nil;

        NSError *libError = nil;
        _library = [_device newDefaultLibrary];
        if (!_library) {
            // Try loading from metallib next to executable
            NSString *exePath = [[NSBundle mainBundle] executablePath];
            NSString *libPath = [[exePath stringByDeletingLastPathComponent]
                                  stringByAppendingPathComponent:@"default.metallib"];
            NSURL *libURL = [NSURL fileURLWithPath:libPath];
            _library = [_device newLibraryWithURL:libURL error:&libError];
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

    // Dispatch compute
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];

    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:pixelBuffer offset:0 atIndex:0];
    [encoder setBytes:&metalParams length:sizeof(metalParams) atIndex:1];

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

    return YES;
}

@end
