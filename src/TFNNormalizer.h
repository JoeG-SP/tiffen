#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TFNOutputMode) {
    TFNOutputModeDirectory,  // Write to output directory (default)
    TFNOutputModeInPlace     // Overwrite originals
};

typedef NS_ENUM(NSInteger, TFNVerbosity) {
    TFNVerbosityNormal,
    TFNVerbosityVerbose,
    TFNVerbosityQuiet
};

/// Result of a normalization run.
@interface TFNNormalizationResult : NSObject
@property (nonatomic) NSUInteger filesNormalized;
@property (nonatomic) NSUInteger filesSkipped;
@property (nonatomic) NSUInteger filesErrored;
@property (nonatomic, strong) NSMutableArray<NSString *> *errors;
@property (nonatomic, strong) NSMutableArray<NSString *> *warnings;
@end

/// Orchestrator: enumerates directory, dispatches normalization.
@interface TFNNormalizer : NSObject

@property (nonatomic) TFNOutputMode outputMode;
@property (nonatomic, copy, nullable) NSString *outputDirectory;
@property (nonatomic) TFNVerbosity verbosity;
@property (nonatomic) double cpuPercent;      // 0.0–1.0, default 0.9
@property (nonatomic) double memPercent;      // 0.0–1.0, default 0.9
@property (nonatomic) NSUInteger memPerFileGB; // GB per file estimate, default 1
@property (nonatomic) NSUInteger maxJobs;      // If > 0, additional cap on concurrency

/// Run normalization.
/// Returns nil on fatal error (sets error).
/// Returns result on completion (may contain per-file errors).
- (nullable TFNNormalizationResult *)normalizeDirectory:(NSString *)inputDirectory
                                           withBaseTIFF:(NSString *)baseTIFFPath
                                                  error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
