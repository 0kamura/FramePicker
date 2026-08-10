#import <Cocoa/Cocoa.h>

#define main FPFramePickerApplicationMain
#import "../Sources/FramePickerObjC/main.m"
#undef main

static NSImage *FPMakeTestImage(size_t width, size_t height, CGFloat phase) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    uint8_t *pixels = CGBitmapContextGetData(context); uint32_t state = (uint32_t)(phase * UINT32_MAX) | 1;
    for (size_t index = 0; index < width * height; index++) { state ^= state << 13; state ^= state >> 17; state ^= state << 5; pixels[index * 4] = state; pixels[index * 4 + 1] = state >> 8; pixels[index * 4 + 2] = state >> 16; pixels[index * 4 + 3] = 255; }
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    NSImage *image = [[NSImage alloc] initWithCGImage:cgImage size:NSZeroSize];
    CGImageRelease(cgImage); CGContextRelease(context); CGColorSpaceRelease(colorSpace);
    return image;
}

int main(void) {
    @autoreleasepool {
        NSArray<NSImage *> *images = @[
            FPMakeTestImage(1170, 2532, 0.1),
            FPMakeTestImage(1170, 2532, 0.4),
            FPMakeTestImage(1170, 2532, 0.7)
        ];
        CFAbsoluteTime tiffStart = CFAbsoluteTimeGetCurrent(); NSMutableArray<NSData *> *tiffs = [NSMutableArray array];
        for (NSImage *image in images) [tiffs addObject:image.TIFFRepresentation];
        CFAbsoluteTime tiffElapsed = CFAbsoluteTimeGetCurrent() - tiffStart;
        CFAbsoluteTime pngStart = CFAbsoluteTimeGetCurrent(); NSMutableArray<NSData *> *pngs = [NSMutableArray array];
        for (NSData *tiff in tiffs) { NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff]; [pngs addObject:[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}]]; }
        CFAbsoluteTime pngElapsed = CFAbsoluteTimeGetCurrent() - pngStart;
        CFAbsoluteTime decodeStart = CFAbsoluteTimeGetCurrent();
        for (NSData *png in pngs) (void)[NSBitmapImageRep imageRepWithData:png];
        CFAbsoluteTime decodeElapsed = CFAbsoluteTimeGetCurrent() - decodeStart;
        CFAbsoluteTime legacyAssemblyStart = CFAbsoluteTimeGetCurrent(); NSMutableString *legacyPayload = [NSMutableString string];
        for (NSData *png in pngs) [legacyPayload appendString:[png base64EncodedStringWithOptions:0]];
        CFAbsoluteTime legacyAssemblyElapsed = CFAbsoluteTimeGetCurrent() - legacyAssemblyStart;
        CFAbsoluteTime fastStart = CFAbsoluteTimeGetCurrent(); NSUInteger fastBytes = 0;
        for (NSImage *image in images) { NSRect rect = NSMakeRect(0, 0, image.size.width, image.size.height); CGImageRef cgImage = [image CGImageForProposedRect:&rect context:nil hints:nil]; NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage]; fastBytes += [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{NSImageCompressionFactor: @0.0}] length]; }
        CFAbsoluteTime fastElapsed = CFAbsoluteTimeGetCurrent() - fastStart;
        NSMutableArray *cgImages = [NSMutableArray array]; for (NSImage *image in images) { NSRect rect = NSMakeRect(0, 0, image.size.width, image.size.height); CGImageRef cgImage = [image CGImageForProposedRect:&rect context:nil hints:nil]; [cgImages addObject:(__bridge id)cgImage]; }
        NSMutableArray *parallelPNGs = [NSMutableArray arrayWithArray:@[NSNull.null, NSNull.null, NSNull.null]]; CFAbsoluteTime parallelStart = CFAbsoluteTimeGetCurrent();
        dispatch_apply(cgImages.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) { NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)cgImages[index]]; NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{NSImageCompressionFactor: @0.0}]; @synchronized (parallelPNGs) { parallelPNGs[index] = png; } });
        CFAbsoluteTime parallelElapsed = CFAbsoluteTimeGetCurrent() - parallelStart;
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        FPClipboardPayload *payload = FPCreateClipboardPayload(cgImages);
        CFAbsoluteTime elapsed = CFAbsoluteTimeGetCurrent() - start;
        printf("legacy-total=%.4f parallel-encode=%.4f optimized-total=%.4f payload-bytes=%lu\n", tiffElapsed + pngElapsed + decodeElapsed + legacyAssemblyElapsed, parallelElapsed, elapsed, (unsigned long)payload.primaryData.length);
    }
    return 0;
}
