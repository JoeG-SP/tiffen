#import "TFNProcessedFileInfo.h"

@implementation TFNProcessedFileInfo

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super init];
    if (self) {
        _filePath = [filePath copy];
        _fileName = [filePath.lastPathComponent copy];
        _status = TFNProcessingStatusPending;
        _readTime = -1;
        _rangeTime = -1;
        _normalizeTime = -1;
        _writeTime = -1;
        _totalTime = -1;
    }
    return self;
}

@end
