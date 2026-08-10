#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

static void FPAssert(BOOL condition, NSString *message) {
    if (condition) return;
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    exit(1);
}

static NSTextField *FPFindVisibleLabel(NSView *view, NSString *text) {
    if (view.hidden) return nil;
    if ([view isKindOfClass:NSTextField.class] && [((NSTextField *)view).stringValue isEqualToString:text]) return (NSTextField *)view;
    for (NSView *subview in view.subviews) {
        NSTextField *label = FPFindVisibleLabel(subview, text);
        if (label) return label;
    }
    return nil;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        FPDelegate *delegate = [FPDelegate new];
        [delegate buildSelectionPanel]; [delegate sequenceArea];
        delegate.asset = [AVMutableComposition composition];
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(120, 240)];
        delegate.timelineFrames = [@[
            @{@"time": @0.0, @"image": image},
            @{@"time": @1.0, @"image": image},
            @{@"time": @2.0, @"image": image}
        ] mutableCopy];
        delegate.frames = [@[@{@"time": @1.1, @"image": image}] mutableCopy];
        delegate.selectedTimelineIndex = 2;
        [delegate rebuildTimeline];

        FPAssert(FPFindVisibleLabel(delegate.sequence.arrangedSubviews[0], @"選択中") == nil, @"未追加フレームには選択中表示を出さない");
        NSTextField *selectedLabel = FPFindVisibleLabel(delegate.sequence.arrangedSubviews[1], @"選択中");
        FPAssert(selectedLabel != nil, @"選択中フレームに最も近いサムネイルへ表示する");
        FPAssert([selectedLabel.textColor isEqual:NSColor.systemBlueColor], @"選択中文字を青にする");
        FPAssert(!selectedLabel.wantsLayer || selectedLabel.layer.backgroundColor == nil, @"選択中文字の背景を付けない");
        FPAssert(delegate.sequence.arrangedSubviews[1].layer.borderWidth == 0, @"選択中表示を現在位置の青枠と区別する");
        FPAssert(delegate.sequence.arrangedSubviews[2].layer.borderWidth == 3, @"現在位置の青枠を維持する");

        [delegate.frames removeAllObjects]; [delegate rebuild];
        FPAssert(FPFindVisibleLabel(delegate.sequence.arrangedSubviews[1], @"選択中") == nil, @"選択中フレームから削除したら表示を消す");

        puts("TimelineCapturedIndicatorTests passed");
    }
    return 0;
}
