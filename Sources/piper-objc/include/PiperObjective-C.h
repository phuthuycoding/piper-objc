//
//  piper.h
//
//
//  Created by Ihor Shevchuk on 22.11.2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PiperPhonemeAlignment;

@protocol PiperDelegate <NSObject>
- (void)piperDidReceiveSamples:(const float* _Nonnull)samples withSize:(NSInteger)count;
@optional
- (void)piperDidReceiveAudioChunk:(const float* _Nonnull)samples
                         withSize:(NSInteger)count
                       sampleRate:(NSInteger)sampleRate
                       alignments:(NSArray<PiperPhonemeAlignment *> *)alignments;
@end

@interface Piper : NSObject
@property (nonatomic, weak) id<PiperDelegate> delegate;
@property (nonatomic, readonly) NSInteger sampleRate;
- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                             andConfigPath:(NSString *)modelConfigPath;
- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                                configPath:(NSString *)modelConfigPath
                              espeakNGData:(NSString *)espeakNGData;
- (BOOL)completed;
- (void)cancel;

#pragma mark - Synthesizion

#pragma mark Text

- (void)synthesize:(NSString *)text;
- (void)synthesize:(NSString *)text
      toFileAtPath:(NSString *)path
        completion:(dispatch_block_t)completion;

#pragma mark SSML

- (void)synthesizeSSML:(NSString *)ssml
             speakerId:(int)speakerId;
- (void)synthesizeSSML:(NSString *)ssml
             speakerId:(int)speakerId
          toFileAtPath:(NSString *)path
            completion:(dispatch_block_t)completion;
@end

NS_ASSUME_NONNULL_END
