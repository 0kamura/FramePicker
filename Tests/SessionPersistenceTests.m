#import <AVKit/AVKit.h>
#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

@interface FPDelegate (SessionPersistenceTests)
- (void)rememberLastSessionForSourceID:(NSString *)sourceID photoID:(NSString *)photoID;
- (void)rememberLastSessionForSourceID:(NSString *)sourceID photoID:(NSString *)photoID position:(double)position;
- (NSDictionary *)lastSessionDescriptor;
- (void)clearLastSession;
- (void)restoreLastSession;
- (void)persistCurrentSessionState;
@end

static void FPAssert(BOOL condition, NSString *message) {
    if (condition) return;
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    exit(1);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        FPAssert(argc == 2, @"復元テスト用動画を受け取る");
        [NSApplication sharedApplication];
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSString *key = @"lastSession.v1";
        id previous = [defaults objectForKey:key];
        id previousCapturedSessions = [defaults objectForKey:@"capturedSessions.v1"];
        [defaults removeObjectForKey:key];

        FPDelegate *delegate = [FPDelegate new];
        FPAssert([delegate respondsToSelector:@selector(rememberLastSessionForSourceID:photoID:)], @"最後に開いた動画を保存できる");
        FPAssert([delegate respondsToSelector:@selector(rememberLastSessionForSourceID:photoID:position:)], @"最後に選んでいた動画位置を保存できる");
        [delegate rememberLastSessionForSourceID:@"file:/tmp/FramePicker Test.mov" photoID:nil];
        NSDictionary *session = [delegate lastSessionDescriptor];
        FPAssert([session[@"kind"] isEqualToString:@"file"] && [session[@"identifier"] isEqualToString:@"/tmp/FramePicker Test.mov"], @"Mac動画のパスを次回復元用に保存する");

        FPDelegate *nextLaunch = [FPDelegate new];
        session = [nextLaunch lastSessionDescriptor];
        FPAssert([session[@"identifier"] isEqualToString:@"/tmp/FramePicker Test.mov"], @"別の起動でも最後の動画を読み出せる");

        [nextLaunch rememberLastSessionForSourceID:@"photo:local-photo-id" photoID:@"local-photo-id"];
        session = [nextLaunch lastSessionDescriptor];
        FPAssert([session[@"kind"] isEqualToString:@"photo"] && [session[@"identifier"] isEqualToString:@"local-photo-id"], @"iPhone動画の写真識別子で最後の動画を上書きする");

        [nextLaunch clearLastSession];
        FPAssert([nextLaunch lastSessionDescriptor] == nil, @"リセット時は次回復元する動画を消去する");

        NSString *videoPath = [NSString stringWithUTF8String:argv[1]];
        NSString *sourceID = [@"file:" stringByAppendingString:videoPath];
        [defaults setObject:@{sourceID: @[@1.0]} forKey:@"capturedSessions.v1"];
        [nextLaunch rememberLastSessionForSourceID:sourceID photoID:nil position:1.5];
        [nextLaunch sourceToolbar]; [nextLaunch videoArea]; [nextLaunch controls]; [nextLaunch sequenceArea]; [nextLaunch buildSelectionPanel];
        FPAssert([nextLaunch respondsToSelector:@selector(restoreLastSession)], @"起動時に前回の動画を復元できる");
        [nextLaunch restoreLastSession];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while ((!nextLaunch.asset || nextLaunch.frames.count != 1) && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        FPAssert(nextLaunch.asset != nil && [nextLaunch.sourceID isEqualToString:sourceID], @"次回起動時に最後のMac動画を自動で開き直す");
        FPAssert(nextLaunch.frames.count == 1, @"動画を開き直した後に前回の選択フレームを復元する");
        deadline = [NSDate dateWithTimeIntervalSinceNow:2];
        while (fabs(CMTimeGetSeconds(nextLaunch.player.currentTime) - 1.5) > 0.05 && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        FPAssert(fabs(CMTimeGetSeconds(nextLaunch.player.currentTime) - 1.5) <= 0.05, @"動画を開き直した後に下のフレームで選んでいた位置へ戻る");
        deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while (nextLaunch.timelineFrames.count < 2 && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        FPAssert(nextLaunch.selectedTimelineIndex != NSNotFound, @"復元した位置に対応する下のフレームを選択状態にする");
        double restoredTimelineTime = [nextLaunch.timelineFrames[nextLaunch.selectedTimelineIndex][@"time"] doubleValue];
        FPAssert(fabs(restoredTimelineTime - 1.5) <= 0.15, @"下の青枠も終了前に選んでいた位置へ戻る");

        __block BOOL finalSeekFinished = NO;
        [nextLaunch.player seekToTime:CMTimeMakeWithSeconds(2.0, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) { finalSeekFinished = finished; }];
        deadline = [NSDate dateWithTimeIntervalSinceNow:2];
        while (!finalSeekFinished && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        [nextLaunch persistCurrentSessionState];
        session = [nextLaunch lastSessionDescriptor];
        FPAssert(fabs([session[@"position"] doubleValue] - 2.0) <= 0.05, @"終了時の動画位置を次回起動用に保存する");

        if (previous) [defaults setObject:previous forKey:key]; else [defaults removeObjectForKey:key];
        if (previousCapturedSessions) [defaults setObject:previousCapturedSessions forKey:@"capturedSessions.v1"]; else [defaults removeObjectForKey:@"capturedSessions.v1"];
        puts("SessionPersistenceTests passed");
    }
    return 0;
}
