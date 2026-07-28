#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct SDL_Window;

void SpaghettiPad_OnWindowCreated(struct SDL_Window* window);
int SpaghettiPad_TouchControlsAvailable(void);
void SpaghettiPad_InitializeTouchControls(void);
void SpaghettiPad_SetTouchControlsEnabled(int enabled);
void SpaghettiPad_SetTouchControlsMenuVisible(int visible);
void SpaghettiPad_SetTiltSteeringEnabled(int enabled);
void SpaghettiPad_SetTiltSensitivity(float sensitivity);
void SpaghettiPad_RecenterTiltSteering(void);
float SpaghettiPad_RecommendedMenuScale(void);
void SpaghettiPad_RecordRawStick(int rawX, int rawY);
void SpaghettiPad_RecordControllerButtons(unsigned int held, unsigned int pressed);

#ifdef __cplusplus
}
#endif
