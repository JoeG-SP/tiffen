#import <XCTest/XCTest.h>
#import "TFNMetalNormalizer.h"
#import "TFNCPUNormalizer.h"
#import "TFNTIFFReader.h"
#import "TFNHistogramData.h"
#import "TFNExposureRange.h"
#import "TFNTestFixtures.h"

@interface TFNHistogramGPUTests : XCTestCase
@property (nonatomic, strong) NSString *fixtureDir;
@end

@implementation TFNHistogramGPUTests

- (void)setUp {
    self.fixtureDir = [TFNTestFixtures createFixturesDirectory];
}

- (void)tearDown {
    [TFNTestFixtures cleanupDirectory:self.fixtureDir];
}

- (void)testGPUBeforeHistogramMatchesCPU_8bit {
    NSString *path = [self.fixtureDir stringByAppendingPathComponent:@"dark_8bit.tiff"];
    TFNTIFFImage *image = [TFNTIFFReader readTIFFAtPath:path error:nil];
    XCTAssertNotNil(image);

    // GPU path
    TFNMetalNormalizer *metal = [[TFNMetalNormalizer alloc] init];
    if (!metal) {
        NSLog(@"Metal not available — skipping GPU histogram test");
        return;
    }

    TFNExposureRange *gpuRange = [metal computeExposureRangeForImage:image error:nil];
    XCTAssertNotNil(gpuRange);
    TFNHistogramData *gpuHist = metal.beforeHistogram;
    XCTAssertNotNil(gpuHist);

    // CPU path: re-read since GPU may have modified buffer
    TFNTIFFImage *cpuImage = [TFNTIFFReader readTIFFAtPath:path error:nil];
    [cpuImage computeExposureRange];
    TFNHistogramData *cpuHist = [TFNCPUNormalizer computeHistogramForPixelData:cpuImage.pixelData
                                                                    pixelCount:cpuImage.width * cpuImage.height
                                                                  channelCount:cpuImage.channelCount
                                                                      bitDepth:cpuImage.bitDepth
                                                                       isFloat:cpuImage.isFloat
                                                                         range:cpuImage.exposureRange];
    XCTAssertNotNil(cpuHist);

    // Compare bins — should match exactly for 8-bit integer
    const float *gpuBins = [gpuHist binsForChannel:0];
    const float *cpuBins = [cpuHist binsForChannel:0];
    for (int i = 0; i < TFN_HISTOGRAM_BIN_COUNT; i++) {
        XCTAssertEqualWithAccuracy(gpuBins[i], cpuBins[i], 1e-5,
            @"Bin %d mismatch: GPU=%.6f CPU=%.6f", i, gpuBins[i], cpuBins[i]);
    }
}

- (void)testGPUAfterHistogramProduced {
    NSString *path = [self.fixtureDir stringByAppendingPathComponent:@"dark_8bit.tiff"];
    TFNTIFFImage *image = [TFNTIFFReader readTIFFAtPath:path error:nil];
    XCTAssertNotNil(image);

    TFNMetalNormalizer *metal = [[TFNMetalNormalizer alloc] init];
    if (!metal) return;

    TFNExposureRange *range = [metal computeExposureRangeForImage:image error:nil];
    XCTAssertNotNil(range);

    // Identity normalization
    TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:range
                                                                     sourceRange:range];
    BOOL ok = [metal normalizeImage:image withParams:params error:nil];
    XCTAssertTrue(ok);

    TFNHistogramData *afterHist = metal.afterHistogram;
    XCTAssertNotNil(afterHist);
    XCTAssertEqual(afterHist.channelCount, 1u);

    // After identity normalization, histograms should be very similar
    TFNHistogramData *beforeHist = metal.beforeHistogram;
    const float *before = [beforeHist binsForChannel:0];
    const float *after = [afterHist binsForChannel:0];
    for (int i = 0; i < TFN_HISTOGRAM_BIN_COUNT; i++) {
        XCTAssertEqualWithAccuracy(before[i], after[i], 0.02,
            @"Bin %d: before=%.4f after=%.4f", i, before[i], after[i]);
    }
}

@end
