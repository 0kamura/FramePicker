#import <AVKit/AVKit.h>
#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

@interface FPDelegate (SourceResetTests)
- (NSAlert *)resetConfirmationAlert;
- (void)handleResetConfirmationResponse:(NSModalResponse)response;
- (void)rememberLastSessionForSourceID:(NSString *)sourceID photoID:(NSString *)photoID;
- (NSDictionary *)lastSessionDescriptor;
- (void)resetSource:(id)sender;
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
        id previousLastSession = [NSUserDefaults.standardUserDefaults objectForKey:@"lastSession.v1"];
        FPDelegate *delegate = [FPDelegate new];
        NSView *toolbar = [delegate sourceToolbar];
        [delegate videoArea];
        [delegate controls];
        [delegate sequenceArea];
        [delegate buildSelectionPanel];

        NSButton *resetButton = FPFindButtonWithAction(toolbar, @selector(requestResetSource:));
        NSButton *finderButton = FPFindButtonWithAction(toolbar, @selector(openLocal:));
        FPAssert(resetButton != nil, @"動画ツールバーにリセットボタンを配置する");
        FPAssert(resetButton.title.length == 0, @"リセットボタンに文字を表示しない");
        FPAssert(resetButton.image != nil, @"リセットボタンをアイコンで表示する");
        FPAssert(resetButton.bordered && resetButton.bezelStyle == finderButton.bezelStyle, @"リセットを他のツールバーボタンと同じ枠付きスタイルにする");
        FPAssert(!resetButton.enabled, @"動画未読込時はリセットを無効にする");
        NSAlert *alert = [delegate resetConfirmationAlert];
        FPAssert([alert.messageText isEqualToString:@"動画をリセットしますか？"], @"リセット前に確認内容を示す");
        FPAssert(alert.buttons.count == 2 && [alert.buttons[0].title isEqualToString:@"リセット"] && [alert.buttons[1].title isEqualToString:@"キャンセル"], @"リセットとキャンセルを選べるようにする");

        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(120, 240)];
        delegate.asset = [AVMutableComposition composition];
        delegate.sourceID = @"file:/tmp/example.mov";
        delegate.photoAssetID = @"photo-id";
        delegate.duration = 12;
        delegate.frames = [@[@{@"time": @1, @"image": image}] mutableCopy];
        delegate.timelineFrames = [@[@{@"time": @0, @"image": image}] mutableCopy];
        delegate.selectedTimelineIndex = 0;
        delegate.selectedCapturedIndex = 0;
        [delegate.selectedCapturedIndexes addIndex:0];
        delegate.titleLabel.stringValue = @"example";
        delegate.sourceLabel.stringValue = @"Macの動画 • example.mov";
        delegate.playerView.hidden = NO;
        delegate.emptyLabel.hidden = YES;
        delegate.slider.maxValue = 12;
        delegate.slider.doubleValue = 4;
        delegate.timeLabel.stringValue = @"00:04 / 00:12";
        resetButton.enabled = YES;
        [delegate rememberLastSessionForSourceID:delegate.sourceID photoID:nil];

        [delegate handleResetConfirmationResponse:NSAlertSecondButtonReturn];
        FPAssert(delegate.asset != nil && delegate.frames.count == 1, @"キャンセル時は読み込んだ状態を維持する");
        [delegate handleResetConfirmationResponse:NSAlertFirstButtonReturn];

        FPAssert(delegate.asset == nil, @"リセット後は読み込んだ動画を解除する");
        FPAssert(delegate.sourceID == nil && delegate.photoAssetID == nil, @"リセット後は動画の識別情報を解除する");
        FPAssert(delegate.frames.count == 0 && delegate.timelineFrames.count == 0, @"リセット後は現在セッションのフレームを画面から消す");
        FPAssert(delegate.selectedTimelineIndex == NSNotFound && delegate.selectedCapturedIndex == NSNotFound && delegate.selectedCapturedIndexes.count == 0, @"リセット後は選択状態を解除する");
        FPAssert(delegate.playerView.hidden && !delegate.emptyLabel.hidden, @"リセット後は動画選択前の表示へ戻す");
        FPAssert([delegate.titleLabel.stringValue isEqualToString:@"動画を選択"], @"リセット後は初期タイトルへ戻す");
        FPAssert([delegate.sourceLabel.stringValue isEqualToString:@"iPhone / Mac 両対応"], @"リセット後は初期説明へ戻す");
        FPAssert(delegate.slider.maxValue == 1 && delegate.slider.doubleValue == 0, @"リセット後は再生位置を初期化する");
        FPAssert([delegate.timeLabel.stringValue isEqualToString:@"00:00 / 00:00"], @"リセット後は時間表示を初期化する");
        FPAssert(!resetButton.enabled, @"リセット後は再度リセットできない状態にする");
        FPAssert([delegate lastSessionDescriptor] == nil, @"リセット後は次回起動時に動画を復元しない");

        if (previousLastSession) [NSUserDefaults.standardUserDefaults setObject:previousLastSession forKey:@"lastSession.v1"];

        puts("SourceResetTests passed");
    }
    return 0;
}
