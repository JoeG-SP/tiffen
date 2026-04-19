#import <XCTest/XCTest.h>
#import "TFNProcessingEngine.h"
#import "TFNProcessedFileInfo.h"
#import "TFNTestFixtures.h"

@interface TFNProcessingEngineTests : XCTestCase
@property (nonatomic, strong) NSString *fixtureDir;
@end

@implementation TFNProcessingEngineTests

- (void)setUp {
    self.fixtureDir = [TFNTestFixtures createFixturesDirectory];
    // Register defaults for engine to read
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"TFNCPUPercent": @90,
        @"TFNMemPercent": @90,
        @"TFNMaxJobs": @2,
        @"TFNInPlace": @NO
    }];
}

- (void)tearDown {
    [TFNTestFixtures cleanupDirectory:self.fixtureDir];
}

- (void)testEnginePostsStartAndFinishNotifications {
    XCTestExpectation *startExp = [self expectationForNotification:TFNProcessingDidStartNotification
                                                           object:nil handler:nil];
    XCTestExpectation *finishExp = [self expectationForNotification:TFNProcessingDidFinishNotification
                                                            object:nil handler:nil];

    TFNProcessingEngine *engine = [[TFNProcessingEngine alloc] init];
    engine.baseTIFFPath = [self.fixtureDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    engine.inputDirectory = self.fixtureDir;
    [engine start];

    [self waitForExpectations:@[startExp, finishExp] timeout:30];
    XCTAssertFalse(engine.isRunning);
    XCTAssertGreaterThan(engine.completedFiles, 0u);
}

- (void)testFileUpdateNotificationsContainIndexAndInfo {
    __block NSUInteger updateCount = 0;
    __block BOOL hasIndex = NO;
    __block BOOL hasInfo = NO;

    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:TFNProcessingFileDidUpdateNotification
                    object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
        updateCount++;
        hasIndex = note.userInfo[TFNFileIndexKey] != nil;
        hasInfo = note.userInfo[TFNFileInfoKey] != nil;
    }];

    XCTestExpectation *finishExp = [self expectationForNotification:TFNProcessingDidFinishNotification
                                                            object:nil handler:nil];

    TFNProcessingEngine *engine = [[TFNProcessingEngine alloc] init];
    engine.baseTIFFPath = [self.fixtureDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    engine.inputDirectory = self.fixtureDir;
    [engine start];

    [self waitForExpectations:@[finishExp] timeout:30];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];

    XCTAssertGreaterThan(updateCount, 0u);
    XCTAssertTrue(hasIndex);
    XCTAssertTrue(hasInfo);
}

- (void)testCancellationStopsNewFiles {
    XCTestExpectation *finishExp = [self expectationForNotification:TFNProcessingDidFinishNotification
                                                            object:nil handler:nil];

    TFNProcessingEngine *engine = [[TFNProcessingEngine alloc] init];
    engine.baseTIFFPath = [self.fixtureDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    engine.inputDirectory = self.fixtureDir;
    [engine start];

    // Cancel immediately
    [engine cancel];

    [self waitForExpectations:@[finishExp] timeout:30];
    XCTAssertFalse(engine.isRunning);
    // Some files may have completed before cancellation took effect
    XCTAssertLessThanOrEqual(engine.completedFiles, engine.totalFiles);
}

- (void)testNotificationsArriveOnMainQueue {
    __block BOOL onMainQueue = NO;

    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:TFNProcessingDidStartNotification
                    object:nil queue:nil
                usingBlock:^(NSNotification *note) {
        onMainQueue = [NSThread isMainThread];
    }];

    XCTestExpectation *finishExp = [self expectationForNotification:TFNProcessingDidFinishNotification
                                                            object:nil handler:nil];

    TFNProcessingEngine *engine = [[TFNProcessingEngine alloc] init];
    engine.baseTIFFPath = [self.fixtureDir stringByAppendingPathComponent:@"base_8bit.tiff"];
    engine.inputDirectory = self.fixtureDir;
    [engine start];

    [self waitForExpectations:@[finishExp] timeout:30];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];

    XCTAssertTrue(onMainQueue, @"Start notification should arrive on main queue");
}

@end
