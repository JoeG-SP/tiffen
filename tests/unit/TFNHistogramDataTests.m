#import <XCTest/XCTest.h>
#import "TFNHistogramData.h"

@interface TFNHistogramDataTests : XCTestCase
@end

@implementation TFNHistogramDataTests

- (void)testBasicCreationFromRawCounts {
    // 1 channel, 256 bins, 100 pixels total
    uint32_t counts[256] = {0};
    counts[0] = 50;
    counts[255] = 50;

    TFNHistogramData *hist = [TFNHistogramData histogramFromRawCounts:counts
                                                         channelCount:1
                                                          totalPixels:100];

    XCTAssertEqual(hist.channelCount, 1u);
    XCTAssertEqual(hist.totalPixels, 100u);

    const float *bins = [hist binsForChannel:0];
    XCTAssertEqualWithAccuracy(bins[0], 0.5f, 1e-6);
    XCTAssertEqualWithAccuracy(bins[255], 0.5f, 1e-6);
    XCTAssertEqualWithAccuracy(bins[128], 0.0f, 1e-6);
}

- (void)testBinsSumToOne {
    // Uniform distribution: all 256 bins have equal count
    uint32_t counts[256];
    for (int i = 0; i < 256; i++) counts[i] = 100;

    TFNHistogramData *hist = [TFNHistogramData histogramFromRawCounts:counts
                                                         channelCount:1
                                                          totalPixels:25600];

    const float *bins = [hist binsForChannel:0];
    float sum = 0;
    for (int i = 0; i < 256; i++) sum += bins[i];
    XCTAssertEqualWithAccuracy(sum, 1.0f, 1e-4);
}

- (void)testMultiChannel {
    // 3 channels
    uint32_t counts[3 * 256] = {0};
    // Channel 0: all pixels in bin 0
    counts[0] = 10;
    // Channel 1: all pixels in bin 128
    counts[256 + 128] = 10;
    // Channel 2: all pixels in bin 255
    counts[512 + 255] = 10;

    TFNHistogramData *hist = [TFNHistogramData histogramFromRawCounts:counts
                                                         channelCount:3
                                                          totalPixels:10];

    XCTAssertEqual(hist.channelCount, 3u);

    const float *ch0 = [hist binsForChannel:0];
    XCTAssertEqualWithAccuracy(ch0[0], 1.0f, 1e-6);
    XCTAssertEqualWithAccuracy(ch0[1], 0.0f, 1e-6);

    const float *ch1 = [hist binsForChannel:1];
    XCTAssertEqualWithAccuracy(ch1[128], 1.0f, 1e-6);

    const float *ch2 = [hist binsForChannel:2];
    XCTAssertEqualWithAccuracy(ch2[255], 1.0f, 1e-6);
}

- (void)testAllZeroCounts {
    uint32_t counts[256] = {0};

    // totalPixels > 0 but all counts are 0 (shouldn't happen in practice but test safety)
    TFNHistogramData *hist = [TFNHistogramData histogramFromRawCounts:counts
                                                         channelCount:1
                                                          totalPixels:100];

    const float *bins = [hist binsForChannel:0];
    for (int i = 0; i < 256; i++) {
        XCTAssertEqualWithAccuracy(bins[i], 0.0f, 1e-6);
    }
}

- (void)testSingleSpike {
    uint32_t counts[256] = {0};
    counts[42] = 1000;

    TFNHistogramData *hist = [TFNHistogramData histogramFromRawCounts:counts
                                                         channelCount:1
                                                          totalPixels:1000];

    const float *bins = [hist binsForChannel:0];
    XCTAssertEqualWithAccuracy(bins[42], 1.0f, 1e-6);
    for (int i = 0; i < 256; i++) {
        if (i != 42) {
            XCTAssertEqualWithAccuracy(bins[i], 0.0f, 1e-6);
        }
    }
}

@end
