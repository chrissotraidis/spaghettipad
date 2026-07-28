#include <stdbool.h>

#import <CoreMotion/CoreMotion.h>
#import <UIKit/UIKit.h>
#include <TargetConditionals.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#if TARGET_OS_SIMULATOR
#include <vector>
#endif

#include <SDL.h>
#include <SDL_syswm.h>

#include "SpaghettiPadTouchControls.h"

#ifndef SPAGHETTIPAD_TOUCH_KEYBOARD_FALLBACK
#define SPAGHETTIPAD_TOUCH_KEYBOARD_FALLBACK 0
#endif

typedef NS_ENUM(NSInteger, SpaghettiPadAction) {
    SpaghettiPadActionA,
    SpaghettiPadActionB,
    SpaghettiPadActionL,
    SpaghettiPadActionR,
    SpaghettiPadActionZ,
    SpaghettiPadActionStart,
    SpaghettiPadActionDUp,
    SpaghettiPadActionDDown,
    SpaghettiPadActionDLeft,
    SpaghettiPadActionDRight,
    SpaghettiPadActionCUp,
    SpaghettiPadActionCDown,
    SpaghettiPadActionCLeft,
    SpaghettiPadActionCRight,
    SpaghettiPadActionMenu,
    SpaghettiPadActionCount,
};

static UIWindow* sSDLWindow;
static SDL_Joystick* sVirtualJoystick;
static int sVirtualDeviceIndex = -1;
static std::array<int, SpaghettiPadActionCount> sActionPressCounts = {};
static std::atomic_bool sTouchControlsMenuVisible(false);
static std::atomic_bool sTouchStickActive(false);
static BOOL sTouchControlsDesired;
static BOOL sControllerWatchInstalled;
static CMMotionManager* sMotionManager;
static BOOL sTiltEnabled;
static float sTiltSensitivity = 1.0f;
static BOOL sTiltReferenceValid;
static double sTiltReferenceRoll;
static double sTiltFilteredDelta;
#if TARGET_OS_SIMULATOR
static std::vector<SDL_Joystick*> sSimulatorTestControllers;
static NSTimer* sSimulatorTiltTimer;
static double sSimulatorTiltRoll;
static BOOL sSimulatorTiltNeedsNeutralSample;
static BOOL sSimulatorTiltHasStarted;
#endif

static void SpaghettiPad_AttachVirtualController(void);
static void SpaghettiPad_DetachVirtualController(void);
static void SpaghettiPad_ApplyTouchControlsState(void);
static void SpaghettiPad_StartTiltUpdates(void);
static void SpaghettiPad_StopTiltUpdates(void);

static void SpaghettiPad_PushKey(SDL_Scancode scancode, BOOL pressed) {
    SDL_Event event = {};
    event.type = pressed ? SDL_KEYDOWN : SDL_KEYUP;
    event.key.timestamp = SDL_GetTicks();
    event.key.state = pressed ? SDL_PRESSED : SDL_RELEASED;
    event.key.repeat = 0;
    event.key.keysym.scancode = scancode;
    event.key.keysym.sym = SDL_GetKeyFromScancode(scancode);
    SDL_Window* window = SDL_GetKeyboardFocus();
    if (window != nullptr) {
        event.key.windowID = SDL_GetWindowID(window);
    }
    SDL_PushEvent(&event);
}

static SDL_Scancode SpaghettiPad_ActionScancode(SpaghettiPadAction action) {
    switch (action) {
        case SpaghettiPadActionA:
            return SDL_SCANCODE_LSHIFT;
        case SpaghettiPadActionB:
            return SDL_SCANCODE_LCTRL;
        case SpaghettiPadActionL:
            return SDL_SCANCODE_Q;
        case SpaghettiPadActionR:
            return SDL_SCANCODE_SPACE;
        case SpaghettiPadActionZ:
            return SDL_SCANCODE_Z;
        case SpaghettiPadActionStart:
            return SDL_SCANCODE_RETURN;
        case SpaghettiPadActionDUp:
            return SDL_SCANCODE_KP_8;
        case SpaghettiPadActionDDown:
            return SDL_SCANCODE_KP_2;
        case SpaghettiPadActionDLeft:
            return SDL_SCANCODE_KP_4;
        case SpaghettiPadActionDRight:
            return SDL_SCANCODE_KP_6;
        case SpaghettiPadActionCUp:
            return SDL_SCANCODE_T;
        case SpaghettiPadActionCDown:
            return SDL_SCANCODE_G;
        case SpaghettiPadActionCLeft:
            return SDL_SCANCODE_F;
        case SpaghettiPadActionCRight:
            return SDL_SCANCODE_H;
        case SpaghettiPadActionMenu:
            return SDL_SCANCODE_ESCAPE;
        default:
            return SDL_SCANCODE_UNKNOWN;
    }
}

static SDL_GameControllerButton SpaghettiPad_ActionButton(SpaghettiPadAction action) {
    switch (action) {
        case SpaghettiPadActionA:
            return SDL_CONTROLLER_BUTTON_A;
        case SpaghettiPadActionB:
            return SDL_CONTROLLER_BUTTON_X;
        case SpaghettiPadActionL:
            return SDL_CONTROLLER_BUTTON_LEFTSHOULDER;
        case SpaghettiPadActionR:
            return SDL_CONTROLLER_BUTTON_RIGHTSHOULDER;
        case SpaghettiPadActionStart:
            return SDL_CONTROLLER_BUTTON_START;
        case SpaghettiPadActionDUp:
            return SDL_CONTROLLER_BUTTON_DPAD_UP;
        case SpaghettiPadActionDDown:
            return SDL_CONTROLLER_BUTTON_DPAD_DOWN;
        case SpaghettiPadActionDLeft:
            return SDL_CONTROLLER_BUTTON_DPAD_LEFT;
        case SpaghettiPadActionDRight:
            return SDL_CONTROLLER_BUTTON_DPAD_RIGHT;
        case SpaghettiPadActionCDown:
            return SDL_CONTROLLER_BUTTON_B;
        case SpaghettiPadActionCLeft:
            return SDL_CONTROLLER_BUTTON_Y;
        default:
            return SDL_CONTROLLER_BUTTON_INVALID;
    }
}

static void SpaghettiPad_EmitAction(SpaghettiPadAction action, BOOL pressed) {
#if TARGET_OS_SIMULATOR
    SDL_Log(
        "[SpaghettiPad] touch action=%ld pressed=%d",
        (long)action, pressed ? 1 : 0);
#endif
    if (!SPAGHETTIPAD_TOUCH_KEYBOARD_FALLBACK &&
        action != SpaghettiPadActionMenu &&
        sVirtualJoystick != nullptr) {
        Sint16 axisValue = pressed ? SDL_JOYSTICK_AXIS_MAX : 0;
        if (action == SpaghettiPadActionZ) {
            SDL_JoystickSetVirtualAxis(
                sVirtualJoystick, SDL_CONTROLLER_AXIS_TRIGGERLEFT, axisValue);
            return;
        }
        if (action == SpaghettiPadActionCUp) {
            SDL_JoystickSetVirtualAxis(
                sVirtualJoystick, SDL_CONTROLLER_AXIS_RIGHTY, -axisValue);
            return;
        }
        if (action == SpaghettiPadActionCRight) {
            SDL_JoystickSetVirtualAxis(
                sVirtualJoystick, SDL_CONTROLLER_AXIS_RIGHTX, axisValue);
            return;
        }

        SDL_GameControllerButton button = SpaghettiPad_ActionButton(action);
        if (button != SDL_CONTROLLER_BUTTON_INVALID) {
            SDL_JoystickSetVirtualButton(
                sVirtualJoystick, button, pressed ? SDL_PRESSED : SDL_RELEASED);
            return;
        }
    }

    SDL_Scancode scancode = SpaghettiPad_ActionScancode(action);
    if (scancode != SDL_SCANCODE_UNKNOWN) {
        SpaghettiPad_PushKey(scancode, pressed);
    }
}

static void SpaghettiPad_SetAction(SpaghettiPadAction action, BOOL pressed) {
    int& count = sActionPressCounts[action];
    BOOL wasPressed = count > 0;
    if (pressed) {
        count += 1;
    } else {
        count = MAX(0, count - 1);
    }
    BOOL isPressed = count > 0;
    if (wasPressed != isPressed) {
        SpaghettiPad_EmitAction(action, isPressed);
    }
}

static BOOL sFallbackStickLeft;
static BOOL sFallbackStickRight;
static BOOL sFallbackStickUp;
static BOOL sFallbackStickDown;

static void SpaghettiPad_SetStickAxes(Sint16 x, Sint16 y) {
    if (SPAGHETTIPAD_TOUCH_KEYBOARD_FALLBACK) {
        const Sint16 threshold = SDL_JOYSTICK_AXIS_MAX / 3;
        BOOL left = x < -threshold;
        BOOL right = x > threshold;
        BOOL up = y < -threshold;
        BOOL down = y > threshold;
        if (left != sFallbackStickLeft) {
            SpaghettiPad_PushKey(SDL_SCANCODE_LEFT, left);
            sFallbackStickLeft = left;
        }
        if (right != sFallbackStickRight) {
            SpaghettiPad_PushKey(SDL_SCANCODE_RIGHT, right);
            sFallbackStickRight = right;
        }
        if (up != sFallbackStickUp) {
            SpaghettiPad_PushKey(SDL_SCANCODE_UP, up);
            sFallbackStickUp = up;
        }
        if (down != sFallbackStickDown) {
            SpaghettiPad_PushKey(SDL_SCANCODE_DOWN, down);
            sFallbackStickDown = down;
        }
        return;
    }

    if (sVirtualJoystick != nullptr) {
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTX, x);
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTY, y);
    }
}

static void SpaghettiPad_SetTiltAxis(Sint16 x) {
    if (!SPAGHETTIPAD_TOUCH_KEYBOARD_FALLBACK &&
        sVirtualJoystick != nullptr) {
        SDL_JoystickSetVirtualAxis(
            sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTX, x);
#if TARGET_OS_SIMULATOR
        static Sint16 lastLoggedAxis;
        if (std::abs((int)x - (int)lastLoggedAxis) >= 4096 ||
            (x == 0 && lastLoggedAxis != 0)) {
            lastLoggedAxis = x;
            SDL_Log("[SpaghettiPad] simulated tilt axis x=%d", x);
        }
#endif
    }
}

static void SpaghettiPad_ProcessTiltRoll(double roll) {
    if (!sTiltEnabled || sTouchControlsMenuVisible.load() ||
        sTouchStickActive.load() || sVirtualJoystick == nullptr) {
        return;
    }

    if (!sTiltReferenceValid) {
        sTiltReferenceRoll = roll;
        sTiltFilteredDelta = 0.0;
        sTiltReferenceValid = YES;
        SpaghettiPad_SetTiltAxis(0);
        SDL_Log("[SpaghettiPad] tilt steering centered");
        return;
    }

    double delta = std::remainder(roll - sTiltReferenceRoll, 2.0 * M_PI);
    sTiltFilteredDelta += (delta - sTiltFilteredDelta) * 0.18;
    double normalized = sTiltFilteredDelta * sTiltSensitivity / 0.45;
    if (std::abs(normalized) < 0.035) {
        normalized = 0.0;
    }
    normalized = std::clamp(normalized, -1.0, 1.0);
    SpaghettiPad_SetTiltAxis(
        (Sint16)std::lround(normalized * SDL_JOYSTICK_AXIS_MAX));
}

static void SpaghettiPad_StartTiltUpdates(void) {
    if (!sTiltEnabled) {
        return;
    }

    sTiltReferenceValid = NO;
    sTiltFilteredDelta = 0.0;

#if TARGET_OS_SIMULATOR
    NSString* simulatedDegrees = NSProcessInfo.processInfo.environment[
        @"SPAGHETTIPAD_SIMULATED_TILT_DEGREES"];
    if (simulatedDegrees.length > 0) {
        sSimulatorTiltRoll = simulatedDegrees.doubleValue * M_PI / 180.0;
        sSimulatorTiltNeedsNeutralSample = !sSimulatorTiltHasStarted;
        sSimulatorTiltHasStarted = YES;
        [sSimulatorTiltTimer invalidate];
        sSimulatorTiltTimer = [NSTimer
            scheduledTimerWithTimeInterval:1.0 / 60.0
                                  repeats:YES
                                    block:^(NSTimer* timer) {
                (void)timer;
                if (sTouchControlsMenuVisible.load() ||
                    sTouchStickActive.load()) {
                    return;
                }
                double roll = sSimulatorTiltNeedsNeutralSample
                    ? 0.0 : sSimulatorTiltRoll;
                sSimulatorTiltNeedsNeutralSample = NO;
                SpaghettiPad_ProcessTiltRoll(roll);
            }];
        SDL_Log(
            "[SpaghettiPad] simulated tilt enabled at %.1f degrees",
            simulatedDegrees.doubleValue);
        return;
    }
#endif

    if (sMotionManager == nil) {
        sMotionManager = [[CMMotionManager alloc] init];
    }
    if (!sMotionManager.deviceMotionAvailable) {
        SDL_Log("[SpaghettiPad] tilt steering unavailable on this device");
        return;
    }

    sMotionManager.deviceMotionUpdateInterval = 1.0 / 60.0;
    [sMotionManager
        startDeviceMotionUpdatesUsingReferenceFrame:
            CMAttitudeReferenceFrameXArbitraryZVertical
                                          toQueue:NSOperationQueue.mainQueue
                                      withHandler:^(
                                          CMDeviceMotion* motion,
                                          NSError* error) {
        if (error == nil && motion != nil) {
            SpaghettiPad_ProcessTiltRoll(motion.attitude.roll);
        }
    }];
    SDL_Log("[SpaghettiPad] tilt steering updates started at 60 Hz");
}

static void SpaghettiPad_StopTiltUpdates(void) {
    [sMotionManager stopDeviceMotionUpdates];
#if TARGET_OS_SIMULATOR
    [sSimulatorTiltTimer invalidate];
    sSimulatorTiltTimer = nil;
#endif
    sTiltReferenceValid = NO;
    sTiltFilteredDelta = 0.0;
    SpaghettiPad_SetTiltAxis(0);
}

static void SpaghettiPad_ResetAllInputs(void) {
    for (NSInteger action = 0; action < SpaghettiPadActionCount; ++action) {
        if (sActionPressCounts[action] > 0) {
            sActionPressCounts[action] = 0;
            SpaghettiPad_EmitAction((SpaghettiPadAction)action, NO);
        }
    }
    SpaghettiPad_SetStickAxes(0, 0);
    sTouchStickActive.store(false);
}

@interface SpaghettiPadTouchButton : UIButton

@property(nonatomic) SpaghettiPadAction action;
@property(nonatomic) BOOL inputPressed;
@property(nonatomic) CFTimeInterval inputDownTime;
@property(nonatomic) NSUInteger releaseGeneration;
@property(nonatomic) BOOL usesPillShape;
@property(nonatomic, strong) UIColor* idleColor;
@property(nonatomic, strong) UIColor* pressedColor;

- (instancetype)initWithLabel:(NSString*)label
                       action:(SpaghettiPadAction)action
                         pill:(BOOL)pill;
- (void)applyIdleColor:(UIColor*)idleColor
          pressedColor:(UIColor*)pressedColor;
- (void)cancelInput;

@end

@implementation SpaghettiPadTouchButton

- (instancetype)initWithLabel:(NSString*)label
                       action:(SpaghettiPadAction)action
                         pill:(BOOL)pill {
    self = [super initWithFrame:CGRectZero];
    if (self != nil) {
        self.action = action;
        self.usesPillShape = pill;
        self.multipleTouchEnabled = YES;
        self.idleColor = [UIColor colorWithWhite:0.04 alpha:0.38];
        self.pressedColor = [UIColor colorWithWhite:0.72 alpha:0.48];
        self.backgroundColor = self.idleColor;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.58].CGColor;
        self.layer.borderWidth = 2.0;
        [self setTitle:label forState:UIControlStateNormal];
        [self setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.92]
                   forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
        self.accessibilityLabel = label;

        [self addTarget:self
                      action:@selector(inputDown)
            forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [self addTarget:self
                      action:@selector(inputUp)
            forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                             UIControlEventTouchCancel | UIControlEventTouchDragExit];
    }
    return self;
}

- (void)applyIdleColor:(UIColor*)idleColor
          pressedColor:(UIColor*)pressedColor {
    self.idleColor = idleColor;
    self.pressedColor = pressedColor;
    self.backgroundColor = self.inputPressed ? pressedColor : idleColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius =
        self.usesPillShape ? CGRectGetHeight(self.bounds) * 0.48
                           : MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) * 0.5;
}

- (void)inputDown {
    self.releaseGeneration += 1;
    if (self.inputPressed) {
        return;
    }
    self.inputPressed = YES;
    self.inputDownTime = CACurrentMediaTime();
    self.backgroundColor = self.pressedColor;
    SpaghettiPad_SetAction(self.action, YES);
}

- (void)inputUp {
    if (!self.inputPressed) {
        return;
    }
    if (self.action != SpaghettiPadActionMenu) {
        CFTimeInterval remaining =
            MAX(0.0, 0.05 - (CACurrentMediaTime() - self.inputDownTime));
        if (remaining > 0.0) {
            NSUInteger generation = ++self.releaseGeneration;
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    if (self.releaseGeneration == generation) {
                        [self finishInputRelease];
                    }
                });
            return;
        }
    }
    [self finishInputRelease];
}

- (void)finishInputRelease {
    if (!self.inputPressed) {
        return;
    }
    self.inputPressed = NO;
    self.backgroundColor = self.idleColor;
    SpaghettiPad_SetAction(self.action, NO);
}

- (void)cancelInput {
    self.releaseGeneration += 1;
    [self finishInputRelease];
}

@end

@interface SpaghettiPadTouchStick : UIView

@property(nonatomic, strong) UIView* knob;

- (void)cancelInput;

@end

@implementation SpaghettiPadTouchStick

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.multipleTouchEnabled = NO;
        self.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.30];
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.42].CGColor;
        self.layer.borderWidth = 2.0;
        self.accessibilityLabel = @"Steering";

        self.knob = [[UIView alloc] initWithFrame:CGRectZero];
        self.knob.userInteractionEnabled = NO;
        self.knob.backgroundColor =
            [UIColor colorWithRed:0.34 green:0.62 blue:0.82 alpha:0.68];
        self.knob.layer.borderColor =
            [UIColor colorWithWhite:1.0 alpha:0.62].CGColor;
        self.knob.layer.borderWidth = 2.0;
        [self addSubview:self.knob];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat size = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    self.layer.cornerRadius = size * 0.5;
    CGFloat knobSize = size * 0.43;
    self.knob.bounds = CGRectMake(0.0, 0.0, knobSize, knobSize);
    self.knob.layer.cornerRadius = knobSize * 0.5;
    if (!sTouchStickActive.load()) {
        self.knob.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    }
}

- (void)updateForPoint:(CGPoint)point {
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat size = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    CGFloat radius = size * 0.34;
    CGFloat dx = point.x - center.x;
    CGFloat dy = point.y - center.y;
    CGFloat distance = hypot(dx, dy);
    if (distance > radius && distance > 0.0) {
        dx = dx / distance * radius;
        dy = dy / distance * radius;
    }

    self.knob.center = CGPointMake(center.x + dx, center.y + dy);

    Sint16 x = (Sint16)std::lround(
        MAX(-1.0, MIN(1.0, (double)(dx / radius))) * SDL_JOYSTICK_AXIS_MAX);
    Sint16 y = (Sint16)std::lround(
        MAX(-1.0, MIN(1.0, (double)(dy / radius))) * SDL_JOYSTICK_AXIS_MAX);
    SpaghettiPad_SetStickAxes(x, y);
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    UITouch* touch = touches.anyObject;
    if (touch == nil) {
        return;
    }
    sTouchStickActive.store(true);
    [self updateForPoint:[touch locationInView:self]];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    UITouch* touch = touches.anyObject;
    if (touch != nil) {
        [self updateForPoint:[touch locationInView:self]];
    }
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self cancelInput];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self cancelInput];
}

- (void)cancelInput {
    SpaghettiPad_SetStickAxes(0, 0);
    sTouchStickActive.store(false);
    self.knob.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}

@end

static CGRect SpaghettiPad_CenteredFrame(CGPoint center, CGFloat width, CGFloat height) {
    return CGRectMake(center.x - width * 0.5, center.y - height * 0.5, width, height);
}

@interface SpaghettiPadTouchOverlay : UIView

@property(nonatomic, strong) SpaghettiPadTouchStick* controlStick;
@property(nonatomic, strong) NSArray<SpaghettiPadTouchButton*>* buttons;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonA;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonB;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonL;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonZLeft;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonZRight;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonR;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonStart;
@property(nonatomic, strong) SpaghettiPadTouchButton* dUp;
@property(nonatomic, strong) SpaghettiPadTouchButton* dDown;
@property(nonatomic, strong) SpaghettiPadTouchButton* dLeft;
@property(nonatomic, strong) SpaghettiPadTouchButton* dRight;
@property(nonatomic, strong) SpaghettiPadTouchButton* cUp;
@property(nonatomic, strong) SpaghettiPadTouchButton* cDown;
@property(nonatomic, strong) SpaghettiPadTouchButton* cLeft;
@property(nonatomic, strong) SpaghettiPadTouchButton* cRight;

- (void)cancelAllInputs;

@end

@implementation SpaghettiPadTouchOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.backgroundColor = UIColor.clearColor;
        self.multipleTouchEnabled = YES;

        self.controlStick = [[SpaghettiPadTouchStick alloc] initWithFrame:CGRectZero];
        self.buttonA = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"A" action:SpaghettiPadActionA pill:NO];
        self.buttonB = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"B" action:SpaghettiPadActionB pill:NO];
        self.buttonL = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"L" action:SpaghettiPadActionL pill:YES];
        self.buttonZLeft = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"Z" action:SpaghettiPadActionZ pill:NO];
        self.buttonZRight = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"Z" action:SpaghettiPadActionZ pill:NO];
        self.buttonR = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"R" action:SpaghettiPadActionR pill:YES];
        self.buttonStart = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"▶" action:SpaghettiPadActionStart pill:NO];
        self.dUp = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"▲" action:SpaghettiPadActionDUp pill:NO];
        self.dDown = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"▼" action:SpaghettiPadActionDDown pill:NO];
        self.dLeft = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"◀" action:SpaghettiPadActionDLeft pill:NO];
        self.dRight = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"▶" action:SpaghettiPadActionDRight pill:NO];
        self.cUp = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"▲" action:SpaghettiPadActionCUp pill:NO];
        self.cDown = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"▼" action:SpaghettiPadActionCDown pill:NO];
        self.cLeft = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"◀" action:SpaghettiPadActionCLeft pill:NO];
        self.cRight = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"▶" action:SpaghettiPadActionCRight pill:NO];

        [self.buttonA
            applyIdleColor:[UIColor colorWithRed:0.08 green:0.35 blue:0.88 alpha:0.58]
              pressedColor:[UIColor colorWithRed:0.14 green:0.48 blue:1.00 alpha:0.88]];
        [self.buttonB
            applyIdleColor:[UIColor colorWithRed:0.05 green:0.55 blue:0.24 alpha:0.58]
              pressedColor:[UIColor colorWithRed:0.10 green:0.76 blue:0.34 alpha:0.88]];
        [self.buttonStart
            applyIdleColor:[UIColor colorWithRed:0.68 green:0.12 blue:0.16 alpha:0.52]
              pressedColor:[UIColor colorWithRed:0.94 green:0.22 blue:0.26 alpha:0.88]];
        UIColor* cIdle = [UIColor colorWithRed:0.95 green:0.67 blue:0.12 alpha:0.48];
        UIColor* cPressed = [UIColor colorWithRed:1.00 green:0.78 blue:0.20 alpha:0.86];
        for (SpaghettiPadTouchButton* button in
             @[ self.cUp, self.cDown, self.cLeft, self.cRight ]) {
            [button applyIdleColor:cIdle pressedColor:cPressed];
        }

        self.buttonStart.accessibilityLabel = @"Start";
        self.buttonZLeft.accessibilityLabel = @"Z left";
        self.buttonZRight.accessibilityLabel = @"Z right";
        self.dUp.accessibilityLabel = @"D-pad Up";
        self.dDown.accessibilityLabel = @"D-pad Down";
        self.dLeft.accessibilityLabel = @"D-pad Left";
        self.dRight.accessibilityLabel = @"D-pad Right";
        self.cUp.accessibilityLabel = @"C Up";
        self.cDown.accessibilityLabel = @"C Down";
        self.cLeft.accessibilityLabel = @"C Left";
        self.cRight.accessibilityLabel = @"C Right";

        self.buttons = @[
            self.buttonA, self.buttonB, self.buttonL, self.buttonZLeft,
            self.buttonZRight, self.buttonR, self.buttonStart,
            self.dUp, self.dDown, self.dLeft, self.dRight,
            self.cUp, self.cDown, self.cLeft, self.cRight,
        ];
        [self addSubview:self.controlStick];
        for (SpaghettiPadTouchButton* button in self.buttons) {
            [self addSubview:button];
        }
    }
    return self;
}

- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    BOOL compact = height < 560.0;

    if (compact) {
        // HarkinianPad's compact layout is purpose-built for a phone rather
        // than a proportional reduction of the iPad controls.
        CGFloat left = safe.left + 10.0;
        CGFloat right = safe.right + 10.0;
        CGFloat top = safe.top + 36.0;
        CGFloat shoulderHeight = 44.0;
        CGFloat shoulderWidth = 76.0;

        self.buttonL.frame = CGRectMake(left, top, shoulderWidth, shoulderHeight);
        self.buttonZLeft.frame =
            CGRectMake(CGRectGetMaxX(self.buttonL.frame) + 8.0, top, shoulderHeight, shoulderHeight);
        self.buttonR.frame =
            CGRectMake(width - right - shoulderWidth, top, shoulderWidth, shoulderHeight);
        self.buttonStart.frame =
            CGRectMake(CGRectGetMinX(self.buttonR.frame) - shoulderHeight - 8.0, top,
                       shoulderHeight, shoulderHeight);

        CGFloat dSize = 44.0;
        CGFloat dRadius = 38.0;
        CGPoint dCenter = CGPointMake(left + 54.0, top + shoulderHeight + 80.0);
        self.dUp.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(dCenter.x, dCenter.y - dRadius), dSize, dSize);
        self.dDown.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(dCenter.x, dCenter.y + dRadius), dSize, dSize);
        self.dLeft.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(dCenter.x - dRadius, dCenter.y), dSize, dSize);
        self.dRight.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(dCenter.x + dRadius, dCenter.y), dSize, dSize);

        CGFloat stickSize = 116.0;
        CGPoint stickCenter = CGPointMake(left + 88.0, height - safe.bottom - 88.0);
        self.controlStick.frame =
            SpaghettiPad_CenteredFrame(stickCenter, stickSize, stickSize);

        CGFloat rightCenterX = width - right - 58.0;
        CGFloat faceCenterY = height - safe.bottom - 82.0;
        CGFloat faceSize = 52.0;
        self.buttonA.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX + 22.0, faceCenterY + 18.0), faceSize, faceSize);
        self.buttonB.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX - 34.0, faceCenterY + 2.0), faceSize, faceSize);
        self.buttonZRight.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX + 12.0, faceCenterY - 44.0), faceSize, faceSize);

        CGFloat cSize = 40.0;
        CGFloat cRadius = 34.0;
        CGPoint cCenter = CGPointMake(rightCenterX, top + shoulderHeight + 80.0);
        self.cUp.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(cCenter.x, cCenter.y - cRadius), cSize, cSize);
        self.cDown.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(cCenter.x, cCenter.y + cRadius), cSize, cSize);
        self.cLeft.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(cCenter.x - cRadius, cCenter.y), cSize, cSize);
        self.cRight.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(cCenter.x + cRadius, cCenter.y), cSize, cSize);

        for (SpaghettiPadTouchButton* button in self.buttons) {
            button.titleLabel.font =
                [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        }
        self.buttonStart.titleLabel.font =
            [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
        return;
    }

    CGFloat scale = MAX(0.78, MIN(1.12, height / 834.0));
    CGFloat edge = 18.0 * scale;
    CGFloat left = safe.left + edge;
    CGFloat right = safe.right + edge;
    CGFloat usableWidth = width - safe.left - safe.right;
    CGFloat railWidth = MIN(250.0 * scale, usableWidth * 0.22);
    CGFloat leftCenter = safe.left + railWidth * 0.5;
    CGFloat rightCenter = width - safe.right - railWidth * 0.5;
    CGFloat gripTopY = MAX(safe.top + edge, height * 0.38);
    CGFloat middleCenterY = height * 0.60;
    CGFloat lowCenterY = height * 0.86;
    CGFloat stickCenterX = leftCenter + 65.0 * scale;
    CGFloat stickCenterY = lowCenterY - 70.0 * scale;
    CGFloat dpadCenterX = leftCenter - 30.0 * scale;
    CGFloat dpadCenterY = middleCenterY + 5.0 * scale;
    CGFloat faceCenterX = rightCenter + 24.0 * scale;
    CGFloat faceCenterY = middleCenterY + 30.0 * scale;
    CGFloat cpadCenterX = rightCenter + 24.0 * scale;
    CGFloat cpadCenterY = lowCenterY - 20.0 * scale;

    CGFloat stickSize = 150.0 * scale;
    self.controlStick.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(stickCenterX, stickCenterY), stickSize, stickSize);

    CGFloat pillHeight = 54.0 * scale;
    CGFloat shoulderWidth = 106.0 * scale;
    CGFloat leftRowY = gripTopY + 55.0 * scale;
    self.buttonL.frame = CGRectMake(left, leftRowY, shoulderWidth, pillHeight);
    self.buttonZLeft.frame =
        CGRectMake(CGRectGetMaxX(self.buttonL.frame) + 10.0 * scale, leftRowY,
                   pillHeight, pillHeight);

    CGFloat dSize = 52.0 * scale;
    CGFloat dRadius = 48.0 * scale;
    CGPoint dCenter = CGPointMake(dpadCenterX, dpadCenterY);
    self.dUp.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(dCenter.x, dCenter.y - dRadius), dSize, dSize);
    self.dDown.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(dCenter.x, dCenter.y + dRadius), dSize, dSize);
    self.dLeft.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(dCenter.x - dRadius, dCenter.y), dSize, dSize);
    self.dRight.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(dCenter.x + dRadius, dCenter.y), dSize, dSize);

    CGFloat faceSize = 66.0 * scale;
    CGFloat faceX = faceCenterX - faceSize * 0.5;
    self.buttonA.frame = CGRectMake(
        faceX, faceCenterY + 12.0 * scale, faceSize, faceSize);
    self.buttonB.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(faceX - faceSize * 0.5 - 10.0 * scale, faceCenterY),
        faceSize, faceSize);
    self.buttonZRight.frame = CGRectMake(
        faceX, faceCenterY - faceSize - 12.0 * scale, faceSize, faceSize);

    CGFloat cSize = 46.0 * scale;
    CGFloat cRadius = 44.0 * scale;
    CGPoint cCenter = CGPointMake(cpadCenterX, cpadCenterY);
    self.cUp.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(cCenter.x, cCenter.y - cRadius), cSize, cSize);
    self.cDown.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(cCenter.x, cCenter.y + cRadius), cSize, cSize);
    self.cLeft.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(cCenter.x - cRadius, cCenter.y), cSize, cSize);
    self.cRight.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(cCenter.x + cRadius, cCenter.y), cSize, cSize);

    CGFloat rightRowY = gripTopY + 55.0 * scale;
    self.buttonR.frame =
        CGRectMake(width - right - shoulderWidth, rightRowY, shoulderWidth, pillHeight);
    self.buttonStart.frame =
        CGRectMake(CGRectGetMinX(self.buttonR.frame) - pillHeight - 12.0 * scale,
                   rightRowY, pillHeight, pillHeight);

    CGFloat labelSize = 18.0 * scale;
    for (SpaghettiPadTouchButton* button in self.buttons) {
        button.titleLabel.font =
            [UIFont systemFontOfSize:labelSize weight:UIFontWeightSemibold];
    }
    self.buttonStart.titleLabel.font =
        [UIFont systemFontOfSize:18.0 * scale weight:UIFontWeightBold];
}

- (void)cancelAllInputs {
    [self.controlStick cancelInput];
    for (SpaghettiPadTouchButton* button in self.buttons) {
        [button cancelInput];
    }
    SpaghettiPad_ResetAllInputs();
}

@end

static SpaghettiPadTouchOverlay* sTouchOverlay;
static SpaghettiPadTouchButton* sMenuButton;

static UIWindow* SpaghettiPad_GetSDLWindow(SDL_Window* sdlWindow) {
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (!SDL_GetWindowWMInfo(sdlWindow, &info) ||
        info.subsystem != SDL_SYSWM_UIKIT) {
        return nil;
    }
    return info.info.uikit.window;
}

static UIWindowScene* SpaghettiPad_ActiveScene(void) {
    UIWindowScene* fallback = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene*)scene;
        }
        fallback = (UIWindowScene*)scene;
    }
    return fallback;
}

static UIWindow* SpaghettiPad_ActiveWindow(void) {
    if (sSDLWindow != nil) {
        return sSDLWindow;
    }
    UIWindowScene* scene = SpaghettiPad_ActiveScene();
    for (UIWindow* window in scene.windows) {
        if (window.isKeyWindow) {
            return window;
        }
    }
    return scene.windows.firstObject;
}

static void SpaghettiPad_EnsureLandscape(UIWindow* window, int attempt) {
    UIWindowScene* scene = SpaghettiPad_ActiveScene();
    if (scene == nil && attempt < 20) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           SpaghettiPad_EnsureLandscape(window, attempt + 1);
                       });
        return;
    }
    if (scene == nil) {
        NSLog(@"[SpaghettiPad] no active window scene for landscape request");
        return;
    }

    if (window.windowScene != scene) {
        window.windowScene = scene;
    }
    window.frame = scene.coordinateSpace.bounds;

    if (scene.interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
        scene.interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        return;
    }

    if (@available(iOS 16.0, *)) {
        UIWindowSceneGeometryPreferencesIOS* preferences =
            [[UIWindowSceneGeometryPreferencesIOS alloc]
                initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscape];
        [scene requestGeometryUpdateWithPreferences:preferences
                                      errorHandler:^(NSError* error) {
                                          NSLog(@"[SpaghettiPad] landscape request failed: %@", error);
                                      }];
        [window.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
    }
}

static BOOL SpaghettiPad_HasPhysicalController(void) {
#if TARGET_OS_SIMULATOR
    // Virtual test controllers exercise the physical-controller policy without
    // changing device builds. The normal touch controller does not count.
    return !sSimulatorTestControllers.empty();
#else
    int joystickCount = SDL_NumJoysticks();
    for (int index = 0; index < joystickCount; ++index) {
        if (!SDL_JoystickIsVirtual(index) && SDL_IsGameController(index)) {
            return YES;
        }
    }
    return NO;
#endif
}

#if TARGET_OS_SIMULATOR
static void SpaghettiPad_AttachSimulatorTestControllers(void) {
    NSInteger requested = [NSProcessInfo.processInfo.environment
        [@"SPAGHETTIPAD_SIMULATED_CONTROLLERS"] integerValue];
    requested = MAX(0, MIN(requested, 4));
    for (NSInteger slot = 0; slot < requested; ++slot) {
        SDL_VirtualJoystickDesc descriptor = {};
        descriptor.version = SDL_VIRTUAL_JOYSTICK_DESC_VERSION;
        descriptor.type = SDL_JOYSTICK_TYPE_GAMECONTROLLER;
        descriptor.naxes = SDL_CONTROLLER_AXIS_MAX;
        descriptor.nbuttons = SDL_CONTROLLER_BUTTON_MAX;
        NSString* name = [NSString stringWithFormat:
            @"SpaghettiPad Simulator Controller %ld", (long)slot + 1];
        descriptor.name = name.UTF8String;
        int deviceIndex = SDL_JoystickAttachVirtualEx(&descriptor);
        SDL_Joystick* joystick =
            deviceIndex >= 0 ? SDL_JoystickOpen(deviceIndex) : nullptr;
        if (joystick == nullptr) {
            SDL_LogError(
                SDL_LOG_CATEGORY_INPUT,
                "[SpaghettiPad] simulator controller %ld attach failed: %s",
                (long)slot + 1, SDL_GetError());
            continue;
        }
        sSimulatorTestControllers.push_back(joystick);
        SDL_Log(
            "[SpaghettiPad] attached simulator controller %ld (instance %d)",
            (long)slot + 1, SDL_JoystickInstanceID(joystick));
    }
}

static void SpaghettiPad_ConfigureSimulatorTestControllers(void) {
    NSTimeInterval delay = [NSProcessInfo.processInfo.environment
        [@"SPAGHETTIPAD_SIMULATED_CONTROLLER_DELAY"] doubleValue];
    if (delay <= 0.0) {
        SpaghettiPad_AttachSimulatorTestControllers();
        return;
    }
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW, (int64_t)(MIN(delay, 10.0) * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            SpaghettiPad_AttachSimulatorTestControllers();
            SpaghettiPad_ApplyTouchControlsState();
        });
}
#endif

static int SpaghettiPad_VirtualControllerDeviceIndex(void) {
    if (sVirtualJoystick == nullptr) {
        return -1;
    }

    SDL_JoystickID instanceId = SDL_JoystickInstanceID(sVirtualJoystick);
    for (int index = 0; index < SDL_NumJoysticks(); ++index) {
        if (SDL_JoystickGetDeviceInstanceID(index) == instanceId) {
            return index;
        }
    }
    return -1;
}

static void SpaghettiPad_InstallMenuButton(UIWindow* window) {
    if (sMenuButton == nil) {
        sMenuButton = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"•••" action:SpaghettiPadActionMenu pill:NO];
        sMenuButton.accessibilityLabel = @"Menu";
        sMenuButton.titleLabel.font =
            [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        [sMenuButton
            applyIdleColor:[UIColor colorWithWhite:0.04 alpha:0.42]
              pressedColor:[UIColor colorWithWhite:0.72 alpha:0.62]];
    }

    UIEdgeInsets safe = window.safeAreaInsets;
    CGFloat height = CGRectGetHeight(window.bounds);
    BOOL compact = height < 560.0;
    CGFloat size = compact ? 44.0 : 38.0;
    if (compact) {
        BOOL menuVisible = sTouchControlsMenuVisible.load();
        CGFloat y = menuVisible
            ? height - safe.bottom - size - 8.0
            : safe.top + 8.0;
        sMenuButton.frame = CGRectMake(
            CGRectGetMidX(window.bounds) - size * 0.5, y, size, size);
    } else {
        sMenuButton.frame = CGRectMake(
            CGRectGetWidth(window.bounds) - safe.right - size - 8.0,
            safe.top + 76.0, size, size);
    }

    if (sMenuButton.superview != window) {
        [sMenuButton removeFromSuperview];
        [window addSubview:sMenuButton];
    }
    [window bringSubviewToFront:sMenuButton];
}

static void SpaghettiPad_ReleaseVisibleInputs(void) {
    [sTouchOverlay cancelAllInputs];
    [sMenuButton cancelInput];
    SpaghettiPad_ResetAllInputs();
}

static void SpaghettiPad_ApplyTouchControlsState(void) {
    UIWindow* window = SpaghettiPad_ActiveWindow();
    if (window == nil) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           SpaghettiPad_ApplyTouchControlsState();
                       });
        return;
    }

    SpaghettiPad_InstallMenuButton(window);
    BOOL hasPhysicalController = SpaghettiPad_HasPhysicalController();
    if (hasPhysicalController) {
        SpaghettiPad_DetachVirtualController();
    } else {
        SpaghettiPad_AttachVirtualController();
    }
    BOOL shouldHide = !sTouchControlsDesired ||
        sTouchControlsMenuVisible.load() ||
        hasPhysicalController;
    if (shouldHide) {
        SpaghettiPad_ReleaseVisibleInputs();
        [sTouchOverlay removeFromSuperview];
        sTouchOverlay = nil;
        return;
    }

    if (sTouchOverlay == nil) {
        sTouchOverlay = [[SpaghettiPadTouchOverlay alloc] initWithFrame:window.bounds];
        sTouchOverlay.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    if (sTouchOverlay.superview != window) {
        [sTouchOverlay removeFromSuperview];
        sTouchOverlay.frame = window.bounds;
        [window addSubview:sTouchOverlay];
    }
    [sTouchOverlay setNeedsLayout];
    [window bringSubviewToFront:sTouchOverlay];
    [window bringSubviewToFront:sMenuButton];
}

static int SpaghettiPad_ControllerEventWatch(void* userdata, SDL_Event* event) {
    (void)userdata;
    if (event->type == SDL_CONTROLLERDEVICEADDED ||
        event->type == SDL_CONTROLLERDEVICEREMOVED) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SpaghettiPad_ApplyTouchControlsState();
        });
    }
    return 1;
}

static void SpaghettiPad_AttachVirtualController(void) {
    if (SPAGHETTIPAD_TOUCH_KEYBOARD_FALLBACK || sVirtualJoystick != nullptr) {
        return;
    }

    SDL_VirtualJoystickDesc descriptor = {};
    descriptor.version = SDL_VIRTUAL_JOYSTICK_DESC_VERSION;
    descriptor.type = SDL_JOYSTICK_TYPE_GAMECONTROLLER;
    descriptor.naxes = SDL_CONTROLLER_AXIS_MAX;
    descriptor.nbuttons = SDL_CONTROLLER_BUTTON_MAX;
    descriptor.name = "SpaghettiPad Touch Controller";
    sVirtualDeviceIndex = SDL_JoystickAttachVirtualEx(&descriptor);
    if (sVirtualDeviceIndex < 0) {
        SDL_LogError(
            SDL_LOG_CATEGORY_INPUT,
            "[SpaghettiPad] virtual controller attach failed: %s", SDL_GetError());
        return;
    }

    sVirtualJoystick = SDL_JoystickOpen(sVirtualDeviceIndex);
    if (sVirtualJoystick == nullptr) {
        SDL_LogError(
            SDL_LOG_CATEGORY_INPUT,
            "[SpaghettiPad] virtual controller open failed: %s", SDL_GetError());
        return;
    }

    SpaghettiPad_ResetAllInputs();
    SDL_Log(
        "[SpaghettiPad] virtual controller attached at device %d, instance %d",
        sVirtualDeviceIndex, SDL_JoystickInstanceID(sVirtualJoystick));
}

static void SpaghettiPad_DetachVirtualController(void) {
    if (SPAGHETTIPAD_TOUCH_KEYBOARD_FALLBACK || sVirtualJoystick == nullptr) {
        return;
    }

    SpaghettiPad_ResetAllInputs();
    SDL_JoystickID instanceId = SDL_JoystickInstanceID(sVirtualJoystick);
    int deviceIndex = SpaghettiPad_VirtualControllerDeviceIndex();
    SDL_JoystickClose(sVirtualJoystick);
    sVirtualJoystick = nullptr;
    sVirtualDeviceIndex = -1;

    if (deviceIndex >= 0 && SDL_JoystickDetachVirtual(deviceIndex) == 0) {
        SDL_Log(
            "[SpaghettiPad] touch controller parked; physical controller owns port 1 "
            "(instance %d)",
            instanceId);
    } else {
        SDL_LogError(
            SDL_LOG_CATEGORY_INPUT,
            "[SpaghettiPad] virtual controller detach failed: %s", SDL_GetError());
    }
}

void SpaghettiPad_OnWindowCreated(SDL_Window* sdlWindow) {
    UIWindow* window = SpaghettiPad_GetSDLWindow(sdlWindow);
    if (window == nil) {
        NSLog(@"[SpaghettiPad] no UIKit window for SDL window");
        return;
    }
    sSDLWindow = window;

    dispatch_async(dispatch_get_main_queue(), ^{
        SpaghettiPad_EnsureLandscape(window, 0);
        if (sControllerWatchInstalled) {
            SpaghettiPad_ApplyTouchControlsState();
        }
    });
}

int SpaghettiPad_TouchControlsAvailable(void) {
    return 1;
}

void SpaghettiPad_InitializeTouchControls(void) {
    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "1");
#if TARGET_OS_SIMULATOR
    SpaghettiPad_ConfigureSimulatorTestControllers();
#endif
    if (!sControllerWatchInstalled) {
        SDL_AddEventWatch(SpaghettiPad_ControllerEventWatch, nullptr);
        sControllerWatchInstalled = YES;
        NSNotificationCenter* notifications = NSNotificationCenter.defaultCenter;
        [notifications
            addObserverForName:UIApplicationWillResignActiveNotification
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(NSNotification* notification) {
                        (void)notification;
                        SpaghettiPad_ReleaseVisibleInputs();
                        SpaghettiPad_StopTiltUpdates();
                    }];
        [notifications
            addObserverForName:UIApplicationDidEnterBackgroundNotification
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(NSNotification* notification) {
                        (void)notification;
                        SpaghettiPad_ReleaseVisibleInputs();
                    }];
        [notifications
            addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(NSNotification* notification) {
                        (void)notification;
                        SpaghettiPad_StartTiltUpdates();
                    }];
    }
    if (!SpaghettiPad_HasPhysicalController()) {
        SpaghettiPad_AttachVirtualController();
    }
}

void SpaghettiPad_SetTouchControlsEnabled(int enabled) {
    dispatch_async(dispatch_get_main_queue(), ^{
        sTouchControlsDesired = enabled != 0;
        SpaghettiPad_ApplyTouchControlsState();
    });
}

void SpaghettiPad_SetTouchControlsMenuVisible(int visible) {
    bool menuVisible = visible != 0;
    if (sTouchControlsMenuVisible.exchange(menuVisible) == menuVisible) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        SpaghettiPad_ApplyTouchControlsState();
    });
}

void SpaghettiPad_SetTiltSteeringEnabled(int enabled) {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL shouldEnable = enabled != 0;
        if (sTiltEnabled == shouldEnable) {
            return;
        }
        sTiltEnabled = shouldEnable;
        if (sTiltEnabled) {
            SpaghettiPad_StartTiltUpdates();
        } else {
            SpaghettiPad_StopTiltUpdates();
        }
    });
}

void SpaghettiPad_SetTiltSensitivity(float sensitivity) {
    dispatch_async(dispatch_get_main_queue(), ^{
        sTiltSensitivity = std::clamp(sensitivity, 0.5f, 2.0f);
    });
}

void SpaghettiPad_RecenterTiltSteering(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        sTiltReferenceValid = NO;
        sTiltFilteredDelta = 0.0;
        SpaghettiPad_SetTiltAxis(0);
        SDL_Log("[SpaghettiPad] tilt steering recenter requested");
    });
}

float SpaghettiPad_RecommendedMenuScale(void) {
    CGRect bounds = UIScreen.mainScreen.bounds;
    CGFloat shortEdge = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    return shortEdge >= 600.0 ? 2.0f : 0.75f;
}

void SpaghettiPad_RecordRawStick(int rawX, int rawY) {
    static std::atomic_int lastRawX(0);
    static std::atomic_int lastRawY(0);
    if (!sTouchStickActive.load()) {
        return;
    }
    int oldX = lastRawX.exchange(rawX);
    int oldY = lastRawY.exchange(rawY);
    if (rawX != oldX || rawY != oldY) {
        SDL_Log("[SpaghettiPad] touch raw stick x=%d y=%d", rawX, rawY);
    }
}

void SpaghettiPad_RecordControllerButtons(unsigned int held, unsigned int pressed) {
#if TARGET_OS_SIMULATOR
    static std::atomic_uint lastHeld(0);
    unsigned int oldHeld = lastHeld.exchange(held);
    if (held != oldHeld || pressed != 0) {
        SDL_Log(
            "[SpaghettiPad] controller held=0x%04x pressed=0x%04x",
            held, pressed);
    }
#else
    (void)held;
    (void)pressed;
#endif
}
