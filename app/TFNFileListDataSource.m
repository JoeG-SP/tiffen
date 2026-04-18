#import "TFNFileListDataSource.h"

@implementation TFNFileListDataSource {
    NSMutableArray<TFNProcessedFileInfo *> *_sortedFiles;
}

- (void)setFiles:(NSArray<TFNProcessedFileInfo *> *)files {
    _files = files;
    _sortedFiles = [files mutableCopy];
}

- (void)sortWithDescriptors:(NSArray<NSSortDescriptor *> *)descriptors {
    if (!descriptors.count || !_sortedFiles.count) return;

    [_sortedFiles sortUsingComparator:^NSComparisonResult(TFNProcessedFileInfo *a, TFNProcessedFileInfo *b) {
        for (NSSortDescriptor *desc in descriptors) {
            NSString *key = desc.key;
            NSComparisonResult result = NSOrderedSame;

            if ([key isEqualToString:@"file"]) {
                result = [a.fileName localizedCaseInsensitiveCompare:b.fileName];
            } else if ([key isEqualToString:@"status"]) {
                result = [@(a.status) compare:@(b.status)];
            } else if ([key isEqualToString:@"totalTime"]) {
                result = [@(a.totalTime) compare:@(b.totalTime)];
            } else if ([key isEqualToString:@"readTime"]) {
                result = [@(a.readTime) compare:@(b.readTime)];
            } else if ([key isEqualToString:@"rangeTime"]) {
                result = [@(a.rangeTime) compare:@(b.rangeTime)];
            } else if ([key isEqualToString:@"normalizeTime"]) {
                result = [@(a.normalizeTime) compare:@(b.normalizeTime)];
            } else if ([key isEqualToString:@"writeTime"]) {
                result = [@(a.writeTime) compare:@(b.writeTime)];
            }

            if (!desc.ascending) {
                result = -result;
            }
            if (result != NSOrderedSame) return result;
        }
        return NSOrderedSame;
    }];
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    [self sortWithDescriptors:tableView.sortDescriptors];
    [tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)(_sortedFiles ? _sortedFiles.count : self.files.count);
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *source = _sortedFiles ?: self.files;
    if (row < 0 || (NSUInteger)row >= source.count) return nil;

    TFNProcessedFileInfo *info = source[row];
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
            case TFNProcessingStatusBase:
                cell.stringValue = @"\u2605 Base";
                cell.toolTip = @"Reference file (copied as-is)";
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

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tv = notification.object;
    NSInteger row = tv.selectedRow;
    if (row < 0) return;

    NSArray *source = _sortedFiles ?: self.files;
    if ((NSUInteger)row >= source.count) return;

    TFNProcessedFileInfo *info = source[row];
    if (info.status != TFNProcessingStatusCompleted && info.status != TFNProcessingStatusBase) return;
    if (!self.onRowSelected) return;

    NSRect rowRect = [tv rectOfRow:row];
    NSRect visibleRect = [tv convertRect:rowRect toView:nil];
    self.onRowSelected(info, visibleRect);
}

@end
