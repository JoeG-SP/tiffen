#import "TFNNormalizer.h"
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

    for (NSUInteger i = 0; i < tiffFiles.count; i++) {
        NSString *filePath = tiffFiles[i];
        NSString *filename = filePath.lastPathComponent;

        // Read target TIFF
        NSError *fileError = nil;
        TFNTIFFImage *targetImage = [TFNTIFFReader readTIFFAtPath:filePath error:&fileError];
        if (!targetImage) {
            NSString *errMsg = [NSString stringWithFormat:@"%@: %@",
                                filename, fileError.localizedDescription];
            fprintf(stderr, "Error: %s (skipping)\n", errMsg.UTF8String);
            [result.errors addObject:errMsg];
            result.filesErrored++;
            continue;
        }

        // Compute target exposure range (GPU if available, CPU fallback)
        TFNExposureRange *targetRange = nil;
        if (useMetal) {
            targetRange = [metalNorm computeExposureRangeForImage:targetImage error:nil];
        }
        if (!targetRange) {
            [targetImage computeExposureRange];
            targetRange = targetImage.exposureRange;
        }

        // Compute normalization params (handles flat exposure: scale=0, offset=base_min)
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
                [result.warnings addObject:warning];
            }
        }

        // Normalize
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

        if (!normalizeOK) {
            NSString *errMsg = [NSString stringWithFormat:@"%@: normalization failed: %@",
                                filename, fileError.localizedDescription];
            fprintf(stderr, "Error: %s (skipping)\n", errMsg.UTF8String);
            [result.errors addObject:errMsg];
            result.filesErrored++;
            continue;
        }

        // Write output
        NSString *writePath;
        if (self.outputMode == TFNOutputModeInPlace) {
            writePath = filePath;
        } else {
            writePath = [outputDir stringByAppendingPathComponent:filename];
        }

        NSError *writeError = nil;
        if (![TFNTIFFWriter writeImage:targetImage toPath:writePath error:&writeError]) {
            NSString *errMsg = [NSString stringWithFormat:@"%@: write failed: %@",
                                filename, writeError.localizedDescription];
            fprintf(stderr, "Error: %s (skipping)\n", errMsg.UTF8String);
            [result.errors addObject:errMsg];
            result.filesErrored++;
            continue;
        }

        result.filesNormalized++;

        if (self.verbosity != TFNVerbosityQuiet) {
            if (self.outputMode == TFNOutputModeInPlace) {
                fprintf(stdout, "  [%lu/%lu] %s (overwritten)\n",
                        (unsigned long)(i + 1), (unsigned long)tiffFiles.count,
                        filename.UTF8String);
            } else {
                fprintf(stdout, "  [%lu/%lu] %s → %s/%s\n",
                        (unsigned long)(i + 1), (unsigned long)tiffFiles.count,
                        filename.UTF8String,
                        outputDir.lastPathComponent.UTF8String,
                        filename.UTF8String);
            }
        }
    }

    // Summary
    if (self.verbosity != TFNVerbosityQuiet) {
        fprintf(stdout, "\nDone: %lu normalized, %lu errors, %lu skipped\n",
                (unsigned long)result.filesNormalized,
                (unsigned long)result.filesErrored,
                (unsigned long)result.filesSkipped);
    }

    return result;
}

@end
