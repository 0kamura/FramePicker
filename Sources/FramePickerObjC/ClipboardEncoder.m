#import "ClipboardEncoder.h"

@implementation FPClipboardPayload
@end

static NSData *FPPNGDataForCGImage(CGImageRef image) {
    NSBitmapImageRep *representation = [[NSBitmapImageRep alloc] initWithCGImage:image];
    return [representation representationUsingType:NSBitmapImageFileTypePNG properties:@{NSImageCompressionFactor: @0.0}];
}

FPClipboardPayload *FPCreateClipboardPayload(NSArray *cgImages) {
    if (!cgImages.count) return nil;

    NSMutableArray *pngData = [NSMutableArray arrayWithCapacity:cgImages.count];
    for (NSUInteger index = 0; index < cgImages.count; index++) [pngData addObject:NSNull.null];
    dispatch_semaphore_t encodingSlots = dispatch_semaphore_create(4);
    dispatch_apply(cgImages.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        dispatch_semaphore_wait(encodingSlots, DISPATCH_TIME_FOREVER);
        CGImageRef image = (__bridge CGImageRef)cgImages[index];
        NSData *png = FPPNGDataForCGImage(image);
        if (png) @synchronized (pngData) { pngData[index] = png; }
        dispatch_semaphore_signal(encodingSlots);
    });

    for (id png in pngData) if (png == NSNull.null) return nil;
    FPClipboardPayload *payload = [FPClipboardPayload new];
    payload.primaryType = NSPasteboardTypePNG;
    payload.primaryData = pngData.firstObject;
    payload.pngItems = (NSArray<NSData *> *)pngData.copy;
    return payload;
}
