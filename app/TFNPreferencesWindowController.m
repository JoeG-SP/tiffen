#import "TFNPreferencesWindowController.h"

@interface TFNPreferencesWindowController ()
@property (nonatomic, strong) NSSlider *cpuSlider;
@property (nonatomic, strong) NSTextField *cpuLabel;
@property (nonatomic, strong) NSSlider *memSlider;
@property (nonatomic, strong) NSTextField *memLabel;
@property (nonatomic, strong) NSTextField *jobsField;
@property (nonatomic, strong) NSStepper *jobsStepper;
@property (nonatomic, strong) NSButton *inPlaceCheckbox;
@property (nonatomic, strong) NSButton *timingCheckbox;
@end

@implementation TFNPreferencesWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 400, 300)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    window.title = @"Settings";
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        [self setupUI];
        [self bindControls];
    }
    return self;
}

- (void)setupUI {
    NSView *content = self.window.contentView;
    CGFloat y = 260;
    CGFloat labelX = 20;
    CGFloat controlX = 200;

    // Processing section
    NSTextField *procHeader = [self headerLabel:@"Processing" at:NSMakePoint(labelX, y)];
    [content addSubview:procHeader];

    // CPU slider
    y -= 30;
    [content addSubview:[self label:@"CPU usage limit:" at:NSMakePoint(labelX, y)]];
    self.cpuSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(controlX, y, 130, 20)];
    self.cpuSlider.minValue = 1;
    self.cpuSlider.maxValue = 100;
    [content addSubview:self.cpuSlider];
    self.cpuLabel = [self valueLabel:NSMakeRect(controlX + 140, y, 40, 20)];
    [content addSubview:self.cpuLabel];

    // Memory slider
    y -= 30;
    [content addSubview:[self label:@"Memory usage limit:" at:NSMakePoint(labelX, y)]];
    self.memSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(controlX, y, 130, 20)];
    self.memSlider.minValue = 1;
    self.memSlider.maxValue = 100;
    [content addSubview:self.memSlider];
    self.memLabel = [self valueLabel:NSMakeRect(controlX + 140, y, 40, 20)];
    [content addSubview:self.memLabel];

    // Max jobs
    y -= 30;
    [content addSubview:[self label:@"Max parallel jobs:" at:NSMakePoint(labelX, y)]];
    self.jobsField = [[NSTextField alloc] initWithFrame:NSMakeRect(controlX, y, 50, 22)];
    [content addSubview:self.jobsField];
    self.jobsStepper = [[NSStepper alloc] initWithFrame:NSMakeRect(controlX + 55, y, 20, 22)];
    self.jobsStepper.minValue = 0;
    self.jobsStepper.maxValue = 64;
    self.jobsStepper.increment = 1;
    [content addSubview:self.jobsStepper];
    [content addSubview:[self label:@"(0 = auto)" at:NSMakePoint(controlX + 80, y)]];

    // Output section
    y -= 40;
    [content addSubview:[self headerLabel:@"Output" at:NSMakePoint(labelX, y)]];

    y -= 26;
    self.inPlaceCheckbox = [NSButton checkboxWithTitle:@"Overwrite originals (in-place)"
                                                target:nil action:nil];
    self.inPlaceCheckbox.frame = NSMakeRect(labelX, y, 300, 20);
    [content addSubview:self.inPlaceCheckbox];

    // Display section
    y -= 40;
    [content addSubview:[self headerLabel:@"Display" at:NSMakePoint(labelX, y)]];

    y -= 26;
    self.timingCheckbox = [NSButton checkboxWithTitle:@"Show per-file timing details"
                                               target:nil action:nil];
    self.timingCheckbox.frame = NSMakeRect(labelX, y, 300, 20);
    [content addSubview:self.timingCheckbox];
}

- (void)bindControls {
    NSUserDefaultsController *dc = [NSUserDefaultsController sharedUserDefaultsController];

    [self.cpuSlider bind:NSValueBinding toObject:dc
             withKeyPath:@"values.TFNCPUPercent" options:nil];
    [self.cpuLabel bind:NSValueBinding toObject:dc
            withKeyPath:@"values.TFNCPUPercent"
                options:@{NSValueTransformerNameBindingOption: @"",
                          NSContinuouslyUpdatesValueBindingOption: @YES}];

    [self.memSlider bind:NSValueBinding toObject:dc
             withKeyPath:@"values.TFNMemPercent" options:nil];
    [self.memLabel bind:NSValueBinding toObject:dc
            withKeyPath:@"values.TFNMemPercent"
                options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];

    [self.jobsField bind:NSValueBinding toObject:dc
             withKeyPath:@"values.TFNMaxJobs" options:nil];
    [self.jobsStepper bind:NSValueBinding toObject:dc
               withKeyPath:@"values.TFNMaxJobs" options:nil];

    [self.inPlaceCheckbox bind:NSValueBinding toObject:dc
                   withKeyPath:@"values.TFNInPlace" options:nil];
    [self.timingCheckbox bind:NSValueBinding toObject:dc
                  withKeyPath:@"values.TFNShowPerFileTiming" options:nil];
}

#pragma mark - Helpers

- (NSTextField *)headerLabel:(NSString *)text at:(NSPoint)pt {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 360, 20)];
    label.stringValue = text;
    label.font = [NSFont boldSystemFontOfSize:13];
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    return label;
}

- (NSTextField *)label:(NSString *)text at:(NSPoint)pt {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 180, 20)];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.alignment = NSTextAlignmentRight;
    return label;
}

- (NSTextField *)valueLabel:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    return label;
}

@end
