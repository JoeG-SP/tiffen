#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Per-channel exposure range (min/max pixel values).
@interface TFNExposureRange : NSObject

@property (nonatomic, readonly) NSUInteger channelCount;
@property (nonatomic, readonly) const float *minValues;
@property (nonatomic, readonly) const float *maxValues;

- (instancetype)initWithChannelCount:(NSUInteger)channelCount
                           minValues:(const float *)minValues
                           maxValues:(const float *)maxValues;

/// Compute exposure range from a raw pixel buffer.
/// pixelData must be row-major, interleaved channels.
+ (nullable instancetype)rangeFromPixelData:(const void *)pixelData
                                      width:(NSUInteger)width
                                     height:(NSUInteger)height
                               channelCount:(NSUInteger)channelCount
                                   bitDepth:(NSUInteger)bitDepth
                                    isFloat:(BOOL)isFloat;

@end

NS_ASSUME_NONNULL_END
