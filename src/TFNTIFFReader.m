#import "TFNTIFFReader.h"
#import <tiffio.h>

NSString *const TFNTIFFReaderErrorDomain = @"TFNTIFFReaderErrorDomain";

@implementation TFNTIFFImage

- (NSUInteger)bytesPerSample {
    return _bitDepth / 8;
}

- (NSUInteger)bytesPerPixel {
    return self.bytesPerSample * _channelCount;
}

- (void)computeExposureRange {
    if (_pixelData) {
        _exposureRange = [TFNExposureRange rangeFromPixelData:_pixelData
                                                        width:_width
                                                       height:_height
                                                 channelCount:_channelCount
                                                     bitDepth:_bitDepth
                                                      isFloat:_isFloat];
    }
}

- (void)dealloc {
    if (_pixelData) {
        free(_pixelData);
        _pixelData = NULL;
    }
}

@end

@implementation TFNTIFFReader

+ (nullable TFNTIFFImage *)readTIFFAtPath:(NSString *)path
                                    error:(NSError **)error {
    // Suppress libtiff warnings/errors during read — we handle errors ourselves
    TIFFSetWarningHandler(NULL);

    TIFF *tif = TIFFOpen([path fileSystemRepresentation], "r");
    if (!tif) {
        if (error) {
            *error = [NSError errorWithDomain:TFNTIFFReaderErrorDomain
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         [NSString stringWithFormat:@"Cannot open TIFF: %@",
                                          path.lastPathComponent]}];
        }
        return nil;
    }

    uint32_t w = 0, h = 0;
    uint16_t bps = 0, spp = 0, sampleFormat = 0;

    TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &w);
    TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &h);
    TIFFGetField(tif, TIFFTAG_BITSPERSAMPLE, &bps);
    TIFFGetField(tif, TIFFTAG_SAMPLESPERPIXEL, &spp);

    if (!TIFFGetField(tif, TIFFTAG_SAMPLEFORMAT, &sampleFormat)) {
        sampleFormat = SAMPLEFORMAT_UINT;
    }

    if (spp == 0) spp = 1;

    BOOL isFloat = (sampleFormat == SAMPLEFORMAT_IEEEFP);

    if (bps != 8 && bps != 16 && bps != 32) {
        if (error) {
            *error = [NSError errorWithDomain:TFNTIFFReaderErrorDomain
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         [NSString stringWithFormat:
                                          @"Unsupported bit depth %u in %@",
                                          bps, path.lastPathComponent]}];
        }
        TIFFClose(tif);
        return nil;
    }

    NSUInteger bytesPerSample = bps / 8;
    NSUInteger rowBytes = (NSUInteger)w * spp * bytesPerSample;
    NSUInteger totalBytes = rowBytes * h;

    void *buffer = malloc(totalBytes);
    if (!buffer) {
        if (error) {
            *error = [NSError errorWithDomain:TFNTIFFReaderErrorDomain
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         @"Out of memory"}];
        }
        TIFFClose(tif);
        return nil;
    }

    // Read scanlines
    for (uint32_t row = 0; row < h; row++) {
        void *rowPtr = (uint8_t *)buffer + row * rowBytes;
        if (TIFFReadScanline(tif, rowPtr, row, 0) < 0) {
            if (error) {
                *error = [NSError errorWithDomain:TFNTIFFReaderErrorDomain
                                             code:4
                                         userInfo:@{NSLocalizedDescriptionKey:
                                             [NSString stringWithFormat:
                                              @"Error reading row %u of %@",
                                              row, path.lastPathComponent]}];
            }
            free(buffer);
            TIFFClose(tif);
            return nil;
        }
    }

    TIFFClose(tif);

    TFNTIFFImage *image = [[TFNTIFFImage alloc] init];
    image.filePath = path;
    image.width = w;
    image.height = h;
    image.channelCount = spp;
    image.bitDepth = bps;
    image.isFloat = isFloat;
    image.pixelData = buffer;
    image.pixelDataLength = totalBytes;

    [image computeExposureRange];

    return image;
}

+ (BOOL)isTIFFFile:(NSString *)path {
    NSString *ext = path.pathExtension.lowercaseString;
    return [ext isEqualToString:@"tiff"] || [ext isEqualToString:@"tif"];
}

@end
