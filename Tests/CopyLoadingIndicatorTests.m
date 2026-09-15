#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

@interface FPDelegate (CopyLoadingIndicatorTests)
- (void)setCopyLoading:(BOOL)loading;
- (void)copyCGImages:(NSArray *)cgImages toPasteboard:(NSPasteboard *)pasteboard completion:(void (^)(BOOL copied))completion;
- (void)copyFrameAtIndex:(NSUInteger)index toPasteboard:(NSPasteboard *)pasteboard completion:(void (^)(BOOL copied))completion;
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

static NSImage *FPMakeNSImage(size_t width, size_t height, CGFloat red) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, red, 0.35, 0.8, 1); CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGImageRef cgImage = CGBitmapContextCreateImage(context); NSImage *image = [[NSImage alloc] initWithCGImage:cgImage size:NSZeroSize];
    CGImageRelease(cgImage); CGContextRelease(context); CGColorSpaceRelease(colorSpace); return image;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        FPDelegate *delegate = [FPDelegate new];
        NSView *panel = [delegate buildSelectionPanel];
        NSProgressIndicator *indicator = FPFindSpinningIndicator(panel);

        FPAssert(indicator != nil && indicator.superview == delegate.clipboardButton, @"コピーボタンの中にスピナーを配置する");
        FPAssert(indicator.hidden, @"初期状態ではコピースピナーを隠す");
        NSSize buttonSize = delegate.clipboardButton.fittingSize;
        [delegate setCopyLoading:YES]; FPAssert(!indicator.hidden, @"コピー開始時にスピナーを表示する");
        FPAssert(NSEqualSizes(buttonSize, delegate.clipboardButton.fittingSize), @"ローディング中もコピーボタンのサイズを維持する");
        [delegate setCopyLoading:NO]; FPAssert(indicator.hidden, @"コピー終了時にスピナーを隠す");

        NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
        __block BOOL finished = NO, copied = NO, completedOnMainThread = NO;
        NSMutableArray *twelveImages = [NSMutableArray array]; for (NSInteger index = 0; index < 12; index++) [twelveImages addObject:FPMakeCGImage(index / 12.0)];
        [delegate copyCGImages:twelveImages toPasteboard:pasteboard completion:^(BOOL result) { copied = result; completedOnMainThread = NSThread.isMainThread; finished = YES; }];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while (!finished && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

        FPAssert(finished && copied, @"バックグラウンド処理後にペーストボードへ書き込む");
        FPAssert(completedOnMainThread, @"ペーストボード書き込み完了をメインスレッドへ返す");
        FPAssert(indicator.hidden, @"非同期コピー完了時にスピナーを隠す");
        NSArray<NSPasteboardItem *> *items = pasteboard.pasteboardItems;
        FPAssert(items.count == 12, @"12枚を別々のクリップボード項目として書き込む");
        FPAssert([items[0] dataForType:NSPasteboardTypePNG].length > 0 && [items[11] dataForType:NSPasteboardTypePNG].length > 0, @"12枚すべてを標準PNGとして書き込む");
        NSArray<NSURL *> *fileURLs = [pasteboard readObjectsForClasses:@[NSURL.class] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
        FPAssert(fileURLs.count == 12, @"貼り付け先が12枚をファイルとして受け取れる");
        FPAssert([fileURLs[0].lastPathComponent isEqualToString:@"001.png"] && [fileURLs[11].lastPathComponent isEqualToString:@"012.png"], @"選択フレームの順番を連番PNGで保つ");
        FPAssert([NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfURL:fileURLs[0]]].pixelsWide == 320 && [NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfURL:fileURLs[11]]].pixelsWide == 320, @"複数ファイル表現も元解像度のPNGを参照する");
        FPAssert([pasteboard dataForType:@"public.svg-image"] == nil, @"複数画像をFigma専用のSVGに変換しない");

        finished = copied = NO;
        [delegate copyCGImages:@[FPMakeCGImage(0.5)] toPasteboard:pasteboard completion:^(BOOL result) { copied = result; finished = YES; }];
        deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while (!finished && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        NSData *pngData = [pasteboard dataForType:NSPasteboardTypePNG]; NSBitmapImageRep *png = [NSBitmapImageRep imageRepWithData:pngData];
        FPAssert(copied && png.pixelsWide == 320 && png.pixelsHigh == 640, @"単一画像を元解像度のPNGとして書き込む");

        delegate.frames = [@[
            @{@"time": @0, @"image": FPMakeNSImage(160, 320, 0.2)},
            @{@"time": @1, @"image": FPMakeNSImage(360, 720, 0.8)}
        ] mutableCopy];
        FPAssert([delegate respondsToSelector:@selector(copyFrameAtIndex:toPasteboard:completion:)], @"左のカードから単体コピーできる");
        finished = copied = NO;
        [delegate copyFrameAtIndex:1 toPasteboard:pasteboard completion:^(BOOL result) { copied = result; finished = YES; }];
        deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while (!finished && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        pngData = [pasteboard dataForType:NSPasteboardTypePNG]; png = [NSBitmapImageRep imageRepWithData:pngData];
        FPAssert(copied && png.pixelsWide == 360 && png.pixelsHigh == 720, @"指定した選択フレーム1枚だけを元解像度でコピーする");
        [pasteboard releaseGlobally];
        if (fileURLs.count) [NSFileManager.defaultManager removeItemAtURL:fileURLs.firstObject.URLByDeletingLastPathComponent error:nil];

        puts("CopyLoadingIndicatorTests passed");
    }
    return 0;
}
