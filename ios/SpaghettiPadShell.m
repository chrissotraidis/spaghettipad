#include <stdbool.h>

#import <UIKit/UIKit.h>

#include <SDL.h>
#include <SDL_syswm.h>

static UIWindow* SpaghettiPad_GetSDLWindow(SDL_Window* sdlWindow) {
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (!SDL_GetWindowWMInfo(sdlWindow, &info) || info.subsystem != SDL_SYSWM_UIKIT) {
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

void SpaghettiPad_OnWindowCreated(SDL_Window* sdlWindow) {
    UIWindow* window = SpaghettiPad_GetSDLWindow(sdlWindow);
    if (window == nil) {
        NSLog(@"[SpaghettiPad] no UIKit window for SDL window");
        return;
    }

    if (NSThread.isMainThread) {
        SpaghettiPad_EnsureLandscape(window, 0);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            SpaghettiPad_EnsureLandscape(window, 0);
        });
    }
}

// Phase 8 replaces this strong app-side hook with the touch-overlay state
// transition. Keeping it here now proves the shell-to-libultraship link.
void SpaghettiPad_SetTouchControlsMenuVisible(bool visible) {
    (void)visible;
}
