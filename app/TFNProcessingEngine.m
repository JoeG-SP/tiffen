#import "TFNProcessingEngine.h"
#import "TFNNormalizer.h"
#import "TFNTIFFReader.h"
#import "TFNTIFFWriter.h"
#import "TFNExposureRange.h"
#import "TFNCPUNormalizer.h"
#import "TFNMetalNormalizer.h"
#import "TFNHistogramData.h"
#import <QuartzCore/CABase.h>

NSNotificationName const TFNProcessingDidStartNotification = @"TFNProcessingDidStart";
NSNotificationName const TFNProcessingFileDidUpdateNotification = @"TFNProcessingFileDidUpdate";
NSNotificationName const TFNProcessingDidFinishNotification = @"TFNProcessingDidFinish";

NSString *const TFNFileInfoKey = @"TFNFileInfo";
NSString *const TFNFileIndexKey = @"TFNFileIndex";

@implementation TFNProcessingEngine {
    NSMutableArray<TFNProcessedFileInfo *> *_files;
    NSMutableArray<NSString *> *_writtenOutputPaths;
    BOOL _cancelled;
    NSLock *_lock;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _files = [NSMutableArray array];
        _writtenOutputPaths = [NSMutableArray array];
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (NSArray<TFNProcessedFileInfo *> *)files {
    return [_files copy];
}

- (NSArray<NSString *> *)writtenOutputPaths {
    return [_writtenOutputPaths copy];
}

- (void)start {
    if (_isRunning) return;
    _isRunning = YES;
    _cancelled = NO;
    _startTime = [NSDate date];
    _completedFiles = 0;
    _cumulativeReadTime = 0;
    _cumulativeRangeTime = 0;
    _cumulativeNormalizeTime = 0;
    _cumulativeWriteTime = 0;
    [_files removeAllObjects];
    [_writtenOutputPaths removeAllObjects];

    // Read settings from NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger cpuPct = [defaults integerForKey:@"TFNCPUPercent"];
    NSInteger memPct = [defaults integerForKey:@"TFNMemPercent"];
    NSInteger maxJobs = [defaults integerForKey:@"TFNMaxJobs"];
    BOOL inPlace = [defaults boolForKey:@"TFNInPlace"];
    _inPlace = inPlace;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self runWithCPUPercent:cpuPct memPercent:memPct maxJobs:maxJobs inPlace:inPlace];
    });
}

- (void)cancel {
    _cancelled = YES;
}

- (void)runWithCPUPercent:(NSInteger)cpuPct
               memPercent:(NSInteger)memPct
                  maxJobs:(NSInteger)maxJobs
                  inPlace:(BOOL)inPlace {

    NSFileManager *fm = [NSFileManager defaultManager];

    // Validate inputs
    if (!self.baseTIFFPath || !self.inputDirectory) {
        [self finishWithError:@"Base TIFF or input directory not set"];
        return;
    }

    // Read base TIFF
    NSError *readError = nil;
    TFNTIFFImage *baseImage = [TFNTIFFReader readTIFFAtPath:self.baseTIFFPath error:&readError];
    if (!baseImage) {
        [self finishWithError:[NSString stringWithFormat:@"Cannot read base TIFF: %@",
                               readError.localizedDescription]];
        return;
    }

    // Initialize Metal
    TFNMetalNormalizer *metalNorm = [[TFNMetalNormalizer alloc] init];
    BOOL useMetal = (metalNorm != nil);

    // Compute base range
    TFNExposureRange *baseRange = nil;
    if (useMetal) {
        baseRange = [metalNorm computeExposureRangeForImage:baseImage error:nil];
    }
    if (!baseRange) {
        [baseImage computeExposureRange];
        baseRange = baseImage.exposureRange;
    }

    // Enumerate TIFF files
    NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:self.inputDirectory error:nil];
    NSString *baseRealPath = [self.baseTIFFPath stringByResolvingSymlinksInPath];

    for (NSString *filename in contents) {
        NSString *fullPath = [self.inputDirectory stringByAppendingPathComponent:filename];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (isDir) continue;

        if (![TFNTIFFReader isTIFFFile:filename]) continue;

        NSString *realPath = [fullPath stringByResolvingSymlinksInPath];
        if ([realPath isEqualToString:baseRealPath]) continue;

        TFNProcessedFileInfo *info = [[TFNProcessedFileInfo alloc] initWithFilePath:fullPath];
        [_files addObject:info];
    }

    _totalFiles = _files.count;

    // Determine output directory
    NSString *outputDir = nil;
    if (!inPlace) {
        outputDir = self.outputDirectory ?: [self.inputDirectory stringByAppendingPathComponent:@"normalized"];
        if (![fm fileExistsAtPath:outputDir]) {
            [fm createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        // Copy base file
        NSString *baseDst = [outputDir stringByAppendingPathComponent:self.baseTIFFPath.lastPathComponent];
        [fm copyItemAtPath:self.baseTIFFPath toPath:baseDst error:nil];
    }

    // Post start notification
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:TFNProcessingDidStartNotification
                                                            object:self];
    });

    if (_files.count == 0) {
        [self finishWithError:nil];
        return;
    }

    // Compute concurrency
    NSUInteger cpuCores = NSProcessInfo.processInfo.processorCount;
    NSUInteger memGB = (NSUInteger)(NSProcessInfo.processInfo.physicalMemory / (1024ULL * 1024 * 1024));
    double cpuFrac = (cpuPct > 0 && cpuPct <= 100) ? cpuPct / 100.0 : 0.9;
    double memFrac = (memPct > 0 && memPct <= 100) ? memPct / 100.0 : 0.9;
    NSUInteger maxConcurrent = MIN((NSUInteger)(cpuCores * cpuFrac), (NSUInteger)(memGB * memFrac));
    if (maxJobs > 0) maxConcurrent = MIN(maxConcurrent, (NSUInteger)maxJobs);
    if (maxConcurrent < 1) maxConcurrent = 1;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(maxConcurrent);
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_queue_create("com.tiffen.app.normalize", DISPATCH_QUEUE_CONCURRENT);

    CFTimeInterval batchStart = CACurrentMediaTime();

    for (NSUInteger i = 0; i < _files.count; i++) {
        if (_cancelled) break;

        TFNProcessedFileInfo *info = _files[i];
        NSUInteger fileIndex = i;

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        dispatch_group_async(group, queue, ^{
            @autoreleasepool {
                if (self->_cancelled) {
                    dispatch_semaphore_signal(semaphore);
                    return;
                }

                info.status = TFNProcessingStatusProcessing;
                [self postFileUpdate:info atIndex:fileIndex];

                // Read
                CFTimeInterval t0 = CACurrentMediaTime();
                NSError *fileError = nil;
                TFNTIFFImage *image = [TFNTIFFReader readTIFFAtPath:info.filePath error:&fileError];
                info.readTime = CACurrentMediaTime() - t0;

                if (!image) {
                    info.status = TFNProcessingStatusError;
                    info.errorMessage = fileError.localizedDescription;
                    [self incrementCompleted:info];
                    [self postFileUpdate:info atIndex:fileIndex];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }

                info.bitDepth = image.bitDepth;
                info.channelCount = image.channelCount;
                info.isFloat = image.isFloat;

                // Range
                CFTimeInterval t1 = CACurrentMediaTime();
                TFNExposureRange *targetRange = nil;
                if (useMetal) {
                    targetRange = [metalNorm computeExposureRangeForImage:image error:nil];
                    info.beforeHistogram = metalNorm.beforeHistogram;
                }
                if (!targetRange) {
                    [image computeExposureRange];
                    targetRange = image.exposureRange;
                    info.beforeHistogram = [TFNCPUNormalizer computeHistogramForPixelData:image.pixelData
                                                                              pixelCount:image.width * image.height
                                                                            channelCount:image.channelCount
                                                                                bitDepth:image.bitDepth
                                                                                 isFloat:image.isFloat
                                                                                   range:targetRange];
                }
                info.rangeTime = CACurrentMediaTime() - t1;
                info.sourceRange = targetRange;

                // Params
                TFNNormalizationParams *params = [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                                                 sourceRange:targetRange];
                // Flat exposure warnings
                for (NSUInteger c = 0; c < params.channelCount; c++) {
                    if (params.scale[c] == 0.0f) {
                        info.warningMessage = [NSString stringWithFormat:
                            @"channel %lu has flat exposure (mapped to base_min)", (unsigned long)c];
                    }
                }

                // Normalize
                CFTimeInterval t2 = CACurrentMediaTime();
                BOOL normalizeOK;
                if (useMetal) {
                    normalizeOK = [metalNorm normalizeImage:image withParams:params error:&fileError];
                    info.afterHistogram = metalNorm.afterHistogram;
                } else {
                    [TFNCPUNormalizer normalizePixelData:image.pixelData
                                             pixelCount:image.width * image.height
                                           channelCount:image.channelCount
                                               bitDepth:image.bitDepth
                                                isFloat:image.isFloat
                                                 params:params];
                    normalizeOK = YES;
                }
                info.normalizeTime = CACurrentMediaTime() - t2;

                if (!normalizeOK) {
                    info.status = TFNProcessingStatusError;
                    info.errorMessage = fileError.localizedDescription;
                    [self incrementCompleted:info];
                    [self postFileUpdate:info atIndex:fileIndex];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }

                // Compute after histogram for CPU path
                if (!useMetal) {
                    // Compute normalized range for after histogram
                    TFNExposureRange *normRange = baseRange; // Output is in base range
                    info.afterHistogram = [TFNCPUNormalizer computeHistogramForPixelData:image.pixelData
                                                                             pixelCount:image.width * image.height
                                                                           channelCount:image.channelCount
                                                                               bitDepth:image.bitDepth
                                                                                isFloat:image.isFloat
                                                                                  range:normRange];
                }
                info.normalizedRange = baseRange;

                // Write
                CFTimeInterval t3 = CACurrentMediaTime();
                NSString *writePath;
                if (inPlace) {
                    writePath = info.filePath;
                } else {
                    writePath = [outputDir stringByAppendingPathComponent:info.fileName];
                }

                NSError *writeError = nil;
                BOOL writeOK = [TFNTIFFWriter writeImage:image toPath:writePath error:&writeError];
                info.writeTime = CACurrentMediaTime() - t3;

                if (!writeOK) {
                    info.status = TFNProcessingStatusError;
                    info.errorMessage = writeError.localizedDescription;
                } else {
                    info.status = TFNProcessingStatusCompleted;
                    info.totalTime = info.readTime + info.rangeTime + info.normalizeTime + info.writeTime;
                    [self->_lock lock];
                    [self->_writtenOutputPaths addObject:writePath];
                    [self->_lock unlock];
                }

                [self incrementCompleted:info];
                [self postFileUpdate:info atIndex:fileIndex];
                dispatch_semaphore_signal(semaphore);
            }
        });
    }

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    _wallClockTime = CACurrentMediaTime() - batchStart;

    [self finishWithError:nil];
}

- (void)incrementCompleted:(TFNProcessedFileInfo *)info {
    [_lock lock];
    _completedFiles++;
    if (info.readTime >= 0) _cumulativeReadTime += info.readTime;
    if (info.rangeTime >= 0) _cumulativeRangeTime += info.rangeTime;
    if (info.normalizeTime >= 0) _cumulativeNormalizeTime += info.normalizeTime;
    if (info.writeTime >= 0) _cumulativeWriteTime += info.writeTime;
    [_lock unlock];
}

- (void)postFileUpdate:(TFNProcessedFileInfo *)info atIndex:(NSUInteger)index {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:TFNProcessingFileDidUpdateNotification
                                                            object:self
                                                          userInfo:@{
            TFNFileInfoKey: info,
            TFNFileIndexKey: @(index)
        }];
    });
}

- (void)finishWithError:(nullable NSString *)error {
    _isRunning = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        if (error) userInfo[@"error"] = error;
        [[NSNotificationCenter defaultCenter] postNotificationName:TFNProcessingDidFinishNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
}

@end
