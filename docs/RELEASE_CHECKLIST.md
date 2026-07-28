# SpaghettiPad release checklist

This is the final gate for a public source snapshot or downloadable IPA.

## Every public source update

- [ ] `scripts/check-repo-safety.sh` passes.
- [ ] Every maintained patch replays on the pinned source revisions.
- [ ] `scripts/build-ios.sh --device` produces the arm64 iPhoneOS app.
- [ ] `scripts/package-ios.sh` accepts that app.
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
- [ ] Confirm the only `.o2r` in the app is the hash-pinned,
      ROM-free `spaghetti.o2r`.
- [ ] Confirm `RIGHTS_AND_LICENSES.md` and `ThirdPartyLicenses/` are present.
- [ ] Re-sign and update-install the exact IPA on a physical iPhone and iPad.
- [ ] Replay launch, touch, ROM import, texture-pack import, controllers,
      split-screen, tilt, lifecycle, audio, and save preservation.
- [ ] Record tag, commit, Xcode/SDK versions, app version, build number,
      device/OS matrix, and exact unsigned IPA SHA-256 in release notes.
- [ ] Publish as a prerelease with [INSTALL_IPA.md](INSTALL_IPA.md), known
      limitations, and an explicit statement that no game data is included.

## Before publishing a signed build

- [ ] Use a deliberate distribution identity and fresh profile.
- [ ] `REQUIRE_SIGNED=1 scripts/package-ios.sh` passes on the exact app.
- [ ] Install the packaged IPA on clean physical hardware and complete the
      full acceptance matrix.
- [ ] Never publish certificates, profiles, or other signing material.

## Current blockers

- Physical iPhone/iPad signing, installation, performance, lifecycle, and
  update-preservation validation remain open.
- Two-controller Bluetooth Grand Prix and physical tilt-steering feel remain
  open.
- A real MK64 Reloaded hardware Grand Prix remains open; the pack is never
  bundled or mirrored.

These blockers may be stated as developer-preview limitations, but they must
not be described as passed.
