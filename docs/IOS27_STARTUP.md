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
- The proposed shared PadMint check rejects the original IPA and accepts the
  rebuilt IPA using the executable's actual linked SDK/platform. These static
  checks do not establish gameplay or runtime compatibility.

## Remaining gate

Do not publish a fixed release yet. With a private game archive, both the
relinked and clean rebuilt diagnostic apps advance the engine through tracks
but display a black game image underneath the visible touch overlay. A freshly
extracted archive with the current pinned Torch and metadata reproduces this.
The SDL probe's rendering success does not establish engine rendering success.
The existing appearance-transition warnings also remain.

The next discriminating experiment is the same engine/archive and scene patch
on iOS 26, then a baseline versus scene-enabled simulator comparison to separate
engine/Metal behavior from scene attachment. Physical iPhone acceptance,
interactive gameplay, audio, controller acceptance, and older-OS regression
remain unverified. The public release tag still supplies the old startup code;
a newer PadMint alone cannot repair that code.
