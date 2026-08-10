#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FPClipboardPayload : NSObject
@property (copy) NSString *primaryType;
@property NSData *primaryData;
@property (copy, nullable) NSString *plainText;
@property (copy, nullable) NSString *html;
@end

FOUNDATION_EXPORT FPClipboardPayload * _Nullable FPCreateClipboardPayload(NSArray *cgImages);

NS_ASSUME_NONNULL_END
