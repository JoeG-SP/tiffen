#import <Cocoa/Cocoa.h>

@class TFNProcessingEngine;

@interface TFNMainWindowController : NSWindowController

@property (nonatomic, strong, readonly) TFNProcessingEngine *engine;

- (void)browseBaseTIFF:(id)sender;
- (void)browseInputDirectory:(id)sender;
- (void)browseOutputDirectory:(id)sender;
- (void)toggleNormalization:(id)sender;
- (void)stopNormalization:(id)sender;

@end
