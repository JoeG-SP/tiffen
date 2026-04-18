#import <XCTest/XCTest.h>

/// CLI tests validate the compiled binary's argument handling.
/// These tests invoke the tiffen binary as a subprocess.
@interface TFNCLITests : XCTestCase
@property (nonatomic, copy) NSString *binaryPath;
@end

@implementation TFNCLITests

- (void)setUp {
    // Find the built binary — adjust path as needed for Xcode build output
    NSString *buildDir = [NSProcessInfo processInfo].environment[@"BUILT_PRODUCTS_DIR"];
    if (buildDir) {
        self.binaryPath = [buildDir stringByAppendingPathComponent:@"tiffen"];
    } else {
        // Fallback: search common build locations
        NSArray *candidates = @[
            @"build/Release/tiffen",
            @"build/Debug/tiffen",
            @"DerivedData/Build/Products/Release/tiffen",
        ];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *path in candidates) {
            NSString *fullPath = [[[NSBundle mainBundle] bundlePath]
                stringByAppendingPathComponent:path];
            if ([fm isExecutableFileAtPath:fullPath]) {
                self.binaryPath = fullPath;
                break;
            }
        }
    }
}

- (NSTask *)taskWithArguments:(NSArray<NSString *> *)arguments {
    NSTask *task = [[NSTask alloc] init];
    if (self.binaryPath) {
        task.executableURL = [NSURL fileURLWithPath:self.binaryPath];
    }
    task.arguments = arguments;
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];
    return task;
}

- (void)testHelpExitsZero {
    if (!self.binaryPath) {
        NSLog(@"Binary not found — skipping CLI test");
        return;
    }

    NSTask *task = [self taskWithArguments:@[@"--help"]];
    [task launch];
    [task waitUntilExit];

    XCTAssertEqual(task.terminationStatus, 0);

    NSData *output = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSString *stdout = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    XCTAssertTrue([stdout containsString:@"Usage"]);
}

- (void)testVersionExitsZero {
    if (!self.binaryPath) return;

    NSTask *task = [self taskWithArguments:@[@"--version"]];
    [task launch];
    [task waitUntilExit];

    XCTAssertEqual(task.terminationStatus, 0);

    NSData *output = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSString *stdout = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    XCTAssertTrue([stdout containsString:@"tiffen"]);
}

- (void)testMissingArgsExits2 {
    if (!self.binaryPath) return;

    NSTask *task = [self taskWithArguments:@[]];
    [task launch];
    [task waitUntilExit];

    XCTAssertEqual(task.terminationStatus, 2);
}

- (void)testInPlaceAndOutputMutuallyExclusive {
    if (!self.binaryPath) return;

    NSTask *task = [self taskWithArguments:@[@"base.tiff", @"dir/", @"--in-place", @"--output", @"out/"]];
    [task launch];
    [task waitUntilExit];

    XCTAssertEqual(task.terminationStatus, 2);

    NSData *errData = [[task.standardError fileHandleForReading] readDataToEndOfFile];
    NSString *stderr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
    XCTAssertTrue([stderr containsString:@"mutually exclusive"]);
}

- (void)testVerboseAndQuietMutuallyExclusive {
    if (!self.binaryPath) return;

    NSTask *task = [self taskWithArguments:@[@"base.tiff", @"dir/", @"-v", @"-q"]];
    [task launch];
    [task waitUntilExit];

    XCTAssertEqual(task.terminationStatus, 2);
}

@end
