#import <XCTest/XCTest.h>

@interface TFNAppSettingsTests : XCTestCase
@end

@implementation TFNAppSettingsTests

- (void)setUp {
    // Register defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"TFNCPUPercent": @90,
        @"TFNMemPercent": @90,
        @"TFNMaxJobs": @0,
        @"TFNInPlace": @NO,
        @"TFNShowPerFileTiming": @YES
    }];
}

- (void)tearDown {
    // Reset to defaults
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:@"TFNCPUPercent"];
    [d removeObjectForKey:@"TFNMemPercent"];
    [d removeObjectForKey:@"TFNMaxJobs"];
    [d removeObjectForKey:@"TFNInPlace"];
    [d removeObjectForKey:@"TFNShowPerFileTiming"];
}

- (void)testDefaultValues {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    XCTAssertEqual([d integerForKey:@"TFNCPUPercent"], 90);
    XCTAssertEqual([d integerForKey:@"TFNMemPercent"], 90);
    XCTAssertEqual([d integerForKey:@"TFNMaxJobs"], 0);
    XCTAssertFalse([d boolForKey:@"TFNInPlace"]);
    XCTAssertTrue([d boolForKey:@"TFNShowPerFileTiming"]);
}

- (void)testRoundTrip {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];

    [d setInteger:50 forKey:@"TFNCPUPercent"];
    [d setInteger:75 forKey:@"TFNMemPercent"];
    [d setInteger:8 forKey:@"TFNMaxJobs"];
    [d setBool:YES forKey:@"TFNInPlace"];
    [d setBool:NO forKey:@"TFNShowPerFileTiming"];

    XCTAssertEqual([d integerForKey:@"TFNCPUPercent"], 50);
    XCTAssertEqual([d integerForKey:@"TFNMemPercent"], 75);
    XCTAssertEqual([d integerForKey:@"TFNMaxJobs"], 8);
    XCTAssertTrue([d boolForKey:@"TFNInPlace"]);
    XCTAssertFalse([d boolForKey:@"TFNShowPerFileTiming"]);
}

- (void)testPathPersistence {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:@"/tmp/base.tiff" forKey:@"TFNLastBaseTIFFPath"];
    [d setObject:@"/tmp/input" forKey:@"TFNLastInputDirectory"];
    [d setObject:@"/tmp/output" forKey:@"TFNLastOutputDirectory"];

    XCTAssertEqualObjects([d stringForKey:@"TFNLastBaseTIFFPath"], @"/tmp/base.tiff");
    XCTAssertEqualObjects([d stringForKey:@"TFNLastInputDirectory"], @"/tmp/input");
    XCTAssertEqualObjects([d stringForKey:@"TFNLastOutputDirectory"], @"/tmp/output");

    [d removeObjectForKey:@"TFNLastBaseTIFFPath"];
    [d removeObjectForKey:@"TFNLastInputDirectory"];
    [d removeObjectForKey:@"TFNLastOutputDirectory"];
}

@end
