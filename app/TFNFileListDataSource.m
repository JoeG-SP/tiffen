#import "TFNFileListDataSource.h"

@implementation TFNFileListDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)self.files.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || (NSUInteger)row >= self.files.count) return nil;

    TFNProcessedFileInfo *info = self.files[row];
    NSString *identifier = tableColumn.identifier;

    NSTextField *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cell) {
        cell = [[NSTextField alloc] init];
        cell.identifier = identifier;
        cell.editable = NO;
        cell.bordered = NO;
        cell.backgroundColor = [NSColor clearColor];
    }

    if ([identifier isEqualToString:@"file"]) {
        cell.stringValue = info.fileName;
        cell.toolTip = info.filePath;
    } else if ([identifier isEqualToString:@"status"]) {
        switch (info.status) {
            case TFNProcessingStatusPending:
                cell.stringValue = @"\u25CB Pending";
                break;
            case TFNProcessingStatusProcessing:
                cell.stringValue = @"\u27F3 Running";
                break;
            case TFNProcessingStatusCompleted:
                cell.stringValue = @"\u2713 Done";
                break;
            case TFNProcessingStatusError:
                cell.stringValue = @"\u2717 Error";
                cell.toolTip = info.errorMessage;
                break;
            case TFNProcessingStatusSkipped:
                cell.stringValue = @"- Skipped";
                break;
        }
        if (info.warningMessage) {
            cell.toolTip = info.warningMessage;
        }
    } else if ([identifier isEqualToString:@"totalTime"]) {
        if (info.totalTime >= 0) {
            cell.stringValue = [NSString stringWithFormat:@"%.2fs", info.totalTime];
        } else {
            cell.stringValue = @"—";
        }
    } else if ([identifier isEqualToString:@"readTime"]) {
        cell.stringValue = info.readTime >= 0 ? [NSString stringWithFormat:@"%.2fs", info.readTime] : @"—";
    } else if ([identifier isEqualToString:@"rangeTime"]) {
        cell.stringValue = info.rangeTime >= 0 ? [NSString stringWithFormat:@"%.3fs", info.rangeTime] : @"—";
    } else if ([identifier isEqualToString:@"normalizeTime"]) {
        cell.stringValue = info.normalizeTime >= 0 ? [NSString stringWithFormat:@"%.3fs", info.normalizeTime] : @"—";
    } else if ([identifier isEqualToString:@"writeTime"]) {
        cell.stringValue = info.writeTime >= 0 ? [NSString stringWithFormat:@"%.2fs", info.writeTime] : @"—";
    }

    return cell;
}

@end
