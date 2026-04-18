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

/// Run normalization.
/// Returns nil on fatal error (sets error).
/// Returns result on completion (may contain per-file errors).
- (nullable TFNNormalizationResult *)normalizeDirectory:(NSString *)inputDirectory
                                           withBaseTIFF:(NSString *)baseTIFFPath
                                                  error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
