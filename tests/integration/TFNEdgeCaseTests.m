#import <XCTest/XCTest.h>
#import "TFNNormalizer.h"
#import "TFNTIFFReader.h"
#import "TFNTestFixtures.h"

@interface TFNEdgeCaseTests : XCTestCase
@property (nonatomic, copy) NSString *fixturesDir;
@end

@implementation TFNEdgeCaseTests

- (void)setUp {
    self.fixturesDir = [TFNTestFixtures createFixturesDirectory];
}

- (void)tearDown {
    [TFNTestFixtures cleanupDirectory:self.fixturesDir];
}

- (void)testNonTIFFFilesSilentlySkipped {
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
    // not_a_tiff.png should be counted as skipped, not errored
    XCTAssertGreaterThan(result.filesSkipped, 0u);

    // not_a_tiff.png should NOT appear in output
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:
        [outputDir stringByAppendingPathComponent:@"not_a_tiff.png"]]);
}

- (void)testMissingBaseTIFFReturnsFatalError {
    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.verbosity = TFNVerbosityQuiet;

    NSError *error = nil;
    TFNNormalizationResult *result = [norm normalizeDirectory:self.fixturesDir
                                                 withBaseTIFF:@"/nonexistent/base.tiff"
                                                        error:&error];
    XCTAssertNil(result);
    XCTAssertNotNil(error);
}

- (void)testEmptyDirectoryReturnsSuccess {
    NSString *emptyDir = [self.fixturesDir stringByAppendingPathComponent:@"empty"];
    [[NSFileManager defaultManager] createDirectoryAtPath:emptyDir
                              withIntermediateDirectories:YES attributes:nil error:nil];

    // Create a base TIFF outside the empty dir
    NSString *basePath = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];

    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.outputMode = TFNOutputModeDirectory;
    norm.verbosity = TFNVerbosityQuiet;

    NSError *error = nil;
    TFNNormalizationResult *result = [norm normalizeDirectory:emptyDir
                                                 withBaseTIFF:basePath
                                                        error:&error];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.filesNormalized, 0u);
    XCTAssertEqual(result.filesErrored, 0u);
}

- (void)testCorruptTIFFSkippedWithError {
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
    // corrupt.tiff should be in errors
    XCTAssertGreaterThan(result.filesErrored, 0u);
    XCTAssertGreaterThan(result.errors.count, 0u);
}

- (void)testFlatExposureGeneratesWarning {
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
    // uniform_8bit.tiff should produce a flat exposure warning
    BOOL foundFlatWarning = NO;
    for (NSString *warning in result.warnings) {
        if ([warning containsString:@"flat exposure"]) {
            foundFlatWarning = YES;
            break;
        }
    }
    XCTAssertTrue(foundFlatWarning, @"Expected flat exposure warning for uniform_8bit.tiff");
}

- (void)testInvalidDirectoryReturnsFatalError {
    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.verbosity = TFNVerbosityQuiet;

    NSError *error = nil;
    TFNNormalizationResult *result = [norm normalizeDirectory:@"/nonexistent/dir"
                                                 withBaseTIFF:[self.fixturesDir
                                                     stringByAppendingPathComponent:@"base_8bit.tiff"]
                                                        error:&error];
    XCTAssertNil(result);
    XCTAssertNotNil(error);
}

@end
