#import <XCTest/XCTest.h>
#import "TFNTIFFReader.h"
#import "TFNCPUNormalizer.h"
#import "TFNMetalNormalizer.h"

@interface TFNMetalNormalizerTests : XCTestCase
@property (nonatomic, strong) TFNMetalNormalizer *metalNorm;
@end

@implementation TFNMetalNormalizerTests

- (void)setUp {
    self.metalNorm = [[TFNMetalNormalizer alloc] init];
    // Metal may not be available in CI
    if (!self.metalNorm) {
        NSLog(@"Metal not available — skipping Metal tests");
    }
}

- (void)testMetalMatchesCPUForUint8 {
    if (!self.metalNorm) return;

    NSUInteger pixelCount = 256;
    NSUInteger bufLen = pixelCount * sizeof(uint8_t);

    // Create two identical buffers
    uint8_t *cpuData = malloc(bufLen);
    uint8_t *gpuData = malloc(bufLen);
    for (NSUInteger i = 0; i < pixelCount; i++) {
        cpuData[i] = (uint8_t)i;
        gpuData[i] = (uint8_t)i;
    }

    float srcMin[] = {0.0f}, srcMax[] = {255.0f};
    float baseMin[] = {50.0f}, baseMax[] = {200.0f};
    TFNExposureRange *srcRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                       minValues:srcMin maxValues:srcMax];
    TFNExposureRange *baseRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                        minValues:baseMin maxValues:baseMax];
    TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                                    sourceRange:srcRange];

    // CPU normalize
    [TFNCPUNormalizer normalizePixelData:cpuData pixelCount:pixelCount
                            channelCount:1 bitDepth:8 isFloat:NO params:params];

    // GPU normalize
    TFNTIFFImage *image = [[TFNTIFFImage alloc] init];
    image.width = pixelCount;
    image.height = 1;
    image.channelCount = 1;
    image.bitDepth = 8;
    image.isFloat = NO;
    image.pixelData = gpuData;
    image.pixelDataLength = bufLen;

    NSError *error = nil;
    BOOL ok = [self.metalNorm normalizeImage:image withParams:params error:&error];
    XCTAssertTrue(ok, @"Metal normalize failed: %@", error);

    // Compare — uint8 should match exactly
    for (NSUInteger i = 0; i < pixelCount; i++) {
        XCTAssertEqual(((uint8_t *)image.pixelData)[i], cpuData[i],
                        @"Mismatch at pixel %lu: GPU=%u CPU=%u",
                        (unsigned long)i,
                        ((uint8_t *)image.pixelData)[i], cpuData[i]);
    }

    free(cpuData);
    // Don't free gpuData — owned by image
    image.pixelData = NULL; // prevent double free
    free(gpuData);
}

- (void)testMetalMatchesCPUForFloat32 {
    if (!self.metalNorm) return;

    NSUInteger pixelCount = 1024;
    NSUInteger bufLen = pixelCount * sizeof(float);

    float *cpuData = malloc(bufLen);
    float *gpuData = malloc(bufLen);
    for (NSUInteger i = 0; i < pixelCount; i++) {
        float v = (float)i / (float)(pixelCount - 1);
        cpuData[i] = v;
        gpuData[i] = v;
    }

    float srcMin[] = {0.0f}, srcMax[] = {1.0f};
    float baseMin[] = {0.1f}, baseMax[] = {0.9f};
    TFNExposureRange *srcRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                       minValues:srcMin maxValues:srcMax];
    TFNExposureRange *baseRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                        minValues:baseMin maxValues:baseMax];
    TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                                    sourceRange:srcRange];

    [TFNCPUNormalizer normalizePixelData:cpuData pixelCount:pixelCount
                            channelCount:1 bitDepth:32 isFloat:YES params:params];

    TFNTIFFImage *image = [[TFNTIFFImage alloc] init];
    image.width = pixelCount;
    image.height = 1;
    image.channelCount = 1;
    image.bitDepth = 32;
    image.isFloat = YES;
    image.pixelData = gpuData;
    image.pixelDataLength = bufLen;

    NSError *error = nil;
    BOOL ok = [self.metalNorm normalizeImage:image withParams:params error:&error];
    XCTAssertTrue(ok, @"Metal normalize failed: %@", error);

    // Compare — float32 within tolerance
    for (NSUInteger i = 0; i < pixelCount; i++) {
        float gpu = ((float *)image.pixelData)[i];
        float cpu = cpuData[i];
        XCTAssertEqualWithAccuracy(gpu, cpu, 1e-5f,
                                    @"Mismatch at pixel %lu: GPU=%f CPU=%f",
                                    (unsigned long)i, gpu, cpu);
    }

    free(cpuData);
    image.pixelData = NULL;
    free(gpuData);
}

@end
