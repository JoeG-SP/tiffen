#import <XCTest/XCTest.h>
#import "TFNProcessedFileInfo.h"

@interface TFNProcessedFileInfoTests : XCTestCase
@end

@implementation TFNProcessedFileInfoTests

- (void)testInitialState {
    TFNProcessedFileInfo *info = [[TFNProcessedFileInfo alloc] initWithFilePath:@"/tmp/test.tiff"];
    XCTAssertEqualObjects(info.fileName, @"test.tiff");
    XCTAssertEqualObjects(info.filePath, @"/tmp/test.tiff");
    XCTAssertEqual(info.status, TFNProcessingStatusPending);
    XCTAssertEqual(info.readTime, -1);
    XCTAssertEqual(info.rangeTime, -1);
    XCTAssertEqual(info.normalizeTime, -1);
    XCTAssertEqual(info.writeTime, -1);
    XCTAssertEqual(info.totalTime, -1);
    XCTAssertNil(info.errorMessage);
}

- (void)testStatusTransitionToCompleted {
    TFNProcessedFileInfo *info = [[TFNProcessedFileInfo alloc] initWithFilePath:@"/tmp/test.tiff"];
    info.status = TFNProcessingStatusProcessing;
    XCTAssertEqual(info.status, TFNProcessingStatusProcessing);

    info.status = TFNProcessingStatusCompleted;
    info.totalTime = 1.5;
    XCTAssertEqual(info.status, TFNProcessingStatusCompleted);
    XCTAssertEqualWithAccuracy(info.totalTime, 1.5, 1e-6);
    XCTAssertNil(info.errorMessage);
}

- (void)testStatusTransitionToError {
    TFNProcessedFileInfo *info = [[TFNProcessedFileInfo alloc] initWithFilePath:@"/tmp/test.tiff"];
    info.status = TFNProcessingStatusProcessing;
    info.status = TFNProcessingStatusError;
    info.errorMessage = @"corrupt TIFF header";
    XCTAssertEqual(info.status, TFNProcessingStatusError);
    XCTAssertEqualObjects(info.errorMessage, @"corrupt TIFF header");
}

- (void)testSkippedStatus {
    TFNProcessedFileInfo *info = [[TFNProcessedFileInfo alloc] initWithFilePath:@"/tmp/test.png"];
    info.status = TFNProcessingStatusSkipped;
    XCTAssertEqual(info.status, TFNProcessingStatusSkipped);
    XCTAssertNil(info.errorMessage);
}

@end
