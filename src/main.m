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
