#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

@interface FPDelegate (SourceLoadingIndicatorTests)
- (void)setSourceLoading:(BOOL)loading;
@end

static void FPAssert(BOOL condition, NSString *message) {
    if (condition) return;
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    exit(1);
}

static NSProgressIndicator *FPFindProgressIndicator(NSView *view) {
    if ([view isKindOfClass:NSProgressIndicator.class]) return (NSProgressIndicator *)view;
    for (NSView *subview in view.subviews) {
        NSProgressIndicator *indicator = FPFindProgressIndicator(subview);
        if (indicator) return indicator;
    }
    return nil;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        FPDelegate *delegate = [FPDelegate new];
        NSView *toolbar = [delegate sourceToolbar];
        NSProgressIndicator *indicator = FPFindProgressIndicator(toolbar);

        FPAssert(indicator != nil, @"動画ソース用スピナーをツールバーに配置する");
        FPAssert(indicator.style == NSProgressIndicatorStyleSpinning, @"小さいスピナーを使用する");
        FPAssert(indicator.hidden, @"初期状態ではスピナーを隠す");

        [delegate setSourceLoading:YES];
        FPAssert(!indicator.hidden, @"取得開始時にスピナーを表示する");

        [delegate setSourceLoading:NO];
        FPAssert(indicator.hidden, @"取得終了時にスピナーを隠す");

        puts("SourceLoadingIndicatorTests passed");
    }
    return 0;
}
