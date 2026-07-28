# SpaghettiPad — Implementation Plan: Mario Kart 64 (SpaghettiKart) native on iPadOS/iOS

Written 2026-07-28. Companion documents: [spaghettikart-ios-feasibility.md](spaghettikart-ios-feasibility.md) (Stage 1 + gate revision) and [rebelancap-ports-review.md](rebelancap-ports-review.md) (competitive positioning). Every file:line claim below was verified against source on 2026-07-27/28 at these revisions:

| Tree | Revision |
|---|---|
| HarbourMasters/SpaghettiKart (`SK:`) | `5b28472d477bab101dee2a0f469fe2aee2c58a01` |
| Kenix3/libultraship (`LUS:`) | `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` (SK's submodule pin) |
| HarbourMasters/Torch (`TORCH:`) | `2d474ddb8da8b213fbdbb49d0273ce31fa955f35` (SK's submodule pin) |
| HarkinianPad (`HP:`) | `ref/harkinianpad` snapshot — 6 maintained patches + build/packaging scripts |

Effort sizes are **estimates** throughout (S ≈ hours-to-a-day, M ≈ days, L ≈ one-to-few weeks, one engineer, HarkinianPad experience assumed). Nothing in this document is a measurement unless it cites one.

---

## 1. Summary

Build **SpaghettiPad**: a native iPadOS-first (iPhone-compatible) port of SpaghettiKart, positioned as *the first Mario Kart 64 built for iPad* — grip-designed touch controls with true analog steering, on-device ROM extraction through the Files app, physical-controller support, 2–4-player split-screen on a single iPad as the headline differentiator, and optional tilt steering. The approach is the proven HarkinianPad model: a single publication repo (`spaghettipad`) holding scripts, maintained patches, and an iOS app shell, applied over pinned, push-disabled, unmodified upstream checkouts (SpaghettiKart @ `5b28472d`, libultraship @ `f5c3843`, Torch @ `2d474ddb`). The engine layer reuses HarkinianPad's `libultraship-ios.patch` backported 12 commits, the extraction layer reuses SpaghettiKart's already-present in-process Torch extractor (statically linked, single-threaded, sandbox-compatible) with an iOS Files-import first-run flow, and the input layer improves on HarkinianPad by feeding a **virtual SDL game controller** (full analog) instead of synthesized keystrokes.

## 2. Decisions

Each decision lists options considered, the choice, and why. Deferred decisions are marked and state what settles them.

**D1 — Repository strategy: overlay repo, upstreams pinned read-only.**
Options: (a) hard fork of SpaghettiKart; (b) branch on a fork with intent to PR; (c) HarkinianPad-style overlay repo (scripts fetch pinned upstreams, disable push URLs, apply reviewable patches, app shell lives here).
**Chosen: (c).** It is the model the developer already operates (HarkinianPad `scripts/build-ios.sh`, `patches/`, package audit), it keeps the ROM/asset safety audit in one place, it survived upstream churn for HarkinianPad, and it was independently converged on by rebelancap (47-patch overlay). Upstreaming later remains possible because every change is already a discrete patch. Upstream repos are never pushed to; push URLs are set to `disabled://spaghettipad-upstream-input`.

**D2 — libultraship strategy: keep SpaghettiKart's pin `f5c3843`, backport HarkinianPad's engine patch.**
Options: (a) bump SK's LUS submodule to `2bfbde3` (HarkinianPad's base) or `port-maintenance` tip; (b) keep `f5c3843` and backport `HP:patches/libultraship-ios.patch`; (c) vendor a custom LUS fork.
**Chosen: (b).** Verified: `f5c3843` is a direct ancestor of `2bfbde3`, 12 commits behind, and the delta renames `Context::GetInstance()` (shared_ptr) → `GetRawInstance()` (raw) plus a large `Gui.h` refactor and `InputEditorWindow` removal — SpaghettiKart has **107 call sites** of `Context::GetInstance()` (`SK:src/port/*`), so bumping forces a game-code migration upstream has not done and every future SK rebase would fight it. Backporting instead requires only mechanical translation inside the patch: `GetRawInstance()` → `GetInstance()`, and one relocation — at `f5c3843` the Apple audio-backend default lives at `LUS:src/ship/config/Config.cpp:269-271` (not `Audio.cpp:100-102` as at `2bfbde3`), so the CoreAudio-exclusion hunk must be applied there too. Dependency pins are identical at both commits (SDL2 `release-2.32.10`, spdlog `v1.16.0`, libzip `v1.11.4`, metal-cpp `macOS13_iOS16`, leetal ios-cmake `06465b27`) — verified in `LUS:cmake/dependencies/ios.cmake` and `cmake/ios-toolchain-populate.cmake`.
*Deferred:* bump to `port-maintenance` when upstream SpaghettiKart bumps; settled by watching SK's `.gitmodules`.

**D3 — Platform define: standardize on `__IOS__`, keep `PLATFORM_IOS` as an alias.**
Verified breakage: LUS defines `__IOS__` **PRIVATE** (`LUS:src/CMakeLists.txt:176-182`) while SK defines only `PLATFORM_IOS=1` (`SK:CMakeLists.txt:138`), so SK's own `#if !defined(__IOS__)` guards (`SK:src/port/GameExtractor.cpp:25,74,89`, `SK:src/port/SpaghettiGui.cpp:19`) take the **desktop** branch on iOS — `portable-file-dialogs` would compile in. Fix in the SK patch: add `__IOS__` to the `Spaghettify` target's compile definitions alongside `PLATFORM_IOS`. Also fix the wrong include path `"port/mobile/MobileImpl.h"` → `"ship/port/mobile/MobileImpl.h"` (`SK:src/port/SpaghettiGui.cpp:20`; correct form per `LUS:src/ship/window/gui/Gui.cpp:34`).

**D4 — Asset extraction: bundle extraction inputs in the .app; extract on device with in-process Torch; bring-your-own-ROM via Files.**
Options: (a) desktop-generated `mk64.o2r` imported via Files only; (b) on-device extraction; (c) both.
**Chosen: (c), with (b) as the headline UX.** Verified feasibility: Torch is already statically linked into `Spaghettify` (`SK:cmake/dependencies/common.cmake:52-65` builds it as a static lib because `USE_STANDALONE=OFF`; linked at `SK:cmake/dependencies/FindLib.cmake:40-41`), the in-process call is cwd-independent (`SK:src/port/GameExtractor.cpp:188-202` passes `GetAppBundlePath()` as source dir and `GetAppDirectoryPath()` as dest dir), Torch spawns no processes, uses no mmap, is single-threaded, and needs no additional dependencies in library mode (libgfxd and `include/defines.h` parsing are `#ifdef STANDALONE`-only — `TORCH:src/Companion.cpp:1205-1213`). The MK64 ROM is 12 MB (vs OoT's 32–64 MB), so Torch's buffer-everything design (ROM ×2 in RAM, non-evicting decompression cache, in-RAM zip at `MZ_BEST_COMPRESSION`) is far below jetsam limits; wall-clock is minutes-order (single-threaded deflate) — **estimate**, measure in Phase 7.
The bundle ships `spaghetti.o2r` + `yamls/` + `config.yml` + `meta/` (the extraction inputs — 7.9 MB of yamls; exactly what Sunset-Dawn's IPA bundled), and the backported Context patch makes `GetAppBundlePath()` return the real `NSBundle` resource path on iOS instead of `Documents` (`HP:patches/libultraship-ios.patch` Context.cpp hunk) — that single change makes Torch's source dir the read-only bundle and its dest dir the writable `Documents/`, which is the correct sandbox split. ROM identification is SHA-1 `579c48e211ae952530ffc8738709f078d5dd215e` (US, big-endian `.z64` only — `SK:src/port/GameExtractor.cpp:29-31`, `TORCH:src/n64/Cartridge.cpp` has no byteswap); the import UI must say so explicitly. Two mandatory guards: delete `Documents/torch.hash.yml` before any (re-)extraction (`TORCH:src/Companion.cpp:509-568,1337-1339` silently skips "unchanged" yamls and would emit a near-empty archive), and pre-validate the hash before calling Torch (a hash miss makes `Companion::Process` return **without throwing** — `TORCH:src/Companion.cpp:1044-1047`).

**D5 — Touch input architecture: UIKit overlay driving a virtual SDL game controller (full analog), not synthesized keystrokes.**
Options: (a) HarkinianPad's pattern — UIKit buttons post SDL key events (8-way stick); (b) UIKit overlay feeding `SDL_JoystickAttachVirtualEx` (SDL ≥ 2.24 provides virtual game controllers; SK's SDL is 2.32.10) so the game sees a normal analog controller through the existing `ControlDeck` stack; (c) inject directly into `OSContPad` via a bridge.
**Chosen: (b), with (a) as the proven fallback.** A kart racer's steering is the product; the game reads genuine analog (deadzone ±12, clamp ±53, from LUS's ±85 convention — `SK:src/player_controller.c:4469-4573`, `LUS:.../ControllerAxisDirectionMapping.h:8`), and an 8-way stick would visibly flatten it. A virtual controller also makes tilt steering (D10) a trivial axis writer, keeps menu navigation working through the existing controller-nav path, and matches how physical controllers already flow. Risk: port-assignment interplay with real controllers (LUS auto-binds defaults only for port 0 — `LUS:src/ship/controller/controldeck/ControlDeck.cpp:35-40` — and SK enables `ENABLE_EXP_AUTO_CONFIGURE_CONTROLLERS` at `SK:cmake/dependencies/common.cmake`); Phase 8 validates, and fallback (a) is a one-day pivot because the overlay geometry/code is shared.
The overlay itself is HarkinianPad's architecture: one Objective-C++ view in the app shell, hit-test pass-through on empty space, menu `•••` button always installed, menu-visible state hides gameplay controls (hook point: `LUS` Gui.cpp patch hunk, renamed `SpaghettiPad_SetTouchControlsMenuVisible`).

**D6 — Audio: SDL backend on iOS (backport), 26800 Hz stereo.**
Verified: at `f5c3843`, `AudioBackend::COREAUDIO` registers on all `__APPLE__` (`LUS:src/ship/audio/Audio.cpp:48-50`), the default is COREAUDIO (`LUS:src/ship/config/Config.cpp:269-271`), and the implementation is macOS-only (`kAudioUnitSubType_HALOutput`, `LUS:src/ship/audio/CoreAudioAudioPlayer.cpp:47`) → iOS silently gets the Null player. Backport HarkinianPad's exclusion (`__APPLE__ && !__IOS__` in Audio.cpp/AudioPlayer.h + the Config.cpp default) plus `SDLAudioPlayer::SetPaused` and `SDL_HINT_AUDIO_CATEGORY=playback`. SK runs audio at 26800 Hz / 512 samples / 1100 buffered, stereo (`SK:src/port/Engine.cpp:179`, `SK:src/port/Engine.h:28-32`) on a real `std::thread` (`SK:src/port/Engine.cpp:562-566`); SDL-on-iOS resamples via AVAudioSession. Because the main thread blocks in `EndAudioFrame()` each frame (`SK:src/port/Game.cpp:985`), gating `push_frame()` while backgrounded also stops audio production naturally; `SetPaused(true)` clears the queue on background.

**D7 — Deployment target: iOS/iPadOS **15.0** (estimate of the safe floor; validate in Phase 3).**
LUS CI proves 14.0 configures; HarkinianPad shipped min 14.0 on the same metal-cpp tag and ran on hardware. 15.0 is chosen for `UIWindowScene` simplifications in the shell and to keep the support matrix honest; nothing identified requires 16+. Device families `1,2`; landscape-only. Split-screen guidance: A12X/A12Z/M-series iPads recommended (**estimate**, measured in Phase 10).

**D8 — Toolchain: single leetal ios-cmake via LUS's populate file with `PLATFORM` override; delete SK's early include.**
Verified conflict: SK vendors `cmake/ios.toolchain.cmake` and `include()`s it **after** `project()` (`SK:CMakeLists.txt:33-37` — non-functional as a toolchain, and hardcodes `PLATFORM "OS64"`), while LUS fetches its own copy with `PLATFORM "OS64COMBINED"` (`LUS:cmake/ios-toolchain-populate.cmake:1`). The SK patch removes the vendored include + `YOUR_TEAM_ID`/`dev.net64.game` placeholders; the backported LUS patch makes `PLATFORM` overridable (`if(NOT DEFINED PLATFORM)` hunk). Build scripts pass `-DPLATFORM=OS64` (device) / `SIMULATORARM64` (simulator), generator `-GXcode`.

**D9 — Multiplayer scope: 2-player split-screen with physical controllers is in scope and is the flagship demo; 3P/4P is a stretch goal behind a perf gate.**
Verified: split-screen is platform-agnostic (modes at `SK:include/defines.h:246-250`; menu flow `SK:src/menus.c:1316-1340`; viewports `SK:src/racing/skybox_and_splitscreen.c:748-820`; no platform `#ifdef` anywhere in the path), and controller→player mapping is fixed port-order (port *i* = player *i*). The work is UX (port mapping without the desktop input editor) and performance, not engine code.
*Deferred:* touch-as-player-2 (two players on one screen's touch overlay) — almost certainly never; settled by user demand after 2P-with-controllers ships.

**D10 — Tilt steering: CoreMotion → virtual controller stick X. In scope, late phase, off by default.**
Cost is small once D5 lands (one motion manager, low-pass filter, calibration offset, CVar + Controls toggle). Neither prior port has it; it is a genuine iPad/iPhone differentiator. LUS's `OSContPad` even carries gyro fields SK ignores (`LUS:include/libultraship/libultra/controller.h:98-107`) — not needed for the chosen wiring.

**D11 — Scripting/WASM: keep dead, add tripwires.**
SK compiles no WAMR (submodule gitlink removed in PR #226; `SK:src/engine/wasm.cpp` fully commented). Backport the `ENABLE_SCRIPTING` → `FATAL_ERROR` iOS guard anyway (`HP` LUS patch hunk 1). No writable-executable memory exists in any shipped configuration.

**D12 — Distribution: source + unsigned re-signable IPA (AltStore Classic/SideStore), ROM-audit-gated; no App Store/TestFlight initially.**
SpaghettiKart, like Shipwright, has **no top-level LICENSE** (verified; Torch and LUS are MIT), so the HarkinianPad posture applies: publish the overlay repo + unsigned IPA; treat every hosted channel as a separate review. Reuse `HP:scripts/package-ios.sh` with guards changed to `mk64*.o2r`/`.z64/.n64/.v64` and the `spaghetti.o2r` content audit.
*Deferred:* a SideStore source JSON (rebelancap-style) and App Store exploration; settled after first public release.

**D13 — Working name: "SpaghettiPad"** (bundle `com.chrissotraidis.spaghettipad`, display name "SpaghettiPad"). *Deferred final naming* — settled by the owner before first public artifact; nothing else in this plan depends on it.

**D14 — Texture packs: first-class native support for MK64 Reloaded; never bundled.**
The [MK64 Reloaded](https://github.com/GhostlyDark/MK64-Reloaded) UHD pack (GhostlyDark) is the marquee visual upgrade and must work as a first-class feature on iPad: guided import (Files → `Documents/mods/`), automatic detection of an installed pack, a one-tap prompt to enable **Use Alternate Assets** (SpaghettiKart's alt-assets CVar; today's toggle is the Tab hotkey — `SK:src/port/Engine.cpp:377-382` — which needs a touch-reachable menu control), and HD-vs-4K guidance per device class. **The pack is never bundled in the app or IPA**: verified 2026-07-28, the MK64-Reloaded repo has **no license** (all rights reserved by default) and the content is derivative of Nintendo art — bundling would violate both GhostlyDark's rights and this project's own audit invariant. Even rebelancap's port ships without it and directs users to the official downloads. In-app *fetching* of the pack is deferred (Open Question 11); v1 opens the official release page in Safari and guides the Files copy.
Performance is part of "native": a 4K/HD pack on iPad means real texture-memory pressure. **rebelancap's `SpaghettiKart-ios` repo is MIT-licensed (verified: `LICENSE`, © 2026 rebelancap)** — his memory/perf patches are directly on point and may be adapted with attribution: `0021-lus-metal-texture-clamp`, `0022-lus-texcache-byte-budget`, `0030-lus-coupled-resource-eviction`, `0031-port-decode-downscale`, `0034-lus-metal-async-shaders`. Treat them as a reviewed starting point, not a blind import; every adaptation becomes one of our maintained patches with a provenance note.

## 3. Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│ spaghettipad repo (publication)                                       │
│  scripts/   clone-sources, apply-patches, generate-port-archive,      │
│             configure-ios, build-ios, package-ios, check-repo-safety  │
│  patches/   libultraship-ios.patch      (backported HP engine patch)  │
│             spaghettikart-ios.patch     (CMake arm + defines + deps)  │
│             spaghettikart-ios-firstrun.patch (Files import flow)      │
│             spaghettikart-ios-touch.patch    (overlay wiring)         │
│  ios/       Info.plist.in, Assets.xcassets, SpaghettiPadShell.mm      │
│             (touch overlay + virtual controller + CoreMotion)         │
│  docs/      this plan, BUILDING, RELEASE_CHECKLIST                    │
│  sources/   (gitignored) SpaghettiKart @5b28472d ─ torch @2d474ddb    │
│                          └ libultraship @f5c3843                      │
└───────────────────────────────────────────────────────────────────────┘

Runtime (device):
  SDL2 UIKit main → SDL_main → SK main() (extern "C" under PLATFORM_IOS,
    SK:src/port/Game.cpp:1017-1025)
  → GameEngine::Create → LUS Context("spaghettify") → Documents/ paths
  → ModManager: mk64.o2r present?
       no → first-run flow (Files guidance → Rescan → SHA-1 gate →
            in-process Torch: bundle yamls → Documents/mk64.o2r)
  → while (WindowIsRunning()) { if (!WindowIsFrameReady()) continue;   ← iOS gate
        push_frame(); }                     (SK:src/port/Game.cpp:1067-1069)
  → Metal via LUS Fast3D (only backend on iOS); ImGui menus (PortMenu)
  → audio std::thread → LUS SDLAudioPlayer (26800 Hz stereo)
  Input: touch overlay → SDL virtual game controller → ControlDeck port 0
         physical controllers → ports 0..3 → gControllers[0..3] → players
  Persistence: Documents/{spaghettify.cfg.json, default.sav,
         controllerPak_*.sav, mk64.o2r, mods/, logs/}   (all verified paths)
```

Code placement: everything engine-generic lands in `patches/libultraship-ios.patch` (upstreamable to Kenix3 later); everything SK-specific in the SK patches; everything Apple-API-touching (UIKit overlay, CoreMotion, haptics) in `ios/` shell sources compiled into the target by the SK patch — mirroring `HP:patches/shipwright-ios-touch-controls.patch`'s mechanism (`list(APPEND soh__ ...)`).

## 4. Phased plan

Conventions: all commands run from the `spaghettipad` repo root on macOS with Xcode + `brew install cmake ninja libpng glew sdl2 nlohmann-json libzip tinyxml2 libogg libvorbis`. `DT` = `-DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 -DDEPLOYMENT_TARGET=15.0` (both spellings — the leetal toolchain consumes `DEPLOYMENT_TARGET`; HarkinianPad's M1a evidence shows passing only one silently mis-targets). A user-supplied US `.z64` lives in gitignored `ref/`.

### Phase 0 — Repo scaffolding and pinned bootstrap
**Goal (observable):** a clean checkout of `spaghettipad` fetches all three upstreams at the exact pins with push disabled, and the safety audit passes.
**Changes:** create `scripts/clone-sources.sh` (clones SK `5b28472d` + submodule LUS `f5c3843` + torch `2d474ddb` into gitignored `sources/`, sets `disabled://` push URLs), `scripts/check-repo-safety.sh` and `.gitignore` (block `*.z64 *.n64 *.v64 *.o2r *.otr sources/ build-* ref/*` except `ref/README.md`) — all adapted from the HarkinianPad equivalents; `docs/` as-is.
**Commands:** `scripts/clone-sources.sh && scripts/check-repo-safety.sh`
**Accept:** script exits 0; `git -C sources/spaghettikart rev-parse HEAD` = `5b28472d…`; `git check-ignore ref/rom.z64 sources` both ignored.
**Verify before moving on:** run the clone on a second clean directory.

### Phase 1 — Host "oracle" build + `spaghetti.o2r` + desktop `mk64.o2r`
**Goal:** the pinned tree builds and runs on macOS unmodified; produces `spaghetti.o2r` (bundle input) and a desktop-generated `mk64.o2r` (Phase 4's staging asset).
**Changes:** none to sources; add `scripts/build-oracle.sh` (host cmake build) and `scripts/generate-port-archive.sh` (standalone torch `pack assets spaghetti.o2r o2r`, per `SK:cmake/GenerateO2R.cmake:7-14`; audit output for ROM-derived entries).
**Commands:**
```bash
cmake -S sources/spaghettikart -B build-oracle -GNinja -DCMAKE_BUILD_TYPE=Release
cmake --build build-oracle
cp ref/*.z64 sources/spaghettikart/baserom.us.z64
cmake --build build-oracle --target ExtractAssets   # host torch: mk64.o2r + headers
```
**Accept:** `Spaghettify` runs on the Mac to the title screen; `spaghetti.o2r` (~20 MB class) and `mk64.o2r` exist; audit confirms `spaghetti.o2r` contains no ROM-derived entries (it is built purely from `SK:assets/` — verified input set).
**Verify:** SHA-256 both archives and record them; delete `sources/spaghettikart/mk64.o2r` from the tree afterward (keep in `ref/`).

### Phase 2 — libultraship builds as an iOS static library with the backported patch
**Goal:** `libultraship.a` (arm64, iphoneos) builds at `f5c3843` + `patches/libultraship-ios.patch`.
**Changes:** author the backport. Contents = `HP:patches/libultraship-ios.patch` with these verified adjustments: `GetRawInstance()`→`GetInstance()` (all hunks); the COREAUDIO-default hunk applied at `LUS:src/ship/config/Config.cpp:269-271` in addition to `Audio.cpp:48-50` registration; keep hunks for `SDL_APP_*` lifecycle + `mIsBackgrounded` + `IsFrameReady()` (`gfx_sdl2.cpp` — note event switch lives at `:580-624` at this pin, not `:619-663`), `WindowIsFrameReady()` bridge (`windowbridge.{h,cpp}`), `GetPixelDepth` guards (`Fast3dWindow.cpp`), macOS-fullscreen carve-outs, Context `GetAppBundlePath` → NSBundle resource path on iOS, STB SHA-256 pin, `PLATFORM` override in `ios-toolchain-populate.cmake`, ENABLE_SCRIPTING FATAL_ERROR, Gui/GameOverlay mobile scaling (600-pt rule), and the Gui menu-visibility hook renamed `SpaghettiPad_SetTouchControlsMenuVisible` (declared `extern "C"`, weak no-op default so the library links without the shell). Drop the SoH-specific keyboard/mouse default-mapping hunks (SK's defaults differ; handled in Phase 8).
**Commands:**
```bash
scripts/apply-patches.sh
cmake -S sources/spaghettikart/libultraship -B build-ios-lus -GXcode \
  -DCMAKE_SYSTEM_NAME=iOS $DT -DPLATFORM=OS64
cmake --build build-ios-lus --config Release -- CODE_SIGNING_ALLOWED=NO
```
**Accept:** `** BUILD SUCCEEDED **`; `lipo -info` reports arm64; `nm` shows no `toggleNativeMacOSFullscreen` or `CoreAudioAudioPlayer` references in the iOS product.
**Verify:** patch applies with `git apply --check` on a pristine clone; macOS oracle build still passes with the patch applied (no desktop regression).

### Phase 3 — SpaghettiKart CMake surgery: full app configures and links for iOS
**Goal:** unsigned `SpaghettiPad.app` (arm64, iphoneos) builds end-to-end. This is the phase that proves the approach; everything after is feature work.
**Changes (`patches/spaghettikart-ios.patch`), all sites verified:**
1. `SK:CMakeLists.txt:33-37` — delete the vendored toolchain include, `YOUR_TEAM_ID`, `dev.net64.game`; keep `SPAGHETTIKART_IOS`.
2. `SK:CMakeLists.txt:118-146` — repoint `IOS_DIR` from nonexistent `libultraship/ios/` to the overlay-provided shell dir (`-DSPAGHETTIPAD_SHELL_DIR`), replace storyboard/PNG resources with `Assets.xcassets` + `ios/Info.plist.in`; add `__IOS__` next to `PLATFORM_IOS=1` (D3); set `MACOSX_BUNDLE`, `XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"`, ARC, bundle-id/team pass-through (`BUNDLE_ID`, `DEVELOPMENT_TEAM` env-driven, HarkinianPad style).
3. `SK:CMakeLists.txt:217-274` — gate `ExternalProject_Add(TorchExternal)` + `ExtractAssets`/`GenerateO2R` behind `if(NOT SPAGHETTIKART_IOS)` (host-tool targets; `ExternalProject` does not forward the toolchain).
4. `SK:cmake/SetCmakeVar.cmake:6` — guard `CMAKE_OSX_DEPLOYMENT_TARGET "10.15"` with `if(NOT SPAGHETTIKART_IOS)`.
5. `SK:cmake/SetFlags.cmake:40-42` — guard `-flto=auto` for AppleClang/iOS.
6. `SK:cmake/dependencies/FindLib.cmake:1-13` — add FetchContent fallback for Ogg (`xiph/ogg v1.3.6`) and Vorbis (`xiph/vorbis v1.3.7`) on iOS with `OVERRIDE_FIND_PACKAGE` (shape copied from `HP:shipwright-ios.patch` CMake/ios.cmake; SK needs no opus/opusfile/libpng — Torch vendors stb, verified).
7. `SK:src/port/SpaghettiGui.cpp:20` — include path fix (D3).
8. Post-build copies into the bundle: `spaghetti.o2r`, `yamls/`, `config.yml`, `meta/`, pinned `gamecontrollerdb.txt` (SHA-256-verified download, HarkinianPad mechanism — SK's CI fetches it only at package time, verified `main.yml`).
9. `ios/Info.plist.in` (new, in overlay): landscape-only both families, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, `UIRequiresFullScreen`, `GCSupportedGameControllers` ExtendedGamepad, `GCSupportsControllerUserInteraction`, `CADisableMinimumFrameDurationOnPhone` (ProMotion), `UIApplicationSupportsIndirectInputEvents`, `UIRequiredDeviceCapabilities` arm64+metal.
**Commands:**
```bash
scripts/configure-ios.sh          # wraps: cmake -S sources/spaghettikart -B build-ios -GXcode \
                                  #   -DCMAKE_SYSTEM_NAME=iOS $DT -DPLATFORM=OS64 \
                                  #   -DSPAGHETTIPAD_SHELL_DIR=$PWD/ios ...
cmake --build build-ios --config Release --target Spaghettify -- CODE_SIGNING_ALLOWED=NO
```
**Accept:** `** BUILD SUCCEEDED **`; `vtool` shows platform IOS, min 15.0; bundle contains `spaghetti.o2r`, `yamls/`, `config.yml`, `meta/`, `gamecontrollerdb.txt`, `Info.plist` with family `1,2`; zero `.z64/.o2r(mk64)/.otr` game data (audit).
**Verify:** run the audit script; keep a `vtool`/`codesign -dv` transcript in the evidence log.

### Phase 4 — Simulator boots to the title screen (Metal frame)
**Goal:** the app renders MK64's title on an iPad Simulator using Phase 1's desktop `mk64.o2r` staged into the container.
**Changes:** none beyond bug fixes discovered.
**Commands:**
```bash
scripts/configure-ios.sh --simulator   # -DPLATFORM=SIMULATORARM64
cmake --build build-ios-sim --config Release --target Spaghettify
xcrun simctl install booted build-ios-sim/Release-iphonesimulator/SpaghettiPad.app
xcrun simctl launch booted com.chrissotraidis.spaghettipad
# stage: cp ref/mk64.o2r into the app container Documents (simctl get_app_container)
```
**Accept:** live Metal title screen on iPad Pro Simulator; log shows `spaghetti.o2r` + `mk64.o2r` both loaded; no `portable-file-dialogs` symbols in the binary (`nm | grep -i pfd` empty — proves D3 landed).
**Verify:** screenshot + log excerpt in evidence log; relaunch skips all prompts.

### Phase 5 — Lifecycle + audio correctness
**Goal:** background/foreground cycles are safe; SDL audio is audible in Simulator.
**Changes:** `patches/spaghettikart-ios.patch` addition — wrap the loop (`SK:src/port/Game.cpp:1067-1069`):
```c
while (WindowIsRunning()) {
#ifdef __IOS__
    if (!WindowIsFrameReady()) { continue; }   // pumps events + sleeps 16 ms internally
#endif
    push_frame();
}
```
This is safe against the event-pump caveat because the backported `WindowIsFrameReady()` calls `HandleEvents()` itself (verified in the HP bridge implementation). Audio pauses implicitly (D6) plus explicit `SetPaused` on background from the LUS patch.
**Accept:** three consecutive Simulator background/foreground cycles on one PID; config flush happens on background (`spaghettify.cfg.json` mtime advances); game log does not advance while backgrounded; audio resumes on foreground; `SDL Audio initialized` in log and audible output.
**Verify:** repeat HarkinianPad's M6a evidence procedure (PID, log-size, container-hash checks).

### Phase 6 — Physical iPad: signed install and boot
**Goal:** the same build, signed with a personal team, installs and reaches the title screen on the iPad Pro.
**Changes:** none; signing via env (`DEVELOPMENT_TEAM=… BUNDLE_ID=… scripts/configure-ios.sh`).
**Commands:** as Phase 3 plus `-allowProvisioningUpdates`; install via Xcode Devices or `devicectl`.
**Accept:** cold boot to title on hardware with a Files-imported desktop `mk64.o2r`; 10+ minutes of attract/demo without a watchdog kill.
**Verify:** record device model/OS/build hash in the evidence log (HarkinianPad discipline).

### Phase 7 — On-device extraction: the first-launch flow
**Goal:** a user with only the app and a US `.z64` reaches the title screen with no desktop.
**Changes (`patches/spaghettikart-ios-firstrun.patch`), sites verified:**
- `SK:src/engine/mods/ModManager.cpp:60-69` — replace the SDL yes/no ("No O2R Files… Generate one now?" / `_Exit(1)`) with the non-quitting flow: device-aware Files guidance ("Copy your Mario Kart 64 (US) .z64 into *On My iPad › SpaghettiPad*"), **Rescan**, retry-on-failure — UX contract transplanted from `HP:patches/shipwright-ios-first-run.patch`, re-sited to SK's ModManager/Engine popups (SK's flow is SDL message boxes, not ImGui popups — keep SDL boxes initially; they are UIKit-backed).
- `SK:src/port/GameExtractor.cpp:121-174` — iOS branch of `GetRoms()`: scan `GetAppDirectoryPath()` (Documents) with `std::filesystem::directory_iterator` for `*.z64` (any filename — the existing mobile branch's hardcoded `baserom.us.z64` at `:89-99` is replaced), full-file SHA-1 against `mGameList`.
- `SK:src/port/Engine.cpp:268-289` — before `GenerateOTR()`: delete stale `Documents/torch.hash.yml` and any zero/partial `mk64.o2r` (D4 traps); keep the "few minutes" modal, add a spinner/progress readout if cheap (Torch exposes per-file iteration at `TORCH:src/Companion.cpp:1290-1313`; a coarse counter callback is a small addition — *optional*).
- Reject non-matching hashes with a message naming the requirement (US 1.0 `.z64`, big-endian) rather than exiting.
**Accept:** clean install on hardware → guidance → Files copy → Rescan → extraction completes → title screen; relaunch skips everything; measured extraction wall-clock and peak memory recorded (replaces the Phase-plan **estimates**); a wrong-region/byteswapped ROM produces the explanatory message and a working Rescan loop, not an exit.
**Verify:** repeat on a disposable Simulator with a genuinely empty container; hash the generated `mk64.o2r`.

### Phase 8 — Touch controls v1 (the racer layout)
**Goal:** a full Grand Prix is playable start-to-finish with touch only, including all menus.
**Changes:** `ios/SpaghettiPadShell.mm` (overlay + virtual controller; see §5 spec) + `patches/spaghettikart-ios-touch.patch` (compile shell into target; boot-time init from `BootCommands`-equivalent — SK has no bootcommands, use `GameEngine::Create` tail at `SK:src/port/Engine.cpp:348-350`; register the Controls-menu toggle in `SK:src/port/ui/PortMenu.cpp` Controls section ~`:336-411`; menu-visibility hook already provided by the LUS patch).
Also: the enhancements menu is unreachable by touch today (F1/Escape/GamepadBack only — `SK:src/port/SpaghettiGui.cpp:40-41,107-113`); the `•••` button posts the toggle. And set `SDL_HINT_TOUCH_MOUSE_EVENTS=1` explicitly (agent found no explicit setting; do not rely on defaults).
**Accept:** all §5 acceptance checks pass on hardware; virtual controller appears as port 0 and steering telemetry shows analog values (not ±max only) — check with the input display or `gControllers[0].rawStickX` logging.
**Verify:** record a full GP run; menu open/close cycles do not strand inputs (all released on hide).

### Phase 9 — iPad UX pass + native texture-pack support (D14)
**Goal:** menus and HUD are correct for iPad specifically, and MK64 Reloaded works as a first-class feature.
**Changes:** confirm the 600-pt scale rule lands well on iPad (2×) and iPhone (1×/0.75 option); safe-area audit of the overlay; expose `gInterpolationFPS` presets (30/60/120) in Settings with ProMotion note (`CADisableMinimumFrameDurationOnPhone` already in plist; SK target-fps plumbing verified at `SK:src/port/Engine.cpp:298-301,467`); hide/neutralize desktop-isms verified by the dive: "Cursor Always Visible" (`SK:src/port/ui/PortMenu.cpp:148-154`), "Open App Files Folder" `SDL_OpenURL(file://…)` (`:176-182` — repoint to a Files-app tip), Ctrl/Cmd+R reset (add confirm popup, HP pattern).
Texture-pack items: touch-reachable **Use Alternate Assets** toggle in the menu (replacing the Tab hotkey path, `SK:src/port/Engine.cpp:377-382`); mods-folder detection on launch/rescan with a one-tap enable prompt; a "Get texture packs" entry that opens the official MK64-Reloaded release page and shows the Files-copy instructions; adapt rebelancap's MIT texture-memory patches (D14 list) as needed to hold frame rate with the HD pack — measure before adopting each.
**Accept:** side-by-side screenshots iPad/iPhone; every Settings/Enhancements panel operable by touch; no dead menu items on iOS; **MK64 Reloaded HD imported via Files on hardware, detected, enabled from the menu without a keyboard, and a full GP completes with the pack active at the Phase-6 baseline frame rate** (4K attempted on M-series iPad; result recorded either way); audit still shows no pack content in the app bundle or IPA.

### Phase 10 — Physical controllers + split-screen on one iPad
**Goal:** 2-player GP/VS/battle, two Bluetooth controllers, one iPad — stable frame rate; the flagship demo.
**Changes:** validate auto-assignment (`ENABLE_EXP_AUTO_CONFIGURE_CONTROLLERS` ON — verified set by SK); the virtual touch controller must yield port 0 to the first physical controller or park itself (decision point documented in §11; likely rule: touch overlay hides + virtual pad detaches when ≥1 physical controller connects, HarkinianPad's toggle UX); document port→player order (port *i* = player *i*, verified `SK:src/racing/race_logic.c:765-767`); test the player-count menu (D-pad L/R on main menu, `SK:src/menus.c:1316-1340`).
**Accept:** 2P horizontal split GP completes on hardware with two controllers; frame-time capture recorded; 3P/4P attempted and the result (ship/defer) recorded with numbers.
**Verify:** video capture — this is also the marketing asset.

### Phase 11 — Tilt steering
**Goal:** playable tilt mode.
**Changes:** `ios/` CoreMotion manager (device-motion @ 60 Hz, roll → stick X with adjustable sensitivity + recenter), Controls toggle + CVar, mutual exclusion with overlay stick input.
**Accept:** a GP is completable with tilt + on-screen A/B/R/Z; setting persists; no drift after backgrounding (recalibrates on foreground).

### Phase 12 — Packaging, CI, docs, release
**Goal:** a tagged release someone else can build and sideload from the docs alone.
**Changes:** `scripts/package-ios.sh` (audit: reject Simulator products, ROMs, `mk64*.o2r`, `.otr`, stale signing; verify bundled `spaghetti.o2r` content hash independent of build-time ZIP timestamps), `scripts/build-ios.sh` one-shot wrapper, GitHub Actions macOS job (bootstrap → patch → build unsigned → audit; mirrors `HP:.github/workflows/ios-build.yml` contract), `docs/BUILDING.md`, `docs/INSTALL_IPA.md`, release checklist.
**Accept:** CI green on a clean runner; `REQUIRE_SIGNED=1` rejects the unsigned artifact; IPA SHA-256 published; README claim language matches §4 of the review doc ("built for iPad"; no false firsts).

## 5. Touch control specification

Landscape only. The owner superseded the earlier proportional 12.9-inch
layout on 2026-07-28: SpaghettiPad uses the current HarkinianPad
device-specific layout and settings behavior as its foundation, with a
dedicated compact iPhone arrangement rather than a shrunken iPad overlay. The
iPad layout uses `s = clamp(height/834, 0.78, 1.12)`, low left/right grip rails,
a 150·s fixed-center stick, 106×54·s shoulders, 52·s D-pad buttons, 66·s face
buttons, and a 46·s four-way C diamond. Displays below 560 pt tall use the
Harkinian compact geometry: 116 pt stick, 76×44 pt shoulders, 44 pt D-pad,
52 pt face buttons, and a 40 pt C diamond. Both layouts anchor to the safe
area. They share HarkinianPad's translucent dark styling and N64 accents:
A blue, B green, Start red, C amber. Empty overlay space passes touches through
(`hitTest` returns `nil`). Opacity, per-button hide, and drag-to-customize are
not in v1.

Input delivery: one `SDL_JoystickAttachVirtualEx` virtual game controller created at boot (SDL_GameController-compatible descriptor), buttons/axes set from the UIKit handlers on the main thread; LUS `ControlDeck` maps it as a normal controller. Fallback mode (compile-time flag): post SDL key events per HarkinianPad.

Left rail (steering hand):

| Control | Behavior |
|---|---|
| **Steering stick** | Harkinian fixed-center visual with continuous X/Y output (-32767..32767 virtual → LUS ±85). The game owns its deadzone. Release springs to center. |
| **Z (item)** | Momentary and duplicated on the right; both instances write the same trigger axis. |
| **D-pad** | Four independent buttons for menu navigation and player-count selection. |
| **L** | Momentary shoulder; music-volume cycle in race and Options shortcut on the main menu. |

Right rail (action hand):

| Control | Behavior |
|---|---|
| **A (gas)** | Momentary hold; no invisible hold-to-lock state in v1. |
| **B (brake/reverse)** | Momentary; the Harkinian face cluster keeps A+B reachable by thumb roll for rocket starts. |
| **R (hop/drift)** | Momentary shoulder on the upper grip rail. |
| **Z (right copy)** | Same virtual trigger as the left Z. |
| **C-Up / C-Down / C-Left / C-Right** | Full N64 C-button diamond. SpaghettiKart maps it through the virtual controller's right-stick/button convention; C-Right reaches HUD/map and C-Left reaches look-behind when enabled. |
| **Start** | Red `▶` button for pause and menu confirmation. |

Persistent chrome:
- **`•••` menu button**, always installed even when gameplay controls are
  disabled. It is 38 pt at the iPad safe-area upper right. On iPhone it is
  44 pt, top-center during gameplay and bottom-center while the menu is open
  so it does not cover the compact controls or menu chrome. It posts the
  SpaghettiGui toggle (Escape/F1 equivalent).
- **Mode changes:** opening the ImGui menu hides all gameplay controls and releases every held input (hook: `SpaghettiPad_SetTouchControlsMenuVisible` from the LUS patch); closing restores them iff the persisted **Settings › Controls › Touch Controls** CVar is on. Connecting a physical controller hides the overlay (toast: "Controller connected — touch controls hidden; re-enable in Settings"); disconnecting restores it. Disabling touch controls never strands the user (the `•••` survives).
- **Not in v1:** haptics, layout editor, portrait, second-player touch.

Acceptance checks (Phase 8 gate): 1) the stick, all 15 gameplay buttons,
and persistent menu button render without overlap on 12.9-inch and 11-inch
iPad plus an iPhone-class Simulator; 2) title→player-count→kart→cup→race using
touch only; 3) analog steering sweep produces intermediate `rawStickX` values;
4) hop-drift (hold R + steer) and rocket start (A+B) are executable; 5) item
throw-forward (stick up + Z) works; 6) pause/resume; 7) menu open hides and
releases gameplay controls, close restores; 8) the persisted Controls toggle
works without restart; 9) backgrounding mid-race releases all held inputs; and
10) iPhone gameplay uses its native wide viewport with aspect-aware horizontal
expansion, never a stretched framebuffer.

## 6. Asset pipeline specification

User's first-launch experience:
1. Install SpaghettiPad → launch → app creates its Files-visible container (Info.plist keys from Phase 3).
2. Screen: "**Add your game**. SpaghettiPad needs your Mario Kart 64 (US) ROM in `.z64` (big-endian) format. Open Files → On My iPad → SpaghettiPad and copy it there, then return here." Buttons: **Rescan** (primary), no Exit.
3. User switches to Files (app keeps running; lifecycle gate from Phase 5 keeps it alive), copies ROM, returns, taps Rescan.
4. App scans `Documents/` for `*.z64`, SHA-1s each; on match `579c48e2…`: "Found Mario Kart 64 (US). Extraction takes a few minutes — keep SpaghettiPad open." → runs Torch in-process → `Documents/mk64.o2r` → "Ready to race." On mismatch: names the problem (wrong region / byteswapped `.n64`/`.v64` — with converter hint) → Rescan again.
5. Every later launch: archives found → straight to title. ROM file may be deleted by the user afterward; `mk64.o2r` persists.

Code path behind it (all verified): `GameEngine::Create` (`SK:src/port/Game.cpp:1039`) → `Engine.cpp:348-350` → `CheckMK64O2RExists()` (`SK:src/engine/mods/ModManager.cpp:211-217`, checks `Documents/mk64.o2r`) → patched prompt loop → `GameExtractor::GetRoms` (patched Documents scan) → `ValidateChecksum` (`GameExtractor.cpp:176-186`) → *delete `Documents/torch.hash.yml` + partial `mk64.o2r`* → `GenerateOTR()` (`GameExtractor.cpp:188-202`): `Companion(gameData, ArchiveType::O2R, false, srcDir=GetAppBundlePath() /*= .app resources via LUS patch*/, destDir=GetAppDirectoryPath() /*= Documents*/)`, `SetAdditionalFiles({"meta/mods.toml"})`, `Init(ExportType::Binary)`. Bundle inputs (`yamls/`, `config.yml`, `meta/`, read-only) are staged into the .app by Phase 3 step 8. `spaghetti.o2r` is found via `LocateFileAcrossAppDirs` (`SK:src/port/Engine.cpp:169`) — with the Context patch, the bundle copy is found without copying to Documents. Mods: users drop `.o2r` files (e.g. MK64 Reloaded HD) into `Documents/mods/` via Files (`SK:src/engine/mods/ModManager.cpp:87`) — document as a feature.

## 7. Build, signing, and distribution

- **Configure/build:** CMake `-GXcode`, `-DCMAKE_SYSTEM_NAME=iOS`, `DT`, `-DPLATFORM=OS64|SIMULATORARM64`, `-DSPAGHETTIPAD_SHELL_DIR`, `-DBUNDLE_ID`, signing off for CI (`CODE_SIGNING_ALLOWED=NO`), on for device via `DEVELOPMENT_TEAM` env → `XCODE_ATTRIBUTE_DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE=Automatic`.
- **Entitlements:** none beyond defaults (no JIT, no special capabilities). File sharing is plist-only. Game Center/haptics need nothing.
- **Provisioning:** personal team for development (7-day resign cadence noted in docs); paid team for the release archive. Device install via Xcode Devices window or `xcrun devicectl device install app`.
- **Artifacts:** unsigned IPA via `scripts/package-ios.sh` (zip `Payload/SpaghettiPad.app`, audit first: no ROM, no `mk64*.o2r`, no `.otr`, no `_CodeSignature`/`embedded.mobileprovision` in the unsigned artifact; verify the sorted paths and uncompressed contents of bundled `spaghetti.o2r` against the recorded clean content hash). `REQUIRE_SIGNED=1` mode for a locally signed archive.
- **Distribution:** GitHub release with the unsigned IPA + AltStore Classic/SideStore instructions (adapt `HP:docs/INSTALL_IPA.md`). SideStore source JSON deferred (D12). Every release runs the repo-safety audit; the repo never contains ROM data or extracted assets (enforced by `.gitignore` + `check-repo-safety.sh` + CI, the HarkinianPad triple lock).

## 8. Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | **rebelancap adds iPad polish** (he ships fast; his stack is public) | Medium | Medium — erodes "built for iPad" exclusivity, not split-screen/tilt | Ship Phases 0–8 quickly; the moat is split-screen (Phase 10) + distribution/community, which he demonstrably doesn't do |
| R2 | **Upstream SK moves under the pins** (active repo; Torch bump PR #712 pending with loader-format changes) | High over months | Low-Medium — patches drift | Pins isolate us; rebase deliberately per release; the FMT_CONSTEVAL/vcpkg pin block in `SK:CMakeLists.txt:163-180` documents the Torch-bump coupling — do not bump Torch independently |
| R3 | **Virtual-controller path fights ControlDeck port mapping** (auto-configure claims ports; physical+virtual ordering) | Medium | Medium — input UX | Phase 8 validates early; fallback to HP keystroke bridge is a bounded one-day pivot (D5) |
| R4 | **Split-screen perf on target iPads** (2–4 viewports, interpolation, Metal) | Medium (3P/4P), Low (2P) | Medium — flagship claim | Perf gate in Phase 10 with numbers; ship 2P first; supersampling off in split modes; note ARM64 float-conversion comment at `SK:src/racing/skybox_and_splitscreen.c:311-313` when touching that code |
| R5 | **Extraction edge cases on device** (`torch.hash.yml` trap, partial archives, jetsam during deflate) | Low-Medium | Medium — first-run is the first impression | Phase 7 guards (delete-before-extract, hash pre-gate, retry loop); measure RSS; extraction runs before game heaps |
| R6 | **Watchdog/GPU kills around lifecycle** | Medium until Phase 5 lands | High | Phase 5 is scheduled before device work; HarkinianPad's exact evidence procedure reused |
| R7 | **Audio artifacts at 26800 Hz via SDL/AVAudioSession resample** | Low | Low-Medium | If audible: raise `SampleRate` param match or resample in HMAS mix; decision deferred until heard |
| R8 | **Nintendo attention** (Mario, visible marketing) | Low-Medium | High | Same posture as HarkinianPad: no ROM/asset distribution ever, hash-gated user ROM, no piracy language, unsigned-IPA-only distribution, takedown-compliant |
| R9 | **SK license gap** (no top-level LICENSE) | Static | Medium for redistribution | Source + unsigned IPA only; ask upstream; keep overlay-repo code clearly licensed (pick MIT for our shell/patches) |
| R10 | **Upstream breaks the build** (LUS or SK force-push/vanish — precedent: Sunset-Dawn, sonicdcer) | Low | High | Pins + full local mirrors in `sources/` cache; consider a private mirror remote after Phase 3 |

## 9. Rollback and recovery

- **Phase 0–1:** nothing to roll back; failures are environment issues — fix brew/Xcode, re-run.
- **Phase 2:** if a backport hunk fights `f5c3843`, drop to per-hunk application; worst case pivot to D2 option (a) (bump LUS + mechanical `GetInstance` migration, sized M) — the decision record stays in this doc.
- **Phase 3:** every change is one patch file; `git -C sources/spaghettikart checkout . && scripts/apply-patches.sh` restores a known state. If Ogg/Vorbis FetchContent fights the toolchain, temporary scope cut: compile out SK's vorbis-consuming audio extras (locate consumers first — they're the same dr_libs/HMAS area) and file it in §11.
- **Phase 4–6:** failures here are diagnosable regressions against HarkinianPad's identical milestones; compare its evidence log step-for-step. Simulator failing but device passing (or vice versa) → treat device as truth (HP precedent).
- **Phase 7:** if in-process extraction proves unreliable on device, ship the release with desktop-generated-`mk64.o2r` import (already working from Phase 4/6) and keep extraction behind a flag — a regression to HarkinianPad-parity UX, explicitly acceptable per D4(c).
- **Phase 8:** virtual-controller issues → compile-time fallback to keystroke bridge (kept building in CI from day one).
- **Phase 10:** if 3P/4P misses frame targets, ship 2P only; the claim language ("2-player split-screen") is adjusted before any marketing.
- **Phase 11–12:** tilt or packaging slips never block a release tag; they're additive.
- **Universal:** the repo is scripts+patches+shell — `git revert` of any phase's commit restores the previous phase's green state; upstream checkouts are disposable (`rm -rf sources/ && scripts/clone-sources.sh`).

## 10. Effort estimates (all figures are estimates)

| Phase | Size | Notes |
|---|---|---|
| 0 Scaffolding | S | Adapting HP scripts |
| 1 Oracle + archives | S | Known-good upstream path |
| 2 LUS backport | M | 18-file patch, 9 files with context drift |
| 3 CMake surgery | M–L | The riskiest unknown-unknowns live here |
| 4 Simulator title | S–M | Mostly staging + fixes from 3 |
| 5 Lifecycle/audio | M | HP recipe, new loop site |
| 6 Device boot | S | Signing bureaucracy |
| 7 On-device extraction | M | UI rework + guards + measurement |
| 8 Touch v1 | M–L | New overlay + virtual controller; layout iteration on hardware |
| 9 iPad UX pass | S–M | |
| 10 Controllers + split-screen | M | Mostly testing + port-mapping UX |
| 11 Tilt | S–M | |
| 12 Packaging/CI/docs | M | HP templates cut this down |
| **Total** | **~6–10 engineer-weeks** | Wide band; calibrate after Phase 3, exactly as HarkinianPad's plan did |

## 11. Open questions

1. **Minimum OS floor.** 15.0 chosen (D7); LUS CI proves 14.0 configures. Settled by: Phase 3 build + Phase 6 oldest-device test.
2. **Virtual controller ↔ auto-configure interplay** (who gets port 0; does `ENABLE_EXP_AUTO_CONFIGURE_CONTROLLERS` bind the virtual pad automatically?). Settled by: Phase 8 on-device test; fallback documented.
3. **Split-screen frame rates per device class** (A12X? M1? 3P/4P?). Settled by: Phase 10 captures. Until then, "2-player" is the only public claim.
4. **Extraction wall-clock/RSS on device.** Settled by: Phase 7 measurement (replaces the minutes-order estimate).
5. **26800 Hz resample quality** through SDL/AVAudioSession on iPad speakers. Settled by: Phase 5/6 listening; contingency R7.
6. **`func_800CB2C4()`** (first call in the tick, untraced) — any hidden timing/state assumption relevant to the background gate. Settled by: reading it during Phase 5.
7. **`SDL_HINT_TOUCH_MOUSE_EVENTS` default in this stack** (agent could not find an explicit setting). Settled by: set it explicitly in Phase 8 and test ImGui touch.
8. **Upstream appetite** — would HarbourMasters take these patches (coco875's PR #694 is stalled)? Settled by: asking after Phase 6 produces evidence; affects only where patches live long-term, not this plan.
9. **Final name/branding** (D13) and the exact public claim language (must match review-doc §4 truth tiers). Settled by: owner before first release.
10. **Sunset-Dawn IPA archaeology** — its `Spaghettify` binary could be strings-inspected for approach hints if Phase 3 hits walls. Settled by: only if needed; not a dependency.
11. **In-app texture-pack download** (fetching MK64 Reloaded from its official source on user request, instead of the Safari-plus-Files flow). Convenience vs. the fact that the pack is unlicensed content we'd be programmatically distributing-by-facilitation. Settled by: owner decision after v1 ships with the guided-import flow; if approved, download only from GhostlyDark's official release URLs with an explicit consent dialog.
