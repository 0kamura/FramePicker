#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * _Nullable FPLatestVideoFailureMessage(
    NSDictionary * _Nullable info,
    AVAsset * _Nullable asset,
    BOOL timedOut
);

NS_ASSUME_NONNULL_END
