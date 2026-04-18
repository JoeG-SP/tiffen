#import <XCTest/XCTest.h>
#import "TFNTIFFReader.h"
#import "TFNTIFFWriter.h"
#import "TFNTestFixtures.h"

@interface TFNTIFFWriterTests : XCTestCase
@property (nonatomic, copy) NSString *fixturesDir;
@end

@implementation TFNTIFFWriterTests

- (void)setUp {
    self.fixturesDir = [TFNTestFixtures createFixturesDirectory];
}

- (void)tearDown {
    [TFNTestFixtures cleanupDirectory:self.fixturesDir];
}

- (void)testRoundTripUint8 {
    NSString *srcPath = [self.fixturesDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    NSString *dstPath = [self.fixturesDir stringByAppendingPathComponent:@"roundtrip_8bit.tiff"];

    NSError *error = nil;
    TFNTIFFImage *original = [TFNTIFFReader readTIFFAtPath:srcPath error:&error];
    XCTAssertNotNil(original, @"Read failed: %@", error);

    BOOL writeOK = [TFNTIFFWriter writeImage:original toPath:dstPath error:&error];
    XCTAssertTrue(writeOK, @"Write failed: %@", error);

    TFNTIFFImage *reloaded = [TFNTIFFReader readTIFFAtPath:dstPath error:&error];
    XCTAssertNotNil(reloaded, @"Re-read failed: %@", error);

    XCTAssertEqual(reloaded.width, original.width);
    XCTAssertEqual(reloaded.height, original.height);
    XCTAssertEqual(reloaded.channelCount, original.channelCount);
    XCTAssertEqual(reloaded.bitDepth, original.bitDepth);
    XCTAssertEqual(reloaded.isFloat, original.isFloat);

    // Pixel data should match exactly
    XCTAssertEqual(reloaded.pixelDataLength, original.pixelDataLength);
    XCTAssertEqual(memcmp(reloaded.pixelData, original.pixelData, original.pixelDataLength), 0);
}

- (void)testRoundTripFloat32 {
    NSString *srcPath = [self.fixturesDir stringByAppendingPathComponent:@"base_32float.tiff"];
    NSString *dstPath = [self.fixturesDir stringByAppendingPathComponent:@"roundtrip_32float.tiff"];

    NSError *error = nil;
    TFNTIFFImage *original = [TFNTIFFReader readTIFFAtPath:srcPath error:&error];
    XCTAssertNotNil(original);

    BOOL writeOK = [TFNTIFFWriter writeImage:original toPath:dstPath error:&error];
    XCTAssertTrue(writeOK);

    TFNTIFFImage *reloaded = [TFNTIFFReader readTIFFAtPath:dstPath error:&error];
    XCTAssertNotNil(reloaded);

    XCTAssertEqual(reloaded.bitDepth, 32u);
    XCTAssertTrue(reloaded.isFloat);
    XCTAssertEqual(memcmp(reloaded.pixelData, original.pixelData, original.pixelDataLength), 0);
}

- (void)testRoundTripMultiChannel {
    NSString *srcPath = [self.fixturesDir stringByAppendingPathComponent:@"multichannel.tiff"];
    NSString *dstPath = [self.fixturesDir stringByAppendingPathComponent:@"roundtrip_multi.tiff"];

    NSError *error = nil;
    TFNTIFFImage *original = [TFNTIFFReader readTIFFAtPath:srcPath error:&error];
    XCTAssertNotNil(original);

    BOOL writeOK = [TFNTIFFWriter writeImage:original toPath:dstPath error:&error];
    XCTAssertTrue(writeOK);

    TFNTIFFImage *reloaded = [TFNTIFFReader readTIFFAtPath:dstPath error:&error];
    XCTAssertNotNil(reloaded);

    XCTAssertEqual(reloaded.channelCount, 3u);
    XCTAssertEqual(memcmp(reloaded.pixelData, original.pixelData, original.pixelDataLength), 0);
}

@end
