#import "TFNHistogramView.h"
#import "TFNHistogramData.h"

// Channel colors: R, G, B, Gray
static CGFloat channelColors[][4] = {
    {1.0, 0.0, 0.0, 0.4},  // Red
    {0.0, 1.0, 0.0, 0.4},  // Green
    {0.0, 0.0, 1.0, 0.4},  // Blue
    {0.5, 0.5, 0.5, 0.6},  // Gray (4th channel or single channel)
};

@implementation TFNHistogramView

- (void)setHistogramData:(TFNHistogramData *)histogramData {
    _histogramData = histogramData;
    [self setNeedsDisplay:YES];
    if (histogramData) {
        self.accessibilityLabel = [NSString stringWithFormat:@"Histogram with %lu channels",
            (unsigned long)histogramData.channelCount];
    } else {
        self.accessibilityLabel = @"Empty histogram";
    }
}

- (BOOL)isFlipped {
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    CGContextRef ctx = [NSGraphicsContext currentContext].CGContext;

    // Background
    CGContextSetRGBFillColor(ctx, 0.95, 0.95, 0.95, 1.0);
    CGContextFillRect(ctx, self.bounds);

    if (!self.histogramData) return;

    NSRect chartRect = NSInsetRect(self.bounds, 8, 8);
    if (self.title) {
        chartRect.size.height -= 16;
    }

    CGFloat binWidth = chartRect.size.width / TFN_HISTOGRAM_BIN_COUNT;
    NSUInteger channels = self.histogramData.channelCount;

    for (NSUInteger c = 0; c < channels; c++) {
        const float *bins = [self.histogramData binsForChannel:c];

        // Find max bin for scaling
        float maxBin = 0;
        for (int i = 0; i < TFN_HISTOGRAM_BIN_COUNT; i++) {
            if (bins[i] > maxBin) maxBin = bins[i];
        }
        if (maxBin <= 0) continue;

        // Select color
        NSUInteger colorIdx;
        if (channels == 1) {
            colorIdx = 3; // Gray
        } else {
            colorIdx = c % 4;
        }

        CGContextSetRGBFillColor(ctx,
            channelColors[colorIdx][0],
            channelColors[colorIdx][1],
            channelColors[colorIdx][2],
            channelColors[colorIdx][3]);

        // Draw filled area
        CGContextBeginPath(ctx);
        CGContextMoveToPoint(ctx, chartRect.origin.x, chartRect.origin.y);

        for (int i = 0; i < TFN_HISTOGRAM_BIN_COUNT; i++) {
            CGFloat x = chartRect.origin.x + i * binWidth;
            CGFloat h = (bins[i] / maxBin) * chartRect.size.height;
            CGContextAddLineToPoint(ctx, x, chartRect.origin.y + h);
        }

        CGContextAddLineToPoint(ctx, chartRect.origin.x + chartRect.size.width, chartRect.origin.y);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    }

    // Title
    if (self.title) {
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:11],
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
        };
        [self.title drawAtPoint:NSMakePoint(chartRect.origin.x, self.bounds.size.height - 16)
                 withAttributes:attrs];
    }
}

@end
