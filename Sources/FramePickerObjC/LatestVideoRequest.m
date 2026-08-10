#import "LatestVideoRequest.h"
#import <Photos/Photos.h>

NSString *FPLatestVideoFailureMessage(NSDictionary *info, AVAsset *asset, BOOL timedOut) {
    if (timedOut) {
        return @"iCloudから最新動画を時間内に取得できませんでした。iPhone側のiCloud写真の同期とネットワーク接続を確認して、もう一度お試しください。";
    }

    NSError *error = info[PHImageErrorKey];
    if (error) {
        return [NSString stringWithFormat:@"iCloudから画面収録を取得できませんでした。\n%@", error.localizedDescription];
    }
    if ([info[PHImageCancelledKey] boolValue]) {
        return @"iCloudからの最新動画の取得がキャンセルされました。もう一度お試しください。";
    }
    if (!asset) return @"画面収録の動画データを取得できませんでした。";
    return nil;
}
