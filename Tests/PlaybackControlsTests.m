#import <AVKit/AVKit.h>
#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

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
        FPAssert(FPFindButtonWithAction(controls, @selector(togglePlayback:)) != nil, @"下部操作列に再生／一時停止ボタンを配置する");

        puts("PlaybackControlsTests passed");
    }
    return 0;
}
