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
- [ ] Re-sign and install the exact IPA on at least one supported physical
      device.
- [ ] State every uncompleted physical-device gate in the release notes.
- [ ] Record tag, commit, Xcode/SDK versions, app version, build number,
      device/OS matrix, and exact unsigned IPA SHA-256 in release notes.
- [ ] Publish as a prerelease with [INSTALL_IPA.md](INSTALL_IPA.md), known
      limitations, and an explicit statement that no game data is included.

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

- A signed development build has been update-installed and played on a
  physical iPad with its app data preserved. The complete ten-minute Phase 6
  evidence gate, final update/save-preservation replay, and all physical
  iPhone checks remain open.
- Two-controller Bluetooth Grand Prix and physical tilt-steering feel remain
  open.
- MK64 Reloaded HD has been imported and rendered on the physical iPad. Its
  off/on restart-confirmation replay, full hardware Grand Prix, and 4K
  performance attempt remain open; the pack is never bundled or mirrored.
- The initial unsigned preview IPA was built from tagged commit `e0b2da5`,
  audited, temporarily re-signed, update-installed, launched on the physical
  iPad, and published as
  [`v0.1.0-preview.1`](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.1).
  The physical iPhone install and the complete hardware replay matrix remain
  open.
- Preview 2 corrects third-party notices and makes unsigned packaging the safe
  default. It does not convert any remaining hardware or hosted-CI gate into a
  pass.

These blockers may be stated as developer-preview limitations, but they must
not be described as passed.
