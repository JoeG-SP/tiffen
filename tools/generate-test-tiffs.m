/*
 * generate-test-tiffs.m
 *
 * Generates a set of TIFF files for visually testing the Tiffen UI.
 * Produces images with gradients, patterns, and varying exposure ranges
 * across multiple bit depths and channel counts.
 *
 * Build & run:
 *   ./tools/generate-test-tiffs.sh [output-directory]
 */

#import <Foundation/Foundation.h>
#import <tiffio.h>
#include <math.h>

static const char *compressionName(uint16_t c);

static void writeTIFF(NSString *path,
                      uint32_t width, uint32_t height,
                      uint16_t bps, uint16_t spp, BOOL isFloat,
                      void *pixels, uint16_t compression) {
    TIFF *tif = TIFFOpen([path fileSystemRepresentation], "w");
    if (!tif) {
        fprintf(stderr, "Error: cannot create %s\n", path.UTF8String);
        return;
    }

    TIFFSetField(tif, TIFFTAG_IMAGEWIDTH, width);
    TIFFSetField(tif, TIFFTAG_IMAGELENGTH, height);
    TIFFSetField(tif, TIFFTAG_BITSPERSAMPLE, bps);
    TIFFSetField(tif, TIFFTAG_SAMPLESPERPIXEL, spp);
    TIFFSetField(tif, TIFFTAG_ORIENTATION, ORIENTATION_TOPLEFT);
    TIFFSetField(tif, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
    TIFFSetField(tif, TIFFTAG_COMPRESSION, compression);
    TIFFSetField(tif, TIFFTAG_ROWSPERSTRIP, height);
    TIFFSetField(tif, TIFFTAG_SAMPLEFORMAT, isFloat ? SAMPLEFORMAT_IEEEFP : SAMPLEFORMAT_UINT);

    if (spp >= 3) {
        TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_RGB);
    } else {
        TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_MINISBLACK);
    }

    TIFFSetWarningHandler(NULL);
    TIFFSetErrorHandler(NULL);

    uint32_t rowBytes = width * spp * (bps / 8);
    for (uint32_t row = 0; row < height; row++) {
        TIFFWriteScanline(tif, (uint8_t *)pixels + row * rowBytes, row, 0);
    }

    TIFFClose(tif);
    fprintf(stdout, "  Created: %-35s [%s]\n", path.lastPathComponent.UTF8String,
            compressionName(compression));
}

#pragma mark - 8-bit Generators

// Compression name for printing
static const char *compressionName(uint16_t c) {
    switch (c) {
        case COMPRESSION_NONE: return "None";
        case COMPRESSION_DEFLATE: return "Deflate";
        case COMPRESSION_LZW: return "LZW";
        case COMPRESSION_PACKBITS: return "PackBits";
        default: return "Unknown";
    }
}

static void generateGrayscaleGradient8(NSString *path, uint32_t w, uint32_t h,
                                        uint8_t minVal, uint8_t maxVal,
                                        uint16_t compression) {
    uint8_t *pixels = malloc(w * h);
    for (uint32_t y = 0; y < h; y++) {
        for (uint32_t x = 0; x < w; x++) {
            float t = (float)x / (w - 1);
            pixels[y * w + x] = (uint8_t)(minVal + t * (maxVal - minVal));
        }
    }
    writeTIFF(path, w, h, 8, 1, NO, pixels, compression);
    free(pixels);
}

static void generateRGBGradient8(NSString *path, uint32_t w, uint32_t h,
                                  uint8_t rMin, uint8_t rMax,
                                  uint8_t gMin, uint8_t gMax,
                                  uint8_t bMin, uint8_t bMax,
                                  uint16_t compression) {
    uint8_t *pixels = malloc(w * h * 3);
    for (uint32_t y = 0; y < h; y++) {
        for (uint32_t x = 0; x < w; x++) {
            float tx = (float)x / (w - 1);
            float ty = (float)y / (h - 1);
            uint32_t idx = (y * w + x) * 3;
            pixels[idx + 0] = (uint8_t)(rMin + tx * (rMax - rMin));
            pixels[idx + 1] = (uint8_t)(gMin + ty * (gMax - gMin));
            pixels[idx + 2] = (uint8_t)(bMin + (tx + ty) / 2.0f * (bMax - bMin));
        }
    }
    writeTIFF(path, w, h, 8, 3, NO, pixels, compression);
    free(pixels);
}

static void generateCheckerboard8(NSString *path, uint32_t w, uint32_t h,
                                   uint32_t blockSize, uint8_t light, uint8_t dark,
                                   uint16_t compression) {
    uint8_t *pixels = malloc(w * h);
    for (uint32_t y = 0; y < h; y++) {
        for (uint32_t x = 0; x < w; x++) {
            BOOL isLight = ((x / blockSize) + (y / blockSize)) % 2 == 0;
            pixels[y * w + x] = isLight ? light : dark;
        }
    }
    writeTIFF(path, w, h, 8, 1, NO, pixels, compression);
    free(pixels);
}

static void generateSineWave8(NSString *path, uint32_t w, uint32_t h,
                               uint8_t minVal, uint8_t maxVal, float frequency,
                               uint16_t compression) {
    uint8_t *pixels = malloc(w * h);
    for (uint32_t y = 0; y < h; y++) {
        for (uint32_t x = 0; x < w; x++) {
            float t = sinf(frequency * M_PI * x / w) * sinf(frequency * M_PI * y / h);
            t = (t + 1.0f) / 2.0f; // normalize to 0-1
            pixels[y * w + x] = (uint8_t)(minVal + t * (maxVal - minVal));
        }
    }
    writeTIFF(path, w, h, 8, 1, NO, pixels, compression);
    free(pixels);
}

static void generateVignette8(NSString *path, uint32_t w, uint32_t h,
                               uint8_t center, uint8_t edge,
                               uint16_t compression) {
    uint8_t *pixels = malloc(w * h * 3);
    float cx = w / 2.0f, cy = h / 2.0f;
    float maxDist = sqrtf(cx * cx + cy * cy);
    for (uint32_t y = 0; y < h; y++) {
        for (uint32_t x = 0; x < w; x++) {
            float dx = x - cx, dy = y - cy;
            float dist = sqrtf(dx * dx + dy * dy) / maxDist;
            float val = center + dist * (edge - center);
            uint32_t idx = (y * w + x) * 3;
            pixels[idx + 0] = (uint8_t)val;
            pixels[idx + 1] = (uint8_t)(val * 0.9f);
            pixels[idx + 2] = (uint8_t)(val * 0.8f);
        }
    }
    writeTIFF(path, w, h, 8, 3, NO, pixels, compression);
    free(pixels);
}

#pragma mark - 16-bit Generators

static void generateGrayscaleGradient16(NSString *path, uint32_t w, uint32_t h,
                                         uint16_t minVal, uint16_t maxVal,
                                         uint16_t compression) {
    uint16_t *pixels = malloc(w * h * sizeof(uint16_t));
    for (uint32_t y = 0; y < h; y++) {
        for (uint32_t x = 0; x < w; x++) {
            float t = (float)x / (w - 1);
            pixels[y * w + x] = (uint16_t)(minVal + t * (maxVal - minVal));
        }
    }
    writeTIFF(path, w, h, 16, 1, NO, pixels, compression);
    free(pixels);
}

static void generateRGBGradient16(NSString *path, uint32_t w, uint32_t h,
                                   uint16_t rMin, uint16_t rMax,
                                   uint16_t gMin, uint16_t gMax,
                                   uint16_t bMin, uint16_t bMax,
                                   uint16_t compression) {
    uint16_t *pixels = malloc(w * h * 3 * sizeof(uint16_t));
    for (uint32_t y = 0; y < h; y++) {
        for (uint32_t x = 0; x < w; x++) {
            float tx = (float)x / (w - 1);
            float ty = (float)y / (h - 1);
            uint32_t idx = (y * w + x) * 3;
            pixels[idx + 0] = (uint16_t)(rMin + tx * (rMax - rMin));
            pixels[idx + 1] = (uint16_t)(gMin + ty * (gMax - gMin));
            pixels[idx + 2] = (uint16_t)(bMin + (tx + ty) / 2.0f * (bMax - bMin));
        }
    }
    writeTIFF(path, w, h, 16, 3, NO, pixels, compression);
    free(pixels);
}

#pragma mark - 32-bit Float Generators

static void generateGrayscaleGradientFloat(NSString *path, uint32_t w, uint32_t h,
                                            float minVal, float maxVal,
                                            uint16_t compression) {
    float *pixels = malloc(w * h * sizeof(float));
    for (uint32_t y = 0; y < h; y++) {
        for (uint32_t x = 0; x < w; x++) {
            float t = (float)x / (w - 1);
            pixels[y * w + x] = minVal + t * (maxVal - minVal);
        }
    }
    writeTIFF(path, w, h, 32, 1, YES, pixels, compression);
    free(pixels);
}

#pragma mark - Main

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *outputDir;
        if (argc > 1) {
            outputDir = [NSString stringWithUTF8String:argv[1]];
        } else {
            outputDir = @"test-images";
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *(^p)(NSString *) = ^NSString *(NSString *name) {
            return [outputDir stringByAppendingPathComponent:name];
        };

        uint32_t W = 512, H = 512;

        // Compression abbreviations for output
        uint16_t DEFLATE = COMPRESSION_DEFLATE;
        uint16_t LZW     = COMPRESSION_LZW;
        uint16_t NONE    = COMPRESSION_NONE;
        uint16_t PACK    = COMPRESSION_PACKBITS;

        fprintf(stdout, "Generating test TIFFs in %s/\n", outputDir.UTF8String);
        fprintf(stdout, "Compression mix: Deflate, LZW, None, PackBits\n\n");

        // === BASE FILE ===
        fprintf(stdout, "Base file (use this as the reference):\n");
        generateRGBGradient8(p(@"BASE_reference.tiff"), W, H,
                             40, 220, 30, 200, 50, 210, DEFLATE);

        // === 8-bit GRAYSCALE — varying exposure + compression ===
        fprintf(stdout, "\n8-bit grayscale (varying exposure + compression):\n");
        generateGrayscaleGradient8(p(@"gray_dark.tiff"), W, H, 0, 80, DEFLATE);
        generateGrayscaleGradient8(p(@"gray_normal.tiff"), W, H, 30, 200, LZW);
        generateGrayscaleGradient8(p(@"gray_bright.tiff"), W, H, 150, 255, NONE);
        generateGrayscaleGradient8(p(@"gray_full_range.tiff"), W, H, 0, 255, PACK);
        generateGrayscaleGradient8(p(@"gray_narrow.tiff"), W, H, 100, 130, DEFLATE);

        // === 8-bit GRAYSCALE — patterns ===
        fprintf(stdout, "\n8-bit grayscale patterns:\n");
        generateCheckerboard8(p(@"checker_high_contrast.tiff"), W, H, 32, 240, 15, LZW);
        generateCheckerboard8(p(@"checker_low_contrast.tiff"), W, H, 32, 130, 110, NONE);
        generateSineWave8(p(@"sine_dark.tiff"), W, H, 0, 100, 4.0f, PACK);
        generateSineWave8(p(@"sine_bright.tiff"), W, H, 128, 255, 6.0f, DEFLATE);

        // === 8-bit RGB — varying exposure ===
        fprintf(stdout, "\n8-bit RGB (varying exposure):\n");
        generateRGBGradient8(p(@"rgb_dark.tiff"), W, H,
                             0, 60, 0, 50, 0, 70, LZW);
        generateRGBGradient8(p(@"rgb_bright.tiff"), W, H,
                             180, 255, 160, 250, 170, 255, NONE);
        generateRGBGradient8(p(@"rgb_red_heavy.tiff"), W, H,
                             100, 255, 10, 80, 10, 60, DEFLATE);
        generateRGBGradient8(p(@"rgb_blue_heavy.tiff"), W, H,
                             10, 60, 10, 80, 100, 255, PACK);
        generateVignette8(p(@"vignette_bright.tiff"), W, H, 230, 40, LZW);
        generateVignette8(p(@"vignette_dark.tiff"), W, H, 120, 10, NONE);

        // === 16-bit ===
        fprintf(stdout, "\n16-bit images:\n");
        generateGrayscaleGradient16(p(@"gray16_dark.tiff"), W, H, 0, 8000, DEFLATE);
        generateGrayscaleGradient16(p(@"gray16_normal.tiff"), W, H, 5000, 55000, LZW);
        generateGrayscaleGradient16(p(@"gray16_bright.tiff"), W, H, 40000, 65535, NONE);
        generateRGBGradient16(p(@"rgb16_wide.tiff"), W, H,
                              1000, 60000, 2000, 58000, 500, 62000, PACK);
        generateRGBGradient16(p(@"rgb16_narrow.tiff"), W, H,
                              30000, 35000, 28000, 34000, 31000, 36000, DEFLATE);

        // === 32-bit float ===
        fprintf(stdout, "\n32-bit float images:\n");
        generateGrayscaleGradientFloat(p(@"float_dark.tiff"), W, H, 0.0f, 0.3f, DEFLATE);
        generateGrayscaleGradientFloat(p(@"float_normal.tiff"), W, H, 0.1f, 0.8f, LZW);
        generateGrayscaleGradientFloat(p(@"float_bright.tiff"), W, H, 0.6f, 1.0f, NONE);
        generateGrayscaleGradientFloat(p(@"float_hdr.tiff"), W, H, 0.0f, 5.0f, PACK);

        // === Edge cases ===
        fprintf(stdout, "\nEdge cases:\n");
        // Uniform (flat exposure — should trigger warning), uncompressed
        {
            uint8_t *pixels = calloc(W * H, 1);
            memset(pixels, 128, W * H);
            writeTIFF(p(@"uniform_128.tiff"), W, H, 8, 1, NO, pixels, NONE);
            free(pixels);
        }
        // Very small image, PackBits
        generateGrayscaleGradient8(p(@"tiny_32x32.tiff"), 32, 32, 20, 180, PACK);
        // Large image, LZW
        generateRGBGradient8(p(@"large_2048x2048.tiff"), 2048, 2048,
                             10, 245, 5, 240, 15, 250, LZW);

        fprintf(stdout, "\nDone! %lu files generated.\n",
                (unsigned long)[[fm contentsOfDirectoryAtPath:outputDir error:nil] count]);
        fprintf(stdout, "\nTo test:\n");
        fprintf(stdout, "  1. Open the Tiffen app\n");
        fprintf(stdout, "  2. Select BASE_reference.tiff as the base file\n");
        fprintf(stdout, "  3. Select %s/ as the input directory\n", outputDir.UTF8String);
        fprintf(stdout, "  4. Click Normalize\n");
        fprintf(stdout, "  5. Click completed files to view before/after histograms\n");
    }
    return 0;
}
