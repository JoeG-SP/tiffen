#import <Foundation/Foundation.h>
#import "TFNProcessedFileInfo.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const TFNProcessingDidStartNotification;
extern NSNotificationName const TFNProcessingFileDidUpdateNotification;
extern NSNotificationName const TFNProcessingDidFinishNotification;

extern NSString *const TFNFileInfoKey;
extern NSString *const TFNFileIndexKey;

/// Wraps TFNNormalizer for UI use. Posts notifications on the main queue
/// as files progress through normalization.
@interface TFNProcessingEngine : NSObject

@property (nonatomic, copy, nullable) NSString *baseTIFFPath;
@property (nonatomic, copy, nullable) NSString *inputDirectory;
@property (nonatomic, copy, nullable) NSString *outputDirectory;
@property (nonatomic, readonly) NSArray<TFNProcessedFileInfo *> *files;
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) NSUInteger totalFiles;
@property (nonatomic, readonly) NSUInteger completedFiles;
@property (nonatomic, readonly, nullable) NSDate *startTime;
@property (nonatomic, readonly) BOOL inPlace;

// Cumulative timing
@property (nonatomic, readonly) NSTimeInterval cumulativeReadTime;
@property (nonatomic, readonly) NSTimeInterval cumulativeRangeTime;
@property (nonatomic, readonly) NSTimeInterval cumulativeNormalizeTime;
@property (nonatomic, readonly) NSTimeInterval cumulativeWriteTime;
@property (nonatomic, readonly) NSTimeInterval wallClockTime;

/// Start normalization. Reads concurrency settings from NSUserDefaults.
/// Posts TFNProcessingDidStartNotification, per-file updates, then finish.
- (void)start;

/// Cancel in-progress normalization. In-flight files complete but no new
/// files are dispatched.
- (void)cancel;

/// List of output file paths written during this batch (for cancellation cleanup).
@property (nonatomic, readonly) NSArray<NSString *> *writtenOutputPaths;

@end

NS_ASSUME_NONNULL_END
