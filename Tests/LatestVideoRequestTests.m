#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import "LatestVideoRequest.h"

static void FPAssert(BOOL condition, NSString *message) {
    if (condition) return;
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    exit(1);
}

int main(void) {
    @autoreleasepool {
        NSString *timeout = FPLatestVideoFailureMessage(nil, nil, YES);
        FPAssert([timeout containsString:@"時間内に取得できませんでした"], @"タイムアウト時に再試行可能な失敗理由を返す");

        NSString *cancelled = FPLatestVideoFailureMessage(@{PHImageCancelledKey: @YES}, nil, NO);
        FPAssert([cancelled containsString:@"キャンセルされました"], @"PhotoKitのキャンセルを明示する");

        NSError *underlying = [NSError errorWithDomain:@"FramePickerTests" code:1 userInfo:@{NSLocalizedDescriptionKey: @"network unavailable"}];
        NSString *failed = FPLatestVideoFailureMessage(@{PHImageErrorKey: underlying}, nil, NO);
        FPAssert([failed containsString:@"network unavailable"], @"PhotoKitのエラー詳細を残す");

        AVAsset *asset = [AVMutableComposition composition];
        FPAssert(FPLatestVideoFailureMessage(@{}, asset, NO) == nil, @"動画取得成功時は失敗メッセージを返さない");

        puts("LatestVideoRequestTests passed");
    }
    return 0;
}
