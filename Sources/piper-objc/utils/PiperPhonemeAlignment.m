#import "PiperPhonemeAlignment.h"

@implementation PiperPhonemeAlignment

- (instancetype)initWithPhoneme:(uint32_t)phoneme sampleCount:(NSInteger)sampleCount {
    self = [super init];
    if (self) {
        _phoneme = phoneme;
        _sampleCount = sampleCount;
    }
    return self;
}

@end
