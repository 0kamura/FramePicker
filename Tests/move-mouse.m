#import <ApplicationServices/ApplicationServices.h>
#import <stdio.h>
#import <stdlib.h>

int main(int argc, const char *argv[]) {
    if (argc != 3) return 2;
    CGPoint target = CGPointMake(atof(argv[1]), atof(argv[2]));
    CGWarpMouseCursorPosition(target);
    CGEventRef movement = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, target, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, movement);
    CFRelease(movement);
    CGAssociateMouseAndMouseCursorPosition(true);
    CGEventRef event = CGEventCreate(NULL);
    CGPoint point = CGEventGetLocation(event);
    printf("%.0f %.0f\n", point.x, point.y);
    CFRelease(event);
    return 0;
}
