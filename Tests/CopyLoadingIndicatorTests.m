#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

@interface FPDelegate (CopyLoadingIndicatorTests)
- (void)setCopyLoading:(BOOL)loading;
- (void)copyCGImages:(NSArray *)cgImages toPasteboard:(NSPasteboard *)pasteboard completion:(void (^)(BOOL copied))completion;
@end

static void FPAssert(BOOL condition, NSString *message) {
    if (condition) return;
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    exit(1);
}

static NSProgressIndicator *FPFindSpinningIndicator(NSView *view) {
    if ([view isKindOfClass:NSProgressIndicator.class] && ((NSProgressIndicator *)view).style == NSProgressIndicatorStyleSpinning) return (NSProgressIndicator *)view;
    for (NSView *subview in view.subviews) {
        NSProgressIndicator *indicator = FPFindSpinningIndicator(subview);
        if (indicator) return indicator;
    }
    return nil;
}

static id FPMakeCGImage(CGFloat red) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 320, 640, 8, 320 * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, red, 0.35, 0.8, 1); CGContextFillRect(context, CGRectMake(0, 0, 320, 640));
    CGImageRef image = CGBitmapContextCreateImage(context); id value = CFBridgingRelease(image);
    CGContextRelease(context); CGColorSpaceRelease(colorSpace); return value;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        FPDelegate *delegate = [FPDelegate new];
        NSView *panel = [delegate buildSelectionPanel];
        NSProgressIndicator *indicator = FPFindSpinningIndicator(panel);

        FPAssert(indicator != nil, @"コピーボタン横にスピナーを配置する");
        FPAssert(indicator.hidden, @"初期状態ではコピースピナーを隠す");
        [delegate setCopyLoading:YES]; FPAssert(!indicator.hidden, @"コピー開始時にスピナーを表示する");
        [delegate setCopyLoading:NO]; FPAssert(indicator.hidden, @"コピー終了時にスピナーを隠す");

        NSString *pasteboardName = [@"FramePickerTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:pasteboardName];
        __block BOOL finished = NO, copied = NO, completedOnMainThread = NO;
        [delegate copyCGImages:@[FPMakeCGImage(0.2), FPMakeCGImage(0.7)] toPasteboard:pasteboard completion:^(BOOL result) { copied = result; completedOnMainThread = NSThread.isMainThread; finished = YES; }];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while (!finished && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

        FPAssert(finished && copied, @"バックグラウンド処理後にペーストボードへ書き込む");
        FPAssert(completedOnMainThread, @"ペーストボード書き込み完了をメインスレッドへ返す");
        FPAssert(indicator.hidden, @"非同期コピー完了時にスピナーを隠す");
        NSData *svgData = [pasteboard dataForType:@"public.svg-image"];
        NSString *svg = [[NSString alloc] initWithData:svgData encoding:NSUTF8StringEncoding];
        FPAssert(svgData.length > 0 && [[svg componentsSeparatedByString:@"<image "] count] - 1 == 2, @"複数画像を順序付きSVGとして書き込む");

        finished = copied = NO;
        [delegate copyCGImages:@[FPMakeCGImage(0.5)] toPasteboard:pasteboard completion:^(BOOL result) { copied = result; finished = YES; }];
        deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while (!finished && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        NSData *pngData = [pasteboard dataForType:NSPasteboardTypePNG]; NSBitmapImageRep *png = [NSBitmapImageRep imageRepWithData:pngData];
        FPAssert(copied && png.pixelsWide == 320 && png.pixelsHigh == 640, @"単一画像を元解像度のPNGとして書き込む");
        [pasteboard releaseGlobally];

        puts("CopyLoadingIndicatorTests passed");
    }
    return 0;
}
