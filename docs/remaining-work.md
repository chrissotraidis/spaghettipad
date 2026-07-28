# SpaghettiPad remaining work

This is the authoritative execution queue and append-only proof log for
[`spaghettikart-implementation-plan.md`](spaghettikart-implementation-plan.md).
The plan and
[`spaghettikart-ios-feasibility.md`](spaghettikart-ios-feasibility.md) remain
the technical baseline; this file records current state, tested evidence, and
the next reproducible gate.

## Goal

Deliver a reproducible, native iPadOS-first SpaghettiKart port with
grip-designed full-analog touch controls, on-device Files import and
extraction, physical-controller support, lifecycle-safe audio, two-player
split-screen, optional tilt steering, user-imported texture packs, and an
audited ROM-free unsigned IPA.

## Invariants

- User-supplied, legally acquired Mario Kart 64 (US) big-endian `.z64` only.
- Never commit or distribute ROMs, `mk64*.o2r`, `.otr`, extracted Nintendo
  assets, or the MK64 Reloaded texture pack.
- `chrissotraidis/spaghettipad` is the sole publication repository.
- SpaghettiKart, libultraship, Torch, and prior-art references are pinned,
  disposable, push-disabled inputs under ignored directories.
- Keep every durable source change as a reviewable maintained patch.
- Keep `ENABLE_SCRIPTING` disabled with an iOS `FATAL_ERROR` guard.
- Treat local, CI, Simulator, physical-device, signing, audio, performance,
  controller, and texture-pack evidence as separate gates.
- Make the smallest maintainable change for the first reproducible failure,
  then replay that gate.

## Repository and source boundary

| Tree | Role | Revision |
|---|---|---|
| `chrissotraidis/spaghettipad` | Sole owned project and publication repository | `59ad133` baseline |
| `HarbourMasters/SpaghettiKart` | Pinned upstream source input | `5b28472d477bab101dee2a0f469fe2aee2c58a01` |
| `Kenix3/libultraship` | SpaghettiKart-pinned upstream source input | `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` |
| `HarbourMasters/Torch` | SpaghettiKart-pinned upstream source input | `2d474ddb8da8b213fbdbb49d0273ce31fa955f35` |
| `rebelancap/SpaghettiKart-ios` | MIT prior-art reference, local only | `397fd9c638b3772ef1526b5af9d56f8d169ee339` |

## Phase queue

| Phase | Gate | State | Required evidence |
|---|---|---|---|
| 0 | Repo scaffolding and pinned bootstrap | Complete | Clean bootstrap, exact revisions, disabled pushes, ignore checks, safety audit, clean-directory replay |
| 1 | Host oracle and clean port archives | Complete | macOS title, archive hashes, clean `spaghetti.o2r` audit |
| 2 | Patched libultraship iOS static library | Complete | arm64 iPhoneOS library, symbol audit, patch replay, macOS regression build |
| 3 | Full unsigned iOS app links | Complete | iPhoneOS app, platform/min-OS/bundle audit |
| 4 | Simulator title screen | Complete | Live Metal frame, logs, screenshot, no desktop dialog symbols |
| 5 | Lifecycle and audio | Complete | Three-cycle continuity, config flush, paused simulation, audible resume |
| 6 | Signed physical-iPad boot | In progress | Signed install, title screen, ten-minute stability run |
| 7 | On-device Files extraction | In progress (hardware replay) | Clean-device extraction, failure recovery, measured time/RSS |
| 8 | Grip-first full-analog touch controls | Pending | Full touch-only GP and analog/menu/lifecycle checks on hardware |
| 9 | iPad UX and imported texture pack | Pending | Touch-complete UX plus Reloaded import/enable/full-GP hardware gate |
| 10 | Controllers and split-screen | Pending | Two-controller 2P session and measured 3P/4P decision |
| 11 | Tilt steering | Pending | Persisted, drift-free tilt GP on hardware |
| 12 | Package, CI, docs, release | Pending | Clean CI, clean-machine replay, audited IPA and SHA-256 |

## Active gate

**Phase 6/7 owner hardware replay; Phase 8 is the next unblocked Simulator gate.**

Expected:

1. On the maintainer's local Mac, a signed arm64 iPhoneOS build installs on
   the connected physical iPad using an available Apple development team and
   the SpaghettiPad bundle identifier.
2. The user-supplied desktop-generated `mk64.o2r` reaches only the app's
   Files-visible Documents container and retains its recorded hash.
3. A cold hardware launch loads bundled `spaghetti.o2r` plus local
   `mk64.o2r`, reaches the Mario Kart 64 title/demo sequence, and remains alive
   for at least ten minutes without watchdog termination.

Boundary:

- Phase 5 proves Simulator lifecycle continuity, durable config flush,
  simulation/audio pause and resume, live rendering continuation, container
  integrity, and human-confirmed audible music/audio.
- The physical iPad is connected to the maintainer's local Mac, not this remote
  build Mac. This machine has no visible iPad, valid code-signing identity, or
  provisioning profile, so it cannot perform or claim the Phase 6 install.
- Remote work therefore continues with the explicitly Simulator-valid part of
  Phase 7: empty-container guidance, ROM validation, recovery, extraction, and
  relaunch behavior. Hardware time/RSS and Files/iPad behavior remain owner
  replay items even when their Simulator equivalents pass.
- Simulator evidence does not prove signing, installation, watchdog behavior,
  or audio on physical hardware. Touch, extraction, performance, controller,
  texture-pack, and package behavior also remain unclaimed.

## Evidence log

### 2026-07-28 — Phase 7 Simulator first-run slice passed; hardware pending

- Implementation: maintained patch
  `patches/spaghettikart-ios-firstrun.patch` (228 lines, 8,534 bytes,
  SHA-256
  `6f6701005cf64dbc3cda22b2105bf4d046932c1b8327e0021d173b2d4674103b`)
  makes the iOS first-run flow recoverable. It scans Files-visible Documents
  for any case-insensitive `.z64`, accepts only the exact US 1.0 big-endian
  SHA-1, rejects corrupt/partial O2R archives, removes stale extraction output
  and cache state, and always returns to a one-button Rescan loop instead of
  exiting. `scripts/apply-patches.sh` now applies and reverse-checks this patch.
- Build proof: Release arm64 Simulator build succeeded. Its executable SHA-256
  is
  `916d8e963fb89b2349361522b0ef69d887de869bbe8d459a1221ebb8e01ea032`.
  The shared-source desktop regression build also succeeded; its arm64
  executable SHA-256 is
  `1d9a87c162dabaa489aa7511a6c60b69a000107e67bec3f1294a777620b08b75`.
- Isolation: all runtime testing used the disposable iPad Pro 11-inch (M4),
  iOS 18.5 Simulator `SpaghettiPad Phase 7`
  (`7D6115C9-2ACC-4E72-A53A-3777D50E7037`). The supplied ROM was copied only
  into that app sandbox. It remains ignored and untracked.
- Recovery proof: an empty container showed the single Rescan prompt and
  remained in-app after rescanning. A deliberately wrong 1 KiB
  `Wrong Region.z64` produced the precise US 1.0/big-endian guidance and
  returned to the loop. A valid US 1.0 ROM was then found without requiring
  the hard-coded `baserom.us.z64` filename.
- Stale-state proof: before the valid run, the sandbox contained a deliberately
  invalid 2 KiB `mk64.o2r` and 1 KiB `torch.hash.yml`. Both were replaced.
  The generated `mk64.o2r` is a valid 26,664,858-byte ZIP with SHA-256
  `dc20466705d5dfcad843847aad4fa10dba60317fa72580e03dcfbcb5ffeb3ebb`;
  `unzip -tq` reports no errors. The new `torch.hash.yml` is 24,209 bytes.
- Measured Simulator extraction: the external monitor observed a valid archive
  after 2,893 seconds (48m13s) with peak process RSS 201,088 KiB. Torch logged
  `Done! Took 2882828ms` (48m02.828s). These are Simulator measurements, not
  physical-iPad performance claims.
- Relaunch proof: the final rebuilt app relaunched as PID `44236`, skipped all
  first-run prompts, and reached a live race. The archive hash, size, and
  `2026-07-28T10:19:29-0500` modification time were unchanged, and all rotated
  logs still contain exactly one `Done! Took` extraction completion.
- Maintenance and safety: the patch passes current reverse application, a
  pristine temporary base-patch -> first-run-patch replay, nested/root
  `git diff --check`, `bash -n scripts/apply-patches.sh`, and
  `scripts/check-repo-safety.sh`.
- Boundary: this closes the remote Simulator slice only. Phase 7 remains in
  progress until the owner repeats the Files workflow on the locally attached
  physical iPad and records hardware extraction time, peak RSS, failure
  recovery, cold relaunch, and archive validation. Phase 6 hardware signing
  and stability likewise remain open. The next unblocked remote gate is Phase
  8 touch controls using the refreshed HarkinianPad reference.

### 2026-07-28 — Remote device boundary and latest HarkinianPad controls fixed

- Device boundary: the maintainer clarified that the physical iPad is attached
  to the local MacBook in hand, while this agent runs on a remote Mac. The
  remote USB inventory contains no iPad, `security find-identity -p
  codesigning` reports `0 valid identities found`, and no provisioning
  profiles are installed. Phase 6 therefore remains in progress and no
  physical-device result is inferred from Simulator work.
- Owner replay required for Phase 6: configure the same source revision with
  the maintainer's development team and unique bundle identifier, build with
  provisioning updates enabled, install on the locally attached iPad, copy
  the recorded `mk64.o2r` only through its Files-visible Documents container,
  then record the device model, OS, executable hash, cold title boot, and a
  continuous ten-minute attract/demo run.
- Reference refresh: ignored `ref/harkinianpad` now exactly overlays every
  tracked file from the authoritative clean HarkinianPad `main` revision
  `01523225a3e9d32348e25d608dcb2d391dab5310`; an all-tracked-file comparison
  reported zero mismatches. This advances the touch reference from
  `88cefb7` through the compact-display fixes in `e22b3fa` and `0152322`.
- Touch baselines: the refreshed `docs/touch-controls-design.md`,
  `patches/shipwright-ios-touch-controls.patch`, and
  `patches/libultraship-ios.patch` hash respectively to
  `2eb23d57f8b042eb1ca0c74b1841e315ab81e0ead5bdb50184354055a3928b5b`,
  `63a5e3ae69930027c9aafe46a8b3688c957c8f447ec6a562f20c436b7f90ee1f`,
  and
  `172429323474038338b8d172c6b5bcc88506b7519313d1b0cd7897ada4d7b9db`.
  SpaghettiPad will reuse the latest grip-first layout, pass-through overlay,
  persistent menu control, compact-display rules, input-release semantics,
  and touch-mouse filtering while retaining its plan-mandated virtual SDL
  controller for full analog steering.
- Boundary: the ignored reference refresh changes no distributed source or
  artifact. This entry proves reference provenance and the remote/local
  device split only; it does not close Phase 6, Phase 7, or Phase 8.

### 2026-07-28 — Phase 5 audible resume accepted and gate closed

- The maintainer confirmed that Mario Kart music and game audio were audible
  through the active Jump Desktop output and that audio behavior was fine
  after the lifecycle replay.
- This human listening result closes the remaining subjective acceptance item
  on top of the same-PID three-cycle, config-flush, paused-log, live-render,
  integrity, and direct SDL pause/clear/resume/refill evidence recorded below.
- Boundary: this closes Simulator lifecycle and audible-output behavior only.
  It does not prove physical-iPad signing, install, watchdog survival, audio,
  extraction, touch, performance, controllers, texture packs, or packaging.

### 2026-07-28 — Phase 5 lifecycle slice passed; audible resume pending

- Implementation: the iOS-only `src/port/Game.cpp` loop now checks
  `WindowIsFrameReady()` before `push_frame()`. The existing bridge pumps SDL
  events and sleeps for 16 ms when the window is backgrounded, so lifecycle
  events still dispatch without advancing the game, renderer, or audio tick.
  The maintained `patches/spaghettikart-ios.patch` is now 313 lines across
  eight source files (142 insertions, 48 deletions), SHA-256
  `3a5f5b7c516a570d8525ec110d0611cafce6a44099a3f3cd32ad2b456782514c`,
  and passes reverse-apply and whitespace checks.
- Audio-timing question: `func_800CB2C4()` updates camera-relative sound
  state, sequence commands/fades, sound requests, and the audio task at the
  start of `thread5_iteration()`. It has no separate wall-clock owner relevant
  to suspension. Because the new readiness gate runs before `push_frame()`,
  neither that function nor `calculate_delta_time()` runs while backgrounded.
- Build proof: the final arm64 Simulator rebuild ended in
  `** BUILD SUCCEEDED **`; executable SHA-256 is
  `839267f64fa6e71b2560f6996a2de31297aefeb6a9d298c0f11f67898e3c59bb`.
  The native arm64 macOS regression target also rebuilt successfully and
  retained SHA-256
  `236e8cddd0dd54963980d0a3bf6bb9b7909aaa75fa5aa71db8c98f547219c39b`.
- Runtime: on the iPad Pro 11-inch (M4), iOS 18.5 Simulator, PID `86185`
  reached the live title screen and survived three consecutive 20-second
  Home/foreground cycles. Foregrounding after every cycle returned the same
  PID and live Metal animation.
- Pause/config proof: the baseline game log was 659 lines and 53,660 bytes
  with mtime `08:43:21-0500`. It retained exactly those three values through
  all three background dwells. Synchronous config saves advanced
  `spaghettify.cfg.json` from `08:43:19-0500` to `08:44:27-0500`,
  `08:45:38-0500`, and `08:46:32-0500`.
- Integrity: after the cycles, `Documents/mk64.o2r` retained SHA-256
  `26a8d0cf64a9e70276856b8876d41037195ea72cbbe78915257e6efd50179064`
  and `Documents/default.sav` retained SHA-256
  `6421a1adf0c5cc7a3eb1c720f21ccaa3ea528bc6ed12dfae5d46a16cbaab0416`.
  The synchronously saved config hashes to
  `39b423a5ddaec718dd592ef866389b7a26bdc96e266e0bf62b859189a9fa5c66`.
  No new SpaghettiPad crash report appeared.
- Audio boundary: the game log recorded `Audio thread started` at
  `08:43:19.364`. The lifecycle handler pauses SDL output, clears queued
  samples, and resumes the device on foreground; the live process resumed
  after every cycle. A non-invasive LLDB trace against that same Release
  process then proved the runtime path directly: background called
  `SDLAudioPlayer::SetPaused(true)` on SDL device 2, changed its paused byte
  from 0 to 1, and left `Buffered()` at zero. Foreground called
  `SetPaused(false)` on the same object, changed 1 to 0, and the audio worker
  immediately called `DoPlay` with 3,584 bytes, refilling the queue to 896
  stereo sample frames. LLDB detached cleanly; PID `86185` remained alive and
  live rendering continued. However, macOS reported `Jump Desktop Audio` as
  `Default Output Device` and `MacBook Air Speakers` only as
  `Default System Output Device`. No human audible-output result is claimed;
  that listening check remains the Phase 5b gate.

### 2026-07-28 — Phase 4 Simulator title-screen gate passed

- Build: `scripts/configure-ios.sh --simulator` generated the Xcode project
  for `arm64-apple-ios15.0-simulator` with the iPhoneSimulator 26.5 SDK. The
  final `SpaghettiPad.app` build ended in `** BUILD SUCCEEDED **`; its arm64
  executable reports `LC_BUILD_VERSION` platform `IOSSIMULATOR`, minimum
  15.0, SDK 26.5, and SHA-256
  `8e18588cf5de24927e8b2a51251c76068ecc24a23d2d98d77d88f9fbd45a4ef2`.
- Data boundary: ignored `ref/mk64.o2r` was staged only into the app's
  Files-visible Simulator Documents container. Source and staged copies both
  retained SHA-256
  `26a8d0cf64a9e70276856b8876d41037195ea72cbbe78915257e6efd50179064`;
  no ROM was copied into the app or repository.
- Runtime: a clean launch on the booted iPad Pro 11-inch (M4), iOS 18.5
  Simulator loaded bundled `spaghetti.o2r`, then
  `Documents/mk64.o2r`, registered the MK64 and extended-asset mods, loaded
  the title-screen audio sequence, and rendered live Metal frames through
  title and attract-mode races.
- Relaunch: a second clean launch at 08:03:04 loaded the persisted
  `Documents/mk64.o2r` by 08:03:05 and reached game rendering without an
  import or portable-file dialog. The final title-screen evidence is the
  ignored `ref/evidence/phase4-simulator-title-landscape.jpeg` (SHA-256
  `31d867e86f124013a39fb1259722b348e75276702cb416c1a480c3eedfbb06ca`).
- Landscape correction: the initial Simulator launch exposed an actual
  portrait scene despite landscape-only plist declarations. The narrow fix
  keeps SDL's landscape hint and wires its created window to the native shell,
  which requests a landscape `UIWindowScene` geometry update. UIKit logs then
  recorded the scene orientation preferences as landscape-left/right, and
  the visually inspected Simulator window and title screen were upright in
  landscape. Xcode 26.6's `simctl io screenshot` retained the raw portrait
  buffer orientation, so the settled Simulator-window capture is the visual
  acceptance source.
- Dialog audit: the Simulator executable's undefined-symbol table contains no
  `pfd`, portable-file-dialog, or file-dialog symbol.
- Patch replay: `patches/libultraship-ios.patch` now contains the two guarded
  landscape integration additions and exactly matches the 17-file upstream
  diff (520 lines, 184 insertions, 23 deletions; SHA-256
  `db284e75edc058f78ff81dca1dd3b6b64e27f0db67f22cc8d69274b25ff011ea`).
  Both maintained patches reverse-applied to pristine pinned inputs, reapplied
  through `scripts/apply-patches.sh`, and passed reverse-check and
  `git diff --check`.
- Desktop regression: the complete patched native arm64 macOS target rebuilt
  and linked successfully after the orientation addition; final executable
  SHA-256 is
  `236e8cddd0dd54963980d0a3bf6bb9b7909aaa75fa5aa71db8c98f547219c39b`.
  `scripts/check-repo-safety.sh` also passed.
- Boundary: this phase does not claim lifecycle continuity, subjective audible
  audio, physical-device runtime, touch, extraction, performance, controller,
  texture-pack, or package behavior.

### 2026-07-28 — Phase 3 unsigned iPhoneOS application gate passed

- Maintained patch: `patches/spaghettikart-ios.patch` (297 lines, seven source
  files, 137 insertions, 48 deletions; SHA-256
  `7cfe87dc5f386001aad61cb6a42f522bc30904494f4a7fccddfbdc62c9a9c5db`)
  backports the shell/resource bundle, iOS CMake guards, pinned Ogg/Vorbis
  fallback, mobile include correction, and iOS-15-safe controller-pak
  filename construction.
- Patch replay: both maintained patches reverse-applied to pristine
  SpaghettiKart `5b28472d477bab101dee2a0f469fe2aee2c58a01` and libultraship
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1`, leaving both inputs clean.
  `scripts/apply-patches.sh` then restored both patches and both passed
  reverse-check and `git diff --check`.
- Build: `scripts/build-ios.sh` configured Xcode 26.6 with the iPhoneOS 26.5
  SDK, `arm64-apple-ios15.0`, scripting disabled, and unsigned code signing,
  then linked `build-ios/Release-iphoneos/SpaghettiPad.app`. The clean wrapper
  replay ended in `** BUILD SUCCEEDED **`.
- Narrow build fixes: Vorbis 1.3.7 required
  `CMAKE_POLICY_VERSION_MINIMUM=3.5` under CMake 4.4, and the upstream
  `std::format` fallback was replaced with simple string concatenation because
  the iOS SDK marks its floating formatter unavailable before iOS 16.3. The
  first resource audit also found upstream's escaped Xcode platform variable;
  iOS runtime directories are now native bundle resources rather than a
  post-build copy.
- Binary audit: the final executable is an arm64 Mach-O with `LC_BUILD_VERSION`
  platform `IOS`, minimum OS 15.0, SDK 26.5, and SHA-256
  `6de1e0ea7bffa7037951911389840873332fe7f431e3fc4a6b8491cf2be4e2f0`.
  `codesign -dv` reports `code object is not signed at all`.
- Bundle audit: `Info.plist` names `SpaghettiPad`, reports `iPhoneOS`,
  minimum 15.0, and device families `1,2`; Files sharing, landscape
  orientations, arm64+Metal capability, extended-controller support, indirect
  input, and ProMotion keys are present. `config.yml`, `yamls/`, `meta/`,
  `gamecontrollerdb.txt`, and `spaghetti.o2r` are inside the bundle.
- Safety audit: the bundled clean archive retains SHA-256
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`;
  the pinned controller database retains SHA-256
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
  `scripts/audit-ios-app.sh` found no ROM, `mk64*.o2r`, `.otr`, signature, or
  provisioning material, and `scripts/check-repo-safety.sh` passed.
- Desktop regression: the full patched native arm64 macOS target relinked
  successfully with final executable SHA-256
  `eba1ae77c1602a14acbc6a6e967ec91e84e0a686854a6a6494063a875aad1187`.
  This replay exposed zero-byte results from upstream's unchecked
  `sse2neon.h` and `semver.hpp` downloads; both are now commit-pinned and
  hash-verified in the maintained patch, and `scripts/build-oracle.sh`
  validates those headers plus `stb_image.h`.
- Boundary: this phase does not claim Simulator or physical-device runtime,
  lifecycle continuity, audible audio, touch, extraction, performance,
  controller, texture-pack, or packaging behavior.

### 2026-07-28 — Phase 2 libultraship iPhoneOS library gate passed

- Patch replay: `patches/libultraship-ios.patch` (505 lines, 17 source files,
  176 insertions, 22 deletions; SHA-256
  `af687f13734f9c3c3d8292003c1695a769a7e54b22fd6cb3a38b122202af29fe`)
  reverse-applied to pristine libultraship
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1`, passed `git apply --check`,
  reapplied through `scripts/apply-patches.sh`, and passed reverse-check and
  `git diff --check`.
- iPhoneOS build: `scripts/build-ios-lus.sh` configured Xcode 26.6 with the
  iPhoneOS 26.5 SDK, `arm64-apple-ios15.0`, and scripting disabled, then built
  `build-ios-lus/src/Release-iphoneos/libultraship.a`. The final archive is
  arm64, reports `LC_BUILD_VERSION` platform 2 and minimum OS 15.0, and has
  SHA-256
  `f8185a4de2681bb5a63fd9fa62d1501ec35d301e8cdb1e0570f8337f0271c1f5`.
- Symbol audit: the archive has no undefined
  `toggleNativeMacOSFullscreen` or `CoreAudioAudioPlayer` reference.
  `WindowIsFrameReady` and the weak
  `SpaghettiPad_SetTouchControlsMenuVisible` integration hook are present.
- Scripting guard: an iPhoneOS configure with `ENABLE_SCRIPTING=ON` stopped
  at CMake with the required `ENABLE_SCRIPTING is unsupported on iOS` fatal
  error.
- Desktop regression: the patched dependency rebuilt and linked the complete
  native arm64 `build-oracle/Spaghettify` target on macOS (340 Ninja steps;
  final executable SHA-256
  `0c53480ea6be03a900a5faf2b51ae10e622f6a7321bd72e6da6d630894a3e69a`).
  The compiler emitted existing upstream warnings but no errors.
- Boundary: this phase does not claim a linked iOS app, Simulator or physical
  device runtime, lifecycle continuity, audible audio, touch, extraction,
  performance, controller, texture-pack, or packaging behavior.

### 2026-07-28 — Phase 1 macOS oracle and archive gate passed

- Input: ignored `ref/Mario Kart 64.z64` was identified as big-endian
  `MARIOKART64`, region/revision `NKTE Rev.00`, with the required SHA-1
  `579c48e211ae952530ffc8738709f078d5dd215e`. Torch independently reported
  the same game, country `us`, version `0`, and hash during extraction.
- Build: `scripts/generate-port-archive.sh` configured the pinned unmodified
  SpaghettiKart tree as a Release Ninja build with scripting disabled, built
  the native arm64 Mach-O `build-oracle/Spaghettify`, generated the clean port
  archive, and generated the desktop game archive. The final bounded replay
  passed with `ORACLE_BUILD_JOBS=4`.
- Dependency failure and recovery: a restricted-network configure left
  CMake's pinned `stb_image.h` download at zero bytes, producing the exact
  `GuiTexture.cpp:9:9: error: use of undeclared identifier
  'stbi_image_free'`. The script now fails fast unless that pinned header is
  nonempty; the authorized network replay fetched the 282,848-byte file and
  completed without source changes.
- Archive evidence: final SHA-256
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`
  for `build-oracle/spaghetti.o2r` (369 entries, 2.6 MiB), and
  `26a8d0cf64a9e70276856b8876d41037195ea72cbbe78915257e6efd50179064`
  for both `build-oracle/mk64.o2r` and ignored `ref/mk64.o2r` (25 MiB).
  The clean archive was packed from the pinned source `assets/` input and its
  entry-list audit found no `.z64`, `.n64`, `.v64`, `.rom`, `.otr`, or nested
  `mk64*.o2r`.
- Source-boundary replay: the extractor's ten regenerated tracked asset
  headers were restored by the script's exit trap. Both
  `sources/spaghettikart/baserom.us.z64` and
  `sources/spaghettikart/mk64.o2r` were removed, the pinned checkout returned
  to detached clean `HEAD`, and `scripts/check-repo-safety.sh` passed.
- Runtime: a fresh launch from `build-oracle/` loaded `spaghetti.o2r`,
  `mk64.o2r`, all 21 audio banks, and the title-screen sequence. Continuous
  startup capture visually proved the libultraship splash, Nintendo boot
  logo, and live Mario Kart 64 title screen with `PUSH START BUTTON`; the
  local ignored evidence frame is
  `ref/evidence/phase1-title-screen.png` (SHA-256
  `a7a1aec2b2ccf764a5e7887f3ab89c1e9a9c70796c8ed74b70a09a27e2d69f93`).
- Boundary: the desktop attract-mode races rendered and advanced, but this
  phase does not claim gameplay correctness, controller input, subjective
  audio quality, or any iOS behavior.

### 2026-07-28 — Phase 0 pinned bootstrap and clean-directory replay passed

- Expected: a clean checkout resolves SpaghettiKart, libultraship, and Torch
  at the plan's exact revisions, makes every upstream input fetch-only, keeps
  all local/build material ignored, and passes the ROM/history/credential
  safety gate.
- Workspace replay: `scripts/clone-sources.sh` resolved SpaghettiKart
  `5b28472d477bab101dee2a0f469fe2aee2c58a01`, libultraship
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1`, and Torch
  `2d474ddb8da8b213fbdbb49d0273ce31fa955f35`. Each `origin` push URL reports
  `disabled://spaghettipad-upstream-input`.
- Safety replay: `scripts/check-repo-safety.sh` passed after validating the
  current file set, Git history, likely credentials, shell syntax and
  executability, Markdown links, ignore rules, and `git fsck --strict`.
  `git check-ignore -v ref/rom.z64 sources` resolves both paths to
  `.gitignore`.
- Clean-directory proof: a repository containing only the current intended
  tracked files was initialized at
  `/tmp/spaghettipad-phase0.Mm1Yzq`. It was clean before bootstrap, fetched all
  three inputs afresh, reproduced the exact revisions and disabled push URLs,
  passed the safety audit after bootstrap, and remained clean (`## master`).
- Prior-art boundary: `ref/rebelancap-spaghettikart-ios` remains ignored,
  push-disabled, and read-only reference material. Its MIT license was
  verified before any equivalent implementation work.
- Concurrent plan update: remote `main` advanced to `230d536` during the
  Phase 0 push. That commit adds Decision D14 and the hardware-gated Phase 9
  MK64 Reloaded workflow named by the goal, and confirms the prior-art
  reference is MIT. It was inspected and integrated before publication; the
  earlier goal/plan discrepancy is resolved.
- Boundary: no source patches, host/iOS build, runtime, ROM extraction, touch,
  audio, device, texture-pack, multiplayer, or packaging claim is made by
  this phase.

### 2026-07-28 — Phase 0 setup started

- Expected: establish the exact source pins, prevent accidental upstream
  publication, and add a ROM/history/credential safety gate before any build
  work.
- Starting repository: clean `main` at
  `59ad133d7f1df88b0783859bbcda03d0c6d292c92`, equal to `origin/main`.
- Prior-art reference: cloned `rebelancap/SpaghettiKart-ios` locally at
  `397fd9c638b3772ef1526b5af9d56f8d169ee339`; its `origin` push URL is
  `disabled://spaghettipad-upstream-input`, its top-level license is MIT, and
  47 maintained patches are present.
- Input boundary: `ref/Mario Kart 64 (U) [!].v64` is ignored. No required
  `.z64` input is present, so no extraction or oracle gate is attempted.
