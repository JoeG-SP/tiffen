#import <Foundation/Foundation.h>
#import "TFNExposureRange.h"

NS_ASSUME_NONNULL_BEGIN

/// Represents a loaded TIFF image in memory.
@interface TFNTIFFImage : NSObject

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic) NSUInteger width;
@property (nonatomic) NSUInteger height;
@property (nonatomic) NSUInteger channelCount;
@property (nonatomic) NSUInteger bitDepth;
@property (nonatomic) BOOL isFloat;
@property (nonatomic, nullable) void *pixelData;
@property (nonatomic) NSUInteger pixelDataLength;
@property (nonatomic, nullable) TFNExposureRange *exposureRange;
@property (nonatomic) uint16_t compression;
@property (nonatomic) uint32_t rowsPerStrip;

/// Bytes per sample (bitDepth / 8).
@property (nonatomic, readonly) NSUInteger bytesPerSample;

/// Bytes per pixel (bytesPerSample * channelCount).
@property (nonatomic, readonly) NSUInteger bytesPerPixel;

- (void)computeExposureRange;

@end

/// Reads TIFF files via libtiff.
@interface TFNTIFFReader : NSObject

/// Read a TIFF file and return a TFNTIFFImage with pixel data.
/// Returns nil and sets error on failure.
+ (nullable TFNTIFFImage *)readTIFFAtPath:(NSString *)path
                                    error:(NSError **)error;

/// Check if a file path appears to be a TIFF file (by extension).
+ (BOOL)isTIFFFile:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
