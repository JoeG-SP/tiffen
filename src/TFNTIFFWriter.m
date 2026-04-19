#import "TFNTIFFWriter.h"
#import <tiffio.h>

NSString *const TFNTIFFWriterErrorDomain = @"TFNTIFFWriterErrorDomain";

static NSString *_lastTIFFError = nil;

static void tiffErrorHandler(const char *module, const char *fmt, va_list ap) {
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, ap);
    _lastTIFFError = [NSString stringWithUTF8String:buf];
}

@implementation TFNTIFFWriter

+ (BOOL)writeImage:(TFNTIFFImage *)image
            toPath:(NSString *)path
             error:(NSError **)error {
    TIFFSetWarningHandler(NULL);
    TIFFSetErrorHandler(tiffErrorHandler);
    _lastTIFFError = nil;

    TIFF *tif = TIFFOpen([path fileSystemRepresentation], "w");
    if (!tif) {
        if (error) {
            *error = [NSError errorWithDomain:TFNTIFFWriterErrorDomain
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         [NSString stringWithFormat:@"Cannot create TIFF: %@",
                                          path.lastPathComponent]}];
        }
        return NO;
    }

    uint32_t w = (uint32_t)image.width;
    uint32_t h = (uint32_t)image.height;
    uint16_t bps = (uint16_t)image.bitDepth;
    uint16_t spp = (uint16_t)image.channelCount;

    TIFFSetField(tif, TIFFTAG_IMAGEWIDTH, w);
    TIFFSetField(tif, TIFFTAG_IMAGELENGTH, h);
    TIFFSetField(tif, TIFFTAG_BITSPERSAMPLE, bps);
    TIFFSetField(tif, TIFFTAG_SAMPLESPERPIXEL, spp);
    TIFFSetField(tif, TIFFTAG_ORIENTATION, ORIENTATION_TOPLEFT);
    TIFFSetField(tif, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);

    // Preserve original compression and strip layout
    uint16_t compression = image.compression ? image.compression : COMPRESSION_NONE;
    uint32_t rowsPerStrip = image.rowsPerStrip ? image.rowsPerStrip : h;
    TIFFSetField(tif, TIFFTAG_COMPRESSION, compression);
    TIFFSetField(tif, TIFFTAG_ROWSPERSTRIP, rowsPerStrip);

    if (image.isFloat) {
        TIFFSetField(tif, TIFFTAG_SAMPLEFORMAT, SAMPLEFORMAT_IEEEFP);
    } else {
        TIFFSetField(tif, TIFFTAG_SAMPLEFORMAT, SAMPLEFORMAT_UINT);
    }

    if (spp >= 3) {
        TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_RGB);
    } else {
        TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_MINISBLACK);
    }

    NSUInteger bytesPerSample = bps / 8;
    NSUInteger rowBytes = (NSUInteger)w * spp * bytesPerSample;

    for (uint32_t row = 0; row < h; row++) {
        void *rowPtr = (uint8_t *)image.pixelData + row * rowBytes;
        if (TIFFWriteScanline(tif, rowPtr, row, 0) < 0) {
            if (error) {
                NSString *detail = _lastTIFFError ?: @"unknown error";
                *error = [NSError errorWithDomain:TFNTIFFWriterErrorDomain
                                             code:2
                                         userInfo:@{NSLocalizedDescriptionKey:
                                             [NSString stringWithFormat:
                                              @"Error writing row %u to %@: %@",
                                              row, path.lastPathComponent, detail]}];
            }
            TIFFClose(tif);
            return NO;
        }
    }

    TIFFClose(tif);
    return YES;
}

@end
