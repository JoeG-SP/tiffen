#import <Cocoa/Cocoa.h>
#import "TFNProcessedFileInfo.h"

@interface TFNFileListDataSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSArray<TFNProcessedFileInfo *> *files;
@property (nonatomic, copy, nullable) void (^onRowSelected)(TFNProcessedFileInfo *info, NSRect rowRect);

/// Sort files using the table view's current sort descriptors.
- (void)sortWithDescriptors:(NSArray<NSSortDescriptor *> *)descriptors;

@end
