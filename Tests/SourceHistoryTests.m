#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

@interface FPDelegate (SourceHistoryTests)
- (NSArray<NSDictionary *> *)sourceHistoryItems;
- (NSView *)sourceHistoryRow:(NSDictionary *)item index:(NSUInteger)index;
- (void)persist;
@end

static void FPAssert(BOOL condition, NSString *message) {
    if (condition) return;
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    exit(1);
}

static NSImage *FPMakeImageWithSize(NSSize size) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:size.width pixelsHigh:size.height
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    memset(rep.bitmapData, 0x7f, rep.bytesPerRow * rep.pixelsHigh);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image addRepresentation:rep];
    return image;
}

static BOOL FPViewContainsText(NSView *view, NSString *text) {
    if ([view isKindOfClass:NSTextField.class] && [[(NSTextField *)view stringValue] containsString:text]) return YES;
    if ([view isKindOfClass:NSButton.class] && [[(NSButton *)view attributedTitle].string containsString:text]) return YES;
    for (NSView *subview in view.subviews) if (FPViewContainsText(subview, text)) return YES;
    return NO;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        id previousHistory = [defaults objectForKey:@"sourceHistory.v1"];
        id previousSessions = [defaults objectForKey:@"capturedSessions.v1"];
        [defaults removeObjectForKey:@"sourceHistory.v1"];
        [defaults removeObjectForKey:@"capturedSessions.v1"];

        FPDelegate *delegate = [FPDelegate new];
        FPAssert([delegate respondsToSelector:@selector(sourceHistoryItems)], @"選択した動画の履歴を取得できる");
        FPDelegate *uiDelegate = [FPDelegate new];
        [uiDelegate outputSidebar];
        FPAssert(uiDelegate.sidebarTabs.segmentCount == 2 && [[uiDelegate.sidebarTabs labelForSegment:1] isEqualToString:@"動画履歴"], @"サイドバーは選択中と動画履歴だけを切り替えられる");
        FPAssert(!FPViewContainsText(uiDelegate.historyPanel, @"過去に選択した動画"), @"動画履歴タブと重複する見出しは表示しない");
        NSString *videoPath = @"/tmp/FramePicker Past Video.mp4";
        NSString *sourceID = [@"file:" stringByAppendingString:videoPath];
        [delegate sourceToolbar]; [delegate videoArea]; [delegate controls]; [delegate sequenceArea]; [delegate buildSelectionPanel];
        delegate.sourceID = sourceID;
        delegate.titleLabel.stringValue = @"前に選んだ動画";
        delegate.sourceLabel.stringValue = @"Macの動画 • history-sample.mp4";
        delegate.frames = [@[@{@"time": @1.0, @"image": FPMakeImageWithSize(NSMakeSize(120, 240))}] mutableCopy];
        [delegate persist];

        NSArray<NSDictionary *> *history = [delegate sourceHistoryItems];
        FPAssert(history.count == 1, @"フレームを選んだ動画を履歴へ追加する");
        FPAssert([history[0][@"title"] isEqualToString:@"前に選んだ動画"] && [history[0][@"count"] integerValue] == 1, @"履歴に動画名と選択枚数を表示できる情報を保存する");
        FPAssert([history[0][@"thumbnailData"] isKindOfClass:NSData.class] && [history[0][@"thumbnailData"] length] > 0, @"履歴に選択フレームのサムネイルを保存する");
        NSButton *portraitRow = (NSButton *)[delegate sourceHistoryRow:history[0] index:0];
        FPAssert([portraitRow isKindOfClass:NSButton.class] && NSEqualSizes(portraitRow.image.size, NSMakeSize(72, 72)), @"縦動画も固定幅のプレビューで履歴に表示する");

        NSMutableDictionary *landscapeItem = [history[0] mutableCopy];
        NSImage *landscapeImage = FPMakeImageWithSize(NSMakeSize(240, 120));
        NSBitmapImageRep *landscapeRep = [NSBitmapImageRep imageRepWithData:landscapeImage.TIFFRepresentation];
        landscapeItem[@"thumbnailData"] = [landscapeRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSButton *landscapeRow = (NSButton *)[delegate sourceHistoryRow:landscapeItem index:1];
        FPAssert([landscapeRow isKindOfClass:NSButton.class] && NSEqualSizes(landscapeRow.image.size, portraitRow.image.size), @"縦動画と横動画でタイトルの開始位置がずれない");

        NSMutableDictionary *fallbackItem = [history[0] mutableCopy];
        [fallbackItem removeObjectForKey:@"thumbnailData"];
        fallbackItem[@"timestamp"] = @1700000000;
        NSButton *fallbackRow = (NSButton *)[delegate sourceHistoryRow:fallbackItem index:0];
        FPAssert([fallbackRow isKindOfClass:NSButton.class] && NSEqualSizes(fallbackRow.image.size, NSMakeSize(72, 72)), @"サムネイルがない履歴も同じ位置にプレースホルダーを表示する");
        FPAssert([fallbackRow.attributedTitle.string containsString:@"2023"], @"サムネイルがない履歴は操作日時を枚数と同じメタ情報として表示する");

        delegate.frames = [NSMutableArray array];
        [delegate persist];
        FPAssert([delegate sourceHistoryItems].count == 0, @"選択フレームがなくなった動画は履歴に表示しない");

        [defaults setObject:@{sourceID: @[@0.5]} forKey:@"capturedSessions.v1"];
        history = [delegate sourceHistoryItems];
        FPAssert(history.count == 1 && [history[0][@"sourceID"] isEqualToString:sourceID], @"既存の選択履歴も過去の動画として表示する");

        if (previousHistory) [defaults setObject:previousHistory forKey:@"sourceHistory.v1"]; else [defaults removeObjectForKey:@"sourceHistory.v1"];
        if (previousSessions) [defaults setObject:previousSessions forKey:@"capturedSessions.v1"]; else [defaults removeObjectForKey:@"capturedSessions.v1"];
        puts("SourceHistoryTests passed");
    }
    return 0;
}
