#import <XCTest/XCTest.h>
#import "TFNNormalizer.h"
#import "TFNTIFFReader.h"
#import "TFNTestFixtures.h"

@interface TFNEndToEndTests : XCTestCase
@property (nonatomic, copy) NSString *fixturesDir;
@end

@implementation TFNEndToEndTests

- (void)setUp {
    self.fixturesDir = [TFNTestFixtures createFixturesDirectory];
}

- (void)tearDown {
    [TFNTestFixtures cleanupDirectory:self.fixturesDir];
}

- (void)testNormalizeDirectoryToBase {
    NSString *basePath = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    NSString *outputDir = [self.fixturesDir stringByAppendingPathComponent:@"output"];

    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.outputMode = TFNOutputModeDirectory;
    norm.outputDirectory = outputDir;
    norm.verbosity = TFNVerbosityQuiet;

    NSError *error = nil;
    TFNNormalizationResult *result = [norm normalizeDirectory:self.fixturesDir
                                                 withBaseTIFF:basePath
                                                        error:&error];

    XCTAssertNotNil(result, @"Failed: %@", error);
    XCTAssertGreaterThan(result.filesNormalized, 0u);

    // Verify output files exist
    NSFileManager *fm = [NSFileManager defaultManager];
    XCTAssertTrue([fm fileExistsAtPath:[outputDir stringByAppendingPathComponent:@"dark_8bit.tiff"]]);

    // Verify the normalized file's exposure range matches the base
    NSError *readError = nil;
    TFNTIFFImage *baseImage = [TFNTIFFReader readTIFFAtPath:basePath error:&readError];
    TFNTIFFImage *normalizedDark = [TFNTIFFReader readTIFFAtPath:
        [outputDir stringByAppendingPathComponent:@"dark_8bit.tiff"] error:&readError];

    XCTAssertNotNil(baseImage);
    XCTAssertNotNil(normalizedDark);

    // Exposure range should match base within +/- 1 for uint8
    XCTAssertEqualWithAccuracy(normalizedDark.exposureRange.minValues[0],
                                baseImage.exposureRange.minValues[0], 1.0f);
    XCTAssertEqualWithAccuracy(normalizedDark.exposureRange.maxValues[0],
                                baseImage.exposureRange.maxValues[0], 1.0f);
}

- (void)testBaseFileCopiedToOutput {
    NSString *basePath = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    NSString *outputDir = [self.fixturesDir stringByAppendingPathComponent:@"output"];

    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.outputMode = TFNOutputModeDirectory;
    norm.outputDirectory = outputDir;
    norm.verbosity = TFNVerbosityQuiet;

    NSError *error = nil;
    TFNNormalizationResult *result = [norm normalizeDirectory:self.fixturesDir
                                                 withBaseTIFF:basePath
                                                        error:&error];
    XCTAssertNotNil(result);

    // base_8bit.tiff should be copied to output as the baseline
    NSFileManager *fm = [NSFileManager defaultManager];
    XCTAssertTrue([fm fileExistsAtPath:[outputDir stringByAppendingPathComponent:@"base_8bit.tiff"]]);
}

- (void)testBaseFileNotNormalized {
    // Base file should be copied as-is, not re-normalized
    NSString *basePath = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    NSString *outputDir = [self.fixturesDir stringByAppendingPathComponent:@"output"];

    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.outputMode = TFNOutputModeDirectory;
    norm.outputDirectory = outputDir;
    norm.verbosity = TFNVerbosityQuiet;

    NSError *error = nil;
    [norm normalizeDirectory:self.fixturesDir withBaseTIFF:basePath error:&error];

    // Copied base should be byte-identical to original
    NSData *original = [NSData dataWithContentsOfFile:basePath];
    NSData *copied = [NSData dataWithContentsOfFile:
        [outputDir stringByAppendingPathComponent:@"base_8bit.tiff"]];
    XCTAssertEqualObjects(original, copied);
}

- (void)testBitDepthPreserved {
    NSString *basePath = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    NSString *outputDir = [self.fixturesDir stringByAppendingPathComponent:@"output"];

    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.outputMode = TFNOutputModeDirectory;
    norm.outputDirectory = outputDir;
    norm.verbosity = TFNVerbosityQuiet;

    NSError *error = nil;
    [norm normalizeDirectory:self.fixturesDir withBaseTIFF:basePath error:&error];

    // 16-bit file should still be 16-bit after normalization
    NSString *bright16Path = [outputDir stringByAppendingPathComponent:@"bright_16bit.tiff"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bright16Path]) {
        TFNTIFFImage *img = [TFNTIFFReader readTIFFAtPath:bright16Path error:nil];
        XCTAssertNotNil(img);
        XCTAssertEqual(img.bitDepth, 16u);
    }
}

- (void)testOutputDirectoryAutoCreated {
    NSString *basePath = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    NSString *outputDir = [self.fixturesDir stringByAppendingPathComponent:@"deeply/nested/output"];

    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.outputMode = TFNOutputModeDirectory;
    norm.outputDirectory = outputDir;
    norm.verbosity = TFNVerbosityQuiet;

    NSError *error = nil;
    TFNNormalizationResult *result = [norm normalizeDirectory:self.fixturesDir
                                                 withBaseTIFF:basePath
                                                        error:&error];
    XCTAssertNotNil(result);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:outputDir]);
}

@end
