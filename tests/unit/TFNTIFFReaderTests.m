#import <XCTest/XCTest.h>
#import "TFNTIFFReader.h"
#import "TFNTestFixtures.h"

@interface TFNTIFFReaderTests : XCTestCase
@property (nonatomic, copy) NSString *fixturesDir;
@end

@implementation TFNTIFFReaderTests

- (void)setUp {
    self.fixturesDir = [TFNTestFixtures createFixturesDirectory];
}

- (void)tearDown {
    [TFNTestFixtures cleanupDirectory:self.fixturesDir];
}

- (void)testRead8BitTIFF {
    NSString *path = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    NSError *error = nil;
    TFNTIFFImage *image = [TFNTIFFReader readTIFFAtPath:path error:&error];

    XCTAssertNotNil(image, @"Failed: %@", error);
    XCTAssertEqual(image.width, 64u);
    XCTAssertEqual(image.height, 64u);
    XCTAssertEqual(image.channelCount, 1u);
    XCTAssertEqual(image.bitDepth, 8u);
    XCTAssertFalse(image.isFloat);
    XCTAssertNotNil(image.exposureRange);
}

- (void)testRead16BitTIFF {
    NSString *path = [self.fixturesDir stringByAppendingPathComponent:@"base_16bit.tiff"];
    NSError *error = nil;
    TFNTIFFImage *image = [TFNTIFFReader readTIFFAtPath:path error:&error];

    XCTAssertNotNil(image, @"Failed: %@", error);
    XCTAssertEqual(image.bitDepth, 16u);
    XCTAssertFalse(image.isFloat);
}

- (void)testRead32BitFloatTIFF {
    NSString *path = [self.fixturesDir stringByAppendingPathComponent:@"base_32float.tiff"];
    NSError *error = nil;
    TFNTIFFImage *image = [TFNTIFFReader readTIFFAtPath:path error:&error];

    XCTAssertNotNil(image, @"Failed: %@", error);
    XCTAssertEqual(image.bitDepth, 32u);
    XCTAssertTrue(image.isFloat);
}

- (void)testRead32BitIntTIFF {
    NSString *path = [self.fixturesDir stringByAppendingPathComponent:@"base_32int.tiff"];
    NSError *error = nil;
    TFNTIFFImage *image = [TFNTIFFReader readTIFFAtPath:path error:&error];

    XCTAssertNotNil(image, @"Failed: %@", error);
    XCTAssertEqual(image.bitDepth, 32u);
    XCTAssertFalse(image.isFloat);
}

- (void)testReadMultiChannelTIFF {
    NSString *path = [self.fixturesDir stringByAppendingPathComponent:@"multichannel.tiff"];
    NSError *error = nil;
    TFNTIFFImage *image = [TFNTIFFReader readTIFFAtPath:path error:&error];

    XCTAssertNotNil(image, @"Failed: %@", error);
    XCTAssertEqual(image.channelCount, 3u);
}

- (void)testReadCorruptTIFFReturnsError {
    NSString *path = [self.fixturesDir stringByAppendingPathComponent:@"corrupt.tiff"];
    NSError *error = nil;
    TFNTIFFImage *image = [TFNTIFFReader readTIFFAtPath:path error:&error];

    XCTAssertNil(image);
    XCTAssertNotNil(error);
}

- (void)testIsTIFFFile {
    XCTAssertTrue([TFNTIFFReader isTIFFFile:@"photo.tiff"]);
    XCTAssertTrue([TFNTIFFReader isTIFFFile:@"photo.tif"]);
    XCTAssertTrue([TFNTIFFReader isTIFFFile:@"photo.TIFF"]);
    XCTAssertFalse([TFNTIFFReader isTIFFFile:@"photo.png"]);
    XCTAssertFalse([TFNTIFFReader isTIFFFile:@"photo.jpg"]);
}

@end
