#import <XCTest/XCTest.h>
#import "TFNExposureRange.h"

@interface TFNExposureRangeTests : XCTestCase
@end

@implementation TFNExposureRangeTests

- (void)testMinMaxFromUint8Buffer {
    uint8_t data[] = {10, 50, 200, 100};
    TFNExposureRange *range = [TFNExposureRange rangeFromPixelData:data
                                                             width:4 height:1
                                                      channelCount:1 bitDepth:8 isFloat:NO];
    XCTAssertNotNil(range);
    XCTAssertEqual(range.channelCount, 1u);
    XCTAssertEqual(range.minValues[0], 10.0f);
    XCTAssertEqual(range.maxValues[0], 200.0f);
}

- (void)testMinMaxFromUint16Buffer {
    uint16_t data[] = {1000, 30000, 65535, 500};
    TFNExposureRange *range = [TFNExposureRange rangeFromPixelData:data
                                                             width:4 height:1
                                                      channelCount:1 bitDepth:16 isFloat:NO];
    XCTAssertNotNil(range);
    XCTAssertEqual(range.minValues[0], 500.0f);
    XCTAssertEqual(range.maxValues[0], 65535.0f);
}

- (void)testMinMaxFromFloat32Buffer {
    float data[] = {0.1f, 0.5f, 0.9f, 0.3f};
    TFNExposureRange *range = [TFNExposureRange rangeFromPixelData:data
                                                             width:4 height:1
                                                      channelCount:1 bitDepth:32 isFloat:YES];
    XCTAssertNotNil(range);
    XCTAssertEqualWithAccuracy(range.minValues[0], 0.1f, 1e-6f);
    XCTAssertEqualWithAccuracy(range.maxValues[0], 0.9f, 1e-6f);
}

- (void)testMultiChannelMinMax {
    // RGB: 3 channels, 2 pixels
    uint8_t data[] = {
        10, 20, 30,   // pixel 0: R=10, G=20, B=30
        200, 100, 50  // pixel 1: R=200, G=100, B=50
    };
    TFNExposureRange *range = [TFNExposureRange rangeFromPixelData:data
                                                             width:2 height:1
                                                      channelCount:3 bitDepth:8 isFloat:NO];
    XCTAssertNotNil(range);
    XCTAssertEqual(range.channelCount, 3u);
    XCTAssertEqual(range.minValues[0], 10.0f);  // R min
    XCTAssertEqual(range.maxValues[0], 200.0f); // R max
    XCTAssertEqual(range.minValues[1], 20.0f);  // G min
    XCTAssertEqual(range.maxValues[1], 100.0f); // G max
    XCTAssertEqual(range.minValues[2], 30.0f);  // B min
    XCTAssertEqual(range.maxValues[2], 50.0f);  // B max
}

- (void)testFlatExposure {
    uint8_t data[] = {128, 128, 128, 128};
    TFNExposureRange *range = [TFNExposureRange rangeFromPixelData:data
                                                             width:4 height:1
                                                      channelCount:1 bitDepth:8 isFloat:NO];
    XCTAssertNotNil(range);
    XCTAssertEqual(range.minValues[0], 128.0f);
    XCTAssertEqual(range.maxValues[0], 128.0f);
}

- (void)testNilOnInvalidInput {
    TFNExposureRange *range = [TFNExposureRange rangeFromPixelData:NULL
                                                             width:0 height:0
                                                      channelCount:0 bitDepth:8 isFloat:NO];
    XCTAssertNil(range);
}

@end
