#import "TFNMainWindowController.h"
#import "TFNProcessingEngine.h"
#import "TFNProcessedFileInfo.h"
#import "TFNFileListDataSource.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *const kBaseTIFFKey = @"TFNLastBaseTIFFPath";
static NSString *const kInputDirKey = @"TFNLastInputDirectory";
static NSString *const kOutputDirKey = @"TFNLastOutputDirectory";
static NSString *const kInPlaceKey = @"TFNInPlace";

@interface TFNMainWindowController () <NSDraggingDestination>

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

@end

@implementation TFNMainWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 900, 600)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    window.title = @"Tiffen";
    window.minSize = NSMakeSize(700, 500);
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        _engine = [[TFNProcessingEngine alloc] init];
        _dataSource = [[TFNFileListDataSource alloc] init];
        [self setupUI];
        [self setupNotifications];
        [self restorePaths];
        [self updateInPlaceState];
        [self updateNormalizeButtonState];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kInPlaceKey];
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;

    CGFloat y = content.bounds.size.height - 40;
    CGFloat labelW = 80;
    CGFloat fieldX = labelW + 20;
    CGFloat btnW = 80;
    CGFloat margin = 15;

    // Base TIFF row
    [self addLabel:@"Base TIFF:" at:NSMakePoint(margin, y) toView:content];
    self.baseTIFFField = [self addPathField:NSMakeRect(fieldX, y, 620, 24) toView:content tag:1];
    [self addButton:@"Browse..." at:NSMakePoint(fieldX + 630, y) action:@selector(browseBaseTIFF:) toView:content];

    // Input Dir row
    y -= 34;
    [self addLabel:@"Input Dir:" at:NSMakePoint(margin, y) toView:content];
    self.inputDirField = [self addPathField:NSMakeRect(fieldX, y, 620, 24) toView:content tag:2];
    [self addButton:@"Browse..." at:NSMakePoint(fieldX + 630, y) action:@selector(browseInputDirectory:) toView:content];

    // Output row
    y -= 34;
    [self addLabel:@"Output:" at:NSMakePoint(margin, y) toView:content];
    self.outputDirField = [self addPathField:NSMakeRect(fieldX, y, 620, 24) toView:content tag:3];
    self.outputBrowseButton = [self addButton:@"Browse..." at:NSMakePoint(fieldX + 630, y) action:@selector(browseOutputDirectory:) toView:content];

    // Normalize button + progress
    y -= 44;
    self.normalizeButton = [[NSButton alloc] initWithFrame:NSMakeRect(margin, y, 120, 32)];
    self.normalizeButton.title = @"Normalize";
    self.normalizeButton.bezelStyle = NSBezelStyleRounded;
    self.normalizeButton.target = self;
    self.normalizeButton.action = @selector(toggleNormalization:);
    self.normalizeButton.enabled = NO;
    [content addSubview:self.normalizeButton];

    self.progressLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(560, y + 6, 240, 20)];
    self.progressLabel.editable = NO;
    self.progressLabel.bordered = NO;
    self.progressLabel.backgroundColor = [NSColor clearColor];
    self.progressLabel.alignment = NSTextAlignmentRight;
    self.progressLabel.stringValue = @"";
    [content addSubview:self.progressLabel];

    y -= 20;
    self.progressBar = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(margin, y, 770, 6)];
    self.progressBar.style = NSProgressIndicatorStyleBar;
    self.progressBar.indeterminate = NO;
    self.progressBar.minValue = 0;
    self.progressBar.doubleValue = 0;
    self.progressBar.hidden = YES;
    [content addSubview:self.progressBar];

    // Table view
    y -= 14;
    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(margin, 40, 770, y)];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.tableView = [[NSTableView alloc] initWithFrame:self.scrollView.bounds];
    self.tableView.headerView = [[NSTableHeaderView alloc] init];
    self.tableView.usesAlternatingRowBackgroundColors = YES;

    NSTableColumn *fileCol = [[NSTableColumn alloc] initWithIdentifier:@"file"];
    fileCol.title = @"File";
    fileCol.width = 300;
    [self.tableView addTableColumn:fileCol];

    NSTableColumn *statusCol = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusCol.title = @"Status";
    statusCol.width = 100;
    [self.tableView addTableColumn:statusCol];

    NSTableColumn *timeCol = [[NSTableColumn alloc] initWithIdentifier:@"totalTime"];
    timeCol.title = @"Time";
    timeCol.width = 80;
    [self.tableView addTableColumn:timeCol];

    self.tableView.dataSource = self.dataSource;
    self.tableView.delegate = self.dataSource;
    self.scrollView.documentView = self.tableView;
    [content addSubview:self.scrollView];

    // Summary bar
    self.summaryLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, 10, 770, 20)];
    self.summaryLabel.editable = NO;
    self.summaryLabel.bordered = NO;
    self.summaryLabel.backgroundColor = [NSColor clearColor];
    self.summaryLabel.stringValue = @"";
    [content addSubview:self.summaryLabel];

    // Register drag-and-drop on path fields
    [self.baseTIFFField registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    [self.inputDirField registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    [self.outputDirField registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
}

- (NSTextField *)addPathField:(NSRect)frame toView:(NSView *)view tag:(NSInteger)tag {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.editable = NO;
    field.selectable = YES;
    field.placeholderString = @"No selection";
    field.tag = tag;
    [view addSubview:field];
    return field;
}

- (void)addLabel:(NSString *)text at:(NSPoint)pt toView:(NSView *)view {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 80, 20)];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.alignment = NSTextAlignmentRight;
    [view addSubview:label];
}

- (NSButton *)addButton:(NSString *)title at:(NSPoint)pt action:(SEL)action toView:(NSView *)view {
    NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 80, 24)];
    btn.title = title;
    btn.bezelStyle = NSBezelStyleRounded;
    btn.target = self;
    btn.action = action;
    [view addSubview:btn];
    return btn;
}

#pragma mark - Notifications

- (void)setupNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(processingDidStart:) name:TFNProcessingDidStartNotification object:nil];
    [nc addObserver:self selector:@selector(processingFileDidUpdate:) name:TFNProcessingFileDidUpdateNotification object:nil];
    [nc addObserver:self selector:@selector(processingDidFinish:) name:TFNProcessingDidFinishNotification object:nil];

    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kInPlaceKey
                                               options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:kInPlaceKey]) {
        [self updateInPlaceState];
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

        // Auto-populate output directory
        if (self.outputDirField.stringValue.length == 0) {
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

- (void)showFatalError:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = @"Cannot Start Normalization";
    alert.informativeText = message;
    [alert runModal];
}

@end
