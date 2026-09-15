#import <AVKit/AVKit.h>
#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

@interface FPDelegate (PlaybackControlsTests)
@property BOOL explicitSeekInProgress;
@end

static void FPAssert(BOOL condition, NSString *message) {
    if (condition) return;
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    exit(1);
}

static NSButton *FPFindButtonWithAction(NSView *view, SEL action) {
    if ([view isKindOfClass:NSButton.class] && ((NSButton *)view).action == action) return (NSButton *)view;
    for (NSView *subview in view.subviews) {
        NSButton *button = FPFindButtonWithAction(subview, action);
        if (button) return button;
    }
    return nil;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        FPDelegate *delegate = [FPDelegate new];
        [delegate videoArea];
        FPAssert(delegate.playerView.controlsStyle == AVPlayerViewControlsStyleNone, @"動画上の標準操作バーを無効にする");

        NSView *controls = [delegate controls];
        NSButton *playButton = FPFindButtonWithAction(controls, @selector(togglePlayback:));
        NSButton *textButton = [delegate button:@"比較" symbol:@"folder" action:nil];
        FPAssert(playButton != nil, @"下部操作列に再生／一時停止ボタンを配置する");
        FPAssert(playButton.bordered && playButton.bezelStyle == textButton.bezelStyle, @"アイコンボタンを文字付きボタンと同じ枠付きスタイルにする");

        [delegate sequenceArea];
        delegate.asset = [AVMutableComposition composition];
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(120, 240)];
        delegate.timelineFrames = [@[
            @{@"time": @0.0, @"image": image},
            @{@"time": @1.0, @"image": image},
            @{@"time": @2.0, @"image": image}
        ] mutableCopy];
        delegate.selectedTimelineIndex = 0;
        [delegate rebuildTimeline];
        [delegate updateTime:1.6];
        FPAssert(delegate.selectedTimelineIndex == 2, @"再生時刻に最も近い下部フレームへ選択を同期する");
        FPAssert(delegate.sequence.arrangedSubviews[0].layer.borderWidth == 0 && delegate.sequence.arrangedSubviews[2].layer.borderWidth == 3, @"同期したフレームへ青枠を移動する");
        FPAssert([delegate respondsToSelector:@selector(setExplicitSeekInProgress:)], @"クリックによるシーク中と自動追従を区別する");
        delegate.explicitSeekInProgress = YES;
        [delegate updateTime:0.0];
        FPAssert(delegate.selectedTimelineIndex == 2, @"左のフレームをクリックしたシーク中は古い再生時刻で下部選択を戻さない");
        delegate.explicitSeekInProgress = NO;
        [delegate updateTime:0.0];
        FPAssert(delegate.selectedTimelineIndex == 0, @"シーク完了後は再生時刻との自動同期を再開する");

        puts("PlaybackControlsTests passed");
    }
    return 0;
}
