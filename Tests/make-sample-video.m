#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 && argc != 4) return 2;
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        int width = argc == 4 ? atoi(argv[2]) : 540;
        int height = argc == 4 ? atoi(argv[3]) : 960;
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

        NSError *error = nil;
        AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&error];
        NSDictionary *settings = @{
            AVVideoCodecKey: AVVideoCodecTypeH264,
            AVVideoWidthKey: @(width),
            AVVideoHeightKey: @(height)
        };
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
        input.expectsMediaDataInRealTime = NO;
        NSDictionary *attributes = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            (NSString *)kCVPixelBufferWidthKey: @(width),
            (NSString *)kCVPixelBufferHeightKey: @(height)
        };
        AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:attributes];
        [writer addInput:input];
        [writer startWriting];
        [writer startSessionAtSourceTime:kCMTimeZero];

        for (int frame = 0; frame < 90; frame++) {
            while (!input.readyForMoreMediaData) [NSThread sleepForTimeInterval:0.002];
            CVPixelBufferRef buffer = NULL;
            CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &buffer);
            CVPixelBufferLockBaseAddress(buffer, 0);
            uint8_t *bytes = CVPixelBufferGetBaseAddress(buffer);
            size_t rowBytes = CVPixelBufferGetBytesPerRow(buffer);
            for (int y = 0; y < height; y++) {
                uint8_t *row = bytes + y * rowBytes;
                for (int x = 0; x < width; x++) {
                    row[x * 4 + 0] = (uint8_t)((x + frame * 3) % 256);
                    row[x * 4 + 1] = (uint8_t)((y / 4 + frame * 2) % 256);
                    row[x * 4 + 2] = (uint8_t)(60 + frame * 2);
                    row[x * 4 + 3] = 255;
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, 0);
            [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame, 30)];
            CVPixelBufferRelease(buffer);
        }
        [input markAsFinished];
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
        return writer.status == AVAssetWriterStatusCompleted ? 0 : 1;
    }
}
