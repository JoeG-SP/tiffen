#import <Cocoa/Cocoa.h>
#import "TFNAppDelegate.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        TFNAppDelegate *delegate = [[TFNAppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
