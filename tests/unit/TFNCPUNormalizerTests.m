#import <XCTest/XCTest.h>
#import "TFNCPUNormalizer.h"

@interface TFNCPUNormalizerTests : XCTestCase
@end

@implementation TFNCPUNormalizerTests

- (void)testNormalizeUint8 {
    // Source range: [0, 100], Base range: [50, 200]
    // scale = (200-50)/(100-0) = 1.5, offset = 50 - 0*1.5 = 50
    uint8_t data[] = {0, 50, 100};
    float srcMin[] = {0.0f}, srcMax[] = {100.0f};
    float baseMin[] = {50.0f}, baseMax[] = {200.0f};

    TFNExposureRange *srcRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                       minValues:srcMin
                                                                       maxValues:srcMax];
    TFNExposureRange *baseRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                        minValues:baseMin
                                                                        maxValues:baseMax];
    TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                                    sourceRange:srcRange];

    [TFNCPUNormalizer normalizePixelData:data pixelCount:3
                            channelCount:1 bitDepth:8 isFloat:NO params:params];

    // 0 * 1.5 + 50 = 50
    XCTAssertEqual(data[0], 50);
    // 50 * 1.5 + 50 = 125
    XCTAssertEqual(data[1], 125);
    // 100 * 1.5 + 50 = 200
    XCTAssertEqual(data[2], 200);
}

- (void)testNormalizeUint16 {
    uint16_t data[] = {0, 32768, 65535};
    float srcMin[] = {0.0f}, srcMax[] = {65535.0f};
    float baseMin[] = {1000.0f}, baseMax[] = {60000.0f};

    TFNExposureRange *srcRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                       minValues:srcMin
                                                                       maxValues:srcMax];
    TFNExposureRange *baseRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                        minValues:baseMin
                                                                        maxValues:baseMax];
    TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                                    sourceRange:srcRange];

    [TFNCPUNormalizer normalizePixelData:data pixelCount:3
                            channelCount:1 bitDepth:16 isFloat:NO params:params];

    XCTAssertEqual(data[0], 1000);
    XCTAssertEqual(data[2], 60000);
    // Middle should be approximately halfway
    XCTAssertEqualWithAccuracy((float)data[1], 30500.0f, 2.0f);
}

- (void)testNormalizeFloat32 {
    float data[] = {0.0f, 0.5f, 1.0f};
    float srcMin[] = {0.0f}, srcMax[] = {1.0f};
    float baseMin[] = {0.1f}, baseMax[] = {0.9f};

    TFNExposureRange *srcRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                       minValues:srcMin
                                                                       maxValues:srcMax];
    TFNExposureRange *baseRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                        minValues:baseMin
                                                                        maxValues:baseMax];
    TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                                    sourceRange:srcRange];

    [TFNCPUNormalizer normalizePixelData:data pixelCount:3
                            channelCount:1 bitDepth:32 isFloat:YES params:params];

    XCTAssertEqualWithAccuracy(data[0], 0.1f, 1e-6f);
    XCTAssertEqualWithAccuracy(data[1], 0.5f, 1e-6f);
    XCTAssertEqualWithAccuracy(data[2], 0.9f, 1e-6f);
}

- (void)testFlatExposureHandling {
    // Source has flat exposure (all 128). scale=0, offset=base_min=50
    uint8_t data[] = {128, 128, 128};
    float srcMin[] = {128.0f}, srcMax[] = {128.0f};
    float baseMin[] = {50.0f}, baseMax[] = {200.0f};

    TFNExposureRange *srcRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                       minValues:srcMin
                                                                       maxValues:srcMax];
    TFNExposureRange *baseRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                        minValues:baseMin
                                                                        maxValues:baseMax];
    TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                                    sourceRange:srcRange];

    XCTAssertEqual(params.scale[0], 0.0f);
    XCTAssertEqual(params.offset[0], 50.0f);

    [TFNCPUNormalizer normalizePixelData:data pixelCount:3
                            channelCount:1 bitDepth:8 isFloat:NO params:params];

    // All should map to base_min (50)
    XCTAssertEqual(data[0], 50);
    XCTAssertEqual(data[1], 50);
    XCTAssertEqual(data[2], 50);
}

- (void)testClampingUint8 {
    // Scale that would push values beyond 255
    uint8_t data[] = {200};
    float srcMin[] = {0.0f}, srcMax[] = {100.0f};
    float baseMin[] = {0.0f}, baseMax[] = {255.0f};

    TFNExposureRange *srcRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                       minValues:srcMin
                                                                       maxValues:srcMax];
    TFNExposureRange *baseRange = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                        minValues:baseMin
                                                                        maxValues:baseMax];
    TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                                    sourceRange:srcRange];

    [TFNCPUNormalizer normalizePixelData:data pixelCount:1
                            channelCount:1 bitDepth:8 isFloat:NO params:params];

    // 200 * 2.55 + 0 = 510 → clamped to 255
    XCTAssertEqual(data[0], 255);
}

- (void)testMultiChannelNormalization {
    // 2 pixels, 3 channels (RGB)
    uint8_t data[] = {0, 50, 100,  100, 150, 200};
    float srcMin[] = {0.0f, 50.0f, 100.0f};
    float srcMax[] = {100.0f, 150.0f, 200.0f};
    float baseMin[] = {10.0f, 20.0f, 30.0f};
    float baseMax[] = {110.0f, 120.0f, 130.0f};

    TFNExposureRange *srcRange = [[TFNExposureRange alloc] initWithChannelCount:3
                                                                       minValues:srcMin
                                                                       maxValues:srcMax];
    TFNExposureRange *baseRange = [[TFNExposureRange alloc] initWithChannelCount:3
                                                                        minValues:baseMin
                                                                        maxValues:baseMax];
    TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                                    sourceRange:srcRange];

    [TFNCPUNormalizer normalizePixelData:data pixelCount:2
                            channelCount:3 bitDepth:8 isFloat:NO params:params];

    // scale[0] = 1.0, offset[0] = 10: 0*1+10=10, 100*1+10=110
    XCTAssertEqual(data[0], 10);
    XCTAssertEqual(data[3], 110);
    // scale[1] = 1.0, offset[1] = -30: 50*1-30=20, 150*1-30=120
    XCTAssertEqual(data[1], 20);
    XCTAssertEqual(data[4], 120);
    // scale[2] = 1.0, offset[2] = -70: 100*1-70=30, 200*1-70=130
    XCTAssertEqual(data[2], 30);
    XCTAssertEqual(data[5], 130);
}

@end
