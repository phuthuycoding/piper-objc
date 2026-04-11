#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PiperPhonemeAlignment : NSObject

@property (nonatomic, readonly) uint32_t phoneme;
@property (nonatomic, readonly) NSInteger sampleCount;

- (instancetype)initWithPhoneme:(uint32_t)phoneme sampleCount:(NSInteger)sampleCount;

@end

NS_ASSUME_NONNULL_END
