#import "TFNMainWindowController.h"
#import "TFNProcessingEngine.h"
#import "TFNProcessedFileInfo.h"
#import "TFNFileListDataSource.h"
#import "TFNHistogramView.h"
#import "TFNExposureRange.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *const kBaseTIFFKey = @"TFNLastBaseTIFFPath";
static NSString *const kInputDirKey = @"TFNLastInputDirectory";
static NSString *const kOutputDirKey = @"TFNLastOutputDirectory";
static NSString *const kInPlaceKey = @"TFNInPlace";

@interface TFNMainWindowController () <NSDraggingDestination, NSTextFieldDelegate>

@property (nonatomic, strong) NSTextField *baseTIFFField;
@property (nonatomic, strong) NSTextField *inputDirField;
@property (nonatomic, strong) NSTextField *outputDirField;
@property (nonatomic, strong) NSButton *outputBrowseButton;
@property (nonatomic, strong) NSButton *normalizeButton;
@property (nonatomic, strong) NSProgressIndicator *progressBar;
@property (nonatomic, strong) NSTextField *progressLabel;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextField *summaryLabel;
@property (nonatomic, strong) TFNFileListDataSource *dataSource;
@property (nonatomic, strong) TFNProcessingEngine *engine;
@property (nonatomic, strong) NSPopover *histogramPopover;
@property (nonatomic, strong) NSWindow *histogramWindow;
@property (nonatomic, strong) TFNProcessedFileInfo *currentHistogramFile;

@end

@implementation TFNMainWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 1050, 650)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    window.title = @"Tiffen";
    window.minSize = NSMakeSize(850, 500);
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        _engine = [[TFNProcessingEngine alloc] init];
        _dataSource = [[TFNFileListDataSource alloc] init];
        [self setupUI];
        [self setupNotifications];
        [self setupHistogramPopover];
        [self restorePaths];
        [self updateInPlaceState];
        [self updateNormalizeButtonState];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kInPlaceKey];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"TFNShowPerFileTiming"];
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *content = self.window.contentView;

    // Use Auto Layout for proper resize behavior
    // Helper to create a label
    NSTextField *(^makeLabel)(NSString *) = ^NSTextField *(NSString *text) {
        NSTextField *label = [NSTextField labelWithString:text];
        label.alignment = NSTextAlignmentRight;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [label setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        return label;
    };

    // Helper to create a path field
    NSTextField *(^makePathField)(NSInteger) = ^NSTextField *(NSInteger tag) {
        NSTextField *field = [[NSTextField alloc] init];
        field.editable = YES;
        field.selectable = YES;
        field.placeholderString = @"Type or browse for a path";
        field.lineBreakMode = NSLineBreakByTruncatingMiddle;
        field.translatesAutoresizingMaskIntoConstraints = NO;
        field.tag = tag;
        field.delegate = self;
        return field;
    };

    // Helper to create a browse button
    NSButton *(^makeButton)(NSString *, SEL) = ^NSButton *(NSString *title, SEL action) {
        NSButton *btn = [[NSButton alloc] init];
        btn.title = title;
        btn.bezelStyle = NSBezelStyleRounded;
        btn.target = self;
        btn.action = action;
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        return btn;
    };

    CGFloat margin = 15;

    // --- Row 1: Base TIFF ---
    NSTextField *baseLabel = makeLabel(@"Base TIFF:");
    self.baseTIFFField = makePathField(1);
    NSButton *baseBrowse = makeButton(@"Browse...", @selector(browseBaseTIFF:));
    [content addSubview:baseLabel];
    [content addSubview:self.baseTIFFField];
    [content addSubview:baseBrowse];

    // --- Row 2: Input Dir ---
    NSTextField *inputLabel = makeLabel(@"Input Dir:");
    self.inputDirField = makePathField(2);
    NSButton *inputBrowse = makeButton(@"Browse...", @selector(browseInputDirectory:));
    [content addSubview:inputLabel];
    [content addSubview:self.inputDirField];
    [content addSubview:inputBrowse];

    // --- Row 3: Output ---
    NSTextField *outputLabel = makeLabel(@"Output:");
    self.outputDirField = makePathField(3);
    self.outputBrowseButton = makeButton(@"Browse...", @selector(browseOutputDirectory:));
    [content addSubview:outputLabel];
    [content addSubview:self.outputDirField];
    [content addSubview:self.outputBrowseButton];

    // --- Normalize button + progress ---
    self.normalizeButton = [[NSButton alloc] init];
    self.normalizeButton.title = @"Normalize";
    self.normalizeButton.bezelStyle = NSBezelStyleRounded;
    self.normalizeButton.target = self;
    self.normalizeButton.action = @selector(toggleNormalization:);
    self.normalizeButton.enabled = NO;
    self.normalizeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.normalizeButton];

    self.progressLabel = [NSTextField labelWithString:@""];
    self.progressLabel.alignment = NSTextAlignmentRight;
    self.progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.progressLabel];

    self.progressBar = [[NSProgressIndicator alloc] init];
    self.progressBar.style = NSProgressIndicatorStyleBar;
    self.progressBar.indeterminate = NO;
    self.progressBar.minValue = 0;
    self.progressBar.doubleValue = 0;
    self.progressBar.hidden = YES;
    self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.progressBar];

    // --- Table view ---
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;

    self.tableView = [[NSTableView alloc] init];
    self.tableView.headerView = [[NSTableHeaderView alloc] init];
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;

    NSTableColumn *fileCol = [[NSTableColumn alloc] initWithIdentifier:@"file"];
    fileCol.title = @"File";
    fileCol.width = 280;
    fileCol.minWidth = 120;
    fileCol.resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
    [self.tableView addTableColumn:fileCol];

    NSTableColumn *statusCol = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusCol.title = @"Status";
    statusCol.width = 100;
    statusCol.minWidth = 70;
    [self.tableView addTableColumn:statusCol];

    NSTableColumn *timeCol = [[NSTableColumn alloc] initWithIdentifier:@"totalTime"];
    timeCol.title = @"Time";
    timeCol.width = 70;
    timeCol.minWidth = 50;
    [self.tableView addTableColumn:timeCol];

    NSTableColumn *readCol = [[NSTableColumn alloc] initWithIdentifier:@"readTime"];
    readCol.title = @"Read";
    readCol.width = 70;
    readCol.minWidth = 50;
    [self.tableView addTableColumn:readCol];

    NSTableColumn *rangeCol = [[NSTableColumn alloc] initWithIdentifier:@"rangeTime"];
    rangeCol.title = @"Range";
    rangeCol.width = 70;
    rangeCol.minWidth = 50;
    [self.tableView addTableColumn:rangeCol];

    NSTableColumn *normCol = [[NSTableColumn alloc] initWithIdentifier:@"normalizeTime"];
    normCol.title = @"Norm";
    normCol.width = 70;
    normCol.minWidth = 50;
    [self.tableView addTableColumn:normCol];

    NSTableColumn *writeCol = [[NSTableColumn alloc] initWithIdentifier:@"writeTime"];
    writeCol.title = @"Write";
    writeCol.width = 70;
    writeCol.minWidth = 50;
    [self.tableView addTableColumn:writeCol];

    for (NSTableColumn *col in self.tableView.tableColumns) {
        col.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:col.identifier ascending:YES];
    }

    self.tableView.dataSource = self.dataSource;
    self.tableView.delegate = self.dataSource;
    self.scrollView.documentView = self.tableView;
    [content addSubview:self.scrollView];

    [self updateTimingColumnVisibility];

    // --- Summary bar ---
    self.summaryLabel = [NSTextField labelWithString:@""];
    self.summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.summaryLabel];

    // --- Auto Layout Constraints ---
    NSDictionary *views = NSDictionaryOfVariableBindings(
        baseLabel, _baseTIFFField, baseBrowse,
        inputLabel, _inputDirField, inputBrowse,
        outputLabel, _outputDirField, _outputBrowseButton,
        _normalizeButton, _progressLabel, _progressBar,
        _scrollView, _summaryLabel);
    NSDictionary *metrics = @{@"m": @(margin), @"lw": @80, @"rh": @24, @"sp": @8};

    // Horizontal rows
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[baseLabel(lw)]-(sp)-[_baseTIFFField]-(sp)-[baseBrowse]-(m)-|"
        options:NSLayoutFormatAlignAllCenterY metrics:metrics views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[inputLabel(lw)]-(sp)-[_inputDirField]-(sp)-[inputBrowse]-(m)-|"
        options:NSLayoutFormatAlignAllCenterY metrics:metrics views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[outputLabel(lw)]-(sp)-[_outputDirField]-(sp)-[_outputBrowseButton]-(m)-|"
        options:NSLayoutFormatAlignAllCenterY metrics:metrics views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[_normalizeButton]-(>=sp)-[_progressLabel]-(m)-|"
        options:NSLayoutFormatAlignAllCenterY metrics:metrics views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[_progressBar]-(m)-|" options:0 metrics:metrics views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[_scrollView]-(m)-|" options:0 metrics:metrics views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[_summaryLabel]-(m)-|" options:0 metrics:metrics views:views]];

    // Vertical layout: top rows pinned to top, table fills remaining space, summary at bottom
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"V:|-(m)-[baseLabel(rh)]-(sp)-[inputLabel(rh)]-(sp)-[outputLabel(rh)]-(12)-[_normalizeButton(32)]-(4)-[_progressBar(6)]-(8)-[_scrollView]-(4)-[_summaryLabel(20)]-(8)-|"
        options:0 metrics:metrics views:views]];

    // Align path field heights
    [self.baseTIFFField.heightAnchor constraintEqualToConstant:24].active = YES;
    [self.inputDirField.heightAnchor constraintEqualToConstant:24].active = YES;
    [self.outputDirField.heightAnchor constraintEqualToConstant:24].active = YES;

    // Register drag-and-drop on path fields
    [self.baseTIFFField registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    [self.inputDirField registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    [self.outputDirField registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
}


#pragma mark - Notifications

- (void)setupNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(processingDidStart:) name:TFNProcessingDidStartNotification object:nil];
    [nc addObserver:self selector:@selector(processingFileDidUpdate:) name:TFNProcessingFileDidUpdateNotification object:nil];
    [nc addObserver:self selector:@selector(processingDidFinish:) name:TFNProcessingDidFinishNotification object:nil];

    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kInPlaceKey
                                               options:NSKeyValueObservingOptionNew context:NULL];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"TFNShowPerFileTiming"
                                               options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:kInPlaceKey]) {
        [self updateInPlaceState];
    } else if ([keyPath isEqualToString:@"TFNShowPerFileTiming"]) {
        [self updateTimingColumnVisibility];
    }
}

- (void)processingDidStart:(NSNotification *)note {
    self.dataSource.files = self.engine.files;
    [self.tableView reloadData];
    self.progressBar.hidden = NO;
    self.progressBar.maxValue = self.engine.totalFiles;
    self.progressBar.doubleValue = 0;
    self.normalizeButton.title = @"Stop";
}

- (void)processingFileDidUpdate:(NSNotification *)note {
    NSUInteger index = [note.userInfo[TFNFileIndexKey] unsignedIntegerValue];
    NSIndexSet *rows = [NSIndexSet indexSetWithIndex:index];
    NSIndexSet *cols = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tableView.numberOfColumns)];
    [self.tableView reloadDataForRowIndexes:rows columnIndexes:cols];
    self.progressBar.doubleValue = self.engine.completedFiles;
    self.progressLabel.stringValue = [NSString stringWithFormat:@"Processing: %lu/%lu (%lu%%)",
        (unsigned long)self.engine.completedFiles,
        (unsigned long)self.engine.totalFiles,
        self.engine.totalFiles > 0 ? (unsigned long)(self.engine.completedFiles * 100 / self.engine.totalFiles) : 0];
}

- (void)processingDidFinish:(NSNotification *)note {
    NSString *error = note.userInfo[@"error"];
    if (error) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleCritical;
        alert.messageText = @"Processing Error";
        alert.informativeText = error;
        [alert runModal];
    }

    self.normalizeButton.title = @"Normalize";
    self.normalizeButton.enabled = [self canNormalize];
    self.progressBar.hidden = YES;
    self.progressLabel.stringValue = @"";

    // Summary
    NSUInteger done = 0, errors = 0, skipped = 0;
    for (TFNProcessedFileInfo *f in self.engine.files) {
        switch (f.status) {
            case TFNProcessingStatusCompleted: done++; break;
            case TFNProcessingStatusError: errors++; break;
            case TFNProcessingStatusSkipped: skipped++; break;
            default: break;
        }
    }
    self.summaryLabel.stringValue = [NSString stringWithFormat:@"%lu done, %lu errors, %lu skipped | Wall: %.1fs",
        (unsigned long)done, (unsigned long)errors, (unsigned long)skipped, self.engine.wallClockTime];

    // If cancelled with written files, show keep/delete dialog
    if (self.engine.writtenOutputPaths.count > 0 && done < self.engine.totalFiles && !error) {
        [self showCancellationDialog];
    }
}

#pragma mark - Browse Actions

- (void)browseBaseTIFF:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"tiff"],
                                   [UTType typeWithFilenameExtension:@"tif"]];
    if ([panel runModal] == NSModalResponseOK) {
        NSString *path = panel.URL.path;
        self.baseTIFFField.stringValue = path;
        self.baseTIFFField.toolTip = path;
        self.engine.baseTIFFPath = path;
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:kBaseTIFFKey];
        [self updateNormalizeButtonState];
    }
}

- (void)browseInputDirectory:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    if ([panel runModal] == NSModalResponseOK) {
        NSString *path = panel.URL.path;
        self.inputDirField.stringValue = path;
        self.inputDirField.toolTip = path;
        self.engine.inputDirectory = path;
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:kInputDirKey];

        // Auto-populate output directory to <input>/normalized/
        // Always update unless in-place mode is active
        if (![[NSUserDefaults standardUserDefaults] boolForKey:kInPlaceKey]) {
            NSString *outPath = [path stringByAppendingPathComponent:@"normalized"];
            self.outputDirField.stringValue = outPath;
            self.outputDirField.toolTip = outPath;
            self.engine.outputDirectory = outPath;
            [[NSUserDefaults standardUserDefaults] setObject:outPath forKey:kOutputDirKey];
        }
        [self updateNormalizeButtonState];
    }
}

- (void)browseOutputDirectory:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    if ([panel runModal] == NSModalResponseOK) {
        NSString *path = panel.URL.path;
        self.outputDirField.stringValue = path;
        self.outputDirField.toolTip = path;
        self.engine.outputDirectory = path;
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:kOutputDirKey];
    }
}

#pragma mark - Text Field Editing

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *field = notification.object;
    NSString *path = [field.stringValue stringByExpandingTildeInPath];

    if (field.tag == 1) {
        // Base TIFF
        self.engine.baseTIFFPath = path;
        field.toolTip = path;
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:kBaseTIFFKey];
        [self updateNormalizeButtonState];
    } else if (field.tag == 2) {
        // Input directory
        self.engine.inputDirectory = path;
        field.toolTip = path;
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:kInputDirKey];
        // Auto-update output
        if (![[NSUserDefaults standardUserDefaults] boolForKey:kInPlaceKey]) {
            NSString *outPath = [path stringByAppendingPathComponent:@"normalized"];
            self.outputDirField.stringValue = outPath;
            self.outputDirField.toolTip = outPath;
            self.engine.outputDirectory = outPath;
            [[NSUserDefaults standardUserDefaults] setObject:outPath forKey:kOutputDirKey];
        }
        [self updateNormalizeButtonState];
    } else if (field.tag == 3) {
        // Output directory
        self.engine.outputDirectory = path;
        field.toolTip = path;
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:kOutputDirKey];
    }
}

#pragma mark - Drag and Drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pb = sender.draggingPasteboard;
    NSArray<NSURL *> *urls = [pb readObjectsForClasses:@[[NSURL class]]
                                               options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
    if (urls.count == 0) return NO;

    NSURL *url = urls[0];
    NSString *path = url.path;

    // Determine which field based on the destination view
    NSPoint loc = [self.window.contentView convertPoint:sender.draggingLocation fromView:nil];

    if (NSPointInRect(loc, self.baseTIFFField.frame)) {
        BOOL isDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        if (isDir) return NO;
        self.baseTIFFField.stringValue = path;
        self.baseTIFFField.toolTip = path;
        self.engine.baseTIFFPath = path;
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:kBaseTIFFKey];
        [self updateNormalizeButtonState];
        return YES;
    } else if (NSPointInRect(loc, self.inputDirField.frame)) {
        BOOL isDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        if (!isDir) return NO;
        self.inputDirField.stringValue = path;
        self.inputDirField.toolTip = path;
        self.engine.inputDirectory = path;
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:kInputDirKey];
        // Auto-populate output directory
        if (![[NSUserDefaults standardUserDefaults] boolForKey:kInPlaceKey]) {
            NSString *outPath = [path stringByAppendingPathComponent:@"normalized"];
            self.outputDirField.stringValue = outPath;
            self.outputDirField.toolTip = outPath;
            self.engine.outputDirectory = outPath;
            [[NSUserDefaults standardUserDefaults] setObject:outPath forKey:kOutputDirKey];
        }
        [self updateNormalizeButtonState];
        return YES;
    } else if (NSPointInRect(loc, self.outputDirField.frame)) {
        BOOL isDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        if (!isDir) return NO;
        self.outputDirField.stringValue = path;
        self.outputDirField.toolTip = path;
        self.engine.outputDirectory = path;
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:kOutputDirKey];
        return YES;
    }

    return NO;
}

#pragma mark - Normalize / Cancel

- (void)toggleNormalization:(id)sender {
    if (self.engine.isRunning) {
        [self stopNormalization:sender];
    } else {
        [self startNormalization];
    }
}

- (void)startNormalization {
    if (![self canNormalize]) return;

    // Validate paths
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.engine.baseTIFFPath]) {
        [self showFatalError:@"Base TIFF file does not exist or is not readable."];
        return;
    }
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:self.engine.inputDirectory isDirectory:&isDir] || !isDir) {
        [self showFatalError:@"Input directory does not exist."];
        return;
    }

    self.summaryLabel.stringValue = @"";
    self.normalizeButton.title = @"Stop";
    [self.engine start];
}

- (void)stopNormalization:(id)sender {
    [self.engine cancel];
}

- (BOOL)canNormalize {
    return self.engine.baseTIFFPath.length > 0 &&
           self.engine.inputDirectory.length > 0 &&
           !self.engine.isRunning;
}

- (void)updateNormalizeButtonState {
    self.normalizeButton.enabled = [self canNormalize];
}

#pragma mark - Path Restoration

- (void)restorePaths {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *base = [defaults stringForKey:kBaseTIFFKey];
    NSString *input = [defaults stringForKey:kInputDirKey];
    NSString *output = [defaults stringForKey:kOutputDirKey];

    if (base.length > 0) {
        self.baseTIFFField.stringValue = base;
        self.baseTIFFField.toolTip = base;
        self.engine.baseTIFFPath = base;
    }
    if (input.length > 0) {
        self.inputDirField.stringValue = input;
        self.inputDirField.toolTip = input;
        self.engine.inputDirectory = input;
    }
    if (output.length > 0) {
        self.outputDirField.stringValue = output;
        self.outputDirField.toolTip = output;
        self.engine.outputDirectory = output;
    }
}

#pragma mark - In-Place Mode

- (void)updateInPlaceState {
    BOOL inPlace = [[NSUserDefaults standardUserDefaults] boolForKey:kInPlaceKey];
    self.outputDirField.enabled = !inPlace;
    self.outputBrowseButton.enabled = !inPlace;
    if (inPlace) {
        self.outputDirField.stringValue = @"(in-place)";
        self.outputDirField.toolTip = @"In-place mode — originals will be overwritten";
    } else {
        NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:kOutputDirKey];
        self.outputDirField.stringValue = saved ?: @"";
        self.outputDirField.toolTip = saved;
    }
}

#pragma mark - Cancellation Dialog

- (void)showCancellationDialog {
    NSUInteger writtenCount = self.engine.writtenOutputPaths.count;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = @"Processing Cancelled";
    alert.informativeText = [NSString stringWithFormat:
        @"%lu files were already written to the output directory.",
        (unsigned long)writtenCount];
    [alert addButtonWithTitle:@"Keep Files"];
    [alert addButtonWithTitle:@"Delete Files"];

    if ([alert runModal] == NSAlertSecondButtonReturn) {
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *path in self.engine.writtenOutputPaths) {
            [fm removeItemAtPath:path error:nil];
        }
    }
}

- (void)setupHistogramPopover {
    __weak typeof(self) weakSelf = self;
    self.dataSource.onRowSelected = ^(TFNProcessedFileInfo *info, NSRect rowRect) {
        [weakSelf showHistogramForFile:info atRect:rowRect];
    };
}

- (NSView *)buildHistogramContentForFile:(TFNProcessedFileInfo *)info
                                    size:(NSSize)size
                           includeExpand:(BOOL)includeExpand {
    NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
    CGFloat m = 10;
    CGFloat topY = size.height - m;

    // Title row with expand button
    NSTextField *titleLabel = [NSTextField labelWithString:
        [NSString stringWithFormat:@"%@ — Histogram", info.fileName]];
    titleLabel.font = [NSFont boldSystemFontOfSize:13];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:titleLabel];

    NSButton *expandBtn = nil;
    if (includeExpand) {
        expandBtn = [[NSButton alloc] init];
        expandBtn.image = [NSImage imageWithSystemSymbolName:@"arrow.up.left.and.arrow.down.right"
                                    accessibilityDescription:@"Expand"];
        expandBtn.bezelStyle = NSBezelStyleInline;
        expandBtn.bordered = NO;
        expandBtn.target = self;
        expandBtn.action = @selector(expandHistogramToWindow:);
        expandBtn.toolTip = @"Open in resizable window";
        expandBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [expandBtn setContentHuggingPriority:NSLayoutPriorityRequired
                              forOrientation:NSLayoutConstraintOrientationHorizontal];
        [contentView addSubview:expandBtn];
    }

    // Before histogram
    TFNHistogramView *beforeView = [[TFNHistogramView alloc] init];
    beforeView.histogramData = info.beforeHistogram;
    beforeView.title = @"Before";
    beforeView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:beforeView];

    // After histogram
    TFNHistogramView *afterView = [[TFNHistogramView alloc] init];
    afterView.histogramData = info.afterHistogram;
    afterView.title = info.afterHistogram ? @"After" : @"(base reference)";
    afterView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:afterView];

    // Range label
    NSString *rangeStr = @"";
    if (info.sourceRange && info.normalizedRange) {
        rangeStr = [NSString stringWithFormat:@"Range: [%.1f, %.1f] \u2192 [%.1f, %.1f]",
            info.sourceRange.minValues[0], info.sourceRange.maxValues[0],
            info.normalizedRange.minValues[0], info.normalizedRange.maxValues[0]];
    } else if (info.sourceRange) {
        rangeStr = [NSString stringWithFormat:@"Range: [%.1f, %.1f]",
            info.sourceRange.minValues[0], info.sourceRange.maxValues[0]];
    }
    NSTextField *rangeLabel = [NSTextField labelWithString:rangeStr];
    rangeLabel.font = [NSFont systemFontOfSize:11];
    rangeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:rangeLabel];

    // Metadata label
    NSString *metaStr = [NSString stringWithFormat:@"Bit depth: %lu-bit%@ | Channels: %lu",
        (unsigned long)info.bitDepth,
        info.isFloat ? @" float" : @"",
        (unsigned long)info.channelCount];
    NSTextField *metaLabel = [NSTextField labelWithString:metaStr];
    metaLabel.font = [NSFont systemFontOfSize:11];
    metaLabel.textColor = [NSColor secondaryLabelColor];
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:metaLabel];

    // Auto Layout
    NSDictionary *views;
    if (expandBtn) {
        views = NSDictionaryOfVariableBindings(titleLabel, expandBtn, beforeView, afterView, rangeLabel, metaLabel);
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
            @"H:|-(m)-[titleLabel]-(>=4)-[expandBtn(20)]-(m)-|"
            options:NSLayoutFormatAlignAllCenterY metrics:@{@"m": @(m)} views:views]];
    } else {
        views = NSDictionaryOfVariableBindings(titleLabel, beforeView, afterView, rangeLabel, metaLabel);
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
            @"H:|-(m)-[titleLabel]-(m)-|"
            options:0 metrics:@{@"m": @(m)} views:views]];
    }

    // Histograms side by side, equal width
    [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[beforeView]-(m)-[afterView(==beforeView)]-(m)-|"
        options:0 metrics:@{@"m": @(m)} views:views]];
    [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[rangeLabel]-(m)-|" options:0 metrics:@{@"m": @(m)} views:views]];
    [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"H:|-(m)-[metaLabel]-(m)-|" options:0 metrics:@{@"m": @(m)} views:views]];

    [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"V:|-(m)-[titleLabel(20)]-(8)-[beforeView(>=100)]-(6)-[rangeLabel(16)]-(2)-[metaLabel(16)]-(m)-|"
        options:0 metrics:@{@"m": @(m)} views:views]];
    // afterView same vertical position and height as beforeView
    [afterView.topAnchor constraintEqualToAnchor:beforeView.topAnchor].active = YES;
    [afterView.bottomAnchor constraintEqualToAnchor:beforeView.bottomAnchor].active = YES;

    return contentView;
}

- (void)showHistogramForFile:(TFNProcessedFileInfo *)info atRect:(NSRect)rowRect {
    if (!info.beforeHistogram && !info.afterHistogram) return;

    self.currentHistogramFile = info;
    [self.histogramPopover close];

    NSView *contentView = [self buildHistogramContentForFile:info
                                                       size:NSMakeSize(480, 300)
                                              includeExpand:YES];

    NSViewController *vc = [[NSViewController alloc] init];
    vc.view = contentView;

    self.histogramPopover = [[NSPopover alloc] init];
    self.histogramPopover.contentViewController = vc;
    self.histogramPopover.contentSize = NSMakeSize(480, 300);
    self.histogramPopover.behavior = NSPopoverBehaviorTransient;

    NSRect anchorRect = [self.tableView rectOfRow:self.tableView.selectedRow];
    [self.histogramPopover showRelativeToRect:anchorRect
                                      ofView:self.tableView
                               preferredEdge:NSRectEdgeMaxY];
}

- (void)expandHistogramToWindow:(id)sender {
    TFNProcessedFileInfo *info = self.currentHistogramFile;
    if (!info) return;

    [self.histogramPopover close];

    NSView *contentView = [self buildHistogramContentForFile:info
                                                       size:NSMakeSize(700, 450)
                                              includeExpand:NO];

    if (!self.histogramWindow) {
        self.histogramWindow = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(0, 0, 700, 450)
                      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                NSWindowStyleMaskResizable
                        backing:NSBackingStoreBuffered
                          defer:NO];
        self.histogramWindow.minSize = NSMakeSize(400, 300);
        self.histogramWindow.releasedWhenClosed = NO;
    }

    self.histogramWindow.title = [NSString stringWithFormat:@"%@ — Histogram", info.fileName];
    self.histogramWindow.contentView = contentView;
    [self.histogramWindow center];
    [self.histogramWindow makeKeyAndOrderFront:nil];
}

- (void)updateTimingColumnVisibility {
    BOOL show = [[NSUserDefaults standardUserDefaults] boolForKey:@"TFNShowPerFileTiming"];
    NSArray *timingIDs = @[@"readTime", @"rangeTime", @"normalizeTime", @"writeTime"];
    for (NSString *ident in timingIDs) {
        NSTableColumn *col = [self.tableView tableColumnWithIdentifier:ident];
        col.hidden = !show;
    }
}

- (void)showFatalError:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = @"Cannot Start Normalization";
    alert.informativeText = message;
    [alert runModal];
}

@end
