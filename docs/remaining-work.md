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
| 8 | Grip-first full-analog touch controls | In progress (Simulator slice passed; hardware GP pending) | Full touch-only GP and analog/menu/lifecycle checks on hardware |
| 9 | iPad UX and imported texture pack | In progress (Simulator UX/import slice passed; hardware pack GP pending) | Touch-complete UX plus Reloaded import/enable/full-GP hardware gate |
| 10 | Controllers and split-screen | In progress (Simulator routing/render slice passed; hardware sessions pending) | Two-controller 2P session and measured 3P/4P decision |
| 11 | Tilt steering | In progress (Simulator slice passed; hardware GP pending) | Persisted, drift-free tilt GP on hardware |
| 12 | Package, CI, docs, release | In progress (local and clean-machine gates passed; CI externally blocked before runner start) | Clean CI, clean-machine replay, audited IPA and SHA-256 |

## Active gate

**Phase 12 GitHub billing/run availability; Phase 6/7/8/9/10/11 owner hardware replay remains separate.**

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
  relaunch behavior, plus the Simulator-valid touch and imported-pack UI
  slices of Phases 8 and 9, plus deterministic controller routing and
  split-screen rendering for Phase 10, plus the persisted CoreMotion-to-stick
  control path for Phase 11. Hardware time/RSS, Files/iPad behavior, sustained
  touch ergonomics, real texture-pack performance, Bluetooth controller
  behavior, split-screen frame time, and a drift-free tilt GP remain owner
  replay items even when their Simulator equivalents pass.
- Simulator evidence does not prove signing, installation, watchdog behavior,
  or audio on physical hardware. Touch, extraction, performance, controller,
  and texture-pack behavior also remain unclaimed on hardware. Local packaging
  proves artifact contents, not device installation or runtime behavior.

## Evidence log

### 2026-07-28 — Phase 6 hardware evidence harness ready; physical run pending

- Remote boundary recheck: `xcrun devicectl list devices --timeout 5` on this
  build Mac reports `No devices found`. The owner's physical iPad remains
  attached to a different local Mac, so no install, launch, rendering, or
  stability result is claimed here.
- Reproducible device gate: `scripts/run-phase6-hardware-smoke.sh` now accepts
  an explicit CoreDevice selector, refuses an unsigned build, records the
  repository/app/Xcode/macOS identity, captures before/after device details,
  installs without deleting the existing container, cold-launches the app,
  and samples the SpaghettiPad process every 30 seconds for a default 600
  seconds. It labels shorter runs diagnostic.
- Evidence boundary: the runner writes CoreDevice JSON/logs, code-signing
  metadata, executable SHA-256, operator title/demo confirmation, and a
  manifest to ignored `ref/evidence/`. Process survival alone is explicitly
  insufficient: Phase 6 still requires the owner to confirm the visible
  title/demo, attach a device screenshot or recording, and enter the reviewed
  device model/OS evidence in this log.
- Signing hardening: `scripts/audit-ios-app.sh` now decodes the embedded
  provisioning profile and signed-app entitlements, rejects an expired
  profile, requires matching team identifiers, requires the code application
  identifier to match the profile prefix plus bundle identifier, and verifies
  that the profile authorizes it. The established unsigned app still passes
  `REQUIRE_UNSIGNED=1`; `REQUIRE_SIGNED=1` rejects it, and an ad-hoc-signed
  test copy with a dummy profile is rejected because the profile cannot be
  decoded.
- Operator handoff: `docs/HARDWARE_ACCEPTANCE.md` provides the exact signed
  build, first-install/Files setup, ten-minute gate, and later Phase 7–11
  sequence. It warns that generated evidence may contain device/signing
  identifiers and must remain ignored.
- CI recheck: run
  [30406005730](https://github.com/chrissotraidis/spaghettipad/actions/runs/30406005730)
  remains an external pre-start failure with zero steps and the unchanged
  GitHub billing/spending-limit annotation.

### 2026-07-28 — Phase 12 clean-machine replay passed; clean CI still externally blocked

- Checkout boundary: a `git clone --no-local` into
  `/tmp/spaghettipad-clean-replay-eb0e026` checked out publication commit
  `eb0e0264b9ad6a7c8977d900ab0ad663cfab1327`. The bootstrap fetched
  SpaghettiKart `5b28472d477bab101dee2a0f469fe2aee2c58a01`,
  libultraship `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1`, and Torch
  `2d474ddb8da8b213fbdbb49d0273ce31fa955f35`, then disabled every upstream
  push URL.
- Reproduction: the fresh tree built the host oracle and ROM-free port archive
  from zero, cleanly applied all eight maintained patch layers, configured
  the iPhoneOS project in 869 seconds, and completed the unsigned arm64
  Release target with `** BUILD SUCCEEDED **`. The fresh executable SHA-256 is
  `70413176cc8e8e427d4b25bbb665c549a109d1ff48e648dd69bc7c0e64788e4d`.
- Reproducibility correction: the first post-build audit correctly exposed
  that Torch writes current timestamps into every ZIP entry, so byte-for-byte
  `spaghetti.o2r` hashes differ across clean builds even when every path and
  payload byte is identical. The established and fresh archives are both
  2,706,468 bytes with 369 entries and 19,658,261 uncompressed bytes; their
  sorted path-plus-uncompressed-content SHA-256 is identically
  `5ab6f5d8898cfdc3e8806b985bf84ec34b2d2968f158ac2e84359e45ff8564a0`.
  `scripts/hash-port-archive.sh` now makes that content digest the maintained
  audit contract while ignoring only build-time ZIP metadata.
- Fresh artifact: the corrected audit passed the clean app as unsigned,
  iPhoneOS 15.0, arm64, ROM-free, and controller-database-pinned.
  `scripts/package-ios.sh` produced an 11,217,754-byte / 292-entry unsigned
  IPA with SHA-256
  `752f8a813d277b7658585803a7dce0383b894b2c6ba24ba14bcbc3c205088533`.
  `unzip -tq` passed; the archive contains the project rights notice and 32
  third-party notices, with no ROM, `mk64*.o2r`, `.otr`, signature, or
  provisioning profile.
- Negative and cleanliness gates: `REQUIRE_SIGNED=1` rejected the fresh
  unsigned app before creating an output. Repository safety passed in both
  the publication checkout and fresh checkout, and the fresh checkout
  remained clean after the complete ignored build/package replay.
- Boundary: the local clean-machine half of Phase 12 is now closed. GitHub's
  hosted runner still must execute the same workflow after the account
  billing/spending-limit block is resolved; physical-device gates remain
  separate.

### 2026-07-28 — Phase 12 local package and documentation gates passed; clean CI pending

- Public build path: `scripts/build-ios.sh --device` replayed the pinned
  sources, ROM-free port archive, maintained patches, generic iPhoneOS
  configuration, unsigned Release build, and bundle audit in one command.
  Xcode 26.6 completed with `** BUILD SUCCEEDED **`; the final arm64 executable
  SHA-256 is
  `e9c4d6e57fbac57f27870a575eb74a493432e3b9da74af72d461efea31bf353c`.
- Bundle audit: the app targets iPhoneOS with a 15.0 minimum, contains both
  iPhone and iPad device families, enables Files sharing, and has no valid or
  stale signing material. The only bundled `.o2r` is the hash-pinned ROM-free
  `spaghetti.o2r`
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`;
  the controller database remains
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
- IPA proof: `scripts/package-ios.sh` produced
  `SpaghettiPad-0.1.0-preview.1-unsigned.ipa`, 11,234,757 bytes / 292 ZIP
  entries, SHA-256
  `3c5048d0ee5bdf5c19012ebe253cffa64b12378f6570c343655678e8d4ef02f9`.
  `unzip -t` passed. The payload has no `_CodeSignature`, provisioning profile,
  ROM, `mk64*.o2r`, or `.otr`; it includes the project rights notice and 32
  discovered third-party license files.
- Negative gates: the audit rejected an iPhoneSimulator bundle by exact
  platform, a changed `spaghetti.o2r`, a rogue `mk64.o2r`, stale signing
  material, contradictory signed/unsigned requirements, and an unsigned app
  submitted with `REQUIRE_SIGNED=1`.
- Public documentation: the README now leads with the live iPad/iPhone product,
  screenshots, tailored controls, widescreen, split-screen, tilt, and
  bring-your-own-assets boundaries. `docs/BUILDING.md`,
  `docs/INSTALL_IPA.md`, `docs/RELEASE_CHECKLIST.md`, and
  `RIGHTS_AND_LICENSES.md` define reproducible build, sideload, release, and
  rights boundaries without claiming a public download.
- Clean-runner attempt: GitHub Actions run
  [30403472162](https://github.com/chrissotraidis/spaghettipad/actions/runs/30403472162)
  was created for commit `738805932ce9102e9a6681bda5d4b34247d9205c`
  but GitHub assigned no runner and executed no steps. Its sole annotation
  reports failed recent account payments or an insufficient spending limit
  and directs the account owner to Billing & plans. This is an external
  pre-start block, not a repository-safety or build failure.
- Boundary: this closes the local Phase 12 build/package slice, not Phase 12
  itself. After GitHub billing/run availability is restored, the workflow must
  reproduce the unsigned artifact on a clean macOS runner. Physical signing,
  installation, runtime, update, and gameplay gates remain open regardless of
  CI.

### 2026-07-28 — Phase 11 tilt-steering Simulator slice passed; hardware GP pending

- Motion path: the iOS shell now samples `CMDeviceMotion.attitude.roll` at
  60 Hz using `CMAttitudeReferenceFrameXArbitraryZVertical`, applies a small
  dead zone and low-pass filter, and maps the calibrated delta to the virtual
  controller's analog left-stick X axis. Tilt is off by default.
- Controls UI: Settings › Controls exposes a persisted Tilt Steering checkbox,
  0.5×–2.0× sensitivity slider, and one-tap Recenter Tilt Steering button.
  `docs/screenshots/ipad-tilt-controls.png` records the default 1.0×/off state,
  SHA-256
  `1827654f7bc8967208ce30fef4d31121fcddb06389ecf7cc8e834cfbdfb01bcd`.
- Input ownership: the on-screen stick wins while held, menu visibility blocks
  motion input, and controller parking leaves tilt unable to write into a
  detached touch controller. Releasing the stick lets the next motion sample
  resume tilt steering.
- Deterministic Simulator proof: launching with the Simulator-only
  `SPAGHETTIPAD_SIMULATED_TILT_DEGREES=15` hook, enabling Tilt Steering, and
  closing the menu produced filtered X values `6245`, `10444`, then `15166`.
  Raising sensitivity from 1.0× to 2.0× through the visible Controls slider
  produced `32767`; the setting was returned to 1.0× afterward.
- Recenter/lifecycle proof: the visible recenter button emitted X `0`; closing
  the menu then calibrated the held angle as center with no subsequent
  non-zero value. Sending the app Home and foregrounding it restarted motion,
  centered at the still-held 15-degree input, and again produced no drift.
- Persistence proof: after terminating and relaunching the process without
  touching Settings, the shell immediately logged simulated tilt enabled,
  centered once, and reproduced the analog ramp. Tilt was returned to its
  default off state after the replay.
- Build and patch proof: the Release arm64 iPhoneSimulator executable SHA-256
  is `bcbd3a2de859794974e336f29a3dff99bfd5d090583d042d2ea82f0e879a1ef5`.
  `patches/spaghettikart-ios-tilt.patch` is 67 lines / 3,281 bytes with
  SHA-256
  `0a61bc4ce654abb600989fed90b1403d7163e640d46eb76d37662f32ec852e99`.
  A fresh local clone passed base → first-run → touch → UX → tilt
  application, `git diff --check`, and reverse-check of the tilt patch.
- Boundary: Phase 11 remains in progress. CoreSimulator cannot prove physical
  sensor orientation, grip comfort, long-session drift, or completion of a GP
  using tilt plus on-screen A/B/R/Z; those remain physical-iPad gates.

### 2026-07-28 — Phase 10 controller routing and split-screen Simulator slice passed; hardware sessions pending

- Controller ownership: on iOS, libultraship now creates default SDL mappings
  for all four N64 ports and assigns recognized controllers in stable SDL
  connection order: first controller to port/player 1, second to port/player
  2, then players 3 and 4. Extra controllers remain ignored. This matches
  SpaghettiKart's fixed `gControllers[i]` to human-player `i` relationship.
- Touch/physical handoff: `ios/SpaghettiPadShell.mm` releases every held input,
  closes and detaches the virtual touch controller, and removes the gameplay
  overlay when a physical controller appears. When no physical controller is
  present, it reattaches the virtual controller and restores touch. The
  persistent `•••` menu control remains available in both modes.
- Simulator realism: CoreSimulator exposes a permanent generic controller
  named `Gamepad`. The iOS controller manager ignores only that exact
  Simulator placeholder, while named pass-through controllers remain
  eligible. A Simulator-only, inert-unless-requested
  `SPAGHETTIPAD_SIMULATED_CONTROLLERS` hook creates up to four virtual test
  controllers; no device-build behavior or release setting is attached to
  that hook.
- Live handoff proof: a second replay started in normal touch mode, logged the
  touch controller on port 1, then attached the same two test controllers
  after a two-second Simulator-only delay. The shell logged the touch
  controller being parked, and the next refresh assigned the new controllers
  to ports 1 and 2. This exercises the actual add-event handoff rather than
  only the two possible startup states.
- Two-controller proof: launching the iPad Pro 11-inch (M4), iOS 18.5
  Simulator `7D6115C9-2ACC-4E72-A53A-3777D50E7037` with
  `SPAGHETTIPAD_SIMULATED_CONTROLLERS=2` logged controller 1 on port 1 and
  controller 2 on port 2 on every refresh. The Files-visible config recorded
  `HasConfig: 1` for ports 1 through 4; port 2 contained 14 N64 button mapping
  groups plus all four left-stick directions. No touch controller appeared in
  the active assignment, and the gameplay overlay was visibly parked.
- Split-screen render proof: the same process entered
  `mk:versus_2p`, selected the `mk:versus_2p` human item table, rendered two
  horizontal viewports, and continued for about 51 seconds before the
  configured automated course cycle advanced. The 2420×1668 evidence image is
  `docs/screenshots/ipad-2p-split-screen.png`, SHA-256
  `a157afb649400b688c2347150a097b836eab8367bee582ac97c71e1f36f6611e`.
  The open settings sheet makes both viewports and the parked touch overlay
  boundary visible; this is routing/render evidence, not a claim that two
  simulated idle controllers completed a race.
- Touch regression: after clearing the test environment and relaunching, the
  placeholder `Gamepad` remained ignored, `SpaghettiPad Touch Controller`
  alone returned to port 1, and the normal touch-mode app remained live.
- Maintained patch: `patches/libultraship-ios-controller-ports.patch` is 108
  lines / 4,289 bytes with SHA-256
  `a213fcae5d77bb529356846cce9339687380bb40e675162acedca576334b658c`.
  A pristine libultraship clone at
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` passed base -> touch ->
  controller-port application, `git diff --check`, and top-patch reverse
  application. `scripts/apply-patches.sh` also recognizes the complete
  already-applied stack.
- Build proof: the final Release arm64 iPhoneSimulator executable SHA-256 is
  `3df1c62174a9c921baf69cea18e0d44caf39b3f0c9d42140c52f4630cefbcfc2`.
  The unsigned Release iPhoneOS build completed with `** BUILD SUCCEEDED **`;
  its ROM-free arm64 audit passed with executable SHA-256
  `b40cc5aad176172ded7af7c02fa751afb77d994c26e4478cb002221c2b9a7f20`,
  clean bundled `spaghetti.o2r`
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`,
  and controller database
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
- Boundary: Phase 10 remains in progress. Only a physical iPad with two
  Bluetooth controllers can close the 2P GP/VS/battle input, reconnect,
  frame-time, and sustained-session gates. Three- and four-player modes must
  then be attempted with measured results to decide whether they ship or are
  explicitly deferred.

### 2026-07-28 — Phase 9 device UX and imported-pack Simulator slice passed; hardware GP pending

- Device-specific menu fit: SpaghettiPad now selects a 2× menu scale for
  iPad and 0.75× for iPhone. The iOS General page puts the optional texture
  workflow first, so `Use Alternate Assets`, `Check Imported Texture Pack`,
  `Texture Pack Files Steps`, and `Get MK64 Reloaded` remain visible on the
  phone's short landscape viewport without relying on scrolling. iPad and
  iPhone screenshots are recorded as `docs/screenshots/ipad-settings.png`
  (2420×1668, SHA-256
  `830b8369d76635786e86f8c48386ef717ec5b4be4d2ae926da33cf25e5df8854`)
  and `docs/screenshots/iphone-settings.png` (2622×1206, SHA-256
  `4da6688d5842031b43944baa384f38ebe23474f4c78312f262651cbb922dbc87`).
- iOS settings cleanup: desktop-only fullscreen, cursor-visibility, Alt-Tab
  assets, file-picker, renderer-backend, match-refresh, jitter-fix,
  windowed-fullscreen, and multi-viewport controls are hidden. Graphics keeps
  the relevant resolution, MSAA, VSync, and texture-filter options and adds
  explicit 30, 60, and 120 FPS (ProMotion) presets.
- Import workflow: the app scans the Files-visible `Documents/mods` directory
  for case-insensitive `.o2r` files, accepts only consistent ZIP archives with
  a root `mods.toml`, and prompts once to enable Alternate Assets. The General
  page also reports a precise no-pack result, explains the Files path and
  HD-first/4K-on-M-series guidance, and opens only the official MK64 Reloaded
  project page.
- Positive/negative proof: the negative detector returned `No texture pack
  found`. A generated ROM-free 232-byte manifest-only `.o2r` with SHA-256
  `036dbc8814ba10f887dfda7c4ba73ea32cae82219469e306b7f77f372693312a`
  triggered `Texture pack found`; choosing Yes persisted
  `gEnhancements.Mods.AlternateAssets: 1`. The setting was restored to off,
  both exact test archives were removed, and relaunch returned to the
  no-pack state. No real texture pack was downloaded, bundled, mirrored, or
  exercised.
- Maintained patch: `patches/spaghettikart-ios-ux.patch` is 254 lines /
  11,441 bytes with SHA-256
  `cfea42612663c80249eab571623905424069d56d531e67a68d4255a4261b2962`.
  `scripts/apply-patches.sh` applies it at the top of the SpaghettiKart stack,
  recognizes an already-patched tree, and requires every earlier patch in
  order. A fresh clone at the exact pin passed base -> first-run -> touch ->
  UX application, reverse-check, idempotent second replay, and
  `git diff --check`.
- Build proof: the final Release arm64 iPhoneSimulator build completed with
  `** BUILD SUCCEEDED **`; its executable SHA-256 is
  `4d57b823388efb8fec0cdbf1fa88dfc88f80c3f06c29455b22059c0f596a4c7e`.
  The same bundle was installed and visually exercised on the disposable
  iPad Pro 11-inch (M4) and compact iPhone Simulators. The iPhone retained its
  native 874×402 widescreen rendering while the adjusted UI exposed the
  complete import workflow. The full unsigned iPhoneOS wrapper also completed
  with `** BUILD SUCCEEDED **` and passed its arm64/ROM-free audit; its
  executable SHA-256 is
  `d5baf2a0be23738b8e713f9fc826583503a01965faadfbafa179aeba3c3bc871`,
  while bundled clean `spaghetti.o2r` remains
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`.
  The shared macOS target rebuilt successfully as an arm64 Mach-O with
  SHA-256
  `166170d41a841a92c1313529a2e49b30a5a13679c210aabd5350899261111275`.
- Public surface: the README now shows the shared app icon, real touch
  gameplay, side-by-side iPad/iPhone settings, current proof boundaries, and
  an accurate user-directed MK64 Reloaded import path.
- Boundary: this closes only the ROM-free Simulator UX and import mechanics.
  Phase 9 remains in progress until the owner imports the real HD pack on a
  physical iPad, confirms one cold relaunch plus a complete Grand Prix, and
  records frame-time/RSS evidence. The 4K pack remains optional and may be
  evaluated only on an M-series iPad after the HD gate.

### 2026-07-28 — Phase 8 Simulator touch and iPhone widescreen slice passed; hardware GP pending

- Implementation: `ios/SpaghettiPadShell.mm` now carries the current
  HarkinianPad-derived, device-specific overlay rather than the discarded
  proportional prototype. iPad uses the low grip rails and scaled 150-point
  fixed-center stick; iPhone uses a dedicated compact layout with a 116-point
  stick, 44-point upper controls, and safe-area-aware top/bottom menu
  placement. Both expose A, B, L, R, duplicate Z, Start, all four D-pad
  directions, and the full four-button C diamond.
- Input path: the overlay attaches one SDL virtual game controller and writes
  true analog axes plus SpaghettiKart's native button mappings. The menu
  button alone retains the Harkinian keyboard event path; a compile-time
  keyboard fallback remains. Quick taps receive only the remainder of a
  50-millisecond minimum hold, while hiding, disabling, or backgrounding the
  overlay releases immediately.
- Maintained patches: `patches/libultraship-ios-touch.patch` is 49 lines /
  1,603 bytes with SHA-256
  `74b849e5daf1cb88096619ce30240937135c7e9ae64ff8e0d50fed32656aa978`.
  It filters touch-generated mouse clicks and reports menu visibility after
  the port's virtual `DrawMenu` override. `patches/spaghettikart-ios-touch.patch`
  is 134 lines / 4,997 bytes with SHA-256
  `ff6f85c9d29704e0d5d9c589115d6064b70ceb18f5812f92c85076e476aa0019`.
  It compiles the Objective-C++ shell, enables controller navigation,
  persists the Touch Controls setting, records Simulator-only input
  telemetry, and selects the shared app icon. `scripts/apply-patches.sh`
  recognizes and replays the complete patch stacks in dependency order.
- Game-level telemetry: direct touches produced Start held/pressed
  `0x1000`, A `0x8000`, B `0x4000`, and C-Right `0x0001`, followed by zero
  held state on release. Held-pointer Simulator input produced raw stick X
  values of 80 and 22 before returning to zero, proving intermediate analog
  values rather than digital extrema.
- Lifecycle proof: A was held at game level (`0x8000`) before the app was
  backgrounded. The resign-active observer emitted its release, and the game
  returned with held/pressed state `0x0000`. Opening the in-game settings
  menu hid and released every gameplay control; closing restored them.
  Settings › Controls exposed the persisted Touch Controls checkbox while the
  always-available `•••` control prevented a disabled overlay from stranding
  the user.
- Device layout proof: the iPad Pro 11-inch (M4), iOS 18.5 Simulator
  `7D6115C9-2ACC-4E72-A53A-3777D50E7037` rendered the full, non-overlapping
  grip layout. The disposable compact iPhone Simulator
  `F07EF5C1-3E0E-45AE-99DE-AE022B0E92D8` rendered its separate layout without
  control overlap or Dynamic Island intrusion, including all four C buttons.
- Native iPhone widescreen: the live Graphics panel reported both viewport
  and internal dimensions as 874×402 (about 2.17:1), with advanced aspect
  forcing disabled. libultraship derives the game viewport from the window
  size and SpaghettiKart's aspect adjustment expands horizontal geometry;
  the live race filled the wide display without scaling a 4:3 framebuffer.
  Enabling a forced ratio retains the renderer's aspect correction rather
  than stretching unless the separate `IgnoreAspectCorrection` option is
  deliberately selected.
- Shared app icon: the original, Nintendo-asset-free spaghetti-track/D-pad
  mark is one opaque universal 1024×1024 source (SHA-256
  `ff669cbfe2d2b11f9f0cc9207d8803d74157cc1cb9fe07c8d25569fe5f2f1a1d`)
  for iPhone and iPad. Xcode emitted `AppIcon60x60@2x.png`,
  `AppIcon76x76@2x~ipad.png`, a 3.8 MiB `Assets.car` (SHA-256
  `dc07c8790b13ea23b47f812c002af88e8c329a8f80e67171f517fa7976f4f968`),
  and matching `CFBundleIcons` / `CFBundleIcons~ipad` metadata. Bundle
  validation passed without asset-catalog warnings.
- Build and replay proof: the Release arm64 Simulator build succeeded; its
  executable SHA-256 is
  `9d6b830057c65f5a2a3779606a6110968938134d92066c57de3a7b097c85ce18`.
  The unsigned Release iPhoneOS wrapper then completed with
  `** BUILD SUCCEEDED **` and its audit accepted an arm64, iOS 15.0,
  iPhone+iPad-family application. The device executable SHA-256 is
  `81fa6a9dc04d7cbe604f7febe44535bc3cdee9f176d70614c139a18cde6c5662`;
  bundled ROM-free `spaghetti.o2r` is
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`;
  and the controller database is
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
  The existing macOS oracle Release target also rebuilt successfully after
  the iOS patch stack, guarding the host path against regression.
  Both differential patches apply and reverse-check after the earlier patches
  in fresh local clones at the exact upstream pins. Root/nested
  `git diff --check`, shell syntax, and the ROM/asset bundle scan pass; no
  ROM, `mk64*.o2r`, `.otr`, or imported texture content exists in the app.
- Boundary: this closes only the reproducible Simulator slice. Phase 8 remains
  in progress until the owner completes a touch-only Grand Prix on physical
  iPad, including rocket start, hop-drift, directed item throw, pause/resume,
  settings cycles, background release, sustained ergonomics, and recorded
  behavior alongside the still-open Phase 6/7 hardware gates.

### 2026-07-28 — Phase 9 texture-pack research narrowed the supported path

- The current realistic visual upgrade is
  [MK64 Reloaded](https://github.com/GhostlyDark/MK64-Reloaded), whose official
  SpaghettiKart release offers an HD `.o2r` around 424 MiB and a 4K `.o2r`
  around 1.15 GiB. The Phase 9 UI will guide a Files copy into `Documents/mods/`,
  detect the archive, and expose SpaghettiKart's Alternate Assets setting.
- Neither the repository nor its release payload carries a redistribution
  license, and the textures derive from Nintendo art. SpaghettiPad must never
  bundle, mirror, or fetch the pack itself; it will link to the
  [official project page](https://evilgames.eu/texture-packs/mk64-reloaded.htm)
  and keep import user-directed. The
  [SpaghettiKart texture-pack guide](https://harbourmasters.github.io/SpaghettiKart/md_docs_2textures-pack.html)
  remains the format reference.
- No complete, maintained, genuinely open-licensed Mario Kart 64 texture pack
  was found. Older Rice-format packs are inactive/unlicensed and require
  conversion, so v1 will support Reloaded HD first, attempt 4K only on an
  M-series physical iPad, and record memory/frame-time measurements before
  adopting any optional texture-memory patch.

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
