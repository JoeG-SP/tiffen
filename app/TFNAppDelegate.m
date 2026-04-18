#import "TFNAppDelegate.h"
#import "TFNMainWindowController.h"

@implementation TFNAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Register default preferences
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"TFNLastBaseTIFFPath": @"",
        @"TFNLastInputDirectory": @"",
        @"TFNLastOutputDirectory": @"",
        @"TFNCPUPercent": @90,
        @"TFNMemPercent": @90,
        @"TFNMaxJobs": @0,
        @"TFNInPlace": @NO,
        @"TFNShowPerFileTiming": @YES
    }];

    self.mainWindowController = [[TFNMainWindowController alloc] init];
    [self.mainWindowController showWindow:nil];

    [self setupMenu];
}

- (void)setupMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    // App menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Tiffen"];
    [appMenu addItemWithTitle:@"About Tiffen" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings..."
                                                          action:@selector(openPreferences:)
                                                   keyEquivalent:@","];
    settingsItem.target = self;
    [appMenu addItem:settingsItem];

    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit Tiffen" action:@selector(terminate:) keyEquivalent:@"q"];
    appMenuItem.submenu = appMenu;
    [mainMenu addItem:appMenuItem];

    // File menu
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];

    NSMenuItem *openBase = [[NSMenuItem alloc] initWithTitle:@"Open Base TIFF..."
                                                      action:@selector(browseBaseTIFF:)
                                               keyEquivalent:@"o"];
    openBase.target = self.mainWindowController;
    [fileMenu addItem:openBase];

    NSMenuItem *openInput = [[NSMenuItem alloc] initWithTitle:@"Open Input Directory..."
                                                       action:@selector(browseInputDirectory:)
                                                keyEquivalent:@"O"];
    openInput.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    openInput.target = self.mainWindowController;
    [fileMenu addItem:openInput];

    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    fileMenuItem.submenu = fileMenu;
    [mainMenu addItem:fileMenuItem];

    // Processing menu
    NSMenuItem *procMenuItem = [[NSMenuItem alloc] init];
    NSMenu *procMenu = [[NSMenu alloc] initWithTitle:@"Processing"];

    NSMenuItem *startItem = [[NSMenuItem alloc] initWithTitle:@"Start Normalization"
                                                       action:@selector(toggleNormalization:)
                                                keyEquivalent:@"r"];
    startItem.target = self.mainWindowController;
    [procMenu addItem:startItem];

    NSMenuItem *stopItem = [[NSMenuItem alloc] initWithTitle:@"Stop Normalization"
                                                      action:@selector(stopNormalization:)
                                               keyEquivalent:@"."];
    stopItem.target = self.mainWindowController;
    [procMenu addItem:stopItem];

    procMenuItem.submenu = procMenu;
    [mainMenu addItem:procMenuItem];

    [NSApp setMainMenu:mainMenu];
}

- (void)openPreferences:(id)sender {
    // Preferences window will be implemented in Phase 4 (US2)
    // For now, this is a placeholder
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
