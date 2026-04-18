#import "TFNTestFixtures.h"
#import <tiffio.h>

@implementation TFNTestFixtures

+ (NSString *)createFixturesDirectory {
    NSString *tmpDir = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    // Base fixtures
    [self createTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"base_8bit.tiff"]
                     width:64 height:64 channelCount:1 bitDepth:8 isFloat:NO
                  minValue:50.0f maxValue:200.0f];

    [self createTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"base_16bit.tiff"]
                     width:64 height:64 channelCount:1 bitDepth:16 isFloat:NO
                  minValue:1000.0f maxValue:60000.0f];

    [self createTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"base_32int.tiff"]
                     width:32 height:32 channelCount:1 bitDepth:32 isFloat:NO
                  minValue:100000.0f maxValue:4000000000.0f];

    [self createTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"base_32float.tiff"]
                     width:64 height:64 channelCount:1 bitDepth:32 isFloat:YES
                  minValue:0.1f maxValue:0.9f];

    // Targets with different ranges
    [self createTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"dark_8bit.tiff"]
                     width:64 height:64 channelCount:1 bitDepth:8 isFloat:NO
                  minValue:0.0f maxValue:100.0f];

    [self createTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"bright_16bit.tiff"]
                     width:64 height:64 channelCount:1 bitDepth:16 isFloat:NO
                  minValue:30000.0f maxValue:65535.0f];

    // Multichannel (RGB)
    [self createTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"multichannel.tiff"]
                     width:32 height:32 channelCount:3 bitDepth:8 isFloat:NO
                  minValue:10.0f maxValue:240.0f];

    // Uniform (flat exposure)
    [self createTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"uniform_8bit.tiff"]
                     width:32 height:32 channelCount:1 bitDepth:8 isFloat:NO
                  minValue:128.0f maxValue:128.0f];

    // Corrupt
    [self createCorruptTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"corrupt.tiff"]];

    // Non-TIFF
    [self createNonTIFFAtPath:[tmpDir stringByAppendingPathComponent:@"not_a_tiff.png"]];

    return tmpDir;
}

+ (NSString *)createTIFFAtPath:(NSString *)path
                         width:(NSUInteger)width
                        height:(NSUInteger)height
                  channelCount:(NSUInteger)channelCount
                      bitDepth:(NSUInteger)bitDepth
                       isFloat:(BOOL)isFloat
                      minValue:(float)minValue
                      maxValue:(float)maxValue {
    TIFFSetWarningHandler(NULL);
    TIFF *tif = TIFFOpen([path fileSystemRepresentation], "w");
    if (!tif) return path;

    uint16_t bps = (uint16_t)bitDepth;
    uint16_t spp = (uint16_t)channelCount;

    TIFFSetField(tif, TIFFTAG_IMAGEWIDTH, (uint32_t)width);
    TIFFSetField(tif, TIFFTAG_IMAGELENGTH, (uint32_t)height);
    TIFFSetField(tif, TIFFTAG_BITSPERSAMPLE, bps);
    TIFFSetField(tif, TIFFTAG_SAMPLESPERPIXEL, spp);
    TIFFSetField(tif, TIFFTAG_ORIENTATION, ORIENTATION_TOPLEFT);
    TIFFSetField(tif, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
    TIFFSetField(tif, TIFFTAG_ROWSPERSTRIP, (uint32_t)height);
    TIFFSetField(tif, TIFFTAG_COMPRESSION, COMPRESSION_NONE);

    if (isFloat) {
        TIFFSetField(tif, TIFFTAG_SAMPLEFORMAT, SAMPLEFORMAT_IEEEFP);
    } else {
        TIFFSetField(tif, TIFFTAG_SAMPLEFORMAT, SAMPLEFORMAT_UINT);
    }

    if (spp >= 3) {
        TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_RGB);
    } else {
        TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_MINISBLACK);
    }

    NSUInteger bytesPerSample = bitDepth / 8;
    NSUInteger rowBytes = width * channelCount * bytesPerSample;
    void *row = calloc(1, rowBytes);

    for (NSUInteger y = 0; y < height; y++) {
        for (NSUInteger x = 0; x < width; x++) {
            // Generate a gradient from minValue to maxValue
            float t = (float)(y * width + x) / (float)(width * height - 1);
            float val = minValue + t * (maxValue - minValue);

            for (NSUInteger c = 0; c < channelCount; c++) {
                NSUInteger idx = x * channelCount + c;
                if (isFloat && bitDepth == 32) {
                    ((float *)row)[idx] = val;
                } else if (bitDepth == 8) {
                    uint8_t v = (uint8_t)(val < 0 ? 0 : (val > 255 ? 255 : val));
                    ((uint8_t *)row)[idx] = v;
                } else if (bitDepth == 16) {
                    uint16_t v = (uint16_t)(val < 0 ? 0 : (val > 65535 ? 65535 : val));
                    ((uint16_t *)row)[idx] = v;
                } else if (bitDepth == 32) {
                    uint32_t v = (uint32_t)(val < 0 ? 0 : val);
                    ((uint32_t *)row)[idx] = v;
                }
            }
        }
        TIFFWriteScanline(tif, row, (uint32_t)y, 0);
    }

    free(row);
    TIFFClose(tif);
    return path;
}

+ (void)createCorruptTIFFAtPath:(NSString *)path {
    // Write garbage bytes that look like they could be a TIFF but aren't valid
    uint8_t garbage[] = {0x49, 0x49, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
                         0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE};
    NSData *data = [NSData dataWithBytes:garbage length:sizeof(garbage)];
    [data writeToFile:path atomically:YES];
}

+ (void)createNonTIFFAtPath:(NSString *)path {
    // Write a minimal PNG-like header
    uint8_t pngHeader[] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
    NSData *data = [NSData dataWithBytes:pngHeader length:sizeof(pngHeader)];
    [data writeToFile:path atomically:YES];
}

+ (void)cleanupDirectory:(NSString *)path {
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

@end
