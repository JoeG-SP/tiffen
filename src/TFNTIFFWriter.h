#import <Foundation/Foundation.h>
#import "TFNTIFFReader.h"

NS_ASSUME_NONNULL_BEGIN

/// Writes TIFF files via libtiff, preserving original metadata.
@interface TFNTIFFWriter : NSObject

/// Write pixel data to a TIFF file, preserving bit depth and channel count
/// from the source image metadata.
+ (BOOL)writeImage:(TFNTIFFImage *)image
            toPath:(NSString *)path
             error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
