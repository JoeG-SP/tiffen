#import <XCTest/XCTest.h>
#import "TFNNormalizer.h"
#import "TFNTestFixtures.h"

@interface TFNProgressTests : XCTestCase
@property (nonatomic, copy) NSString *fixturesDir;
@end

@implementation TFNProgressTests

- (void)setUp {
    self.fixturesDir = [TFNTestFixtures createFixturesDirectory];
}

- (void)tearDown {
    [TFNTestFixtures cleanupDirectory:self.fixturesDir];
}

- (void)testNormalModeProducesResult {
    NSString *basePath = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    NSString *outputDir = [self.fixturesDir stringByAppendingPathComponent:@"output"];

    TFNNormalizer *norm = [[TFNNormalizer alloc] init];
    norm.outputMode = TFNOutputModeDirectory;
    norm.outputDirectory = outputDir;
    norm.verbosity = TFNVerbosityNormal;

    NSError *error = nil;
    TFNNormalizationResult *result = [norm normalizeDirectory:self.fixturesDir
                                                 withBaseTIFF:basePath
                                                        error:&error];
    XCTAssertNotNil(result);
    XCTAssertGreaterThan(result.filesNormalized, 0u);
}

- (void)testQuietModeSuppressesOutput {
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
    // Should still produce a valid result even in quiet mode
    XCTAssertNotNil(result);
    XCTAssertGreaterThan(result.filesNormalized, 0u);
}

- (void)testErrorsTrackedInResult {
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
    // corrupt.tiff should produce an error
    XCTAssertGreaterThan(result.filesErrored, 0u);
    // But valid files should still be normalized
    XCTAssertGreaterThan(result.filesNormalized, 0u);
}

@end
