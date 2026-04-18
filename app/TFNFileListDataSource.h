#import <Cocoa/Cocoa.h>
#import "TFNProcessedFileInfo.h"

@interface TFNFileListDataSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSArray<TFNProcessedFileInfo *> *files;

@end
