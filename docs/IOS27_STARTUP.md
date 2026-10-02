# SDK 27 startup investigation

Issue [#26](https://github.com/chrissotraidis/spaghettipad/issues/26) is confirmed
by the reporter's crash report and an independent physical-iPad reproduction.
Both stop in
`___UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption_block_invoke`
with `EXC_BREAKPOINT` / `SIGTRAP`. The reporter used PadMint, app 0.2.0 build 7,
and iOS 27.0 (24A437). This assertion occurs before ROM setup.

Apple requires scene startup for apps built with SDK 27. See
[Apple's migration guide](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)
and [TN3187](https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle).
The pinned SDL 2.32.10 UIKit integration uses the older app lifecycle.
The minimum deployment target of iOS 15 does not exempt an SDK 27 build.

## Change

`scripts/configure-ios.sh` installs a CMake project hook for the fetched SDL2
input. The hook applies `patches/sdl2-ios-scenes.patch` before compilation,
requires the reviewed SDL version, and recognizes an already-applied patch.
Unexpected source drift fails configuration without discarding that source.
The application declares one scene in Info.plist. Its SDL scene delegate
starts SDL_main once, and SDL's application and first-run alert windows attach
to the application scene. URL events forward to the existing SDL drop path.
SDL also reads orientation from the application scene, using effective geometry
on iOS 27, and handles scene geometry changes. UIKit's old status-bar orientation
API becomes a no-op for SDK 27 clients. This part follows
[SDL upstream 114aca1727c7](https://github.com/libsdl-org/SDL/commit/114aca1727c755104ecfbd3bf4db986e0ff483e2).
Existing SDL app-notification observers continue handling foreground/background.
The patch is marked as a SpaghettiPad modification of SDL; SDL's license remains
unchanged. SDL3's scene implementation informed the approach, without changing
the engine's SDL2 API. The app audit verifies the manifest and linked delegate.

## Evidence, October 2, 2026

- Public v0.2.0 source, exact pins, PadMint-produced IPA: SDK 27.0, minimum
  iOS 15.0, no scene manifest. Physical M2 iPad, iPadOS 27.0 (24A437): UIKit
  scene-adoption assertion. Original executable SHA-256:
  `bd2270228f8fea738e1741383a7d67e1f0c05dce21b20f34c4ff7944040f3402`.
- A native SDL probe with the backport renders its green test frame on that
  device, connects one scene, and receives SDL events 259, 260, 261 and 262
  during a background/foreground round trip.
- Relinking the public app with the patched SDL input removes the assertion.
  Without the alert-window change, the first-run alert is invisible. With it,
  the physical iPad displays the Add your game / Rescan prompt.
- A clean configure and arm64 device build succeeds with Xcode 27.0 (27A266a),
  SDK 27.0. Reconfiguration recognizes the applied patch. App audit and unsigned
  IPA packaging pass. Unsigned executable SHA-256:
  `139424e5e156249a9f77d6dcab3238e709931347ad5cf803f4ac5b16f3aa21dc`.
- The clean rebuilt app also displays the first-run prompt on the physical iPad.
  Every diagnostic app uses a separate bundle ID. Production app and saves were
  preserved. Private inputs, apps, signing material and device logs stay local.
- The shared PadMint check records the executable's actual linked SDK/platform
  and conservative scene evidence. The original IPA is unverified and receives
  an SDK 27 warning; the rebuilt IPA declares scene startup. Missing evidence is
  not a blanket rejection because callbacks may be inherited or stripped. These
  static checks do not establish gameplay or runtime compatibility. PadMint
  PR #73 is merged, with 205 local tests and Windows/Linux CI passing.

## Follow-up: black image isolated and corrected

The initial scene-only patch removed the launch assertion, but both relinked and
clean rebuilt apps displayed a black game image underneath the touch overlay.
Fresh current-Torch extraction reproduced it. Follow-up comparisons used the
same engine and private archive:

- Original and scene-enabled SDK 27 apps render their intro on a physical iPhone
  14 running iOS 26.6.2.
- On the iPad, the scene-only app has an attached, visible 1366 by 1024 Metal
  view. Sampled GPU commands complete without errors, but the sampled drawable
  has zero colored pixels.
- Diagnostic-only copies with the executable's linked-SDK stamp changed from
  27 to 26 render on the same iPad, including the scene-enabled copy. No game
  code changed. These copies are private comparison probes, not release outputs
  or a supported workaround.
- With scene-aware orientation and the real SDK 27 stamp, the sampled drawable
  contains 1,006,083 colored pixels out of 1,398,784. A relink without diagnostic
  hooks also renders the intro and animated track/attract sequence on the iPad.
- The full unsigned arm64 rebuild and app audit pass with the combined patch.
  Executable SHA-256:
  `0038888111a363324fbbbf547e647a3879cdd56a95b1ae2751e433478d40d8e6`.
  Applying the combined patch twice to pristine SDL inputs passes.

## Final artifact and hardware regression

The final version is 0.2.1 build 8, compiled with Xcode 27.0 (27A266a), SDK
27.0, minimum iOS 15.0. The full unsigned arm64 build, app audit, package audit,
controller ownership regression and repository safety checks pass. Final
unsigned executable SHA-256:
`5d7316a6402e554f26f7c3c383f17d0f8e822a30bb9c279c18be237ab0b2a91e`.
Final local unsigned IPA SHA-256:
`a6fdc0b22e671a4b11de72209665cdb47e421c41b030f198b69f08b76f995dea`.
These hashes identify private validation artifacts, not public downloads.

The exact unsigned IPA was unpacked and temporarily signed under a separate
diagnostic bundle ID, with its executable and actual SDK stamp unchanged:

- Physical M2 iPad Pro, iPadOS 27.0 (24A437): animated intro and attract rendering;
  touch Start/A navigation through single-player Grand Prix, character and cup
  selection; Luigi Raceway loads and continues rendering with HUD and AI racers
  for more than 17 minutes. Backgrounding to the Home screen and reopening the
  app resumes the same rendered race.
- Physical iPhone 14, iOS 26.6.2 (23G90): the same final artifact launches and
  renders the animated attract sequence, confirming the older-OS rendering
  regression check.
- A 71-second iPad capture contains non-silent 48 kHz AAC audio. This establishes
  digital audio output, not physical-speaker listening or sound-quality acceptance.

The diagnostic containers' Documents and Library were backed up before in-place
updates. Production app containers were not replaced or cleared. Game inputs,
recordings, device evidence, signing material and apps remain local.

This fixes the reproduced SDK 27 launch assertion and black game image. Full
race completion, physical controllers, speaker listening and the reporter's
own device confirmation remain separate acceptance checks. The attempted XCTest
UI driver required device-side automation approval and did not pass; physical
menu/race navigation was verified through the native device mirror instead.

## Delivery

The fix belongs in SpaghettiPad's pinned SDL integration; no SDK downgrade or
PadMint game-specific workaround is required. PadMint PR #73 adds a shared
linked-SDK and scene-evidence check, but that static check cannot repair an
already-built IPA or replace runtime testing. It is merged in PadMint source;
its next normal PadMint release will distribute the check.

PadMint builds this project's latest public release. A source-only 0.2.1 release
is therefore required before the default PadMint selection receives this fix.
The existing public 0.2.0 release still supplies the old startup code. Existing
installed IPAs must be rebuilt and re-signed. No compiled app or game data should
be published; the recipe retains `public_binaries: false`.
