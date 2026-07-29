# Technical debt

## Imported 4K texture packs at 120 Hz

**Status:** deferred. This is deliberately separate from touch controls.

SpaghettiPad exposes a 120 FPS interpolation preset and allows an imported
enhanced/HD texture pack, but that combination is not yet a supported
performance target. It has shown visible tearing/frame-pacing problems and
needs measurement on ProMotion hardware before any claim is made.

### What is known

- `ios/Info.plist.in` opts eligible phones into frame durations below 60 Hz.
- `src/port/ui/PortMenu.cpp` changes `gInterpolationFPS` to 120. That selects
  the interpolation target; it does not by itself prove that Metal presents
  every frame at 120 Hz.
- The current Metal backend grows `mTextures` in `NewTexture()`, while
  `DeleteTexture()` is empty. The interpreter reuses texture IDs, so this is
  not proof of the tearing cause, but resource lifetime and peak memory must be
  profiled with the large pack.
- The current setting does not report whether the display, drawable
  presentation, or GPU actually sustained the selected rate.

### Investigation

1. Capture Metal System Trace and Core Animation data on an M-series ProMotion
   iPad using the same imported pack, track, camera, and race duration at 60
   and 120 FPS.
2. Record requested rate, actual presentation cadence, missed deadlines,
   drawable waits, GPU duration, resident memory, and thermal state.
3. Inspect the SDL/UIKit/Metal presentation path. Confirm that display-link
   pacing, `CAMetalLayer` synchronization, and the app's interpolation loop
   agree instead of allowing unsynchronized presents.
4. Audit Metal texture ownership. Implement and test safe release/reuse only
   if profiling shows retention or churn; do not change `DeleteTexture()` from
   assumption alone.
5. Test pack load, a full Grand Prix, background/foreground, and pack
   enable/disable/relaunch at both rates.
6. If 120 cannot remain paced under the 4K workload, make the UI honest:
   recommend 60, warn for the combination, or automatically cap it only with
   explicit user-facing behavior.

### Acceptance gate

- No visible tearing in a full physical-device race.
- Presentation cadence and frame-time traces support the selected rate.
- No unbounded Metal texture/resource growth across repeated races.
- No regression at 30 or 60 FPS, with original or imported textures.
- Results name the exact device, OS, pack version/hash, resolution, and thermal
  conditions. Simulator or build success is not acceptance evidence.
