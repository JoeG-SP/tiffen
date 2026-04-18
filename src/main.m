#import <Foundation/Foundation.h>
#import "TFNNormalizer.h"

static void printUsage(void) {
    fprintf(stdout,
        "Usage: tiffen <base-tiff> <input-directory> [options]\n"
        "\n"
        "Normalize the exposure range of TIFF files to match a base TIFF.\n"
        "\n"
        "Arguments:\n"
        "  <base-tiff>         Reference TIFF file\n"
        "  <input-directory>   Directory of TIFF files to normalize\n"
        "\n"
        "Options:\n"
        "  -o, --output <dir>  Output directory (default: <input-dir>/normalized/)\n"
        "  --in-place          Overwrite original files\n"
        "  -v, --verbose       Detailed progress output\n"
        "  -q, --quiet         Suppress stdout (errors still on stderr)\n"
        "  --cpu-percent <N>   Max CPU usage percent (1-100, default: 90)\n"
        "  --mem-percent <N>   Max memory usage percent (1-100, default: 90)\n"
        "  -j, --jobs <N>      Override concurrency (number of parallel files)\n"
        "  -h, --help          Show this help\n"
        "  --version           Show version\n"
        "\n"
        "Constraints:\n"
        "  --in-place and --output are mutually exclusive\n"
        "  --verbose and --quiet are mutually exclusive\n"
    );
}

static void printVersion(void) {
    fprintf(stdout, "tiffen %s\n", TIFFEN_VERSION);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSMutableArray<NSString *> *args = [NSMutableArray array];
        for (int i = 1; i < argc; i++) {
            [args addObject:[NSString stringWithUTF8String:argv[i]]];
        }

        // Parse options
        NSString *baseTIFFPath = nil;
        NSString *inputDirectory = nil;
        NSString *outputDirectory = nil;
        BOOL inPlace = NO;
        BOOL verbose = NO;
        BOOL quiet = NO;
        double cpuPercent = 0.9;
        double memPercent = 0.9;
        NSInteger jobsOverride = 0;

        NSMutableArray<NSString *> *positional = [NSMutableArray array];

        for (NSUInteger i = 0; i < args.count; i++) {
            NSString *arg = args[i];

            if ([arg isEqualToString:@"-h"] || [arg isEqualToString:@"--help"]) {
                printUsage();
                return 0;
            } else if ([arg isEqualToString:@"--version"]) {
                printVersion();
                return 0;
            } else if ([arg isEqualToString:@"--in-place"]) {
                inPlace = YES;
            } else if ([arg isEqualToString:@"-v"] || [arg isEqualToString:@"--verbose"]) {
                verbose = YES;
            } else if ([arg isEqualToString:@"-q"] || [arg isEqualToString:@"--quiet"]) {
                quiet = YES;
            } else if ([arg isEqualToString:@"-o"] || [arg isEqualToString:@"--output"]) {
                if (i + 1 < args.count) {
                    outputDirectory = args[++i];
                } else {
                    fprintf(stderr, "Error: --output requires a directory argument\n");
                    return 2;
                }
            } else if ([arg isEqualToString:@"--cpu-percent"]) {
                if (i + 1 < args.count) {
                    int val = [args[++i] intValue];
                    if (val < 1 || val > 100) {
                        fprintf(stderr, "Error: --cpu-percent must be 1-100\n");
                        return 2;
                    }
                    cpuPercent = val / 100.0;
                } else {
                    fprintf(stderr, "Error: --cpu-percent requires a value\n");
                    return 2;
                }
            } else if ([arg isEqualToString:@"--mem-percent"]) {
                if (i + 1 < args.count) {
                    int val = [args[++i] intValue];
                    if (val < 1 || val > 100) {
                        fprintf(stderr, "Error: --mem-percent must be 1-100\n");
                        return 2;
                    }
                    memPercent = val / 100.0;
                } else {
                    fprintf(stderr, "Error: --mem-percent requires a value\n");
                    return 2;
                }
            } else if ([arg isEqualToString:@"-j"] || [arg isEqualToString:@"--jobs"]) {
                if (i + 1 < args.count) {
                    int val = [args[++i] intValue];
                    if (val < 1) {
                        fprintf(stderr, "Error: --jobs must be >= 1\n");
                        return 2;
                    }
                    jobsOverride = val;
                } else {
                    fprintf(stderr, "Error: --jobs requires a value\n");
                    return 2;
                }
            } else if ([arg hasPrefix:@"-"]) {
                fprintf(stderr, "Error: unknown option: %s\n", arg.UTF8String);
                return 2;
            } else {
                [positional addObject:arg];
            }
        }

        // Validate mutual exclusions
        if (inPlace && outputDirectory) {
            fprintf(stderr, "Error: --in-place and --output are mutually exclusive\n");
            return 2;
        }
        if (verbose && quiet) {
            fprintf(stderr, "Error: --verbose and --quiet are mutually exclusive\n");
            return 2;
        }

        // Validate positional args
        if (positional.count < 2) {
            fprintf(stderr, "Error: missing required arguments\n");
            printUsage();
            return 2;
        }

        baseTIFFPath = positional[0];
        inputDirectory = positional[1];

        // Resolve to absolute paths
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![baseTIFFPath isAbsolutePath]) {
            baseTIFFPath = [[fm currentDirectoryPath] stringByAppendingPathComponent:baseTIFFPath];
        }
        if (![inputDirectory isAbsolutePath]) {
            inputDirectory = [[fm currentDirectoryPath] stringByAppendingPathComponent:inputDirectory];
        }
        if (outputDirectory && ![outputDirectory isAbsolutePath]) {
            outputDirectory = [[fm currentDirectoryPath] stringByAppendingPathComponent:outputDirectory];
        }

        // Validate base TIFF exists
        if (![fm fileExistsAtPath:baseTIFFPath]) {
            fprintf(stderr, "Error: base TIFF not found: %s\n", baseTIFFPath.UTF8String);
            return 2;
        }

        // Validate input directory
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:inputDirectory isDirectory:&isDir] || !isDir) {
            fprintf(stderr, "Error: not a directory: %s\n", inputDirectory.UTF8String);
            return 2;
        }

        // Configure normalizer
        TFNNormalizer *normalizer = [[TFNNormalizer alloc] init];
        normalizer.outputMode = inPlace ? TFNOutputModeInPlace : TFNOutputModeDirectory;
        normalizer.outputDirectory = outputDirectory;
        normalizer.cpuPercent = cpuPercent;
        normalizer.memPercent = memPercent;

        if (jobsOverride > 0) {
            normalizer.maxJobs = (NSUInteger)jobsOverride;
        }

        if (verbose) {
            normalizer.verbosity = TFNVerbosityVerbose;
        } else if (quiet) {
            normalizer.verbosity = TFNVerbosityQuiet;
        } else {
            normalizer.verbosity = TFNVerbosityNormal;
        }

        // Run
        NSError *error = nil;
        TFNNormalizationResult *result = [normalizer normalizeDirectory:inputDirectory
                                                           withBaseTIFF:baseTIFFPath
                                                                  error:&error];
        if (!result) {
            fprintf(stderr, "Error: %s\n", error.localizedDescription.UTF8String);
            return 2;
        }

        return (result.filesErrored > 0) ? 1 : 0;
    }
}
