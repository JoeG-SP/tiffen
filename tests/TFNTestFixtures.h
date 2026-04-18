#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Generates test TIFF fixtures in a temporary directory.
@interface TFNTestFixtures : NSObject

/// Create all test fixtures in a temp directory. Returns the directory path.
+ (NSString *)createFixturesDirectory;

/// Create a single TIFF with specified parameters.
+ (NSString *)createTIFFAtPath:(NSString *)path
                         width:(NSUInteger)width
                        height:(NSUInteger)height
                  channelCount:(NSUInteger)channelCount
                      bitDepth:(NSUInteger)bitDepth
                       isFloat:(BOOL)isFloat
                      minValue:(float)minValue
                      maxValue:(float)maxValue;

/// Create a TIFF with a specific compression scheme.
+ (NSString *)createTIFFAtPath:(NSString *)path
                         width:(NSUInteger)width
                        height:(NSUInteger)height
                  channelCount:(NSUInteger)channelCount
                      bitDepth:(NSUInteger)bitDepth
                       isFloat:(BOOL)isFloat
                      minValue:(float)minValue
                      maxValue:(float)maxValue
                   compression:(uint16_t)compression;

/// Create a corrupt file that is not a valid TIFF.
+ (void)createCorruptTIFFAtPath:(NSString *)path;

/// Create a non-TIFF file (PNG-like).
+ (void)createNonTIFFAtPath:(NSString *)path;

/// Clean up a fixtures directory.
+ (void)cleanupDirectory:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
