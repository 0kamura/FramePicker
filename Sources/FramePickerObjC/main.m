#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Cocoa/Cocoa.h>
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <float.h>
#import "ClipboardEncoder.h"
#import "LatestVideoRequest.h"

@interface FPPaddedButton : NSButton
@property NSString *instantToolTipText;
@property NSPopover *instantToolTipPopover;
@property id instantToolTipMouseMonitor;
@property BOOL instantToolTipPointerInside;
- (void)showInstantToolTip;
- (void)hideInstantToolTip;
@end

@implementation FPPaddedButton
- (NSSize)intrinsicContentSize {
    NSSize size = [super intrinsicContentSize];
    if (size.height != NSViewNoIntrinsicMetric) size.height += 8;
    return size;
}
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow]; if (self.instantToolTipMouseMonitor) { [NSEvent removeMonitor:self.instantToolTipMouseMonitor]; self.instantToolTipMouseMonitor = nil; }
    if (!self.window || !self.instantToolTipText.length) return; self.window.acceptsMouseMovedEvents = YES; __weak typeof(self) weak = self;
    self.instantToolTipMouseMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskMouseMoved handler:^NSEvent *(NSEvent *event) { typeof(self) strong = weak; if (!strong || event.window != strong.window) return event; NSPoint point = [strong convertPoint:event.locationInWindow fromView:nil]; BOOL inside = NSPointInRect(point, strong.bounds) && !strong.hiddenOrHasHiddenAncestor; if (inside && !strong.instantToolTipPointerInside) { strong.instantToolTipPointerInside = YES; [strong showInstantToolTip]; } else if (!inside && strong.instantToolTipPointerInside) { strong.instantToolTipPointerInside = NO; [strong hideInstantToolTip]; } return event; }];
}
- (void)showInstantToolTip {
    if (!self.instantToolTipText.length || self.instantToolTipPopover.shown) return;
    NSTextField *label = [NSTextField labelWithString:self.instantToolTipText]; label.font = [NSFont systemFontOfSize:11]; [label sizeToFit];
    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, label.frame.size.width + 16, label.frame.size.height + 10)]; label.frame = NSMakeRect(8, 5, label.frame.size.width, label.frame.size.height); [content addSubview:label];
    NSViewController *controller = [NSViewController new]; controller.view = content; NSPopover *popover = [NSPopover new]; popover.animates = NO; popover.behavior = NSPopoverBehaviorTransient; popover.contentSize = content.frame.size; popover.contentViewController = controller; self.instantToolTipPopover = popover;
    [popover showRelativeToRect:self.bounds ofView:self preferredEdge:NSRectEdgeMinY];
}
- (void)hideInstantToolTip { [self.instantToolTipPopover close]; self.instantToolTipPopover = nil; }
- (void)dealloc { if (self.instantToolTipMouseMonitor) [NSEvent removeMonitor:self.instantToolTipMouseMonitor]; }
@end

@interface FPDropView : NSView <NSDraggingDestination>
@property (copy) void (^onURL)(NSURL *);
@property BOOL targeted;
@end

@implementation FPDropView
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    return self;
}
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender { self.targeted = YES; self.needsDisplay = YES; return NSDragOperationCopy; }
- (void)draggingExited:(id<NSDraggingInfo>)sender { self.targeted = NO; self.needsDisplay = YES; }
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    self.targeted = NO; self.needsDisplay = YES;
    NSURL *url = [NSURL URLFromPasteboard:sender.draggingPasteboard];
    if (url && self.onURL) { self.onURL(url); return YES; }
    return NO;
}
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (!self.targeted) return;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 16, 16) xRadius:12 yRadius:12];
    CGFloat dash[] = {10, 6}; [path setLineDash:dash count:2 phase:0]; path.lineWidth = 4;
    [NSColor.systemBlueColor setStroke]; [path stroke];
}
@end

@interface FPFlippedView : NSView
@end

@implementation FPFlippedView
- (BOOL)isFlipped { return YES; }
@end

@interface FPHoverCardView : NSView
@property NSView *controls;
@property NSTrackingArea *hoverTrackingArea;
@end

@implementation FPHoverCardView
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.wantsLayer = YES;
        self.layer.cornerRadius = 6;
        self.layer.backgroundColor = NSColor.clearColor.CGColor;
    }
    return self;
}
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.hoverTrackingArea) [self removeTrackingArea:self.hoverTrackingArea];
    self.hoverTrackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways owner:self userInfo:nil];
    [self addTrackingArea:self.hoverTrackingArea];
}
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self updateTrackingAreas];
}
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseEntered:(NSEvent *)event {
    self.controls.hidden = NO;
}
- (void)mouseExited:(NSEvent *)event {
    self.controls.hidden = YES;
}
@end

@interface FPDelegate : NSObject <NSApplicationDelegate, PHPhotoLibraryChangeObserver>
@property NSWindow *window;
@property AVPlayer *player;
@property AVPlayerView *playerView;
@property AVAsset *asset;
@property id timeObserver;
@property NSMutableArray<NSDictionary *> *frames;
@property NSMutableArray<NSDictionary *> *timelineFrames;
@property NSMutableArray<NSDictionary *> *exportHistory;
@property NSString *sourceID;
@property NSString *photoAssetID;
@property double duration;
@property NSTextField *titleLabel, *sourceLabel, *emptyLabel, *countLabel, *timeLabel, *statusLabel, *timelineCaption;
@property NSSlider *slider;
@property NSSegmentedControl *densityControl;
@property NSButton *exportButton, *clipboardButton, *finderButton, *playPauseButton;
@property NSProgressIndicator *progress;
@property NSProgressIndicator *sourceLoadingIndicator;
@property NSProgressIndicator *clipboardLoadingIndicator;
@property NSStackView *selectedStack, *sequence, *historyStack;
@property NSScrollView *timelineScroll;
@property NSView *selectionPanel, *historyPanel;
@property NSSegmentedControl *sidebarTabs;
@property NSInteger selectedTimelineIndex;
@property NSInteger selectedCapturedIndex;
@property NSMutableIndexSet *selectedCapturedIndexes;
@property NSUInteger timelineGeneration;
@property NSUInteger latestVideoRequestGeneration;
@property NSUInteger latestVideoActivityGeneration;
@property PHImageRequestID latestVideoRequestID;
@property BOOL copyInProgress;
@property NSInteger sampleFPS;
@property id keyMonitor;
@property NSPanel *confirmationPanel;
@property NSURL *outputURL;
@end

@implementation FPDelegate

- (instancetype)init {
    if ((self = [super init])) { _frames = [NSMutableArray array]; _timelineFrames = [NSMutableArray array]; _exportHistory = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"exportHistory.v1"] mutableCopy] ?: [NSMutableArray array]; _selectedTimelineIndex = NSNotFound; _selectedCapturedIndex = NSNotFound; _selectedCapturedIndexes = [NSMutableIndexSet indexSet]; _sampleFPS = 8; _player = [AVPlayer playerWithPlayerItem:nil]; }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    [self buildWindow];
    __weak typeof(self) weak = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 30) queue:dispatch_get_main_queue() usingBlock:^(CMTime t) {
        [weak updateTime:CMTimeGetSeconds(t)];
        [weak updatePlaybackButton];
    }];
    self.keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        NSEventModifierFlags modifiers = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
        if (event.keyCode == 8 && !(modifiers & NSEventModifierFlagOption) && (modifiers & (NSEventModifierFlagCommand|NSEventModifierFlagControl))) {
            [weak copySelectedFrames:nil];
            return nil;
        }
        if (modifiers & (NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl)) return event;
        if (event.keyCode == 123) { [weak moveTimelineSelectionBy:-1]; return nil; }
        if (event.keyCode == 124) { [weak moveTimelineSelectionBy:1]; return nil; }
        return event;
    }];
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (void)applicationWillTerminate:(NSNotification *)note {
    if (self.timeObserver) [self.player removeTimeObserver:self.timeObserver];
    if (self.keyMonitor) [NSEvent removeMonitor:self.keyMonitor];
    if (self.latestVideoRequestID != PHInvalidImageRequestID) [[PHImageManager defaultManager] cancelImageRequest:self.latestVideoRequestID];
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
- (void)application:(NSApplication *)sender openURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (url) [self loadLocalURL:url];
}

- (NSTextField *)label:(NSString *)text size:(CGFloat)size weight:(NSFontWeight)weight {
    NSTextField *v = [NSTextField labelWithString:text];
    v.font = [NSFont systemFontOfSize:size weight:weight];
    return v;
}
- (NSButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    NSButton *v = [FPPaddedButton buttonWithTitle:title target:self action:action];
    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    if (image) { v.image = image; v.imagePosition = NSImageLeading; }
    return v;
}
- (NSButton *)icon:(NSString *)symbol action:(SEL)action help:(NSString *)help {
    FPPaddedButton *v = [FPPaddedButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:help] target:self action:action];
    v.bezelStyle = NSBezelStyleInline; v.toolTip = help; return v;
}

- (void)buildWindow {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1180, 760)
                                              styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"FramePicker"; self.window.minSize = NSMakeSize(980, 680); [self.window center];
    NSSplitView *split = [[NSSplitView alloc] initWithFrame:self.window.contentView.bounds];
    split.vertical = YES; split.dividerStyle = NSSplitViewDividerStyleThin; split.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    NSView *sidebar = [self outputSidebar]; NSView *workspace = [self workspace];
    [split addArrangedSubview:sidebar]; [split addArrangedSubview:workspace];
    [sidebar.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
    [sidebar.widthAnchor constraintLessThanOrEqualToConstant:280].active = YES;
    self.window.contentView = split; [split setPosition:240 ofDividerAtIndex:0];
}

- (NSView *)outputSidebar {
    NSView *v = [NSView new]; v.wantsLayer = YES; v.layer.backgroundColor = NSColor.controlBackgroundColor.CGColor;
    self.sidebarTabs = [NSSegmentedControl segmentedControlWithLabels:@[@"書き出し", @"出力済み"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(sidebarTabChanged:)]; self.sidebarTabs.selectedSegment = 0; self.sidebarTabs.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionPanel = [self buildSelectionPanel]; self.historyPanel = [self buildHistoryPanel]; self.historyPanel.hidden = YES;
    for (NSView *panel in @[self.selectionPanel, self.historyPanel]) { panel.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:panel]; }
    [v addSubview:self.sidebarTabs];
    [NSLayoutConstraint activateConstraints:@[
        [self.sidebarTabs.topAnchor constraintEqualToAnchor:v.topAnchor constant:16], [self.sidebarTabs.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16], [self.sidebarTabs.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-16],
        [self.selectionPanel.topAnchor constraintEqualToAnchor:self.sidebarTabs.bottomAnchor constant:12], [self.selectionPanel.leadingAnchor constraintEqualToAnchor:v.leadingAnchor], [self.selectionPanel.trailingAnchor constraintEqualToAnchor:v.trailingAnchor], [self.selectionPanel.bottomAnchor constraintEqualToAnchor:v.bottomAnchor],
        [self.historyPanel.topAnchor constraintEqualToAnchor:self.selectionPanel.topAnchor], [self.historyPanel.leadingAnchor constraintEqualToAnchor:v.leadingAnchor], [self.historyPanel.trailingAnchor constraintEqualToAnchor:v.trailingAnchor], [self.historyPanel.bottomAnchor constraintEqualToAnchor:v.bottomAnchor]
    ]];
    return v;
}

- (NSView *)buildSelectionPanel {
    NSView *v = [NSView new];
    NSTextField *heading = [self label:@"選択フレーム" size:18 weight:NSFontWeightSemibold];
    self.countLabel = [self label:@"0枚" size:12 weight:NSFontWeightRegular]; self.countLabel.textColor = NSColor.secondaryLabelColor;
    self.clipboardButton = [self icon:@"doc.on.doc" action:@selector(copyAllFrames:) help:@"すべてクリップボードにコピー"]; self.clipboardButton.toolTip = nil; ((FPPaddedButton *)self.clipboardButton).instantToolTipText = @"すべてクリップボードにコピー"; self.clipboardButton.enabled = NO;
    self.clipboardLoadingIndicator = [NSProgressIndicator new]; self.clipboardLoadingIndicator.style = NSProgressIndicatorStyleSpinning; self.clipboardLoadingIndicator.controlSize = NSControlSizeSmall; self.clipboardLoadingIndicator.indeterminate = YES; self.clipboardLoadingIndicator.hidden = YES;
    self.exportButton = [self button:@"PNGを書き出す" symbol:@"square.and.arrow.down" action:@selector(exportFrames:)]; self.exportButton.enabled = NO;
    NSStackView *summary = [NSStackView stackViewWithViews:@[self.countLabel, [NSView new], self.clipboardLoadingIndicator, self.clipboardButton, self.exportButton]]; summary.alignment = NSLayoutAttributeCenterY; summary.spacing = 6; summary.translatesAutoresizingMaskIntoConstraints = NO;
    self.progress = [NSProgressIndicator new]; self.progress.indeterminate = NO; self.progress.minValue = 0; self.progress.maxValue = 1; self.progress.hidden = YES; self.progress.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectedStack = [NSStackView new]; self.selectedStack.orientation = NSUserInterfaceLayoutOrientationVertical; self.selectedStack.alignment = NSLayoutAttributeCenterX; self.selectedStack.spacing = 10; self.selectedStack.edgeInsets = NSEdgeInsetsMake(4, 4, 4, 4); self.selectedStack.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *doc = [FPFlippedView new]; doc.translatesAutoresizingMaskIntoConstraints = NO; [doc addSubview:self.selectedStack];
    NSScrollView *scroll = [NSScrollView new]; scroll.documentView = doc; scroll.hasVerticalScroller = YES; scroll.drawsBackground = NO; scroll.translatesAutoresizingMaskIntoConstraints = NO;
    heading.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:heading]; [v addSubview:summary]; [v addSubview:self.progress]; [v addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [heading.topAnchor constraintEqualToAnchor:v.topAnchor], [heading.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16],
        [summary.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:6], [summary.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16], [summary.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-16],
        [self.progress.topAnchor constraintEqualToAnchor:summary.bottomAnchor constant:6], [self.progress.leadingAnchor constraintEqualToAnchor:summary.leadingAnchor], [self.progress.trailingAnchor constraintEqualToAnchor:summary.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.progress.bottomAnchor constant:6], [scroll.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:8], [scroll.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-8], [scroll.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-8],
        [self.selectedStack.topAnchor constraintEqualToAnchor:doc.topAnchor], [self.selectedStack.leadingAnchor constraintEqualToAnchor:doc.leadingAnchor], [self.selectedStack.trailingAnchor constraintEqualToAnchor:doc.trailingAnchor], [self.selectedStack.bottomAnchor constraintEqualToAnchor:doc.bottomAnchor], [doc.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor]
    ]]; [self rebuild]; return v;
}

- (NSView *)buildHistoryPanel {
    NSView *v = [NSView new]; NSTextField *heading = [self label:@"出力済み" size:18 weight:NSFontWeightSemibold]; heading.translatesAutoresizingMaskIntoConstraints = NO;
    self.historyStack = [NSStackView new]; self.historyStack.orientation = NSUserInterfaceLayoutOrientationVertical; self.historyStack.alignment = NSLayoutAttributeLeading; self.historyStack.spacing = 8; self.historyStack.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *doc = [FPFlippedView new]; doc.translatesAutoresizingMaskIntoConstraints = NO; [doc addSubview:self.historyStack]; NSScrollView *scroll = [NSScrollView new]; scroll.documentView = doc; scroll.hasVerticalScroller = YES; scroll.drawsBackground = NO; scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:heading]; [v addSubview:scroll]; [NSLayoutConstraint activateConstraints:@[[heading.topAnchor constraintEqualToAnchor:v.topAnchor], [heading.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16], [scroll.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:10], [scroll.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:8], [scroll.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-8], [scroll.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-8], [self.historyStack.topAnchor constraintEqualToAnchor:doc.topAnchor], [self.historyStack.leadingAnchor constraintEqualToAnchor:doc.leadingAnchor], [self.historyStack.trailingAnchor constraintEqualToAnchor:doc.trailingAnchor], [self.historyStack.bottomAnchor constraintEqualToAnchor:doc.bottomAnchor], [doc.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor]]]; [self rebuildHistory]; return v;
}

- (void)sidebarTabChanged:(NSSegmentedControl *)sender { BOOL history = sender.selectedSegment == 1; self.selectionPanel.hidden = history; self.historyPanel.hidden = !history; if (history) [self rebuildHistory]; }

- (NSView *)workspace {
    NSView *v = [NSView new]; v.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *toolbar = [self sourceToolbar]; FPDropView *video = [self videoArea]; NSView *controls = [self controls]; NSView *sequence = [self sequenceArea];
    NSStackView *stack = [NSStackView stackViewWithViews:@[toolbar, video, controls, sequence]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical; stack.spacing = 0; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:v.topAnchor], [stack.leadingAnchor constraintEqualToAnchor:v.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:v.trailingAnchor], [stack.bottomAnchor constraintEqualToAnchor:v.bottomAnchor],
        [toolbar.widthAnchor constraintEqualToAnchor:stack.widthAnchor], [toolbar.heightAnchor constraintEqualToConstant:64],
        [video.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [controls.widthAnchor constraintEqualToAnchor:stack.widthAnchor], [controls.heightAnchor constraintEqualToConstant:54],
        [sequence.widthAnchor constraintEqualToAnchor:stack.widthAnchor], [sequence.heightAnchor constraintEqualToConstant:188]
    ]]; return v;
}

- (NSView *)sourceToolbar {
    NSView *v = [NSView new]; v.wantsLayer = YES; v.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
    self.titleLabel = [self label:@"動画を選択" size:14 weight:NSFontWeightSemibold];
    self.sourceLabel = [self label:@"iPhone / Mac 両対応" size:11 weight:NSFontWeightRegular]; self.sourceLabel.textColor = NSColor.secondaryLabelColor;
    self.sourceLoadingIndicator = [NSProgressIndicator new]; self.sourceLoadingIndicator.style = NSProgressIndicatorStyleSpinning; self.sourceLoadingIndicator.controlSize = NSControlSizeSmall; self.sourceLoadingIndicator.indeterminate = YES; self.sourceLoadingIndicator.hidden = YES;
    NSStackView *sourceStatus = [NSStackView stackViewWithViews:@[self.sourceLoadingIndicator, self.sourceLabel]]; sourceStatus.alignment = NSLayoutAttributeCenterY; sourceStatus.spacing = 5;
    NSStackView *labels = [NSStackView stackViewWithViews:@[self.titleLabel, sourceStatus]]; labels.orientation = NSUserInterfaceLayoutOrientationVertical; labels.alignment = NSLayoutAttributeLeading; labels.spacing = 2;
    NSStackView *actions = [NSStackView stackViewWithViews:@[[self button:@"iPhoneの最新録画" symbol:@"iphone" action:@selector(openLatest:)], [self button:@"Macの最新動画" symbol:@"macbook" action:@selector(openLatestMac:)], [self button:@"Finderで選択" symbol:@"folder" action:@selector(openLocal:)]]]; actions.spacing = 10;
    labels.translatesAutoresizingMaskIntoConstraints = NO; actions.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:labels]; [v addSubview:actions];
    [NSLayoutConstraint activateConstraints:@[[labels.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16], [labels.centerYAnchor constraintEqualToAnchor:v.centerYAnchor], [actions.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-16], [actions.centerYAnchor constraintEqualToAnchor:v.centerYAnchor], [labels.trailingAnchor constraintLessThanOrEqualToAnchor:actions.leadingAnchor constant:-12]]]; return v;
}

- (void)setSourceLoading:(BOOL)loading {
    if (!self.sourceLoadingIndicator) return;
    if (loading) { self.sourceLoadingIndicator.hidden = NO; [self.sourceLoadingIndicator startAnimation:nil]; }
    else { [self.sourceLoadingIndicator stopAnimation:nil]; self.sourceLoadingIndicator.hidden = YES; }
}

- (FPDropView *)videoArea {
    FPDropView *v = [FPDropView new]; v.wantsLayer = YES; v.layer.backgroundColor = [NSColor colorWithWhite:0.06 alpha:1].CGColor;
    self.playerView = [AVPlayerView new]; self.playerView.player = self.player; self.playerView.controlsStyle = AVPlayerViewControlsStyleNone; self.playerView.videoGravity = AVLayerVideoGravityResizeAspect; self.playerView.hidden = YES;
    self.emptyLabel = [self label:@"動画を開く\niPhoneの画面収録、またはMac上の動画を選択してください。\n動画ファイルはここへドロップできます。" size:15 weight:NSFontWeightRegular]; self.emptyLabel.textColor = NSColor.whiteColor; self.emptyLabel.alignment = NSTextAlignmentCenter; self.emptyLabel.maximumNumberOfLines = 4;
    self.playerView.translatesAutoresizingMaskIntoConstraints = NO; self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:self.playerView]; [v addSubview:self.emptyLabel];
    [NSLayoutConstraint activateConstraints:@[[self.playerView.topAnchor constraintEqualToAnchor:v.topAnchor], [self.playerView.leadingAnchor constraintEqualToAnchor:v.leadingAnchor], [self.playerView.trailingAnchor constraintEqualToAnchor:v.trailingAnchor], [self.playerView.bottomAnchor constraintEqualToAnchor:v.bottomAnchor], [self.emptyLabel.centerXAnchor constraintEqualToAnchor:v.centerXAnchor], [self.emptyLabel.centerYAnchor constraintEqualToAnchor:v.centerYAnchor]]];
    __weak typeof(self) weak = self; v.onURL = ^(NSURL *url){ [weak loadLocalURL:url]; }; return v;
}

- (NSView *)controls {
    NSView *v = [NSView new]; v.wantsLayer = YES; v.layer.backgroundColor = NSColor.controlBackgroundColor.CGColor;
    NSButton *back = [self icon:@"backward.frame.fill" action:@selector(back:) help:@"1フレーム戻る"];
    self.playPauseButton = [self icon:@"play.fill" action:@selector(togglePlayback:) help:@"再生"];
    NSButton *forward = [self icon:@"forward.frame.fill" action:@selector(forward:) help:@"1フレーム進む"];
    self.slider = [NSSlider new]; self.slider.minValue = 0; self.slider.maxValue = 1; self.slider.target = self; self.slider.action = @selector(seek:); self.slider.continuous = YES;
    self.timeLabel = [self label:@"00:00 / 00:00" size:11 weight:NSFontWeightRegular]; self.timeLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular]; self.timeLabel.alignment = NSTextAlignmentRight;
    NSStackView *stack = [NSStackView stackViewWithViews:@[back, self.playPauseButton, self.slider, self.timeLabel, forward]]; stack.spacing = 12; stack.alignment = NSLayoutAttributeCenterY; stack.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:stack];
    [self.timeLabel.widthAnchor constraintEqualToConstant:88].active = YES; [self.slider.widthAnchor constraintGreaterThanOrEqualToConstant:180].active = YES; [self.slider setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14], [stack.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14], [stack.centerYAnchor constraintEqualToAnchor:v.centerYAnchor]]]; return v;
}

- (NSView *)sequenceArea {
    NSView *v = [NSView new];
    NSTextField *heading = [self label:@"フレームを選択" size:14 weight:NSFontWeightSemibold]; self.timelineCaption = [self label:@"実フレームで停止 • 8 fps" size:11 weight:NSFontWeightRegular]; self.timelineCaption.textColor = NSColor.secondaryLabelColor;
    self.densityControl = [NSSegmentedControl segmentedControlWithLabels:@[@"4", @"8", @"12", @"24 fps"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(densityChanged:)]; self.densityControl.target = self; self.densityControl.action = @selector(densityChanged:); self.densityControl.selectedSegment = 1; self.densityControl.controlSize = NSControlSizeSmall;
    NSView *spacer = [NSView new]; NSButton *capture = [self button:@"このフレームを選択" symbol:@"plus.square.on.square" action:@selector(capture:)];
    NSStackView *header = [NSStackView stackViewWithViews:@[heading, self.timelineCaption, self.densityControl, spacer, capture]]; header.spacing = 10; header.translatesAutoresizingMaskIntoConstraints = NO;
    self.sequence = [NSStackView new]; self.sequence.orientation = NSUserInterfaceLayoutOrientationHorizontal; self.sequence.alignment = NSLayoutAttributeCenterY; self.sequence.spacing = 1; self.sequence.edgeInsets = NSEdgeInsetsMake(3, 2, 3, 2); self.sequence.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *doc = [NSView new]; doc.translatesAutoresizingMaskIntoConstraints = NO; [doc addSubview:self.sequence]; [NSLayoutConstraint activateConstraints:@[[self.sequence.topAnchor constraintEqualToAnchor:doc.topAnchor], [self.sequence.leadingAnchor constraintEqualToAnchor:doc.leadingAnchor], [self.sequence.trailingAnchor constraintEqualToAnchor:doc.trailingAnchor], [self.sequence.bottomAnchor constraintEqualToAnchor:doc.bottomAnchor], [doc.heightAnchor constraintEqualToConstant:130]]];
    self.timelineScroll = [NSScrollView new]; self.timelineScroll.documentView = doc; self.timelineScroll.hasHorizontalScroller = YES; self.timelineScroll.drawsBackground = NO; self.timelineScroll.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:header]; [v addSubview:self.timelineScroll];
    [NSLayoutConstraint activateConstraints:@[[header.topAnchor constraintEqualToAnchor:v.topAnchor constant:12], [header.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14], [header.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14], [self.timelineScroll.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:7], [self.timelineScroll.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:12], [self.timelineScroll.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-12], [self.timelineScroll.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-8]]]; [self rebuildTimeline]; return v;
}

- (void)densityChanged:(NSSegmentedControl *)sender {
    NSInteger values[] = {4, 8, 12, 24}; self.sampleFPS = values[MAX(0, MIN(3, sender.selectedSegment))];
    self.timelineCaption.stringValue = [NSString stringWithFormat:@"実フレームで停止 • %ld fps", (long)self.sampleFPS];
    if (self.asset) [self generateTimelineForAsset:self.asset duration:self.duration];
}

- (void)openLocal:(id)sender {
    NSOpenPanel *p = [NSOpenPanel openPanel]; p.title = @"動画を選択"; p.prompt = @"開く"; p.allowedContentTypes = @[UTTypeMovie, UTTypeMPEG4Movie, UTTypeQuickTimeMovie]; p.canChooseDirectories = NO;
    if ([p runModal] == NSModalResponseOK && p.URL) [self loadLocalURL:p.URL];
}
- (void)openLatestMac:(id)sender {
    NSFileManager *manager = NSFileManager.defaultManager; NSArray<NSNumber *> *locations = @[@(NSDesktopDirectory), @(NSMoviesDirectory), @(NSDownloadsDirectory)]; NSURL *latestURL = nil; NSDate *latestDate = nil;
    NSArray<NSURLResourceKey> *keys = @[NSURLContentTypeKey, NSURLContentModificationDateKey, NSURLCreationDateKey, NSURLIsRegularFileKey];
    for (NSNumber *location in locations) {
        NSURL *directory = [manager URLsForDirectory:location.unsignedIntegerValue inDomains:NSUserDomainMask].firstObject; if (!directory) continue;
        NSArray<NSURL *> *files = [manager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
        for (NSURL *url in files) {
            NSDictionary<NSURLResourceKey,id> *values = [url resourceValuesForKeys:keys error:nil]; UTType *type = values[NSURLContentTypeKey];
            if (![values[NSURLIsRegularFileKey] boolValue] || ![type conformsToType:UTTypeMovie]) continue;
            NSDate *date = values[NSURLContentModificationDateKey] ?: values[NSURLCreationDateKey] ?: NSDate.distantPast;
            if (!latestDate || [date compare:latestDate] == NSOrderedDescending) { latestDate = date; latestURL = url; }
        }
    }
    if (!latestURL) { [self error:@"デスクトップ、ムービー、ダウンロードに動画が見つかりませんでした。「Finderで選択」から動画を選んでください。"]; return; }
    [self loadAsset:[AVURLAsset URLAssetWithURL:latestURL options:nil] title:latestURL.URLByDeletingPathExtension.lastPathComponent description:[NSString stringWithFormat:@"Macの最新動画 • %@", latestURL.lastPathComponent] sourceID:[@"file:" stringByAppendingString:latestURL.URLByStandardizingPath.path] photoID:nil];
}
- (void)loadLocalURL:(NSURL *)url {
    if (!url.isFileURL) { [self error:@"Mac上の動画ファイルを選択してください。"]; return; }
    [self loadAsset:[AVURLAsset URLAssetWithURL:url options:nil] title:url.URLByDeletingPathExtension.lastPathComponent description:[NSString stringWithFormat:@"Macの動画 • %@", url.lastPathComponent] sourceID:[@"file:" stringByAppendingString:url.URLByStandardizingPath.path] photoID:nil];
}

- (void)openLatest:(id)sender {
    PHAuthorizationStatus s = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
    if (s == PHAuthorizationStatusAuthorized || s == PHAuthorizationStatusLimited) { [self fetchLatest]; return; }
    if (s == PHAuthorizationStatusNotDetermined) {
        __weak typeof(self) weak = self; [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus n){ dispatch_async(dispatch_get_main_queue(), ^{ if (n == PHAuthorizationStatusAuthorized || n == PHAuthorizationStatusLimited) [weak fetchLatest]; else [weak photoError]; }); }]; return;
    }
    [self photoError];
}
- (void)photoError { [self setSourceLoading:NO]; self.sourceLabel.stringValue = @"iPhone動画を読み込めませんでした"; [self error:@"写真へのアクセスが必要です。システム設定の「プライバシーとセキュリティ」→「写真」でFramePickerを許可してください。"]; }
- (BOOL)isScreenRecordingAsset:(PHAsset *)asset {
    for (PHAssetResource *resource in [PHAssetResource assetResourcesForAsset:asset]) {
        NSString *name = resource.originalFilename.lowercaseString;
        if ([name containsString:@"rpreplay"] ||
            [name containsString:@"screenrecording"] ||
            [name containsString:@"screen_recording"] ||
            [name containsString:@"画面収録"]) {
            return YES;
        }
    }
    return NO;
}
- (void)failLatestVideoRequest:(NSUInteger)generation message:(NSString *)message {
    if (generation != self.latestVideoRequestGeneration) return;
    self.latestVideoRequestGeneration += 1;
    PHImageRequestID requestID = self.latestVideoRequestID;
    self.latestVideoRequestID = PHInvalidImageRequestID;
    if (requestID != PHInvalidImageRequestID) [[PHImageManager defaultManager] cancelImageRequest:requestID];
    [self setSourceLoading:NO];
    self.sourceLabel.stringValue = @"iPhone動画を読み込めませんでした";
    [self error:message];
}
- (void)scheduleLatestVideoInactivityTimeoutForRequestGeneration:(NSUInteger)generation activityGeneration:(NSUInteger)activityGeneration {
    __weak typeof(self) weak = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        typeof(self) strong = weak;
        if (!strong || generation != strong.latestVideoRequestGeneration || activityGeneration != strong.latestVideoActivityGeneration) return;
        [strong failLatestVideoRequest:generation message:FPLatestVideoFailureMessage(nil, nil, YES)];
    });
}
- (void)fetchLatest {
    [self setSourceLoading:YES];
    self.latestVideoRequestGeneration += 1;
    NSUInteger generation = self.latestVideoRequestGeneration;
    self.latestVideoActivityGeneration += 1;
    if (self.latestVideoRequestID != PHInvalidImageRequestID) [[PHImageManager defaultManager] cancelImageRequest:self.latestVideoRequestID];
    self.latestVideoRequestID = PHInvalidImageRequestID;
    self.sourceLabel.stringValue = @"iPhoneの画面収録を検索中…";
    PHFetchOptions *o = [PHFetchOptions new]; o.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:o]; __block PHAsset *latest = nil;
    [assets enumerateObjectsUsingBlock:^(PHAsset *a, NSUInteger i, BOOL *stop){ if ([self isScreenRecordingAsset:a]) { latest = a; *stop = YES; } }];
    if (!latest && assets.count > 0) latest = [assets objectAtIndex:0];
    if (!latest) { [self setSourceLoading:NO]; self.sourceLabel.stringValue = @"iPhone動画が見つかりませんでした"; [self error:@"写真ライブラリに動画が見つかりませんでした。iPhone側のiCloud写真の同期完了後に再試行してください。"]; return; }
    PHVideoRequestOptions *o2 = [PHVideoRequestOptions new]; o2.version = PHVideoRequestOptionsVersionOriginal; o2.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat; o2.networkAccessAllowed = YES;
    self.sourceLabel.stringValue = @"iCloudから最新動画を読み込み中…";
    __weak typeof(self) weak = self;
    o2.progressHandler = ^(double progress, NSError *progressError, BOOL *stop, NSDictionary *info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strong = weak;
            if (!strong || generation != strong.latestVideoRequestGeneration) return;
            if (progressError) {
                [strong failLatestVideoRequest:generation message:FPLatestVideoFailureMessage(@{PHImageErrorKey: progressError}, nil, NO)];
                return;
            }
            strong.sourceLabel.stringValue = [NSString stringWithFormat:@"iCloudから最新動画を読み込み中… %ld%%", (long)lrint(progress * 100.0)];
            strong.latestVideoActivityGeneration += 1;
            [strong scheduleLatestVideoInactivityTimeoutForRequestGeneration:generation activityGeneration:strong.latestVideoActivityGeneration];
        });
    };
    self.latestVideoRequestID = [[PHImageManager defaultManager] requestAVAssetForVideo:latest options:o2 resultHandler:^(AVAsset *asset, AVAudioMix *mix, NSDictionary *info){ dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strong = weak;
        if (!strong || generation != strong.latestVideoRequestGeneration) return;
        if ([info[PHImageResultIsDegradedKey] boolValue] || ([info[PHImageResultIsInCloudKey] boolValue] && !asset && !info[PHImageErrorKey])) return;
        NSString *failureMessage = FPLatestVideoFailureMessage(info, asset, NO); if (failureMessage) { [strong failLatestVideoRequest:generation message:failureMessage]; return; }
        strong.latestVideoRequestGeneration += 1;
        strong.latestVideoRequestID = PHInvalidImageRequestID;
        NSDateFormatter *f = [NSDateFormatter new]; f.locale = [NSLocale localeWithLocaleIdentifier:@"ja_JP"]; f.dateFormat = @"yyyy/MM/dd HH:mm の画面収録";
        [strong loadAsset:asset title:latest.creationDate ? [f stringFromDate:latest.creationDate] : @"最新の画面収録" description:@"iPhoneの画面収録 • iCloud写真" sourceID:[@"photo:" stringByAppendingString:latest.localIdentifier] photoID:latest.localIdentifier];
    }); }];
    [self scheduleLatestVideoInactivityTimeoutForRequestGeneration:generation activityGeneration:self.latestVideoActivityGeneration];
}

- (void)loadAsset:(AVAsset *)asset title:(NSString *)title description:(NSString *)desc sourceID:(NSString *)sourceID photoID:(NSString *)photoID {
    [self setSourceLoading:YES]; [self.player pause]; [self updatePlaybackButton]; self.sourceLabel.stringValue = @"動画を準備中…"; __weak typeof(self) weak = self;
    [asset loadValuesAsynchronouslyForKeys:@[@"duration"] completionHandler:^{ NSError *e = nil; AVKeyValueStatus s = [asset statusOfValueForKey:@"duration" error:&e]; dispatch_async(dispatch_get_main_queue(), ^{
        double d = CMTimeGetSeconds(asset.duration); if (s != AVKeyValueStatusLoaded || !isfinite(d) || d <= 0) { [weak setSourceLoading:NO]; weak.sourceLabel.stringValue = @"動画を読み込めませんでした"; [weak error:[NSString stringWithFormat:@"動画を開けませんでした。\n%@", e.localizedDescription ?: @"動画の長さを取得できません。"]]; return; }
        [weak setSourceLoading:NO];
        weak.asset = asset; weak.sourceID = sourceID; weak.photoAssetID = photoID; weak.duration = d; weak.slider.maxValue = d; weak.slider.doubleValue = 0; weak.titleLabel.stringValue = title; weak.sourceLabel.stringValue = desc; weak.playerView.hidden = NO; weak.emptyLabel.hidden = YES; [weak.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithAsset:asset]]; [weak restore]; [weak updateTime:0]; [weak generateTimelineForAsset:asset duration:d];
    }); }];
}

- (void)seek:(NSSlider *)sender { [self.player seekToTime:CMTimeMakeWithSeconds(sender.doubleValue, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero]; [self updateTime:sender.doubleValue]; }
- (void)togglePlayback:(id)sender { if (self.player.timeControlStatus == AVPlayerTimeControlStatusPaused) [self.player play]; else [self.player pause]; [self updatePlaybackButton]; }
- (void)updatePlaybackButton { if (!self.playPauseButton) return; BOOL active = self.player.timeControlStatus != AVPlayerTimeControlStatusPaused; NSString *symbol = active ? @"pause.fill" : @"play.fill"; NSString *help = active ? @"一時停止" : @"再生"; self.playPauseButton.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:help]; self.playPauseButton.toolTip = help; }
- (void)back:(id)sender { [self.player pause]; [self updatePlaybackButton]; [self.player.currentItem stepByCount:-1]; [self refreshTimelineSelectionAfterStep]; }
- (void)forward:(id)sender { [self.player pause]; [self updatePlaybackButton]; [self.player.currentItem stepByCount:1]; [self refreshTimelineSelectionAfterStep]; }
- (NSString *)time:(double)v { NSInteger s = isfinite(v) ? MAX(0, (NSInteger)floor(v)) : 0; return [NSString stringWithFormat:@"%02ld:%02ld", (long)(s/60), (long)(s%60)]; }
- (void)updateTime:(double)s { if (!isfinite(s) || s < 0) s = 0; if (!self.slider.highlighted) self.slider.doubleValue = MIN(s, self.duration); self.timeLabel.stringValue = [NSString stringWithFormat:@"%@ / %@", [self time:s], [self time:self.duration]]; }
- (NSImage *)imageAt:(double)seconds {
    AVAssetImageGenerator *g = [[AVAssetImageGenerator alloc] initWithAsset:self.asset]; g.appliesPreferredTrackTransform = YES; g.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture; g.requestedTimeToleranceBefore = kCMTimeZero; g.requestedTimeToleranceAfter = kCMTimeZero;
    CGImageRef ref = [g copyCGImageAtTime:CMTimeMakeWithSeconds(seconds, 600) actualTime:NULL error:nil]; if (!ref) return nil; NSImage *image = [[NSImage alloc] initWithCGImage:ref size:NSZeroSize]; CGImageRelease(ref); return image;
}
- (void)capture:(id)sender { if (!self.asset) return; double t = MAX(0, CMTimeGetSeconds(self.player.currentTime)); NSImage *i = [self imageAt:t]; if (!i) { [self error:@"この位置のフレームを取得できませんでした。"]; return; } [self.frames addObject:@{@"time":@(t), @"image":i}]; self.selectedCapturedIndex = self.frames.count - 1; [self.selectedCapturedIndexes removeAllIndexes]; [self.selectedCapturedIndexes addIndex:self.selectedCapturedIndex]; [self persist]; [self rebuild]; }

- (void)generateTimelineForAsset:(AVAsset *)asset duration:(double)duration {
    NSUInteger generation = ++self.timelineGeneration;
    [self.timelineFrames removeAllObjects]; self.selectedTimelineIndex = NSNotFound; [self rebuildTimeline];
    NSUInteger count = MIN((NSUInteger)3600, MAX((NSUInteger)2, (NSUInteger)ceil(duration * self.sampleFPS) + 1));
    NSInteger sampleFPS = self.sampleFPS;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSDictionary *> *items = [NSMutableArray arrayWithCapacity:count];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset]; generator.appliesPreferredTrackTransform = YES;
        generator.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture; generator.maximumSize = NSMakeSize(190, 104);
        generator.requestedTimeToleranceBefore = kCMTimeZero; generator.requestedTimeToleranceAfter = kCMTimeZero;
        for (NSUInteger index = 0; index < count; index++) {
            double time = (double)index / sampleFPS;
            time = MIN(time, MAX(0, duration - 0.001));
            CMTime actualTime = kCMTimeInvalid; CGImageRef ref = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(time, 600) actualTime:&actualTime error:nil];
            if (ref) { NSImage *image = [[NSImage alloc] initWithCGImage:ref size:NSZeroSize]; CGImageRelease(ref); double actual = CMTIME_IS_VALID(actualTime) ? CMTimeGetSeconds(actualTime) : time; [items addObject:@{@"time":@(actual), @"image":image}]; }
            if ((index + 1) % 24 == 0) { NSMutableArray *snapshot = [items mutableCopy]; dispatch_async(dispatch_get_main_queue(), ^{ if (generation != self.timelineGeneration || asset != self.asset) return; self.timelineFrames = snapshot; if (self.selectedTimelineIndex == NSNotFound && snapshot.count) self.selectedTimelineIndex = 0; [self rebuildTimeline]; }); }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (generation != self.timelineGeneration || asset != self.asset) return; self.timelineFrames = items; if (self.selectedTimelineIndex == NSNotFound && items.count) self.selectedTimelineIndex = 0; [self rebuildTimeline]; });
    });
}

- (NSView *)timelineCard:(NSDictionary *)frame index:(NSUInteger)index {
    NSImage *image = frame[@"image"]; CGFloat height = 104; CGFloat ratio = image.size.height > 0 ? image.size.width / image.size.height : 1; CGFloat width = MAX(34, MIN(190, height * ratio));
    NSButton *button = [NSButton buttonWithImage:image target:self action:@selector(selectTimeline:)];
    button.tag = index; button.imagePosition = NSImageOnly; button.imageScaling = NSImageScaleProportionallyUpOrDown; button.bordered = NO;
    button.wantsLayer = YES; button.layer.backgroundColor = NSColor.clearColor.CGColor; button.layer.borderWidth = index == self.selectedTimelineIndex ? 3 : 0; button.layer.borderColor = NSColor.systemBlueColor.CGColor;
    [button.widthAnchor constraintEqualToConstant:width].active = YES; [button.heightAnchor constraintEqualToConstant:height].active = YES; return button;
}

- (void)rebuildTimeline {
    for (NSView *view in self.sequence.arrangedSubviews.copy) { [self.sequence removeArrangedSubview:view]; [view removeFromSuperview]; }
    if (!self.asset || !self.timelineFrames.count) {
        NSString *text = self.asset ? @"動画からフレームを自動生成中…" : @"動画を開くと、選択用のフレームが自動で並びます。";
        NSTextField *empty = [self label:text size:12 weight:NSFontWeightRegular]; empty.textColor = NSColor.secondaryLabelColor; [empty.widthAnchor constraintGreaterThanOrEqualToConstant:420].active = YES; [self.sequence addArrangedSubview:empty]; return;
    }
    [self.timelineFrames enumerateObjectsUsingBlock:^(NSDictionary *frame, NSUInteger index, BOOL *stop){ [self.sequence addArrangedSubview:[self timelineCard:frame index:index]]; }];
}

- (void)selectTimeline:(NSButton *)sender {
    [self clearCapturedSelection];
    [self setTimelineSelectionIndex:sender.tag seek:YES];
}

- (void)setTimelineSelectionIndex:(NSInteger)index seek:(BOOL)shouldSeek {
    if (index < 0 || index >= self.timelineFrames.count) return;
    NSInteger old = self.selectedTimelineIndex; self.selectedTimelineIndex = index;
    if (old >= 0 && old < self.sequence.arrangedSubviews.count) ((NSView *)self.sequence.arrangedSubviews[old]).layer.borderWidth = 0;
    if (index < self.sequence.arrangedSubviews.count) {
        NSView *selected = self.sequence.arrangedSubviews[index]; selected.layer.borderWidth = 3; selected.layer.borderColor = NSColor.systemBlueColor.CGColor;
        [selected scrollRectToVisible:selected.bounds];
    }
    if (!shouldSeek) return;
    double time = [self.timelineFrames[index][@"time"] doubleValue]; [self.player pause]; [self updatePlaybackButton];
    [self.player seekToTime:CMTimeMakeWithSeconds(time, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished){ dispatch_async(dispatch_get_main_queue(), ^{ [self updateTime:time]; }); }];
}

- (void)moveTimelineSelectionBy:(NSInteger)offset {
    if (!self.timelineFrames.count) return;
    [self clearCapturedSelection];
    NSInteger current = self.selectedTimelineIndex == NSNotFound ? 0 : self.selectedTimelineIndex;
    [self setTimelineSelectionIndex:MAX(0, MIN((NSInteger)self.timelineFrames.count - 1, current + offset)) seek:YES];
}

- (void)refreshTimelineSelectionAfterStep {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self clearCapturedSelection];
        double time = CMTimeGetSeconds(self.player.currentTime); double best = DBL_MAX; NSInteger bestIndex = NSNotFound;
        for (NSUInteger index = 0; index < self.timelineFrames.count; index++) { double delta = fabs([self.timelineFrames[index][@"time"] doubleValue] - time); if (delta < best) { best = delta; bestIndex = index; } }
        [self setTimelineSelectionIndex:bestIndex seek:NO]; [self updateTime:time];
    });
}

- (NSView *)card:(NSDictionary *)frame index:(NSUInteger)i {
    NSImage *sourceImage = frame[@"image"]; CGFloat ratio = sourceImage.size.height > 0 ? sourceImage.size.width / sourceImage.size.height : 1;
    CGFloat imageWidth, imageHeight; if (ratio >= 180.0 / 240.0) { imageWidth = 180; imageHeight = imageWidth / ratio; } else { imageHeight = 240; imageWidth = imageHeight * ratio; }
    FPHoverCardView *v = [FPHoverCardView new]; v.layer.borderWidth = [self.selectedCapturedIndexes containsIndex:i] ? 3 : 0; v.layer.borderColor = NSColor.systemBlueColor.CGColor; [v.widthAnchor constraintEqualToConstant:imageWidth].active = YES; [v.heightAnchor constraintEqualToConstant:imageHeight].active = YES;
    NSImageView *image = [NSImageView new]; image.image = sourceImage; image.imageScaling = NSImageScaleProportionallyUpOrDown; image.wantsLayer = YES; image.layer.cornerRadius = 6;
    NSButton *select = [NSButton buttonWithTitle:@"" target:self action:@selector(selectCaptured:)]; select.tag = i; select.bordered = NO; select.focusRingType = NSFocusRingTypeNone; select.toolTip = @"このフレームへ移動";
    NSTextField *n = [self label:[NSString stringWithFormat:@"%lu", (unsigned long)i+1] size:10 weight:NSFontWeightBold]; n.textColor = NSColor.whiteColor; n.alignment = NSTextAlignmentCenter; n.wantsLayer = YES; n.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:.72].CGColor; n.layer.cornerRadius = 8;
    NSButton *up = [self icon:@"chevron.up" action:@selector(up:) help:@"上へ移動"], *down = [self icon:@"chevron.down" action:@selector(down:) help:@"下へ移動"], *x = [self icon:@"trash" action:@selector(remove:) help:@"削除"];
    up.tag = down.tag = x.tag = i; up.enabled = i > 0; down.enabled = i+1 < self.frames.count; x.contentTintColor = NSColor.systemRedColor;
    for (NSButton *button in @[up, x, down]) { button.bezelStyle = NSBezelStyleCircular; button.controlSize = NSControlSizeSmall; }
    NSStackView *a = [NSStackView stackViewWithViews:@[up,x,down]]; a.spacing = 4; a.edgeInsets = NSEdgeInsetsMake(4, 5, 4, 5); a.wantsLayer = YES; a.layer.backgroundColor = [NSColor.windowBackgroundColor colorWithAlphaComponent:.92].CGColor; a.layer.cornerRadius = 15; a.hidden = YES; v.controls = a;
    for (NSView *z in @[image,select,n,a]) { z.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:z]; }
    [NSLayoutConstraint activateConstraints:@[[image.topAnchor constraintEqualToAnchor:v.topAnchor], [image.leadingAnchor constraintEqualToAnchor:v.leadingAnchor], [image.trailingAnchor constraintEqualToAnchor:v.trailingAnchor], [image.bottomAnchor constraintEqualToAnchor:v.bottomAnchor], [select.topAnchor constraintEqualToAnchor:image.topAnchor], [select.leadingAnchor constraintEqualToAnchor:image.leadingAnchor], [select.trailingAnchor constraintEqualToAnchor:image.trailingAnchor], [select.bottomAnchor constraintEqualToAnchor:image.bottomAnchor], [n.topAnchor constraintEqualToAnchor:image.topAnchor constant:5], [n.leadingAnchor constraintEqualToAnchor:image.leadingAnchor constant:5], [n.widthAnchor constraintGreaterThanOrEqualToConstant:24], [n.heightAnchor constraintEqualToConstant:17], [a.bottomAnchor constraintEqualToAnchor:image.bottomAnchor constant:-8], [a.centerXAnchor constraintEqualToAnchor:v.centerXAnchor]]]; return v;
}
- (void)rebuild {
    if (!self.selectedStack) return;
    for (NSView *v in self.selectedStack.arrangedSubviews.copy) { [self.selectedStack removeArrangedSubview:v]; [v removeFromSuperview]; }
    if (!self.frames.count) { NSTextField *e = [self label:@"下のフレーム列から選択してください。" size:12 weight:NSFontWeightRegular]; e.textColor = NSColor.secondaryLabelColor; e.maximumNumberOfLines = 2; [e.widthAnchor constraintEqualToConstant:180].active = YES; [self.selectedStack addArrangedSubview:e]; }
    else [self.frames enumerateObjectsUsingBlock:^(NSDictionary *f, NSUInteger i, BOOL *stop){ [self.selectedStack addArrangedSubview:[self card:f index:i]]; }];
    self.countLabel.stringValue = [NSString stringWithFormat:@"%lu枚", (unsigned long)self.frames.count]; self.exportButton.enabled = self.frames.count > 0; self.clipboardButton.enabled = self.frames.count > 0;
}
- (void)up:(NSButton *)b { [self move:b.tag offset:-1]; } - (void)down:(NSButton *)b { [self move:b.tag offset:1]; }
- (void)selectCaptured:(NSButton *)button {
    if (button.tag < 0 || button.tag >= self.frames.count) return;
    BOOL extendsSelection = (NSApp.currentEvent.modifierFlags & NSEventModifierFlagShift) != 0;
    if (!extendsSelection) [self.selectedCapturedIndexes removeAllIndexes];
    if (extendsSelection && [self.selectedCapturedIndexes containsIndex:button.tag]) {
        [self.selectedCapturedIndexes removeIndex:button.tag];
        self.selectedCapturedIndex = self.selectedCapturedIndexes.count ? self.selectedCapturedIndexes.lastIndex : NSNotFound;
    } else {
        [self.selectedCapturedIndexes addIndex:button.tag]; self.selectedCapturedIndex = button.tag;
    }
    double time = [self.frames[button.tag][@"time"] doubleValue]; double best = DBL_MAX; NSInteger bestIndex = NSNotFound;
    for (NSUInteger index = 0; index < self.timelineFrames.count; index++) { double delta = fabs([self.timelineFrames[index][@"time"] doubleValue] - time); if (delta < best) { best = delta; bestIndex = index; } }
    if (bestIndex != NSNotFound) [self setTimelineSelectionIndex:bestIndex seek:NO];
    [self updateCapturedSelectionVisual];
    [self.player pause]; [self updatePlaybackButton]; [self.player seekToTime:CMTimeMakeWithSeconds(time, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished){ dispatch_async(dispatch_get_main_queue(), ^{ [self updateTime:time]; }); }];
}
- (void)clearCapturedSelection { self.selectedCapturedIndex = NSNotFound; [self.selectedCapturedIndexes removeAllIndexes]; [self updateCapturedSelectionVisual]; }
- (void)updateCapturedSelectionVisual {
    [self.selectedStack.arrangedSubviews enumerateObjectsUsingBlock:^(NSView *card, NSUInteger index, BOOL *stop) {
        card.layer.borderWidth = [self.selectedCapturedIndexes containsIndex:index] ? 3 : 0; card.layer.borderColor = NSColor.systemBlueColor.CGColor;
    }];
}
- (void)move:(NSInteger)i offset:(NSInteger)o { NSInteger d=i+o; if (i<0||d<0||i>=self.frames.count||d>=self.frames.count) return; NSDictionary *f=self.frames[i]; [self.frames removeObjectAtIndex:i]; [self.frames insertObject:f atIndex:d]; BOOL iSelected=[self.selectedCapturedIndexes containsIndex:i], dSelected=[self.selectedCapturedIndexes containsIndex:d]; [self.selectedCapturedIndexes removeIndex:i]; [self.selectedCapturedIndexes removeIndex:d]; if(iSelected)[self.selectedCapturedIndexes addIndex:d];if(dSelected)[self.selectedCapturedIndexes addIndex:i]; if(self.selectedCapturedIndex==i)self.selectedCapturedIndex=d;else if(self.selectedCapturedIndex==d)self.selectedCapturedIndex=i; [self persist]; [self rebuild]; }
- (void)remove:(NSButton *)b { if (b.tag<self.frames.count) { NSMutableIndexSet *updated=[NSMutableIndexSet indexSet]; [self.selectedCapturedIndexes enumerateIndexesUsingBlock:^(NSUInteger index,BOOL *stop){if(index<b.tag)[updated addIndex:index];else if(index>b.tag)[updated addIndex:index-1];}]; self.selectedCapturedIndexes=updated; if(self.selectedCapturedIndex==b.tag)self.selectedCapturedIndex=updated.count?updated.lastIndex:NSNotFound;else if(b.tag<self.selectedCapturedIndex)self.selectedCapturedIndex--; [self.frames removeObjectAtIndex:b.tag]; [self persist]; [self rebuild]; } }
- (void)clear:(id)sender { [self.frames removeAllObjects]; self.selectedCapturedIndex=NSNotFound; [self.selectedCapturedIndexes removeAllIndexes]; [self persist]; [self rebuild]; }
- (void)persist { if (!self.sourceID) return; NSUserDefaults *d=NSUserDefaults.standardUserDefaults; NSMutableDictionary *s=[[d dictionaryForKey:@"capturedSessions.v1"] mutableCopy]?:[NSMutableDictionary dictionary]; NSMutableArray *t=[NSMutableArray array]; for (NSDictionary *f in self.frames) [t addObject:f[@"time"]]; s[self.sourceID]=t; [d setObject:s forKey:@"capturedSessions.v1"]; }
- (void)restore { [self.frames removeAllObjects]; NSArray *times=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"capturedSessions.v1"][self.sourceID]; for (NSNumber *t in times) { if (t.doubleValue>self.duration) continue; NSImage *i=[self imageAt:t.doubleValue]; if (i) [self.frames addObject:@{@"time":t,@"image":i}]; } [self rebuild]; }

- (void)setCopyLoading:(BOOL)loading {
    self.copyInProgress = loading;
    if (loading) { self.clipboardLoadingIndicator.hidden = NO; [self.clipboardLoadingIndicator startAnimation:nil]; self.clipboardButton.enabled = NO; }
    else { [self.clipboardLoadingIndicator stopAnimation:nil]; self.clipboardLoadingIndicator.hidden = YES; self.clipboardButton.enabled = self.frames.count > 0; }
}

- (NSArray *)cgImagesForImages:(NSArray<NSImage *> *)images {
    NSMutableArray *cgImages = [NSMutableArray arrayWithCapacity:images.count];
    for (NSImage *image in images) { NSRect rect = NSMakeRect(0, 0, image.size.width, image.size.height); CGImageRef cgImage = [image CGImageForProposedRect:&rect context:nil hints:nil]; if (cgImage) [cgImages addObject:CFBridgingRelease(CGImageRetain(cgImage))]; }
    return cgImages;
}

- (BOOL)writeClipboardPayload:(FPClipboardPayload *)payload toPasteboard:(NSPasteboard *)pasteboard {
    if (!payload.primaryData.length) return NO;
    NSPasteboardItem *item = [NSPasteboardItem new]; [item setData:payload.primaryData forType:payload.primaryType];
    if (payload.plainText) [item setString:payload.plainText forType:NSPasteboardTypeString];
    if (payload.html) [item setString:payload.html forType:NSPasteboardTypeHTML];
    [pasteboard clearContents]; return [pasteboard writeObjects:@[item]];
}

- (void)copyCGImages:(NSArray *)cgImages toPasteboard:(NSPasteboard *)pasteboard completion:(void (^)(BOOL copied))completion {
    if (!cgImages.count) { [self setCopyLoading:NO]; if (completion) completion(NO); return; }
    [self setCopyLoading:YES]; __weak typeof(self) weak = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        FPClipboardPayload *payload = FPCreateClipboardPayload(cgImages);
        dispatch_async(dispatch_get_main_queue(), ^{ BOOL copied = payload && [weak writeClipboardPayload:payload toPasteboard:pasteboard]; [weak setCopyLoading:NO]; if (completion) completion(copied); });
    });
}

- (void)showCopyConfirmation {
    [(FPPaddedButton *)self.clipboardButton hideInstantToolTip]; if (self.confirmationPanel) { [self.window removeChildWindow:self.confirmationPanel]; [self.confirmationPanel orderOut:nil]; }
    NSSize size = NSMakeSize(108, 28); NSRect windowFrame = self.window.frame; NSRect frame = NSMakeRect(NSMidX(windowFrame) - size.width / 2, NSMinY(windowFrame) + 18, size.width, size.height); NSPanel *panel = [[NSPanel alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO]; panel.opaque = NO; panel.backgroundColor = NSColor.clearColor; panel.hasShadow = YES; panel.ignoresMouseEvents = YES;
    NSView *background = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)]; background.wantsLayer = YES; background.layer.backgroundColor = [NSColor colorWithWhite:0.12 alpha:.9].CGColor; background.layer.cornerRadius = 7; NSTextField *label = [NSTextField labelWithString:@"コピーしました"]; label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium]; label.textColor = NSColor.whiteColor; label.alignment = NSTextAlignmentCenter; label.frame = NSMakeRect(8, 6, size.width - 16, 16); [background addSubview:label]; panel.contentView = background; self.confirmationPanel = panel; [self.window addChildWindow:panel ordered:NSWindowAbove]; [panel orderFront:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ if (self.confirmationPanel == panel) { [self.window removeChildWindow:panel]; [panel orderOut:nil]; self.confirmationPanel = nil; } });
}

- (void)copySelectedFrames:(id)sender {
    if (self.copyInProgress) return;
    void (^finished)(BOOL) = ^(BOOL copied) { if (copied) [self showCopyConfirmation]; else NSBeep(); };
    if (self.selectedCapturedIndexes.count) {
        NSMutableArray<NSImage *> *images = [NSMutableArray array]; [self.selectedCapturedIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) { if (index < self.frames.count) [images addObject:self.frames[index][@"image"]]; }];
        NSArray *cgImages = [self cgImagesForImages:images]; if (!cgImages.count) { NSBeep(); return; } [self copyCGImages:cgImages toPasteboard:NSPasteboard.generalPasteboard completion:finished]; return;
    }
    if (self.selectedTimelineIndex < 0 || self.selectedTimelineIndex >= self.timelineFrames.count || !self.asset) { NSBeep(); return; }
    double time = [self.timelineFrames[self.selectedTimelineIndex][@"time"] doubleValue]; AVAsset *asset = self.asset; [self setCopyLoading:YES]; __weak typeof(self) weak = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset]; generator.appliesPreferredTrackTransform = YES; generator.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture; generator.requestedTimeToleranceBefore = kCMTimeZero; generator.requestedTimeToleranceAfter = kCMTimeZero;
        CGImageRef image = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(time, 600) actualTime:NULL error:nil]; id retainedImage = image ? CFBridgingRelease(image) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ if (!retainedImage) { [weak setCopyLoading:NO]; NSBeep(); return; } [weak copyCGImages:@[retainedImage] toPasteboard:NSPasteboard.generalPasteboard completion:finished]; });
    });
}

- (void)copyAllFrames:(id)sender {
    if (self.copyInProgress) return; NSMutableArray<NSImage *> *images = [NSMutableArray arrayWithCapacity:self.frames.count]; for (NSDictionary *frame in self.frames) { NSImage *image = frame[@"image"]; if (image) [images addObject:image]; }
    NSArray *cgImages = [self cgImagesForImages:images]; if (!cgImages.count) { NSBeep(); return; }
    [self copyCGImages:cgImages toPasteboard:NSPasteboard.generalPasteboard completion:^(BOOL copied) { if (copied) [self showCopyConfirmation]; else NSBeep(); }];
}

- (NSURL *)defaultExportParentURL {
    return [NSFileManager.defaultManager URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask].firstObject;
}

- (void)exportFrames:(id)sender {
    if (!self.frames.count) return; NSOpenPanel *p=[NSOpenPanel openPanel]; p.title=@"書き出し先を選択"; p.prompt=@"ここに保存"; p.canChooseFiles=NO; p.canChooseDirectories=YES; p.canCreateDirectories=YES; p.directoryURL=[self defaultExportParentURL]; if ([p runModal]!=NSModalResponseOK||!p.URL) return;
    NSError *e=nil; NSURL *dir=[self createOutputDirectoryIn:p.URL error:&e]; if(!dir) { [self error:e.localizedDescription]; return; }
    self.exportButton.enabled=NO; self.progress.hidden=NO; self.progress.doubleValue=0; NSUInteger digits=MAX((NSUInteger)3,[@(self.frames.count) stringValue].length);
    for(NSUInteger i=0;i<self.frames.count;i++){ NSImage *image=self.frames[i][@"image"]; NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithData:image.TIFFRepresentation]; NSData *png=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}]; NSURL *url=[dir URLByAppendingPathComponent:[NSString stringWithFormat:@"%0*lu.png",(int)digits,(unsigned long)i+1]]; if(!png||![png writeToURL:url options:NSDataWritingAtomic error:&e]){ self.exportButton.enabled=YES; self.progress.hidden=YES; [self error:e.localizedDescription?:@"PNG画像への変換に失敗しました。"]; return;} self.progress.doubleValue=(double)(i+1)/self.frames.count; }
    self.outputURL=dir; self.progress.hidden=YES; self.exportButton.enabled=YES; [self recordExportURL:dir count:self.frames.count]; self.sidebarTabs.selectedSegment=1; [self sidebarTabChanged:self.sidebarTabs];
}

- (NSURL *)createOutputDirectoryIn:(NSURL *)parent error:(NSError **)error {
    NSDateFormatter *f=[NSDateFormatter new]; f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; f.dateFormat=@"yyyyMMdd"; NSString *base=[@"framepicker-" stringByAppendingString:[f stringFromDate:NSDate.date]];
    NSFileManager *m=NSFileManager.defaultManager; NSURL *dir=[parent URLByAppendingPathComponent:base isDirectory:YES]; NSInteger suffix=2; while([m fileExistsAtPath:dir.path]) dir=[parent URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-%ld",base,(long)suffix++] isDirectory:YES];
    return [m createDirectoryAtURL:dir withIntermediateDirectories:NO attributes:nil error:error] ? dir : nil;
}

- (void)recordExportURL:(NSURL *)url count:(NSUInteger)count {
    [self.exportHistory insertObject:@{@"path":url.path, @"count":@(count), @"timestamp":@(NSDate.date.timeIntervalSince1970)} atIndex:0];
    if(self.exportHistory.count>50) [self.exportHistory removeObjectsInRange:NSMakeRange(50,self.exportHistory.count-50)];
    [NSUserDefaults.standardUserDefaults setObject:self.exportHistory forKey:@"exportHistory.v1"]; [self rebuildHistory];
}

- (NSView *)historyRow:(NSDictionary *)item index:(NSUInteger)index {
    NSButton *open=[self button:[item[@"path"] lastPathComponent] symbol:@"folder" action:@selector(revealHistory:)]; open.tag=index; open.alignment=NSTextAlignmentLeft; [open setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSTextField *count=[self label:[NSString stringWithFormat:@"%@枚",item[@"count"]] size:11 weight:NSFontWeightRegular]; count.textColor=NSColor.secondaryLabelColor;
    NSButton *again=[self button:@"再出力" symbol:@"arrow.clockwise" action:@selector(reexportHistory:)]; again.tag=index; again.controlSize=NSControlSizeSmall;
    NSStackView *row=[NSStackView stackViewWithViews:@[open,count,again]]; row.alignment=NSLayoutAttributeCenterY; row.spacing=6; [row.widthAnchor constraintEqualToConstant:210].active=YES; return row;
}

- (void)rebuildHistory {
    if(!self.historyStack) return; for(NSView *v in self.historyStack.arrangedSubviews.copy){[self.historyStack removeArrangedSubview:v];[v removeFromSuperview];}
    if(!self.exportHistory.count){NSTextField *empty=[self label:@"まだ出力はありません。" size:12 weight:NSFontWeightRegular];empty.textColor=NSColor.secondaryLabelColor;[self.historyStack addArrangedSubview:empty];return;}
    [self.exportHistory enumerateObjectsUsingBlock:^(NSDictionary *item,NSUInteger index,BOOL *stop){[self.historyStack addArrangedSubview:[self historyRow:item index:index]];}];
}

- (void)revealHistory:(NSButton *)sender { if(sender.tag>=self.exportHistory.count)return; NSURL *url=[NSURL fileURLWithPath:self.exportHistory[sender.tag][@"path"]]; if([NSFileManager.defaultManager fileExistsAtPath:url.path])[NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[url]];else[self error:@"出力済みフォルダが見つかりません。"]; }

- (void)reexportHistory:(NSButton *)sender {
    if(sender.tag>=self.exportHistory.count)return; NSURL *source=[NSURL fileURLWithPath:self.exportHistory[sender.tag][@"path"]]; BOOL isDir=NO; if(![NSFileManager.defaultManager fileExistsAtPath:source.path isDirectory:&isDir]||!isDir){[self error:@"再出力元のフォルダが見つかりません。"];return;}
    NSOpenPanel *p=[NSOpenPanel openPanel];p.title=@"再出力先を選択";p.prompt=@"ここに再出力";p.canChooseFiles=NO;p.canChooseDirectories=YES;p.canCreateDirectories=YES;p.directoryURL=[self defaultExportParentURL];if([p runModal]!=NSModalResponseOK||!p.URL)return;
    NSError *e=nil;NSURL *dest=[self createOutputDirectoryIn:p.URL error:&e];if(!dest){[self error:e.localizedDescription];return;}
    NSArray<NSURL *> *files=[[NSFileManager.defaultManager contentsOfDirectoryAtURL:source includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:&e] sortedArrayUsingComparator:^NSComparisonResult(NSURL *a,NSURL *b){return[a.lastPathComponent compare:b.lastPathComponent options:NSNumericSearch];}];NSUInteger copied=0;
    for(NSURL *file in files){if(![file.pathExtension.lowercaseString isEqualToString:@"png"])continue;NSURL *target=[dest URLByAppendingPathComponent:file.lastPathComponent];if(![NSFileManager.defaultManager copyItemAtURL:file toURL:target error:&e]){[self error:e.localizedDescription];return;}copied++;}
    [self recordExportURL:dest count:copied];
}
- (void)reveal:(id)sender { if(self.outputURL) [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[self.outputURL]]; }
- (void)error:(NSString *)message { NSAlert *a=[NSAlert new]; a.messageText=@"エラー"; a.informativeText=message?:@"不明なエラーが発生しました。"; [a addButtonWithTitle:@"閉じる"]; if(self.window.visible)[a beginSheetModalForWindow:self.window completionHandler:nil];else[a runModal]; }
- (void)photoLibraryDidChange:(PHChange *)change { if(self.photoAssetID) dispatch_async(dispatch_get_main_queue(), ^{ [self fetchLatest]; }); }
@end

int main(void) {
    @autoreleasepool { NSApplication *app=NSApplication.sharedApplication; FPDelegate *delegate=[FPDelegate new]; app.delegate=delegate; [app setActivationPolicy:NSApplicationActivationPolicyRegular]; [app run]; }
    return 0;
}
