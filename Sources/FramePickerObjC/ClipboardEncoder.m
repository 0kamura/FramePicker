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

    if (cgImages.count == 1) {
        if (pngData.firstObject == NSNull.null) return nil;
        FPClipboardPayload *payload = [FPClipboardPayload new];
        payload.primaryType = NSPasteboardTypePNG;
        payload.primaryData = pngData.firstObject;
        return payload;
    }

    CGFloat totalWidth = 0, maxHeight = 0, gap = 40;
    for (NSUInteger index = 0; index < cgImages.count; index++) {
        if (pngData[index] == NSNull.null) return nil;
        CGImageRef image = (__bridge CGImageRef)cgImages[index];
        totalWidth += CGImageGetWidth(image); maxHeight = MAX(maxHeight, CGImageGetHeight(image));
    }
    totalWidth += gap * (cgImages.count - 1);

    NSMutableString *svg = [NSMutableString stringWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%.0f\" height=\"%.0f\" viewBox=\"0 0 %.0f %.0f\">", totalWidth, maxHeight, totalWidth, maxHeight];
    CGFloat x = 0;
    for (NSUInteger index = 0; index < cgImages.count; index++) {
        CGImageRef image = (__bridge CGImageRef)cgImages[index]; CGFloat width = CGImageGetWidth(image), height = CGImageGetHeight(image);
        NSString *base64 = [pngData[index] base64EncodedStringWithOptions:0];
        [svg appendFormat:@"<g id=\"frame-%03lu\"><image x=\"%.0f\" y=\"0\" width=\"%.0f\" height=\"%.0f\" xlink:href=\"data:image/png;base64,%@\"/></g>", (unsigned long)index + 1, x, width, height, base64];
        x += width + gap;
    }
    [svg appendString:@"</svg>"];

    FPClipboardPayload *payload = [FPClipboardPayload new];
    payload.primaryType = @"public.svg-image";
    payload.primaryData = [svg dataUsingEncoding:NSUTF8StringEncoding];
    payload.plainText = svg;
    payload.html = [NSString stringWithFormat:@"<html><body>%@</body></html>", svg];
    return payload;
}
