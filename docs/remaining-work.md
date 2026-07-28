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
| 2 | Patched libultraship iOS static library | In progress | arm64 iPhoneOS library, symbol audit, patch replay, macOS regression build |
| 3 | Full unsigned iOS app links | Pending | iPhoneOS app, platform/min-OS/bundle audit |
| 4 | Simulator title screen | Pending | Live Metal frame, logs, screenshot, no desktop dialog symbols |
| 5 | Lifecycle and audio | Pending | Three-cycle continuity, config flush, paused simulation, audible resume |
| 6 | Signed physical-iPad boot | Pending | Signed install, title screen, ten-minute stability run |
| 7 | On-device Files extraction | Pending | Clean-device extraction, failure recovery, measured time/RSS |
| 8 | Grip-first full-analog touch controls | Pending | Full touch-only GP and analog/menu/lifecycle checks on hardware |
| 9 | iPad UX and imported texture pack | Pending | Touch-complete UX plus Reloaded import/enable/full-GP hardware gate |
| 10 | Controllers and split-screen | Pending | Two-controller 2P session and measured 3P/4P decision |
| 11 | Tilt steering | Pending | Persisted, drift-free tilt GP on hardware |
| 12 | Package, CI, docs, release | Pending | Clean CI, clean-machine replay, audited IPA and SHA-256 |

## Active gate

**Phase 2 — backport the maintained libultraship iOS patch and build the
arm64 iPhoneOS static library without regressing the macOS oracle.**

Expected:

1. `patches/libultraship-ios.patch` applies to pristine libultraship
   `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1`.
2. The Xcode iPhoneOS build produces an arm64 `libultraship.a`.
3. The iOS product contains no `toggleNativeMacOSFullscreen` or
   `CoreAudioAudioPlayer` references.
4. Reverse-apply and pristine-replay checks pass, and the patched source still
   builds the macOS oracle.

Boundary:

- Phase 1 proves the pinned desktop baseline, clean port archive, local
  ROM-derived archive, and title screen only.
- No iOS library/app, Simulator, device, lifecycle, audio, touch, extraction,
  performance, controller, texture-pack, or package behavior is claimed yet.

## Evidence log

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
