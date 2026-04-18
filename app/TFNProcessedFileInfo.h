#import <Foundation/Foundation.h>

@class TFNExposureRange;
@class TFNHistogramData;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TFNProcessingStatus) {
    TFNProcessingStatusPending,
    TFNProcessingStatusProcessing,
    TFNProcessingStatusCompleted,
    TFNProcessingStatusError,
    TFNProcessingStatusSkipped,
    TFNProcessingStatusBase       // Base reference file (copied as-is)
};

/// Per-file processing result displayed in the file list.
@interface TFNProcessedFileInfo : NSObject

@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic) TFNProcessingStatus status;

@property (nonatomic) NSTimeInterval readTime;
@property (nonatomic) NSTimeInterval rangeTime;
@property (nonatomic) NSTimeInterval normalizeTime;
@property (nonatomic) NSTimeInterval writeTime;
@property (nonatomic) NSTimeInterval totalTime;

@property (nonatomic, copy, nullable) NSString *errorMessage;
@property (nonatomic, copy, nullable) NSString *warningMessage;

@property (nonatomic, strong, nullable) TFNExposureRange *sourceRange;
@property (nonatomic, strong, nullable) TFNExposureRange *normalizedRange;
@property (nonatomic, strong, nullable) TFNHistogramData *beforeHistogram;
@property (nonatomic, strong, nullable) TFNHistogramData *afterHistogram;

@property (nonatomic) NSUInteger bitDepth;
@property (nonatomic) NSUInteger channelCount;
@property (nonatomic) BOOL isFloat;

- (instancetype)initWithFilePath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
