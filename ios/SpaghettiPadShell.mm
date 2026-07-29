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
static std::atomic_bool sGameplayActive(false);
static BOOL sTouchControlsDesired;
static BOOL sLegacyTouchControls;
static BOOL sLayoutEditorRequested;
static BOOL sLayoutEditorActive;
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
        if (action == SpaghettiPadActionZ) {
            // SDL normalizes virtual triggers from MIN (released) to MAX
            // (pressed); zero is a half-pressed trigger, not its resting state.
            SDL_JoystickSetVirtualAxis(
                sVirtualJoystick, SDL_CONTROLLER_AXIS_TRIGGERLEFT,
                pressed ? SDL_JOYSTICK_AXIS_MAX : SDL_JOYSTICK_AXIS_MIN);
            return;
        }
        Sint16 axisValue = pressed ? SDL_JOYSTICK_AXIS_MAX : 0;
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
@property(nonatomic) BOOL outputPressed;
@property(nonatomic) BOOL holdAssistEnabled;
@property(nonatomic) BOOL holdLocked;
@property(nonatomic) BOOL layoutEditing;
@property(nonatomic) CFTimeInterval inputDownTime;
@property(nonatomic) NSUInteger releaseGeneration;
@property(nonatomic) BOOL usesPillShape;
@property(nonatomic, copy) NSString* normalLabel;
@property(nonatomic, strong) UIColor* idleColor;
@property(nonatomic, strong) UIColor* pressedColor;

- (instancetype)initWithLabel:(NSString*)label
                       action:(SpaghettiPadAction)action
                         pill:(BOOL)pill;
- (void)applyIdleColor:(UIColor*)idleColor
          pressedColor:(UIColor*)pressedColor;
- (void)cancelInput;
- (void)cancelHoldAssist;
- (void)updateOutput;
- (void)updateAppearance;

@end

@implementation SpaghettiPadTouchButton

- (instancetype)initWithLabel:(NSString*)label
                       action:(SpaghettiPadAction)action
                         pill:(BOOL)pill {
    self = [super initWithFrame:CGRectZero];
    if (self != nil) {
        self.action = action;
        self.normalLabel = label;
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
    [self updateAppearance];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius =
        self.usesPillShape ? CGRectGetHeight(self.bounds) * 0.48
                           : MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) * 0.5;
}

- (void)inputDown {
    if (self.layoutEditing) {
        return;
    }
    self.releaseGeneration += 1;
    if (self.inputPressed) {
        return;
    }
    BOOL wasLocked = self.holdLocked;
    self.holdLocked = NO;
    self.inputPressed = YES;
    self.inputDownTime = CACurrentMediaTime();
    [self updateOutput];
    [self updateAppearance];

    if (self.holdAssistEnabled && !wasLocked &&
        self.action == SpaghettiPadActionA && sGameplayActive.load()) {
        NSUInteger generation = self.releaseGeneration;
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.65 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
                if (self.releaseGeneration != generation ||
                    !self.inputPressed || !self.holdAssistEnabled ||
                    !sGameplayActive.load()) {
                    return;
                }
                self.holdLocked = YES;
                [self updateOutput];
                [self updateAppearance];
                UIImpactFeedbackGenerator* feedback =
                    [[UIImpactFeedbackGenerator alloc]
                        initWithStyle:UIImpactFeedbackStyleMedium];
                [feedback impactOccurred];
                SDL_Log("[SpaghettiPad] A hold assist locked");
            });
    }
}

- (void)inputUp {
    if (self.layoutEditing) {
        return;
    }
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
    [self updateOutput];
    [self updateAppearance];
}

- (void)updateOutput {
    BOOL shouldPress = self.inputPressed || self.holdLocked;
    if (self.outputPressed == shouldPress) {
        return;
    }
    self.outputPressed = shouldPress;
    SpaghettiPad_SetAction(self.action, shouldPress);
}

- (void)updateAppearance {
    BOOL active = self.inputPressed || self.holdLocked;
    self.backgroundColor = active ? self.pressedColor : self.idleColor;
    if (self.holdLocked) {
        [self setTitle:@"A •" forState:UIControlStateNormal];
        self.layer.borderColor =
            [UIColor colorWithRed:0.42 green:0.88 blue:1.0 alpha:0.95].CGColor;
        self.layer.borderWidth = 4.0;
        self.accessibilityValue = @"Acceleration locked";
    } else {
        [self setTitle:self.normalLabel forState:UIControlStateNormal];
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.58].CGColor;
        self.layer.borderWidth = 2.0;
        self.accessibilityValue = nil;
    }
}

- (void)cancelHoldAssist {
    self.releaseGeneration += 1;
    if (!self.holdLocked) {
        return;
    }
    self.holdLocked = NO;
    [self updateOutput];
    [self updateAppearance];
}

- (void)cancelInput {
    self.releaseGeneration += 1;
    self.inputPressed = NO;
    self.holdLocked = NO;
    [self updateOutput];
    [self updateAppearance];
}

@end

@interface SpaghettiPadTouchStick : UIView

@property(nonatomic, strong) UIView* knob;
@property(nonatomic) BOOL layoutEditing;

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
    if (self.layoutEditing) {
        return;
    }
    UITouch* touch = touches.anyObject;
    if (touch == nil) {
        return;
    }
    sTouchStickActive.store(true);
    [self updateForPoint:[touch locationInView:self]];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    if (self.layoutEditing) {
        return;
    }
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

static CGRect SpaghettiPad_CompactMenuFrame(
    CGRect bounds, UIEdgeInsets safe, CGFloat size) {
    return CGRectMake(
        CGRectGetWidth(bounds) - safe.right - size - 8.0,
        safe.top + 4.0, size, size);
}

static SpaghettiPadTouchButton* sMenuButton;

@interface SpaghettiPadTouchOverlay : UIView

@property(nonatomic, strong) SpaghettiPadTouchStick* controlStick;
@property(nonatomic, strong) NSArray<SpaghettiPadTouchButton*>* buttons;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonA;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonB;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonL;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonZStick;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonZRight;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonR;
@property(nonatomic, strong) SpaghettiPadTouchButton* buttonStart;
@property(nonatomic, strong) SpaghettiPadTouchButton* cUp;
@property(nonatomic, strong) SpaghettiPadTouchButton* cDown;
@property(nonatomic, strong) SpaghettiPadTouchButton* cLeft;
@property(nonatomic, strong) SpaghettiPadTouchButton* cRight;
@property(nonatomic) BOOL customizableControls;
@property(nonatomic) BOOL layoutEditing;
@property(nonatomic, strong) NSArray<UIView*>* editableControls;
@property(nonatomic, strong) NSMutableArray<UIGestureRecognizer*>* editGestures;
@property(nonatomic, strong) NSMutableDictionary<NSString*, NSArray<NSNumber*>*>* layoutCenters;
@property(nonatomic, strong) NSMutableDictionary<NSString*, NSNumber*>* layoutScales;
@property(nonatomic, strong) NSMutableSet<NSString*>* hiddenControls;
@property(nonatomic, strong) NSMutableDictionary<NSString*, NSValue*>* defaultSizes;
@property(nonatomic, copy) NSString* layoutProfile;
@property(nonatomic, strong) UIView* selectedControl;
@property(nonatomic, strong) UIView* editorPanel;
@property(nonatomic, strong) UILabel* editorLabel;
@property(nonatomic, strong) UISlider* sizeSlider;
@property(nonatomic, strong) UIButton* visibilityButton;
@property(nonatomic, strong) UIButton* resetButton;
@property(nonatomic, strong) UIButton* doneButton;

- (void)cancelAllInputs;
- (void)setCustomizableControlsEnabled:(BOOL)enabled;
- (void)beginLayoutEditing;
- (void)endLayoutEditing;

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
            initWithLabel:@"L" action:SpaghettiPadActionL pill:NO];
        self.buttonZStick = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"Z" action:SpaghettiPadActionZ pill:NO];
        self.buttonZRight = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"Z" action:SpaghettiPadActionZ pill:NO];
        self.buttonR = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"R" action:SpaghettiPadActionR pill:NO];
        self.buttonStart = [[SpaghettiPadTouchButton alloc]
            initWithLabel:@"▶" action:SpaghettiPadActionStart pill:NO];
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
        self.buttonZStick.accessibilityLabel = @"Z above steering";
        self.buttonZRight.accessibilityLabel = @"Z right";
        self.cUp.accessibilityLabel = @"C Up";
        self.cDown.accessibilityLabel = @"C Down";
        self.cLeft.accessibilityLabel = @"C Left";
        self.cRight.accessibilityLabel = @"C Right";

        self.buttons = @[
            self.buttonA, self.buttonB, self.buttonL,
            self.buttonZStick, self.buttonZRight, self.buttonR, self.buttonStart,
            self.cUp, self.cDown, self.cLeft, self.cRight,
        ];
        self.layoutCenters = [NSMutableDictionary dictionary];
        self.layoutScales = [NSMutableDictionary dictionary];
        self.hiddenControls = [NSMutableSet set];
        self.defaultSizes = [NSMutableDictionary dictionary];
        self.editGestures = [NSMutableArray array];

        self.controlStick.accessibilityIdentifier = @"stick";
        self.buttonA.accessibilityIdentifier = @"a";
        self.buttonB.accessibilityIdentifier = @"b";
        self.buttonL.accessibilityIdentifier = @"l";
        self.buttonZStick.accessibilityIdentifier = @"z-left";
        self.buttonZRight.accessibilityIdentifier = @"z-right";
        self.buttonR.accessibilityIdentifier = @"r";
        self.buttonStart.accessibilityIdentifier = @"start";
        self.cUp.accessibilityIdentifier = @"c-up";
        self.cDown.accessibilityIdentifier = @"c-down";
        self.cLeft.accessibilityIdentifier = @"c-left";
        self.cRight.accessibilityIdentifier = @"c-right";
        self.editableControls = @[
            self.controlStick, self.buttonA, self.buttonB, self.buttonL,
            self.buttonZStick, self.buttonZRight, self.buttonR, self.buttonStart,
            self.cUp, self.cDown, self.cLeft, self.cRight,
        ];

        [self addSubview:self.controlStick];
        for (SpaghettiPadTouchButton* button in self.buttons) {
            [self addSubview:button];
        }
        [self installLayoutEditor];
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

        CGFloat stickSize = 116.0;
        CGPoint stickCenter = CGPointMake(left + 88.0, height - safe.bottom - 88.0);
        self.controlStick.frame =
            SpaghettiPad_CenteredFrame(stickCenter, stickSize, stickSize);
        CGFloat stickZSize = 50.0;
        CGFloat stickZGap = 8.0;
        self.buttonZStick.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(stickCenter.x,
                        CGRectGetMinY(self.controlStick.frame) -
                            stickZGap - stickZSize * 0.5),
            stickZSize, stickZSize);
        self.buttonL.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(stickCenter.x - stickZSize - stickZGap,
                        CGRectGetMidY(self.buttonZStick.frame)),
            stickZSize, stickZSize);
        self.buttonR.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(stickCenter.x + stickZSize + stickZGap,
                        CGRectGetMidY(self.buttonZStick.frame)),
            stickZSize, stickZSize);

        CGFloat rightCenterX = width - right - 58.0;
        CGFloat faceCenterY = height - safe.bottom - 82.0;
        CGFloat faceSize = 52.0;
        CGFloat aSize = 58.0;
        CGFloat bSize = 54.0;
        self.buttonA.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX + 22.0, faceCenterY + 18.0), aSize, aSize);
        self.buttonB.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX - 34.0, faceCenterY + 2.0), bSize, bSize);
        self.buttonZRight.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX + 12.0, faceCenterY - 44.0), faceSize, faceSize);
        CGFloat compactMenuSize = 38.0;
        CGRect menuFrame =
            SpaghettiPad_CompactMenuFrame(self.bounds, safe, compactMenuSize);
        CGFloat startGap = 6.0;
        self.buttonStart.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(CGRectGetMidX(menuFrame),
                        CGRectGetMaxY(menuFrame) +
                            startGap + shoulderHeight * 0.5),
            shoulderHeight, shoulderHeight);

        CGFloat cSize = 40.0;
        CGFloat cRadius = 34.0;
        CGPoint cCenter = CGPointMake(
            width - safe.right - cRadius - cSize * 0.5 - 4.0,
            top + shoulderHeight + 75.0);
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
        self.buttonA.titleLabel.font =
            [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
        self.buttonB.titleLabel.font =
            [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
        self.buttonStart.titleLabel.font =
            [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
        [self finishControlLayoutForCompact:YES];
        return;
    }

    CGFloat scale = MAX(0.78, MIN(1.12, height / 834.0));
    CGFloat usableWidth = width - safe.left - safe.right;
    CGFloat railWidth = MIN(250.0 * scale, usableWidth * 0.22);
    CGFloat leftCenter = safe.left + railWidth * 0.5;
    CGFloat rightCenter = width - safe.right - railWidth * 0.5;
    CGFloat middleCenterY = height * 0.60;
    CGFloat lowCenterY = height * 0.86;
    CGFloat stickCenterX = leftCenter + 65.0 * scale;
    CGFloat stickCenterY = lowCenterY - 70.0 * scale;
    CGFloat faceCenterX = rightCenter + 24.0 * scale;
    CGFloat faceCenterY = middleCenterY + 30.0 * scale;
    CGFloat cpadCenterX = rightCenter + 24.0 * scale;
    CGFloat cpadCenterY = lowCenterY - 20.0 * scale;

    CGFloat stickSize = 150.0 * scale;
    self.controlStick.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(stickCenterX, stickCenterY), stickSize, stickSize);
    CGFloat stickZSize = 56.0 * scale;
    CGFloat stickZGap = 12.0 * scale;
    self.buttonZStick.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(stickCenterX,
                    CGRectGetMinY(self.controlStick.frame) -
                        stickZGap - stickZSize * 0.5),
        stickZSize, stickZSize);
    self.buttonL.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(stickCenterX - stickZSize - stickZGap,
                    CGRectGetMidY(self.buttonZStick.frame)),
        stickZSize, stickZSize);
    self.buttonR.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(stickCenterX + stickZSize + stickZGap,
                    CGRectGetMidY(self.buttonZStick.frame)),
        stickZSize, stickZSize);

    CGFloat faceSize = 66.0 * scale;
    CGFloat faceX = faceCenterX - faceSize * 0.5;
    self.buttonA.frame = CGRectMake(
        faceX, faceCenterY + 12.0 * scale, faceSize, faceSize);
    self.buttonB.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(faceX - faceSize * 0.5 - 10.0 * scale, faceCenterY),
        faceSize, faceSize);
    self.buttonZRight.frame = CGRectMake(
        faceX, faceCenterY - faceSize - 12.0 * scale, faceSize, faceSize);
    CGFloat startSize = 54.0 * scale;
    CGFloat startGap = 12.0 * scale;
    self.buttonStart.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(CGRectGetMidX(self.buttonZRight.frame),
                    CGRectGetMinY(self.buttonZRight.frame) -
                        startGap - startSize * 0.5),
        startSize, startSize);

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

    CGFloat labelSize = 18.0 * scale;
    for (SpaghettiPadTouchButton* button in self.buttons) {
        button.titleLabel.font =
            [UIFont systemFontOfSize:labelSize weight:UIFontWeightSemibold];
    }
    self.buttonStart.titleLabel.font =
        [UIFont systemFontOfSize:18.0 * scale weight:UIFontWeightBold];
    [self finishControlLayoutForCompact:NO];
}

- (void)cancelAllInputs {
    [self.controlStick cancelInput];
    for (SpaghettiPadTouchButton* button in self.buttons) {
        [button cancelInput];
    }
    SpaghettiPad_ResetAllInputs();
}

- (void)setCustomizableControlsEnabled:(BOOL)enabled {
    if (self.customizableControls == enabled) {
        return;
    }
    [self cancelAllInputs];
    self.customizableControls = enabled;
    self.buttonA.holdAssistEnabled = enabled;
    if (!enabled && self.layoutEditing) {
        [self endLayoutEditing];
    }
    [self setNeedsLayout];
}

- (UIButton*)editorButtonWithTitle:(NSString*)title
                            action:(SEL)action {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font =
        [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    button.layer.cornerRadius = 10.0;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)installLayoutEditor {
    self.editorPanel = [[UIView alloc] initWithFrame:CGRectZero];
    self.editorPanel.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.88];
    self.editorPanel.layer.borderColor =
        [UIColor colorWithWhite:1.0 alpha:0.24].CGColor;
    self.editorPanel.layer.borderWidth = 1.0;
    self.editorPanel.layer.cornerRadius = 16.0;
    self.editorPanel.hidden = YES;

    self.editorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.editorLabel.textColor = UIColor.whiteColor;
    self.editorLabel.numberOfLines = 2;
    self.editorLabel.font =
        [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [self.editorPanel addSubview:self.editorLabel];

    self.sizeSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    self.sizeSlider.minimumValue = 0.70f;
    self.sizeSlider.maximumValue = 1.50f;
    self.sizeSlider.value = 1.0f;
    self.sizeSlider.minimumTrackTintColor =
        [UIColor colorWithRed:0.28 green:0.68 blue:1.0 alpha:1.0];
    [self.sizeSlider addTarget:self
                        action:@selector(editorSizeChanged:)
              forControlEvents:UIControlEventValueChanged];
    [self.editorPanel addSubview:self.sizeSlider];

    self.visibilityButton =
        [self editorButtonWithTitle:@"Hide" action:@selector(toggleSelectedVisibility)];
    self.resetButton =
        [self editorButtonWithTitle:@"Reset" action:@selector(resetCurrentLayout)];
    self.doneButton =
        [self editorButtonWithTitle:@"Done" action:@selector(endLayoutEditing)];
    self.doneButton.backgroundColor =
        [UIColor colorWithRed:0.10 green:0.48 blue:0.92 alpha:0.88];
    [self.editorPanel addSubview:self.visibilityButton];
    [self.editorPanel addSubview:self.resetButton];
    [self.editorPanel addSubview:self.doneButton];
    self.resetButton.accessibilityIdentifier = @"touch-layout-reset";
    self.doneButton.accessibilityIdentifier = @"touch-layout-done";

    [self addSubview:self.editorPanel];

    for (UIView* control in self.editableControls) {
        UIPanGestureRecognizer* pan =
            [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(moveControl:)];
        UITapGestureRecognizer* tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(selectControlGesture:)];
        pan.enabled = NO;
        tap.enabled = NO;
        [control addGestureRecognizer:pan];
        [control addGestureRecognizer:tap];
        [self.editGestures addObject:pan];
        [self.editGestures addObject:tap];
    }
}

- (void)layoutEditorPanel {
    if (self.editorPanel.hidden) {
        return;
    }
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat panelWidth =
        MIN(620.0, width - safe.left - safe.right - 20.0);
    CGFloat panelHeight = CGRectGetHeight(self.bounds) < 560.0 ? 76.0 : 86.0;
    self.editorPanel.frame = CGRectMake(
        CGRectGetMidX(self.bounds) - panelWidth * 0.5,
        safe.top + 8.0, panelWidth, panelHeight);

    CGFloat inset = 12.0;
    CGFloat buttonWidth = 70.0;
    CGFloat gap = 8.0;
    CGFloat contentHeight = panelHeight - inset * 2.0;
    CGFloat trailingButtonsWidth = buttonWidth * 3.0 + gap * 2.0;
    CGFloat labelWidth = MIN(150.0, panelWidth * 0.23);
    CGFloat sliderX = inset + labelWidth + gap;
    CGFloat sliderWidth =
        panelWidth - inset * 2.0 - labelWidth - gap -
        trailingButtonsWidth - gap;
    self.editorLabel.frame =
        CGRectMake(inset, inset, labelWidth, contentHeight);
    self.sizeSlider.frame =
        CGRectMake(sliderX, inset, MAX(80.0, sliderWidth), contentHeight);

    CGFloat buttonX = panelWidth - inset - trailingButtonsWidth;
    NSArray<UIButton*>* buttons = @[
        self.visibilityButton, self.resetButton, self.doneButton,
    ];
    for (UIButton* button in buttons) {
        button.frame =
            CGRectMake(buttonX, inset, buttonWidth, contentHeight);
        buttonX += buttonWidth + gap;
    }
}

- (NSString*)profileForCompact:(BOOL)compact {
    return compact ? @"phone-v1" : @"tablet-v1";
}

- (NSString*)storageKeyForProfile:(NSString*)profile {
    return [@"SpaghettiPad.TouchLayout." stringByAppendingString:profile];
}

- (NSString*)legacyStorageKeyForProfile:(NSString*)profile {
    return [@"SpaghettiPad.ExperimentalTouchLayout." stringByAppendingString:profile];
}

- (void)loadLayoutForProfile:(NSString*)profile {
    if ([self.layoutProfile isEqualToString:profile]) {
        return;
    }
    self.layoutProfile = profile;
    [self.layoutCenters removeAllObjects];
    [self.layoutScales removeAllObjects];
    [self.hiddenControls removeAllObjects];

    NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
    NSString* storageKey = [self storageKeyForProfile:profile];
    NSDictionary* stored = [defaults dictionaryForKey:storageKey];
    if (stored == nil) {
        stored = [defaults
            dictionaryForKey:[self legacyStorageKeyForProfile:profile]];
        if (stored != nil) {
            // Preserve layouts created before customizable controls became
            // the default without retaining the old user-facing mode.
            [defaults setObject:stored forKey:storageKey];
        }
    }
    NSDictionary* centers = stored[@"centers"];
    NSDictionary* scales = stored[@"scales"];
    NSArray* hidden = stored[@"hidden"];
    if ([centers isKindOfClass:NSDictionary.class]) {
        [self.layoutCenters addEntriesFromDictionary:centers];
    }
    if ([scales isKindOfClass:NSDictionary.class]) {
        [self.layoutScales addEntriesFromDictionary:scales];
    }
    if ([hidden isKindOfClass:NSArray.class]) {
        [self.hiddenControls addObjectsFromArray:hidden];
    }
}

- (void)saveCurrentLayout {
    if (self.layoutProfile.length == 0) {
        return;
    }
    NSDictionary* stored = @{
        @"centers": [self.layoutCenters copy],
        @"scales": [self.layoutScales copy],
        @"hidden": self.hiddenControls.allObjects,
    };
    [NSUserDefaults.standardUserDefaults
        setObject:stored
           forKey:[self storageKeyForProfile:self.layoutProfile]];
}

- (void)applyCustomizableDefaultsForCompact:(BOOL)compact {
    if (compact) {
        CGFloat width = CGRectGetWidth(self.bounds);
        CGFloat height = CGRectGetHeight(self.bounds);
        UIEdgeInsets safe = self.safeAreaInsets;
        CGFloat rightCenterX = width - safe.right - 68.0;
        CGFloat faceCenterY = height - safe.bottom - 82.0;
        self.buttonA.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX + 22.0, faceCenterY + 18.0), 66.0, 66.0);
        self.buttonB.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX - 42.0, faceCenterY + 6.0), 58.0, 58.0);
        self.buttonZRight.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX - 40.0, faceCenterY - 52.0), 54.0, 54.0);
        self.buttonR.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(rightCenterX + 22.0, faceCenterY - 52.0), 56.0, 56.0);
        for (SpaghettiPadTouchButton* cButton in
             @[ self.cUp, self.cDown, self.cLeft, self.cRight ]) {
            cButton.center =
                CGPointMake(cButton.center.x, cButton.center.y - 14.0);
        }

        CGFloat leftCenter = CGRectGetMidX(self.buttonZStick.frame);
        CGFloat topCenter = CGRectGetMidY(self.buttonZStick.frame);
        self.buttonL.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(leftCenter - 29.0, topCenter), 50.0, 50.0);
        self.buttonZStick.frame = SpaghettiPad_CenteredFrame(
            CGPointMake(leftCenter + 29.0, topCenter), 50.0, 50.0);

        // Physically accepted iPhone 14 racing layout. Normalized centers
        // preserve the same thumb relationships on other compact widths.
        self.controlStick.center =
            CGPointMake(width * 0.185624, height * 0.726622);
        self.buttonL.center =
            CGPointMake(width * 0.151264, height * 0.488034);
        self.buttonZStick.center =
            CGPointMake(width * 0.244076, height * 0.496581);
        self.buttonR.center =
            CGPointMake(width * 0.817930, height * 0.586325);
        self.buttonZRight.center =
            CGPointMake(width * 0.890995, height * 0.602564);
        self.buttonB.center =
            CGPointMake(width * 0.813586, height * 0.753846);
        self.buttonA.center =
            CGPointMake(width * 0.888626, height * 0.789744);
        self.cRight.center =
            CGPointMake(width * 0.915877, height * 0.364103);

        CGRect menuFrame =
            SpaghettiPad_CompactMenuFrame(self.bounds, safe, 38.0);
        self.buttonStart.center = CGPointMake(
            CGRectGetMidX(menuFrame),
            CGRectGetMaxY(menuFrame) + 9.0 +
                CGRectGetHeight(self.buttonStart.bounds) * 0.5);
        return;
    }

    CGFloat unit = CGRectGetWidth(self.buttonA.frame);
    CGPoint aCenter = self.buttonA.center;
    CGPoint upperCenter =
        CGPointMake(aCenter.x, CGRectGetMinY(self.buttonA.frame) - 28.0 - unit * 0.5);
    self.buttonZRight.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(upperCenter.x - unit * 0.54, upperCenter.y), unit, unit);
    self.buttonR.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(upperCenter.x + unit * 0.54, upperCenter.y), unit, unit);
    self.buttonB.center =
        CGPointMake(self.buttonB.center.x - 16.0, self.buttonB.center.y);

    CGFloat leftUnit = CGRectGetWidth(self.buttonZStick.frame);
    CGFloat leftCenter = CGRectGetMidX(self.buttonZStick.frame);
    CGFloat topCenter = CGRectGetMidY(self.buttonZStick.frame);
    self.buttonL.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(leftCenter - leftUnit * 0.55, topCenter),
        leftUnit, leftUnit);
    self.buttonZStick.frame = SpaghettiPad_CenteredFrame(
        CGPointMake(leftCenter + leftUnit * 0.55, topCenter),
        leftUnit, leftUnit);

    // Physically accepted 12.9-inch iPad layout. Normalized centers keep the
    // same grip relationships on other tablet sizes; safe-area clamping below
    // keeps every control reachable.
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    self.controlStick.center =
        CGPointMake(width * 0.158712, height * 0.782949);
    self.buttonL.center =
        CGPointMake(width * 0.114791, height * 0.657168);
    self.buttonZStick.center =
        CGPointMake(width * 0.174814, height * 0.652773);
    self.buttonStart.center =
        CGPointMake(width * 0.938053, height * 0.540000);
    self.buttonZRight.center =
        CGPointMake(width * 0.904805, height * 0.609355);
    self.buttonR.center =
        CGPointMake(width * 0.962882, height * 0.611797);
    self.buttonB.center =
        CGPointMake(width * 0.841698, height * 0.653809);
    self.buttonA.center =
        CGPointMake(width * 0.899985, height * 0.692285);
}

- (void)clampControlToSafeBounds:(UIView*)control {
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat halfWidth = CGRectGetWidth(control.bounds) * 0.5;
    CGFloat halfHeight = CGRectGetHeight(control.bounds) * 0.5;
    CGFloat minX = safe.left + halfWidth + 4.0;
    CGFloat maxX = CGRectGetWidth(self.bounds) - safe.right - halfWidth - 4.0;
    CGFloat minY = safe.top + halfHeight + 4.0;
    CGFloat maxY = CGRectGetHeight(self.bounds) - safe.bottom - halfHeight - 4.0;
    control.center = CGPointMake(
        std::clamp(control.center.x, minX, MAX(minX, maxX)),
        std::clamp(control.center.y, minY, MAX(minY, maxY)));
}

- (void)finishControlLayoutForCompact:(BOOL)compact {
    if (!self.customizableControls) {
        for (UIView* control in self.editableControls) {
            control.hidden = NO;
            control.alpha = 1.0;
            control.layer.shadowOpacity = 0.0;
        }
        [self layoutEditorPanel];
        return;
    }

    [self applyCustomizableDefaultsForCompact:compact];
    [self loadLayoutForProfile:[self profileForCompact:compact]];
    [self.defaultSizes removeAllObjects];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    for (UIView* control in self.editableControls) {
        NSString* key = control.accessibilityIdentifier;
        if (key.length == 0) {
            continue;
        }
        CGSize defaultSize = control.bounds.size;
        self.defaultSizes[key] = [NSValue valueWithCGSize:defaultSize];
        CGFloat defaultScale = 1.0;
        if (compact && [key isEqualToString:@"stick"]) {
            defaultScale = 1.068117;
        } else if (compact && [key isEqualToString:@"l"]) {
            defaultScale = 1.094607;
        } else if (compact && [key isEqualToString:@"z-left"]) {
            defaultScale = 1.254809;
        } else if (compact && [key isEqualToString:@"z-right"]) {
            defaultScale = 1.143803;
        } else if (!compact && [key isEqualToString:@"a"]) {
            defaultScale = 1.105960;
        } else if (!compact && [key isEqualToString:@"z-left"]) {
            defaultScale = 1.244087;
        }
        CGFloat controlScale = self.layoutScales[key] == nil
            ? defaultScale
            : std::clamp(self.layoutScales[key].doubleValue, 0.70, 1.50);
        control.bounds = CGRectMake(
            0.0, 0.0,
            defaultSize.width * controlScale,
            defaultSize.height * controlScale);
        NSArray<NSNumber*>* center = self.layoutCenters[key];
        if ([center isKindOfClass:NSArray.class] && center.count == 2) {
            control.center = CGPointMake(
                center[0].doubleValue * width,
                center[1].doubleValue * height);
        }
        [self clampControlToSafeBounds:control];
        BOOL hidden = [self.hiddenControls containsObject:key];
        control.hidden = self.layoutEditing ? NO : hidden;
        control.alpha = self.layoutEditing && hidden ? 0.28 : 1.0;
        BOOL selected = self.layoutEditing && control == self.selectedControl;
        control.layer.shadowColor =
            [UIColor colorWithRed:1.0 green:0.78 blue:0.16 alpha:1.0].CGColor;
        control.layer.shadowRadius = selected ? 8.0 : 0.0;
        control.layer.shadowOpacity = selected ? 1.0 : 0.0;
        control.layer.shadowOffset = CGSizeZero;
    }
    [self layoutEditorPanel];
    [self bringSubviewToFront:self.editorPanel];
}

- (void)selectControl:(UIView*)control {
    if (!self.layoutEditing || control == nil) {
        return;
    }
    self.selectedControl = control;
    NSString* label = control.accessibilityLabel;
    if (label.length == 0) {
        label = control.accessibilityIdentifier;
    }
    self.editorLabel.text =
        [NSString stringWithFormat:@"%@\nDrag to move • Size", label];
    NSString* key = control.accessibilityIdentifier;
    self.sizeSlider.value =
        self.layoutScales[key] == nil ? 1.0f : self.layoutScales[key].floatValue;
    BOOL hidden = [self.hiddenControls containsObject:key];
    [self.visibilityButton setTitle:(hidden ? @"Show" : @"Hide")
                           forState:UIControlStateNormal];
    self.visibilityButton.enabled = ![key isEqualToString:@"stick"];
    self.visibilityButton.alpha = self.visibilityButton.enabled ? 1.0 : 0.4;
    [self setNeedsLayout];
}

- (void)selectControlGesture:(UITapGestureRecognizer*)gesture {
    [self selectControl:gesture.view];
}

- (void)moveControl:(UIPanGestureRecognizer*)gesture {
    UIView* control = gesture.view;
    if (!self.layoutEditing || control == nil) {
        return;
    }
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self selectControl:control];
    }
    CGPoint translation = [gesture translationInView:self];
    control.center = CGPointMake(
        control.center.x + translation.x,
        control.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self];
    [self clampControlToSafeBounds:control];
    self.layoutCenters[control.accessibilityIdentifier] = @[
        @(control.center.x / CGRectGetWidth(self.bounds)),
        @(control.center.y / CGRectGetHeight(self.bounds)),
    ];
}

- (void)editorSizeChanged:(UISlider*)slider {
    UIView* control = self.selectedControl;
    NSString* key = control.accessibilityIdentifier;
    NSValue* sizeValue = self.defaultSizes[key];
    if (control == nil || key.length == 0 || sizeValue == nil) {
        return;
    }
    CGFloat scale = slider.value;
    self.layoutScales[key] = @(scale);
    CGSize baseSize = sizeValue.CGSizeValue;
    control.bounds = CGRectMake(
        0.0, 0.0, baseSize.width * scale, baseSize.height * scale);
    [self clampControlToSafeBounds:control];
    self.layoutCenters[key] = @[
        @(control.center.x / CGRectGetWidth(self.bounds)),
        @(control.center.y / CGRectGetHeight(self.bounds)),
    ];
}

- (void)toggleSelectedVisibility {
    NSString* key = self.selectedControl.accessibilityIdentifier;
    if (key.length == 0 || [key isEqualToString:@"stick"]) {
        return;
    }
    if ([self.hiddenControls containsObject:key]) {
        [self.hiddenControls removeObject:key];
    } else {
        [self.hiddenControls addObject:key];
    }
    [self selectControl:self.selectedControl];
}

- (void)resetCurrentLayout {
    if (self.layoutProfile.length == 0) {
        return;
    }
    [self.layoutCenters removeAllObjects];
    [self.layoutScales removeAllObjects];
    [self.hiddenControls removeAllObjects];
    [NSUserDefaults.standardUserDefaults
        removeObjectForKey:[self storageKeyForProfile:self.layoutProfile]];
    [NSUserDefaults.standardUserDefaults
        removeObjectForKey:[self legacyStorageKeyForProfile:self.layoutProfile]];
    [self setNeedsLayout];
    [self selectControl:self.buttonA];
}

- (void)beginLayoutEditing {
    if (!self.customizableControls || self.layoutEditing) {
        return;
    }
    [self cancelAllInputs];
    self.layoutEditing = YES;
    self.buttonA.layoutEditing = YES;
    for (SpaghettiPadTouchButton* button in self.buttons) {
        button.layoutEditing = YES;
    }
    self.controlStick.layoutEditing = YES;
    for (UIGestureRecognizer* gesture in self.editGestures) {
        gesture.enabled = YES;
    }
    self.editorPanel.hidden = NO;
    sLayoutEditorActive = YES;
    sMenuButton.hidden = YES;
    [self selectControl:self.buttonA];
    [self setNeedsLayout];
    SDL_Log("[SpaghettiPad] touch layout editor opened");
}

- (void)endLayoutEditing {
    if (!self.layoutEditing) {
        return;
    }
    [self saveCurrentLayout];
    self.layoutEditing = NO;
    for (SpaghettiPadTouchButton* button in self.buttons) {
        button.layoutEditing = NO;
    }
    self.controlStick.layoutEditing = NO;
    for (UIGestureRecognizer* gesture in self.editGestures) {
        gesture.enabled = NO;
    }
    self.editorPanel.hidden = YES;
    self.selectedControl = nil;
    sLayoutEditorActive = NO;
    sMenuButton.hidden = NO;
    [self setNeedsLayout];
    SDL_Log("[SpaghettiPad] touch layout saved");
}

@end

static SpaghettiPadTouchOverlay* sTouchOverlay;

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
    CGFloat size = 38.0;
    BOOL menuVisible = sTouchControlsMenuVisible.load();
    BOOL compactMenuVisible = compact && menuVisible;
    if (compactMenuVisible) {
        sMenuButton.frame = CGRectMake(
            CGRectGetMidX(window.bounds) - size * 0.5,
            height - safe.bottom - size - 8.0, size, size);
    } else if (compact) {
        sMenuButton.frame =
            SpaghettiPad_CompactMenuFrame(window.bounds, safe, size);
    } else {
        sMenuButton.frame = CGRectMake(
            CGRectGetWidth(window.bounds) - safe.right - size - 8.0,
            safe.top + (menuVisible ? 76.0 : 8.0), size, size);
    }

    if (sMenuButton.superview != window) {
        [sMenuButton removeFromSuperview];
        [window addSubview:sMenuButton];
    }
    sMenuButton.hidden = sLayoutEditorActive;
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
        [sTouchOverlay endLayoutEditing];
        SpaghettiPad_ReleaseVisibleInputs();
        [sTouchOverlay removeFromSuperview];
        sTouchOverlay = nil;
        return;
    }

    if (sTouchOverlay == nil) {
        sTouchOverlay = [[SpaghettiPadTouchOverlay alloc] initWithFrame:window.bounds];
        [sTouchOverlay
            setCustomizableControlsEnabled:!sLegacyTouchControls];
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
    if (sLayoutEditorRequested && !sLegacyTouchControls) {
        sLayoutEditorRequested = NO;
        [sTouchOverlay beginLayoutEditing];
    }
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

void SpaghettiPad_SetLegacyTouchControlsEnabled(int enabled) {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL legacyEnabled = enabled != 0;
#if TARGET_OS_SIMULATOR
        NSDictionary<NSString*, NSString*>* environment =
            NSProcessInfo.processInfo.environment;
        if ([environment[@"SPAGHETTIPAD_SIMULATE_LEGACY_TOUCH"]
                boolValue]) {
            legacyEnabled = YES;
        }
        BOOL shouldOpenEditor =
            [environment[@"SPAGHETTIPAD_SIMULATE_TOUCH_LAYOUT_EDITOR"]
                boolValue];
#else
        BOOL shouldOpenEditor = NO;
#endif
        sLegacyTouchControls = legacyEnabled;
        if (legacyEnabled) {
            sLayoutEditorRequested = NO;
        } else if (shouldOpenEditor) {
            sLayoutEditorRequested = YES;
        }
        [sTouchOverlay setCustomizableControlsEnabled:!legacyEnabled];
        SpaghettiPad_ApplyTouchControlsState();
        SDL_Log(
            "[SpaghettiPad] legacy touch controls %s",
            legacyEnabled ? "enabled" : "disabled");
    });
}

void SpaghettiPad_BeginTouchLayoutEditing(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sLegacyTouchControls || !sTouchControlsDesired) {
            SDL_Log(
                "[SpaghettiPad] layout editor requires customizable touch controls");
            return;
        }
        sLayoutEditorRequested = YES;
        if (sTouchControlsMenuVisible.load()) {
            SpaghettiPad_PushKey(SDL_SCANCODE_ESCAPE, YES);
            SpaghettiPad_PushKey(SDL_SCANCODE_ESCAPE, NO);
        } else {
            SpaghettiPad_ApplyTouchControlsState();
        }
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

void SpaghettiPad_SetGameplayActive(int active) {
    bool isActive = active != 0;
    bool wasActive = sGameplayActive.exchange(isActive);
    if (wasActive && !isActive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [sTouchOverlay.buttonA cancelHoldAssist];
        });
    }
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
