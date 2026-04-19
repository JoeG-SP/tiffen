#import <Cocoa/Cocoa.h>

@class TFNHistogramData;

@interface TFNHistogramView : NSView

@property (nonatomic, strong, nullable) TFNHistogramData *histogramData;
@property (nonatomic, copy, nullable) NSString *title;

@end
