#import <Cocoa/Cocoa.h>

@class TFNMainWindowController;
@class TFNPreferencesWindowController;

@interface TFNAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) TFNMainWindowController *mainWindowController;
@property (nonatomic, strong) TFNPreferencesWindowController *preferencesWindowController;

@end
