# SpaghettiKart on iOS/iPadOS — Feasibility Assessment

**Verdict: Feasible but not recommended. Hard stop #1 (prior art) is triggered: a complete, released, actively distributed iOS port of SpaghettiKart shipped on 2026-07-26 — one day before this investigation — and the original 2026-era iOS build this project believed lost is now publicly mirrored with a downloadable IPA. This project would not be first; it would be third.**

> **Gate revision, 2026-07-28.** After the competitive review ([rebelancap-ports-review.md](rebelancap-ports-review.md)), the project owner revised the premise from "first SpaghettiKart on iOS" to **"the first Mario Kart 64 built for iPad"** — grip-designed iPad touch controls, split-screen multiplayer on one iPad, tilt steering, and a release people can actually find. Under that premise the prior-art hard stop does not bind: both prior IPAs were inspected directly (`UIDeviceFamily [1,2]` but zero iPad-specific design, code, testing, screenshots, or claims; single-digit downloads; no announcement anywhere), upstream press lists PC/Linux/Mac/Steam Deck/Switch only, and no public evidence exists of MK64 ever *running* natively on an iPad. Revised verdict: **feasible and recommended**, and the owner directed the project to proceed. Stage 2 is written to [spaghettikart-implementation-plan.md](spaghettikart-implementation-plan.md). The original verdict above is retained unchanged as the answer to the original premise.

Investigation date: 2026-07-27/28. All repository claims verified against fresh clones or the live GitHub API on that date. Citations are `repo:path:line` or commit SHAs. Per the task's hard-stop rule, Stage 2 (the implementation plan) was not written. Sections D and E below are intentionally abbreviated: the hard stop was confirmed before deep control-design and Torch-internals work, and pushing further would have violated "stop and report immediately." Everything that *was* established is recorded, because most of it was established before the prior-art finding landed.

Trees examined:

| Label | Repo | Revision | Note |
|---|---|---|---|
| `sk` | HarbourMasters/SpaghettiKart | `5b28472d477bab101dee2a0f469fe2aee2c58a01` (main, 2026-07-26) | HEAD at research time |
| `lus` | Kenix3/libultraship | full clone, `origin/main` = `a3f1e102` (2026-06-12), `origin/port-maintenance` = `f57f4d25` (2026-07-26) | |
| `lus-sk-pin` | Kenix3/libultraship | `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` (2026-05-02) | SpaghettiKart's submodule pin, worktree |
| `starship` | HarbourMasters/Starship | `6202c443` (2026-06-15) | |
| `torch` | HarbourMasters/Torch | `b4b75e66` (2026-07-26) | SK pins `2d474ddb` |
| `hp` | ref/harkinianpad | working-copy snapshot | HarkinianPad docs + 6 maintained patches, read in full |

---

## 1. Verdict

**Feasible but not recommended.**

Feasibility itself is not in question — it is *proven by existence*, three times over:

1. **`rebelancap/SpaghettiKart-ios`** — a complete, released iOS + visionOS port of SpaghettiKart. Repo created 2026-07-26T05:01Z, last pushed 2026-07-27T13:12Z (the day of this investigation). Release **v1.0.0, published 2026-07-26T14:55Z**, with two installable artifacts: `spaghettikart-1.0.0-iOS.ipa` and `spaghettikart-1.0.0-visionOS.ipa`. Distribution is live via self-updating SideStore/AltStore sources (`rebelancap/harbourmasters-ports`). The README describes — and the repo's contents corroborate — native Metal rendering, a tunable touch layout, game-controller support, first-launch bring-your-own-ROM import, `.o2r` texture-pack/mod support (MK64 Reloaded), and a stereoscopic 3D mode on Vision Pro. The repo is a patch-overlay build over pinned upstream (the same architecture HarkinianPad uses): **47 maintained patches** under `overlay/patches/` covering exactly the territory this project would have had to cover — `0003-lus-gfx-sdl2-gate-macutils-off-ios`, `0005-lus-context-ios-real-bundle-path`, `0011-lus-ios-no-render-while-backgrounded`, `0012-lus-ios-audio-sdl`, `0013-spaghetti-cmake-ios-app-target`, `0017-spaghetti-autoextract-env`, plus mature performance work (`0034-lus-metal-async-shaders`, `0030-lus-coupled-resource-eviction`, `0035-lus-ios-supersampling`) and a full visionOS stereo layer. An app shell exists at `app/ios/` (`SohIosShell.m`, `SohHostViewController.m`, `SohVisionApp.swift`, complete `Assets.xcassets`).
   Link: https://github.com/rebelancap/SpaghettiKart-ios (release: https://github.com/rebelancap/SpaghettiKart-ios/releases/tag/v1.0.0)

2. **The Sunset-Dawn build is no longer lost.** HarkinianPad's 2026-07-25 research recorded `Sunset-Dawn/SpaghettiKart` release `1.0.0-E` (the first iOS SpaghettiKart, with on-device Torch extraction) as 404 and unverifiable. That is stale: **`rebelancap/HarbourMasters-Sunset-Dawn-iOS-Ports`** (created 2026-07-01) mirrors the final Sunset-Dawn IPAs, and its release `last` carries `SpaghettiKart-iOS-1.0.0-E.ipa` — downloadable today — alongside `Shipwright-iOS-9.2.3-I.ipa`, `2Ship2Harkinian-iOS-4.0.2-F.ipa`, `Starship-iOS-2.0.0-A.ipa`, and `Ghostship-iOS-2.0.0-A.ipa`.
   Link: https://github.com/rebelancap/HarbourMasters-Sunset-Dawn-iOS-Ports

3. **Upstream iOS work is in flight in HarbourMasters/SpaghettiKart itself.** PR #684 ("Add partial iOS support and fix most race-entry crashes", by the now-deleted Sunset-Dawn account, closed 2026-04-21) consolidated the iOS work into a source-only branch; PR #694 ("WIP Ios", coco875, draft, **still open**, head `coco875:ios`, last updated 2026-05-30) continues it, paired with libultraship draft PR #1083 (coco875, open, head `0942619`, updated 2026-04-20).
   Links: https://github.com/HarbourMasters/SpaghettiKart/pull/694 , https://github.com/HarbourMasters/SpaghettiKart/pull/684 , https://github.com/Kenix3/libultraship/pull/1083

The task's stated premise — "The value of this project depends on being first" — does not survive contact with these facts. rebelancap also shipped v1.0.0 iOS/visionOS releases of **the entire HarbourMasters family on 2026-07-26**: `Shipwright-ios` (Ocarina of Time, 01:50Z), `2ship2harkinian-ios` (14:55Z), `Ghostship-ios` (16:17Z), and `Starship-ios` (Star Fox 64, 17:04Z) — so the fallback target evaluated in section G (Starship) is equally taken, and the "shared libultraship fork makes the second port nearly free" thesis has already been executed by someone else, five times in one day.

Scope of verification: repo contents, patch stacks, release assets, timestamps, and distribution sources were verified via the GitHub API. The IPAs were **not** downloaded or run on a device as part of this investigation; "shipped" here means published release artifacts with live distribution channels, not an independently reproduced device test.

**What would change the verdict:** only a reframing of the project's goal. If the goal becomes (a) contributing iOS support to `HarbourMasters/SpaghettiKart` mainline (PR #694 is a draft; nothing is merged upstream; CI still has no iOS job), (b) building a differentiated experience the shipped ports lack (examples worth validating first: split-screen multiplayer on one iPad, CoreMotion tilt steering, App Store-track distribution), or (c) collaborating with the existing ports rather than duplicating them — then a new Stage 1 with that goal would be worth running. As specified, this project should not proceed.

---

## 2. Corrections to the starting facts

Each item was verified against source; everything not listed here checked out as stated.

1. **The WebAssembly premise is stale — WAMR is not in the tree.** `sk:.gitmodules` still declares `lib/wasm-micro-runtime`, but the submodule gitlink was deleted from the tree by commit `d3a3e761c` ("Remove unused submodules (#226)"); at HEAD `5b28472d`, `git ls-tree HEAD lib/` is empty. The integration itself (added by `9cf1f9e1d`, "[Modding] start add wasm integration (#84)") survives only as `sk:src/engine/wasm.cpp` — 246 lines, **every line commented out** — a two-declaration `sk:src/engine/wasm.h`, and commented-out call sites (`sk:src/port/Game.cpp:1038` `// load_wasm();`, `sk:src/main.c:1175` `// call_render_hook();`). No WAMR code is compiled in any configuration. The interpreter/JIT/AOT question is moot.

2. **SpaghettiKart's libultraship pin is closer to HarkinianPad's than the starting facts implied.** `f5c3843` is not merely "on the main lineage, 5 behind main" (true: verified, 5 commits behind `a3f1e102`) — it is also a **direct ancestor of the `port-maintenance` lineage**, sitting exactly 12 commits behind `2bfbde3a` (HarkinianPad's LUS base, 2026-07-21). The two branches have effectively converged: merge-base `f30fe0ed` (2026-05-22) is only 2 commits behind main's tip and 15 behind port-maintenance's tip (`f57f4d25`, 2026-07-26). "main vs port-maintenance" is no longer a meaningful fork split; it is one history with two short tips.

3. **Starship's pin is worse than stated: it is a dangling commit.** `eaaf9d0f` ("Fix metal compatibility with prism (#925)", 2026-03-13) is **not reachable from any branch** of Kenix3/libultraship — a plain clone does not contain it; it is only fetchable by explicit SHA. Its merge-base with main is `#908` (2025-08-07), with main 116 commits ahead of that point (matches the "116 behind" figure). Starship's submodule pin points at an orphaned object that survives only as long as GitHub serves unreferenced SHAs.

4. **The four missing bundle files: confirmed, with sharper provenance.** `Launch.storyboard`, `PoweredBy.png`, `Icon.png`, `plist.in` have never existed at any commit on any branch of Kenix3/libultraship (`git log --all -- ios/` is empty; filename searches across all refs are empty). The stub expecting them was introduced into SpaghettiKart by **KiritoDv** in `a2c3feb67` ("WIP Compilation", 2024-05-01) — the same person who added the original iOS support to libultraship (LUS PR #491, April 2024). Starship's byte-equivalent stub arrived via its own "Added IOS Support" commit (`dc9e2584`). Shared origin confirmed: both are copies of a KiritoDv template (the `dev.net64.game` bundle ID is from KiritoDv's Net64 work). One nuance: `sk:cmake/ios.toolchain.cmake` is a **vendored copy** of leetal's ios-cmake, so that include resolves; what breaks the target is only the four missing `libultraship/ios/` files.

5. **The `copilot/disable-ios-builds-in-ci` branch has not merged.** The iOS CI job is live on both `main` and `port-maintenance` (`build-validation.yml:54`: `cmake -GXcode -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0`).

6. **HarkinianPad's own prior-art finding is stale.** `docs/findings/05-priorart-licensing.md` (2026-07-25) states "No released/working iOS port of Ship of Harkinian (OoT) exists." The Sunset-Dawn mirror (created 2026-07-01) had already published `Shipwright-iOS-9.2.3-I.ipa`, and `rebelancap/Shipwright-ios` shipped v1.0.0 IPAs on 2026-07-26. This does not affect the SpaghettiKart verdict but directly affects the developer's HarkinianPad project and is reported here because it was discovered in the course of this work.

7. **Minor confirmations:** SpaghettiKart defines `F3DEX_GBI=1` (`sk:cmake/SetFlags.cmake:120`), not libultraship's `F3DEX_GBI_2` default — the GBI question in section F was real but is now moot. `USE_OPENGLES` exists, default OFF (`sk:CMakeLists.txt:41`). CI workflow list matches the starting facts exactly (8 workflows, no iOS). `ENABLE_SCRIPTING` defaults OFF at the pin (`lus-sk-pin:CMakeLists.txt:12`) and SpaghettiKart never sets it; the pin commit itself (#1095) *tightened* that gate.

---

## 3. Current state (file/commit granularity)

**HarbourMasters/SpaghettiKart @ `5b28472d` (2026-07-26).** Actively developed (PR #720 merged the day before this investigation). Submodules actually present in the tree: `libultraship` @ `f5c3843f`, `torch` @ `2d474ddb`, `doxygen-awesome-css`, `tools/blender/fast64` (nested). `lib/wasm-micro-runtime` is `.gitmodules`-only vestige (see Correction 1). iOS stub: `CMakeLists.txt:31-37` (`SPAGHETTIKART_IOS`, `PLATFORM "OS64"`, vendored toolchain include, `YOUR_TEAM_ID` / `dev.net64.game` placeholders) and `:118-146` (expects the four nonexistent `libultraship/ios/` files; `MACOSX_BUNDLE`, `plist.in`, `PLATFORM_IOS=1`). The stub cannot produce a build as written. No iOS CI. Bring-your-own-ROM posture: user supplies a `.z64`, the app generates `mk64.o2r` (README:18-39); no ROM or Nintendo-derived data in the repo.

**Kenix3/libultraship.** iOS support at `f5c3843` is real and CI-exercised as a *library*: `cmake/dependencies/ios.cmake`, `cmake/ios-toolchain-populate.cmake`, `SIGN_LIBRARY`/`BUNDLE_ID` options, `__IOS__` branches in 8 files (`src/CMakeLists.txt`, `Fast3dWindow.cpp`, `gfx_metal.cpp`, `gfx_sdl2.cpp`, `Context.cpp`, `MobileImpl.cpp`, `Gui.cpp`, `StatsWindow.cpp`), Metal-only on iOS, SDL2 static, metal-cpp `macOS13_iOS16`. What it lacks at that pin is exactly what HarkinianPad's `libultraship-ios.patch` adds: lifecycle handling, audio pause, CoreAudio-on-iOS exclusion, frame-ready gating, mobile UI scaling, and a scripting hard-block. Known-broken-at-pin items HarkinianPad already diagnosed (CoreAudio link error, macOS-fullscreen link error) apply to `f5c3843` unchanged.

**HarbourMasters/Starship @ `6202c443` (2026-06-15).** Last release v2.0.0 (2025-05-25). LUS pin dangling (Correction 3). Same broken iOS stub, same origin. Lead developer account `sonicdcer` still 404 (verified via API). Star Fox 64 Switch 2 remake released 2026-06-25 remains a takedown-risk aggravator.

**HarkinianPad (ref/).** Six maintained patches over Shipwright `da4e6dc3` + LUS `2bfbde3a` + ZAPDTR + OTRExporter; physical-iPad-verified through Files import, on-device extraction, touch gameplay, saves, and packaging (evidence ledger in `ref/harkinianpad/docs/remaining-work.md`). This was the intended reuse donor; the reuse analysis (section 4) was completed before the hard stop landed and is retained.

**rebelancap ports (the prior art).** See section 1. Additional context: rebelancap's account dates to 2014 with 31 public repos; the ports fleet spans the five HarbourMasters games plus vkQuake/Quake II/III, sm64coopdx, and others, all released or refreshed 2026-07-23 → 2026-07-27, with a shared self-updating SideStore source repo. The SpaghettiKart port self-describes as "100% vibe coded."

---

## 4. Reuse inventory (HarkinianPad → SpaghettiKart)

Completed against the six HarkinianPad patches before the hard stop was confirmed; retained because it documents what a fourth implementation would have reused — and closely matches what rebelancap's patch stack independently converged on (their `0003/0005/0011/0012` correspond to rows 1, 4, 5, 6 below).

| # | HarkinianPad change | Where it lives | Classification | Notes for SpaghettiKart |
|---|---|---|---|---|
| 1 | CoreAudio excluded on iOS (`__APPLE__ && !__IOS__` across `Audio.cpp`/`AudioPlayer.h`), SDL falls through | `libultraship-ios.patch` | **Shared** | Applies to `f5c3843` with context drift: `src/ship/audio/Audio.cpp` is among the 12-commit delta files |
| 2 | `ENABLE_SCRIPTING` → `FATAL_ERROR` on iOS | `libultraship-ios.patch` | **Shared** | Even more moot for SK (no scripting anywhere), still correct defense |
| 3 | STB download SHA-256 pinning | `libultraship-ios.patch` | **Shared** | Applies clean (`common.cmake` unchanged in delta) |
| 4 | `SDL_APP_*` lifecycle cases, synchronous config flush, `mIsBackgrounded`, `IsFrameReady()` | `libultraship-ios.patch` | **Shared** | `gfx_sdl2.cpp` changed in the 12-commit delta; mechanical rebase |
| 5 | `Audio::SetPaused` / `SDLAudioPlayer::SetPaused` + `SDL_HINT_AUDIO_CATEGORY` | `libultraship-ios.patch` | **Shared** | |
| 6 | `WindowIsFrameReady()` C bridge + `GetPixelDepth` frame-ready guards | `libultraship-ios.patch` | **Shared** | Consumer-side gate must be re-sited in SK's game loop (not `graph.c`) |
| 7 | macOS-native-fullscreen carve-outs | `libultraship-ios.patch` | **Shared** | |
| 8 | `GetAppBundlePath()` → real `NSBundle` resource path on iOS | `libultraship-ios.patch` | **Shared** (review) | SK/Torch asset-lookup paths differ from SoH's extractor-XML layout; rebelancap's `0005` confirms the same fix was needed |
| 9 | ImGui/GameOverlay mobile scaling (600-pt compact rule) | `libultraship-ios.patch` | **Shared** | `Gui.cpp`/`GameOverlay.cpp` changed in delta; rebase |
| 10 | Toolchain `PLATFORM` override (simulator builds) | `libultraship-ios.patch` | **Shared** | |
| 11 | Keyboard Enter=Start, iOS mouse A/B/Z defaults | `libultraship-ios.patch` | **Portable** | Binding set is per-game; MK64 wants A=accelerate etc. |
| 12 | `Gui.cpp` → app-shell menu-visibility hook | `libultraship-ios.patch` | **Portable** | Rename + re-point at SK's shell |
| 13 | iOS CMake arm: FetchContent deps, bundle target, signing wiring, pinned gamecontrollerdb | `shipwright-ios.patch` | **Portable** (template) | SK's dependency set differs (yaml-cpp/Torch stack vs Ogg/Vorbis/Opus/libpng); structure transfers, contents do not |
| 14 | `Info.plist.in` (Files sharing, landscape, game-controller keys) | `shipwright-ios.patch` | **Portable** | Near-verbatim template; per-game identity |
| 15 | `SDL_main` gate in `main.c`, `WindowIsFrameReady()` loop gate | `shipwright-ios.patch` | **Portable** | SK's entry point/loop live elsewhere (`src/main.c`, `src/port/Game.cpp`); same pattern |
| 16 | Networking compile-out (`SOH_DISABLE_NETWORKING`) | `shipwright-ios.patch` | Ocarina-specific | SK has no Anchor/Sail/CrowdControl equivalent |
| 17 | UIKit touch overlay (16 buttons + stick posting SDL scancodes) | `shipwright-ios-touch-controls.patch` | **Portable** (pattern) | Mechanism transfers; the *layout* is OoT-shaped. MK64 needs a driving layout (steer/accel/brake/hop/item) — new design work |
| 18 | First-run Files-import UX (device-aware, non-quitting, Rescan) | `shipwright-ios-first-run.patch` | **Portable** (pattern) | SK's first-run flow is Torch-based, different code path; UX contract transfers |
| 19 | Asset catalog / app icon wiring | `shipwright-ios-app-icon.patch` | **Portable** | |
| 20 | ZAPDTR link-option fixes | `zapdtr-ios.patch` | **Ocarina-specific** | SK uses Torch; no transfer |
| 21 | Build/package/audit scripts, ROM-exclusion audit, CI job | HarkinianPad scripts | **Portable** | Swap `oot*.o2r` guards for `mk64.o2r` |

**The four missing bundle files:** HarkinianPad answers this concretely — it produced equivalents (`soh/ios/Info.plist.in`, `Assets.xcassets`; no separate `Launch.storyboard` proved necessary) and put them **in the game repo's app shell, not in libultraship**. LUS draft PR #1083 reaches the same conclusion (it relocates `Launch.storyboard`/`plist.in` to the port side), and rebelancap's port keeps them in `app/ios/`. Three independent implementations agree: the correct fix for SpaghettiKart's stub is to stop pointing `IOS_DIR` at `libultraship/ios/` and supply per-app files — which also answers "does one fix serve both SpaghettiKart and Starship": the *pattern* serves both; the files are per-game.

---

## 5. Blockers

1. **Prior art — HARD STOP, triggered.** Full evidence and links in section 1. This is the sole reason for the "not recommended" verdict.

2. **WebAssembly/JIT — HARD STOP, cleared.** Called out explicitly per the brief: SpaghettiKart compiles **no** WAMR code in any mode (interpreter, JIT, or AOT) — the submodule gitlink is gone from the tree and the only integration file is 100% commented out (Correction 1). libultraship's `ENABLE_SCRIPTING` (the TinyCC path) defaults OFF at the pin, SpaghettiKart never enables it, and the pin commit itself further gated scripting code. No `PROT_EXEC`/`MAP_JIT`/writable-executable memory exists in the shipped configuration. An iOS build should still add HarkinianPad's `FATAL_ERROR` guard (reuse row 2) as a defense against future re-enablement.

3. **ROM data — HARD STOP, cleared.** SpaghettiKart's repo contains no ROM or Nintendo assets; the model is user-supplied `.z64` → on-device/desktop-generated `mk64.o2r` (`sk:README.md:18-39`). Enforcement for a port repo is the already-proven HarkinianPad pattern: gitignore + package-audit scripts that reject `.z64/.n64/.v64/mk64*.o2r` in tree, app bundle, and IPA, replayed in CI.

4. **Non-stop blockers that were live before the verdict** (recorded for completeness): the four missing bundle files (solved pattern, section 4); the 12-commit LUS rebase (9 of the 18 files touched by `libultraship-ios.patch` changed between `f5c3843` and `2bfbde3` — small, mechanical); Torch-on-device feasibility — **answered affirmatively by two shipped implementations** (Sunset-Dawn's release notes describe on-device `mk64.o2r` generation with a fullscreen async setup UI; rebelancap's `0002-torch-external-mk64-only.patch` + `0017-spaghetti-autoextract-env.patch` show Torch statically compiled into the app with only the MK64 backend enabled).

---

## 6. Target comparison (SpaghettiKart vs Starship)

Moot as a "which do we port first" decision — **both are already shipped** by rebelancap (v1.0.0 IPAs for each, 2026-07-26), and both had Sunset-Dawn predecessors now mirrored. The data gathered before that finding, for the record:

1. **Engineering cost:** SpaghettiKart decisively cheaper. Its LUS pin (`f5c3843`, 2026-05-02) is on the live shared lineage, 12 commits from HarkinianPad's patch base — a fast-forward bump or a light rebase. Starship's pin (`eaaf9d0`, 2026-03-13) is a dangling commit ~10 months of API drift behind, reachable only by SHA (Correction 3), so its LUS must be bumped across a far larger delta before any HarkinianPad engine work applies.
2. **Upstream health:** SpaghettiKart clearly healthier — commits within 24 hours of this investigation, PRs in the 700s, an open first-party iOS PR (#694). Starship: last commit 2026-06-15, last release 2025-05-25, lead developer's account deleted (README credits now point at 404s). Six-month maintenance odds favor SpaghettiKart strongly; Starship's are genuinely uncertain.
3. **Touch suitability:** Mario Kart 64 is the better touch game — kart steering tolerates a discrete/tilt-assisted input model far better than Star Fox 64's continuous all-range flight, and MK64's inputs (steer, A-throttle, B-brake, Z-item, R-hop, C-camera) map onto fewer simultaneous touch targets than SF64's stick+boost/brake+bank+fire cluster. (Analysis performed at the design level; the code-level derivation of section D was cut short by the hard stop.)
4. **Legal exposure:** Starship is strictly worse right now: Nintendo shipped a Star Fox 64 remake on Switch 2 on 2026-06-25, and takedown history across the ecosystem correlates with commercial adjacency. Mario Kart 64 has no 2026 re-release, though Mario is Nintendo's most-defended franchise generally. Both repos are asset-clean.
5. **Shared-fork leverage:** validated in the strongest possible way — rebelancap's shared patch stack shipped five games in one day. Had this project proceeded, the same leverage argued for doing the LUS-layer work once against the `port-maintenance` lineage; that conclusion transfers to any future reframed effort.

A third libultraship-family target is not better than either: the other family members (Shipwright, 2ship, Ghostship) are equally covered by the same shipped fleet.

---

## 7. Open questions

1. **Is collaboration the better move?** rebelancap's ports are patch-overlay repos with LICENSE files, active pushes, and a distribution channel already serving users. Whether the developer's goals (and HarkinianPad's) are better served by contributing (e.g., iPad-specific UX, tilt steering, split-screen) than by competing is a product/strategy question only the developer can answer. Resolve by: reading `rebelancap/SpaghettiKart-ios` in depth and contacting the maintainer.
2. **Quality of the shipped port on iPad specifically.** Not assessed — no IPA was installed. The README's framing is iPhone/Vision Pro-first (iPad is covered by the SideStore source but not showcased). If the shipped port is weak on iPad, "best-on-iPad" is a possible differentiation angle. Resolve by: sideloading v1.0.0 on an iPad and evaluating.
3. **Upstream mainline status.** Nothing iOS has merged into HarbourMasters/SpaghettiKart; PR #694 is a stale-ish draft (last update 2026-05-30). Whether upstream wants a finished contribution is unknown. Resolve by: asking in the PR/Discord.
4. **Section D at code level** (exact input constants, Controller Pak/ghost-data handling, rumble plumbing in `sk:src/`) and **section E at Torch-internals level** (memory envelope, NAudio path, archive layout) were deliberately not completed after the hard stop. Two shipped implementations plus Sunset-Dawn's release notes answer the feasibility-grade versions of both; the implementation-grade versions belong to whatever reframed project follows, if any.
5. **Durability of the prior art.** Sunset-Dawn's original repos vanished once already; rebelancap's could too (single-maintainer risk, Nintendo attention risk). If the entire fleet disappeared *and stayed gone*, the first-mover premise would partially revive — though the mirrored IPAs and upstream PRs make a true void unlikely. Resolve by: nothing to do now; re-check if this project is ever revisited.

---

## Appendix: verification ledger for the prior-art claim

| Claim | Evidence | Checked |
|---|---|---|
| SpaghettiKart iOS shipped | `rebelancap/SpaghettiKart-ios` release v1.0.0, assets `spaghettikart-1.0.0-iOS.ipa` / `-visionOS.ipa`, published 2026-07-26T14:55:30Z | GitHub API, 2026-07-27 |
| Substantially built, not a stub | 47 patches in `overlay/patches/` incl. lifecycle, audio, bundle-path, extraction, Metal perf, visionOS stereo; `app/ios/` Obj-C/Swift shell; screenshots; VERSION/scripts/CI | GitHub API tree listing |
| Actively distributed | SideStore/AltStore source repo `rebelancap/harbourmasters-ports` (pushed 2026-07-27); "Refresh the SideStore sources on release" commit 2026-07-27T13:12Z | GitHub API |
| Original prior art accessible again | `rebelancap/HarbourMasters-Sunset-Dawn-iOS-Ports` release `last` incl. `SpaghettiKart-iOS-1.0.0-E.ipa` | GitHub API |
| Whole family covered | v1.0.0 releases with IPAs: Shipwright-ios, 2ship2harkinian-ios, Ghostship-ios, Starship-ios (all 2026-07-26) | GitHub API |
| Upstream iOS in flight | HarbourMasters/SpaghettiKart PR #694 (open draft, coco875), PR #684 (closed, ghost); Kenix3/libultraship PR #1083 (open draft, coco875) | GitHub API |
| Sunset-Dawn account gone | `users/Sunset-Dawn` → 404 | GitHub API |
