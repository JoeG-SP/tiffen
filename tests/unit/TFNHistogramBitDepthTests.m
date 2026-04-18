#import <XCTest/XCTest.h>
#import "TFNCPUNormalizer.h"
#import "TFNHistogramData.h"
#import "TFNExposureRange.h"

@interface TFNHistogramBitDepthTests : XCTestCase
@end

@implementation TFNHistogramBitDepthTests

- (void)test8BitDirectMapping {
    // 3 pixels: values 0, 128, 255
    uint8_t pixels[] = {0, 128, 255};
    TFNHistogramData *hist = [TFNCPUNormalizer computeHistogramForPixelData:pixels
                                                                pixelCount:3
                                                              channelCount:1
                                                                  bitDepth:8
                                                                   isFloat:NO
                                                                     range:nil];
    const float *bins = [hist binsForChannel:0];
    XCTAssertEqualWithAccuracy(bins[0], 1.0f/3.0f, 1e-5);
    XCTAssertEqualWithAccuracy(bins[128], 1.0f/3.0f, 1e-5);
    XCTAssertEqualWithAccuracy(bins[255], 1.0f/3.0f, 1e-5);
}

- (void)test16BitQuantizedTo256 {
    // 16-bit: value 0 → bin 0, 32767 → bin ~127, 65535 → bin 255
    uint16_t pixels[] = {0, 32767, 65535};
    TFNHistogramData *hist = [TFNCPUNormalizer computeHistogramForPixelData:pixels
                                                                pixelCount:3
                                                              channelCount:1
                                                                  bitDepth:16
                                                                   isFloat:NO
                                                                     range:nil];
    const float *bins = [hist binsForChannel:0];
    XCTAssertEqualWithAccuracy(bins[0], 1.0f/3.0f, 1e-5);
    XCTAssertEqualWithAccuracy(bins[255], 1.0f/3.0f, 1e-5);

    // 32767 maps to bin ~127 (32767 * 255 / 65535 ≈ 127.498)
    uint32_t midBin = (uint32_t)(32767.0f * 255.0f / 65535.0f);
    XCTAssertEqualWithAccuracy(bins[midBin], 1.0f/3.0f, 1e-5);
}

- (void)testFloat32RangeMapped {
    // Float: values 0.0, 0.5, 1.0 with range [0, 1]
    float pixels[] = {0.0f, 0.5f, 1.0f};
    float mins[] = {0.0f};
    float maxs[] = {1.0f};
    TFNExposureRange *range = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                   minValues:mins
                                                                   maxValues:maxs];
    TFNHistogramData *hist = [TFNCPUNormalizer computeHistogramForPixelData:pixels
                                                                pixelCount:3
                                                              channelCount:1
                                                                  bitDepth:32
                                                                   isFloat:YES
                                                                     range:range];
    const float *bins = [hist binsForChannel:0];
    // 0.0 → bin 0, 0.5 → bin 127, 1.0 → bin 255
    XCTAssertEqualWithAccuracy(bins[0], 1.0f/3.0f, 1e-5);
    XCTAssertEqualWithAccuracy(bins[255], 1.0f/3.0f, 1e-5);

    uint32_t midBin = (uint32_t)(0.5f * 255.0f);
    XCTAssertEqualWithAccuracy(bins[midBin], 1.0f/3.0f, 1e-5);
}

- (void)testFloat32FlatRange {
    // All same value — range is 0, all should go to bin 0
    float pixels[] = {5.0f, 5.0f, 5.0f};
    float mins[] = {5.0f};
    float maxs[] = {5.0f};
    TFNExposureRange *range = [[TFNExposureRange alloc] initWithChannelCount:1
                                                                   minValues:mins
                                                                   maxValues:maxs];
    TFNHistogramData *hist = [TFNCPUNormalizer computeHistogramForPixelData:pixels
                                                                pixelCount:3
                                                              channelCount:1
                                                                  bitDepth:32
                                                                   isFloat:YES
                                                                     range:range];
    const float *bins = [hist binsForChannel:0];
    XCTAssertEqualWithAccuracy(bins[0], 1.0f, 1e-5);
}

@end
