#import "TFNNormalizer.h"
#import <QuartzCore/CABase.h>
#import "TFNTIFFReader.h"
#import "TFNTIFFWriter.h"
#import "TFNExposureRange.h"
#import "TFNCPUNormalizer.h"
#import "TFNMetalNormalizer.h"

NSString *const TFNNormalizerErrorDomain = @"TFNNormalizerErrorDomain";

@implementation TFNNormalizationResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _errors = [NSMutableArray array];
        _warnings = [NSMutableArray array];
    }
    return self;
}

@end

@implementation TFNNormalizer

- (nullable TFNNormalizationResult *)normalizeDirectory:(NSString *)inputDirectory
                                           withBaseTIFF:(NSString *)baseTIFFPath
                                                  error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    // Validate base TIFF exists
    if (![fm fileExistsAtPath:baseTIFFPath]) {
        if (error) {
            *error = [NSError errorWithDomain:TFNNormalizerErrorDomain code:2
                        userInfo:@{NSLocalizedDescriptionKey:
                            [NSString stringWithFormat:@"Base TIFF not found: %@", baseTIFFPath]}];
        }
        return nil;
    }

    // Validate input directory exists
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:inputDirectory isDirectory:&isDir] || !isDir) {
        if (error) {
            *error = [NSError errorWithDomain:TFNNormalizerErrorDomain code:2
                        userInfo:@{NSLocalizedDescriptionKey:
                            [NSString stringWithFormat:@"Not a directory: %@", inputDirectory]}];
        }
        return nil;
    }

    // Read base TIFF
    NSError *readError = nil;
    TFNTIFFImage *baseImage = [TFNTIFFReader readTIFFAtPath:baseTIFFPath error:&readError];
    if (!baseImage) {
        if (error) {
            *error = [NSError errorWithDomain:TFNNormalizerErrorDomain code:2
                        userInfo:@{NSLocalizedDescriptionKey:
                            [NSString stringWithFormat:@"Cannot read base TIFF: %@",
                             readError.localizedDescription]}];
        }
        return nil;
    }

    // Initialize Metal normalizer early — needed for GPU range computation
    TFNMetalNormalizer *metalNorm = [[TFNMetalNormalizer alloc] init];
    BOOL useMetal = (metalNorm != nil);

    if (self.verbosity == TFNVerbosityVerbose) {
        fprintf(stdout, "Metal GPU: %s\n", useMetal ? "available" : "not available (CPU fallback)");
    }

    // Compute base exposure range (GPU if available, CPU fallback)
    TFNExposureRange *baseRange = nil;
    if (useMetal) {
        baseRange = [metalNorm computeExposureRangeForImage:baseImage error:nil];
    }
    if (!baseRange) {
        [baseImage computeExposureRange];
        baseRange = baseImage.exposureRange;
    }

    // Enumerate TIFF files in directory
    NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:inputDirectory error:nil];
    NSString *baseRealPath = [baseTIFFPath stringByResolvingSymlinksInPath];

    NSMutableArray<NSString *> *tiffFiles = [NSMutableArray array];
    NSUInteger skippedNonTIFF = 0;

    for (NSString *filename in contents) {
        NSString *fullPath = [inputDirectory stringByAppendingPathComponent:filename];

        // Skip directories
        BOOL isSubDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isSubDir];
        if (isSubDir) continue;

        if (![TFNTIFFReader isTIFFFile:filename]) {
            skippedNonTIFF++;
            continue;
        }

        // Skip the base TIFF if it's in the input directory
        NSString *realPath = [fullPath stringByResolvingSymlinksInPath];
        if ([realPath isEqualToString:baseRealPath]) {
            continue;
        }

        [tiffFiles addObject:fullPath];
    }

    // Determine output directory
    NSString *outputDir = nil;
    if (self.outputMode == TFNOutputModeDirectory) {
        outputDir = self.outputDirectory ?: [inputDirectory stringByAppendingPathComponent:@"normalized"];
        if (![fm fileExistsAtPath:outputDir]) {
            NSError *mkdirError = nil;
            [fm createDirectoryAtPath:outputDir withIntermediateDirectories:YES
                           attributes:nil error:&mkdirError];
            if (mkdirError) {
                if (error) {
                    *error = [NSError errorWithDomain:TFNNormalizerErrorDomain code:2
                                userInfo:@{NSLocalizedDescriptionKey:
                                    [NSString stringWithFormat:@"Cannot create output directory: %@",
                                     mkdirError.localizedDescription]}];
                }
                return nil;
            }
        }
    }

    // Copy base file into output directory (not needed for in-place mode)
    if (self.outputMode == TFNOutputModeDirectory) {
        NSString *baseDst = [outputDir stringByAppendingPathComponent:
            baseTIFFPath.lastPathComponent];
        NSError *copyError = nil;
        if (![fm copyItemAtPath:baseTIFFPath toPath:baseDst error:&copyError]) {
            if (error) {
                *error = [NSError errorWithDomain:TFNNormalizerErrorDomain code:2
                            userInfo:@{NSLocalizedDescriptionKey:
                                [NSString stringWithFormat:@"Cannot copy base TIFF: %@",
                                 copyError.localizedDescription]}];
            }
            return nil;
        }
    }

    TFNNormalizationResult *result = [[TFNNormalizationResult alloc] init];
    result.filesSkipped = skippedNonTIFF;

    if (tiffFiles.count == 0) {
        if (self.verbosity != TFNVerbosityQuiet) {
            fprintf(stdout, "No TIFF files to process\n");
        }
        return result;
    }

    if (self.verbosity != TFNVerbosityQuiet) {
        NSString *modeStr = (self.outputMode == TFNOutputModeInPlace) ? @"in-place" : @"";
        fprintf(stdout, "Normalizing %lu files to match base: %s%s\n",
                (unsigned long)tiffFiles.count,
                baseTIFFPath.lastPathComponent.UTF8String,
                modeStr.length > 0 ? [NSString stringWithFormat:@" (%@)", modeStr].UTF8String : "");
    }

    // Aggregate timing accumulators (atomic via lock)
    __block CFTimeInterval totalRead = 0, totalRange = 0, totalNormalize = 0, totalWrite = 0;
    CFTimeInterval batchStart = CACurrentMediaTime();
    __block NSUInteger completedCount = 0;
    NSLock *resultLock = [[NSLock alloc] init];

    // Process files concurrently using GCD
    NSUInteger cpuCores = NSProcessInfo.processInfo.processorCount;
    NSUInteger memGB = (NSUInteger)(NSProcessInfo.processInfo.physicalMemory / (1024ULL * 1024 * 1024));
    double cpuPct = self.cpuPercent > 0.0 ? self.cpuPercent : 0.9;
    double memPct = self.memPercent > 0.0 ? self.memPercent : 0.9;
    NSUInteger memPerFile = self.memPerFileGB > 0 ? self.memPerFileGB : 1;
    NSUInteger cpuLimit = (NSUInteger)(cpuCores * cpuPct);
    NSUInteger memLimit = (NSUInteger)((memGB * memPct) / memPerFile);
    NSUInteger maxConcurrent = MIN(cpuLimit, memLimit);
    if (self.maxJobs > 0) {
        maxConcurrent = MIN(maxConcurrent, self.maxJobs);
    }
    if (maxConcurrent < 1) maxConcurrent = 1;

    if (self.verbosity == TFNVerbosityVerbose) {
        fprintf(stdout, "Concurrency: %lu (CPU cores: %lu, RAM: %lu GB)\n",
                (unsigned long)maxConcurrent,
                (unsigned long)cpuCores,
                (unsigned long)memGB);
    }
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(maxConcurrent);
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_queue_create("com.tiffen.normalize",
                                                    DISPATCH_QUEUE_CONCURRENT);

    for (NSUInteger i = 0; i < tiffFiles.count; i++) {
        NSString *filePath = tiffFiles[i];

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        dispatch_group_async(group, queue, ^{
            @autoreleasepool {
                NSString *filename = filePath.lastPathComponent;

                // --- Read (includes decompression by libtiff) ---
                CFTimeInterval t0 = CACurrentMediaTime();
                NSError *fileError = nil;
                TFNTIFFImage *targetImage = [TFNTIFFReader readTIFFAtPath:filePath error:&fileError];
                CFTimeInterval readTime = CACurrentMediaTime() - t0;

                if (!targetImage) {
                    NSString *errMsg = [NSString stringWithFormat:@"%@: %@",
                                        filename, fileError.localizedDescription];
                    fprintf(stderr, "Error: %s (skipping)\n", errMsg.UTF8String);
                    [resultLock lock];
                    [result.errors addObject:errMsg];
                    result.filesErrored++;
                    totalRead += readTime;
                    [resultLock unlock];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }

                // --- Range computation (GPU parallel reduction) ---
                CFTimeInterval t1 = CACurrentMediaTime();
                TFNExposureRange *targetRange = nil;
                if (useMetal) {
                    targetRange = [metalNorm computeExposureRangeForImage:targetImage error:nil];
                }
                if (!targetRange) {
                    [targetImage computeExposureRange];
                    targetRange = targetImage.exposureRange;
                }
                CFTimeInterval rangeTime = CACurrentMediaTime() - t1;

                // Compute normalization params
                TFNNormalizationParams *params =
                    [TFNNormalizationParams paramsWithBaseRange:baseRange
                                                   sourceRange:targetRange];

                // Check for flat exposure warnings
                for (NSUInteger c = 0; c < params.channelCount; c++) {
                    if (params.scale[c] == 0.0f) {
                        NSString *warning = [NSString stringWithFormat:
                            @"%@: channel %lu has flat exposure (mapped to base_min)",
                            filename, (unsigned long)c];
                        fprintf(stderr, "Warning: %s\n", warning.UTF8String);
                        [resultLock lock];
                        [result.warnings addObject:warning];
                        [resultLock unlock];
                    }
                }

                // --- Normalize (GPU compute or CPU) ---
                CFTimeInterval t2 = CACurrentMediaTime();
                BOOL normalizeOK;
                if (useMetal) {
                    normalizeOK = [metalNorm normalizeImage:targetImage
                                                 withParams:params
                                                      error:&fileError];
                } else {
                    [TFNCPUNormalizer normalizePixelData:targetImage.pixelData
                                             pixelCount:targetImage.width * targetImage.height
                                           channelCount:targetImage.channelCount
                                               bitDepth:targetImage.bitDepth
                                                isFloat:targetImage.isFloat
                                                 params:params];
                    normalizeOK = YES;
                }
                CFTimeInterval normTime = CACurrentMediaTime() - t2;

                if (!normalizeOK) {
                    NSString *errMsg = [NSString stringWithFormat:@"%@: normalization failed: %@",
                                        filename, fileError.localizedDescription];
                    fprintf(stderr, "Error: %s (skipping)\n", errMsg.UTF8String);
                    [resultLock lock];
                    [result.errors addObject:errMsg];
                    result.filesErrored++;
                    totalRead += readTime;
                    totalRange += rangeTime;
                    totalNormalize += normTime;
                    [resultLock unlock];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }

                // --- Write (includes compression by libtiff) ---
                CFTimeInterval t3 = CACurrentMediaTime();
                NSString *writePath;
                if (self.outputMode == TFNOutputModeInPlace) {
                    writePath = filePath;
                } else {
                    writePath = [outputDir stringByAppendingPathComponent:filename];
                }

                NSError *writeError = nil;
                BOOL writeOK = [TFNTIFFWriter writeImage:targetImage toPath:writePath error:&writeError];
                CFTimeInterval writeTime = CACurrentMediaTime() - t3;

                [resultLock lock];
                totalRead += readTime;
                totalRange += rangeTime;
                totalNormalize += normTime;
                totalWrite += writeTime;

                if (!writeOK) {
                    NSString *errMsg = [NSString stringWithFormat:@"%@: write failed: %@",
                                        filename, writeError.localizedDescription];
                    fprintf(stderr, "Error: %s (skipping)\n", errMsg.UTF8String);
                    [result.errors addObject:errMsg];
                    result.filesErrored++;
                } else {
                    result.filesNormalized++;
                    completedCount++;

                    if (self.verbosity != TFNVerbosityQuiet) {
                        CFTimeInterval fileTotal = readTime + rangeTime + normTime + writeTime;
                        if (self.outputMode == TFNOutputModeInPlace) {
                            fprintf(stdout, "  [%lu/%lu] %s (overwritten)",
                                    (unsigned long)completedCount, (unsigned long)tiffFiles.count,
                                    filename.UTF8String);
                        } else {
                            fprintf(stdout, "  [%lu/%lu] %s → %s/%s",
                                    (unsigned long)completedCount, (unsigned long)tiffFiles.count,
                                    filename.UTF8String,
                                    outputDir.lastPathComponent.UTF8String,
                                    filename.UTF8String);
                        }
                        if (self.verbosity == TFNVerbosityVerbose) {
                            fprintf(stdout, "  (%.2fs: read %.2f, range %.3f, norm %.3f, write %.2f)",
                                    fileTotal, readTime, rangeTime, normTime, writeTime);
                        }
                        fprintf(stdout, "\n");
                    }
                }
                [resultLock unlock];

                dispatch_semaphore_signal(semaphore);
            }
        });
    }

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    CFTimeInterval batchTotal = CACurrentMediaTime() - batchStart;

    // Summary
    if (self.verbosity != TFNVerbosityQuiet) {
        fprintf(stdout, "\nDone: %lu normalized, %lu errors, %lu skipped\n",
                (unsigned long)result.filesNormalized,
                (unsigned long)result.filesErrored,
                (unsigned long)result.filesSkipped);
        fprintf(stdout, "\nTiming (cumulative across %lu concurrent workers):\n",
                (unsigned long)maxConcurrent);
        fprintf(stdout, "  Read/decompress:  %7.2fs  (%4.1f%%)\n",
                totalRead, totalRead / (totalRead + totalRange + totalNormalize + totalWrite) * 100);
        fprintf(stdout, "  Range (GPU):      %7.2fs  (%4.1f%%)\n",
                totalRange, totalRange / (totalRead + totalRange + totalNormalize + totalWrite) * 100);
        fprintf(stdout, "  Normalize (GPU):  %7.2fs  (%4.1f%%)\n",
                totalNormalize, totalNormalize / (totalRead + totalRange + totalNormalize + totalWrite) * 100);
        fprintf(stdout, "  Write/compress:   %7.2fs  (%4.1f%%)\n",
                totalWrite, totalWrite / (totalRead + totalRange + totalNormalize + totalWrite) * 100);
        fprintf(stdout, "  Wall clock:       %7.2fs\n", batchTotal);
        if (result.filesNormalized > 0) {
            fprintf(stdout, "  Avg per file:     %7.2fs  (wall: %.2fs)\n",
                    (totalRead + totalRange + totalNormalize + totalWrite) / result.filesNormalized,
                    batchTotal / result.filesNormalized);
        }
    }

    return result;
}

@end
