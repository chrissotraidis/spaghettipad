# SpaghettiPad release checklist

This is the final gate for a public source snapshot or downloadable IPA.

## Every public source update

- [ ] `scripts/check-repo-safety.sh` passes.
- [ ] Every maintained patch replays on the pinned source revisions.
- [ ] `scripts/build-ios.sh --device` produces the arm64 iPhoneOS app.
- [ ] `scripts/package-ios.sh` accepts the unsigned app and refuses signed
      input by default.
- [ ] `REQUIRE_SIGNED=1 scripts/package-ios.sh` rejects the unsigned app.
- [ ] README screenshots and control descriptions match the current app.
- [ ] No ROM, `mk64*.o2r`, `.otr`, imported texture, signing material, app,
      or IPA appears in the current tree or Git history.
- [ ] Simulator and physical-device claims remain clearly separated.

## Before publishing an unsigned preview IPA

- [ ] Build from a clean checkout at the tagged commit.
- [ ] Use a deliberate app version and monotonically increasing build number.
- [ ] Build without `DEVELOPMENT_TEAM`, then run `scripts/package-ios.sh`.
- [ ] Confirm the IPA has no `_CodeSignature` or
      `embedded.mobileprovision`.
- [ ] Confirm the only `.o2r` in the app is the content-hash-pinned,
      ROM-free `spaghetti.o2r`.
- [ ] Confirm `RIGHTS_AND_LICENSES.md`,
      `ThirdPartyLicenses/SDL_GameControllerDB.LICENSE`, and discovered
      dependency notices are present.
- [ ] Recheck
      [SpaghettiKart issue #731](https://github.com/HarbourMasters/SpaghettiKart/issues/731)
      and [mk64 issue #474](https://github.com/n64decomp/mk64/issues/474), and
      update the rights notice if upstream has adopted or changed a license.
- [ ] Re-sign and install the exact IPA on at least one supported physical
      device.
- [ ] State every uncompleted physical-device gate in the release notes.
- [ ] Record tag, commit, Xcode/SDK versions, app version, build number,
      device/OS matrix, and exact unsigned IPA SHA-256 in release notes.
- [ ] Publish as a prerelease with [INSTALL_IPA.md](INSTALL_IPA.md), known
      limitations, and an explicit statement that no game data is included.
- [ ] Keep the preview free. Do not treat this checklist as clearance for paid
      access, commercial licensing, App Store/TestFlight, or other
      official-store distribution.

## Before claiming final acceptance

- [ ] Re-sign and update-install the exact IPA on a physical iPhone and iPad.
- [ ] Follow [HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md), then replay
      touch, ROM import, texture-pack import, controllers, split-screen, tilt,
      lifecycle, audio, and save preservation.
- [ ] Confirm the hosted safety and unsigned-build jobs are green.

## Before publishing a signed build

- [ ] Use a deliberate distribution identity and fresh profile.
- [ ] `REQUIRE_SIGNED=1 scripts/package-ios.sh` passes on the exact app.
- [ ] Install the packaged IPA on clean physical hardware and complete the
      full acceptance matrix.
- [ ] Never publish certificates, profiles, or other signing material.

## Current blockers

- Signed development builds have been update-installed and played on physical
  iPad and iPhone hardware. The promoted customizable controls, A-button hold
  assist, safe-area menu placement, texture-pack rendering, and Grand Prix
  play have been exercised on iPhone. The complete ten-minute Phase 6 evidence
  gate remains open. Preview 4's signed source build passed an in-place iPad
  update and exact readback preservation for game data, saves, config, and
  controller/touch preferences.
- Two-controller Bluetooth Grand Prix and physical tilt-steering feel remain
  open.
- MK64 Reloaded HD has been imported and rendered on the physical iPad. Its
  off/on restart-confirmation replay, full hardware Grand Prix, and 4K
  performance attempt remain open; the pack is never bundled or mirrored.
- The initial unsigned preview IPA was built from tagged commit `e0b2da5`,
  audited, temporarily re-signed, update-installed, launched on the physical
  iPad, and published as
  [`v0.1.0-preview.1`](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.1).
  The complete hardware replay matrix remains open.
- Preview 2 corrects third-party notices and makes unsigned packaging the safe
  default. Hosted repository safety and unsigned build/package jobs pass; the
  remaining physical-hardware gates are still open.
- Preview 3 promotes the customizable touch controls to the default, retains
  legacy controls as an option, and carries separate physically tuned phone
  and tablet layouts. Its exact artifact was temporarily re-signed,
  update-installed, launched, and verified live on a physical iPhone, then
  published with its checksum as
  [`v0.1.0-preview.3`](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.3).
- Preview 4 repairs engine-managed SDL2 stale controller ownership without
  restarting SDL or discarding valid player slots. The deterministic regression,
  arm64 Simulator/device builds, signed iPad install/boot, preservation readback,
  and repeatable ROM-free package passed. The unsigned IPA is
  `SpaghettiPad-0.1.0-preview.4-unsigned.ipa` with SHA-256
  `61cd25268e98d2e638d1d94c5a3486ffb64b81ed4cb572fe60a12c5b97eadf69`.
  Physical Bluetooth, wired, natural-sleep, full-mapping, touch-overlay, and
  multi-controller acceptance remain open.

These blockers may be stated as developer-preview limitations, but they must
not be described as passed.
