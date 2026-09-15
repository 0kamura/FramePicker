#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

@interface FPDelegate (TimelineCapturedIndicatorTests)
- (void)appendTimelineFrames:(NSArray<NSDictionary *> *)frames;
@end

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
        [delegate buildSelectionPanel]; [delegate sequenceArea];
        FPAssert(delegate.densityControl.segmentCount == 4, @"フレーム密度は4段階から選べる");
        FPAssert([[delegate.densityControl labelForSegment:0] isEqualToString:@"8"] && [[delegate.densityControl labelForSegment:1] isEqualToString:@"12"] && [[delegate.densityControl labelForSegment:2] isEqualToString:@"24"] && [[delegate.densityControl labelForSegment:3] isEqualToString:@"48 fps"], @"4 fpsを外して48 fpsを追加する");
        FPAssert(delegate.sampleFPS == 8 && delegate.densityControl.selectedSegment == 0, @"初期値は8 fpsを維持する");
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

        NSView *firstCard = delegate.sequence.arrangedSubviews.firstObject;
        NSImage *additionalImage = [[NSImage alloc] initWithSize:NSMakeSize(120, 240)];
        FPAssert([delegate respondsToSelector:@selector(appendTimelineFrames:)], @"生成済みフレームを差分追加できる");
        [delegate appendTimelineFrames:@[@{@"time": @3.0, @"image": additionalImage}]];
        FPAssert(delegate.timelineFrames.count == 4 && delegate.sequence.arrangedSubviews.count == 4, @"追加生成したサムネイルだけを末尾へ表示する");
        FPAssert(delegate.sequence.arrangedSubviews.firstObject == firstCard, @"追加時に既存サムネイルを作り直さない");

        [delegate rebuild];
        FPHoverCardView *selectedCard = (FPHoverCardView *)delegate.selectedStack.arrangedSubviews.firstObject;
        NSButton *moveUpButton = FPFindButtonWithAction(selectedCard, @selector(up:));
        NSButton *singleCopyButton = FPFindButtonWithAction(selectedCard, @selector(copyFrame:));
        NSColor *overlayColor = [[NSColor colorWithCGColor:selectedCard.controls.layer.backgroundColor] colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
        FPAssert(moveUpButton.fittingSize.width >= 40 && moveUpButton.fittingSize.height >= 40, @"選択フレームの操作ボタンを約160%へ拡大する");
        FPAssert(overlayColor.redComponent < .5 && overlayColor.alphaComponent >= .16, @"ホバー操作背景を今までより濃く表示する");
        FPAssert(singleCopyButton != nil && [singleCopyButton.toolTip isEqualToString:@"このフレームだけコピー"], @"左の選択フレーム操作に単体コピーボタンを表示する");
        NSButton *selectCapturedButton = FPFindButtonWithAction(selectedCard, @selector(selectCaptured:));
        [delegate selectCaptured:selectCapturedButton];
        FPAssert(delegate.selectedTimelineIndex == 1, @"左の選択フレームをクリックしたら下部の対応フレームへ移動する");

        [delegate.frames removeAllObjects]; [delegate rebuild];
        FPAssert(FPFindVisibleLabel(delegate.sequence.arrangedSubviews[1], @"選択中") == nil, @"選択中フレームから削除したら表示を消す");

        puts("TimelineCapturedIndicatorTests passed");
    }
    return 0;
}
