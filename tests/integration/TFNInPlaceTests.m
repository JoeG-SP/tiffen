#import <XCTest/XCTest.h>
#import "TFNNormalizer.h"
#import "TFNTIFFReader.h"
#import "TFNTIFFWriter.h"
#import "TFNTestFixtures.h"

@interface TFNInPlaceTests : XCTestCase
@property (nonatomic, copy) NSString *fixturesDir;
@end

@implementation TFNInPlaceTests

- (void)setUp {
    self.fixturesDir = [TFNTestFixtures createFixturesDirectory];
}

- (void)tearDown {
    [TFNTestFixtures cleanupDirectory:self.fixturesDir];
}

- (void)testInPlaceOverwritesOriginals {
    NSString *basePath = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    NSString *darkPath = [self.fixturesDir stringByAppendingPathComponent:@"dark_8bit.tiff"];

    // Read original dark file to get its exposure range before normalization
    TFNTIFFImage *origDark = [TFNTIFFReader readTIFFAtPath:darkPath error:nil];
    float origMin = origDark.exposureRange.minValues[0];
    float origMax = origDark.exposureRange.maxValues[0];

    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.outputMode = TFNOutputModeInPlace;
    norm.verbosity = TFNVerbosityQuiet;

    NSError *error = nil;
    TFNNormalizationResult *result = [norm normalizeDirectory:self.fixturesDir
                                                 withBaseTIFF:basePath
                                                        error:&error];
    XCTAssertNotNil(result, @"Failed: %@", error);

    // Re-read dark file — should now have base's exposure range
    TFNTIFFImage *newDark = [TFNTIFFReader readTIFFAtPath:darkPath error:nil];
    XCTAssertNotNil(newDark);

    TFNTIFFImage *baseImage = [TFNTIFFReader readTIFFAtPath:basePath error:nil];

    // Should match base range, not original range
    XCTAssertEqualWithAccuracy(newDark.exposureRange.minValues[0],
                                baseImage.exposureRange.minValues[0], 1.0f);
    XCTAssertEqualWithAccuracy(newDark.exposureRange.maxValues[0],
                                baseImage.exposureRange.maxValues[0], 1.0f);

    // Should differ from original range
    BOOL rangeChanged = (fabsf(newDark.exposureRange.minValues[0] - origMin) > 1.0f) ||
                        (fabsf(newDark.exposureRange.maxValues[0] - origMax) > 1.0f);
    XCTAssertTrue(rangeChanged, @"In-place file should have different exposure range");
}

@end
