#import <UIKit/UIKit.h>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
using Sint16 = int16_t;
constexpr int SDL_JOYSTICK_AXIS_MAX = 32767;
static std::atomic_bool sTouchStickActive(false);
static Sint16 axisX, axisY;
static void SpaghettiPad_SetStickAxes(Sint16 x, Sint16 y) { axisX = x; axisY = y; }
#include "SpaghettiPadTouchStick.inc"

@interface TestTouch : UITouch
@property(nonatomic) CGPoint point;
@end
@implementation TestTouch
- (CGPoint)locationInView:(UIView*)view { return self.point; }
@end
static void check(bool value, const char* message) {
    if (!value) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}
int main() {
    @autoreleasepool {
        UIView* overlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 800, 400)];
        SpaghettiPadTouchStick* stick = [[SpaghettiPadTouchStick alloc]
            initWithFrame:CGRectMake(80, 220, 120, 120)];
        [overlay addSubview:stick];
        [stick layoutIfNeeded];
        check(stick.disc.hidden, "idle stick must be invisible");
        check([stick pointInside:CGPointMake(-60, 60) withEvent:nil], "expanded pickup zone");
        check(![stick pointInside:CGPointMake(-90, 60) withEvent:nil], "pickup remains bounded");
        TestTouch* finger = [TestTouch new];
        finger.point = CGPointMake(-30, 80);
        NSSet* owned = [NSSet setWithObject:finger];
        [stick touchesBegan:owned withEvent:nil];
        check(axisX == 0 && axisY == 0, "touch down must start neutral");
        check(CGPointEqualToPoint(stick.disc.center, finger.point), "stick must center under thumb");
        check(!stick.disc.hidden && sTouchStickActive, "touch must show and own stick");
        finger.point = CGPointMake(10.8, 80);
        [stick touchesMoved:owned withEvent:nil];
        check(axisX == 32767 && axisY == 0, "existing full-scale steering travel");
        TestTouch* other = [TestTouch new];
        other.point = CGPointMake(60, 60);
        NSSet* foreign = [NSSet setWithObject:other];
        [stick touchesBegan:foreign withEvent:nil];
        [stick touchesMoved:foreign withEvent:nil];
        [stick touchesEnded:foreign withEvent:nil];
        check(stick.activeTouch == finger && axisX == 32767, "second touch cannot steal or release steering");
        finger.point = CGPointMake(-300, -190);
        [stick touchesMoved:owned withEvent:nil];
        check(axisX < 0 && axisY < 0 && hypot(axisX, axisY) <= 32768, "diagonal radial clamp");
        [stick touchesEnded:owned withEvent:nil];
        check(stick.disc.hidden && axisX == 0 && axisY == 0 && !sTouchStickActive, "lift hides and releases axes");
        finger.point = CGPointMake(100, 30);
        [stick touchesBegan:owned withEvent:nil];
        check(CGPointEqualToPoint(stick.disc.center, finger.point) && axisX == 0, "next touch recenters");
        [stick touchesCancelled:owned withEvent:nil];
        check(stick.disc.hidden && !sTouchStickActive, "cancel hides and releases");
        [stick touchesBegan:owned withEvent:nil];
        stick.layoutEditing = YES;
        [stick layoutIfNeeded];
        check(!stick.disc.hidden && !sTouchStickActive, "editor shows resting stick without input");
        check(![stick pointInside:CGPointMake(-60, 60) withEvent:nil], "editor uses exact editable frame");
        [stick touchesBegan:owned withEvent:nil];
        check(!sTouchStickActive, "editor cannot steer");
        stick.layoutEditing = NO;
        [stick layoutIfNeeded];
        check(stick.disc.hidden, "leaving editor hides stick");
        [stick touchesBegan:owned withEvent:nil];
        stick.bounds = CGRectMake(0, 0, 150, 150);
        [stick layoutIfNeeded];
        check(stick.disc.hidden && !sTouchStickActive && axisX == 0, "resize cancels input");
        UIButton* button = [[UIButton alloc] initWithFrame:CGRectMake(30, 260, 40, 40)];
        [overlay addSubview:button];
        check([overlay hitTest:CGPointMake(45, 275) withEvent:nil] == button, "buttons win over pickup zone");
        check([overlay hitTest:CGPointMake(60, 300) withEvent:nil] == stick, "expanded zone routes UIKit touches");
        stick.floatingEnabled = NO;
        [stick layoutIfNeeded];
        check(!stick.disc.hidden, "legacy stick stays visible");
        check(![stick pointInside:CGPointMake(-60, 60) withEvent:nil], "legacy keeps fixed pickup frame");
        finger.point = CGPointMake(126, 75);
        [stick touchesBegan:owned withEvent:nil];
        check(axisX == 32767 && axisY == 0, "legacy uses fixed center");
        [stick touchesEnded:owned withEvent:nil];
        check(!stick.disc.hidden && axisX == 0, "legacy release stays visible");
        stick.hidden = YES;
        check([overlay hitTest:CGPointMake(60, 300) withEvent:nil] == overlay, "hidden overlay control cannot capture touches");
        puts("Floating stick UIKit regression passed.");
    }
}
