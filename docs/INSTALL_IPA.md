# Install a SpaghettiPad developer preview

SpaghettiPad publishes a ROM-free unsigned developer-preview IPA. It is not
an App Store or TestFlight build.

An unsigned IPA must be re-signed for your own iPhone or iPad with an Apple
development identity or a compatible personal-signing tool. The IPA contains
no Mario Kart 64 ROM, extracted game archive, or texture pack.

## Build or obtain the IPA

Download
[SpaghettiPad 0.1.0 preview 4](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.4)
and verify the IPA against the attached `SHA256SUMS` file before signing it.

To create the artifact from source:

```sh
scripts/build-ios.sh --device
scripts/package-ios.sh
```

The default packager requires an unsigned device app and prints the exact
output path and SHA-256. It refuses signed input unless a maintainer explicitly
uses `REQUIRE_SIGNED=1`. Verify any separately provided artifact against its
published SHA-256 before signing it.

## Install

Use one of these local development paths:

1. Sign and run the app from Xcode using the instructions in
   [BUILDING.md](BUILDING.md), or
2. Re-sign the `-unsigned.ipa` with a compatible sideloading tool that you
   trust, then install it on your device.

Do not install an artifact containing another maintainer's provisioning
profile. SpaghettiPad's public packaging contract is an unsigned IPA intended
to be signed by the person installing it.

After installation:

1. Launch SpaghettiPad once so iOS creates its Files-visible folder.
2. In Files, copy your legally acquired Mario Kart 64 US 1.0 big-endian
   `.z64` into `On My iPhone > SpaghettiPad` or
   `On My iPad > SpaghettiPad`.
3. Return to SpaghettiPad and follow the import screen.
4. Keep the app open while extraction runs.

Maintainers validating a source-signed build should use the
[physical-device acceptance workflow](HARDWARE_ACCEPTANCE.md) to capture
device, signing, launch, stability, and hash evidence without confusing a
successful install with a completed hardware gate.

For an optional texture pack, follow the README's
[texture-pack instructions](../README.md#texture-packs) only after
the base game launches.

## Updates and saves

Install updates with the same bundle identifier and signing identity, without
deleting the existing app first. Back up the SpaghettiPad folder in Files
before updating. Preview signing and sideload tools can expire, fail, or
replace an app container. Preview 4's source-signed build was installed in
place on a physical iPad with the same bundle ID, and post-launch readback
hashes matched the existing game archive, texture pack, saves, config, and
controller/touch preferences. That proof does not guarantee how every
third-party sideloading tool handles updates.

## Preview boundaries

- No jailbreak or JIT is required by SpaghettiPad.
- The user supplies all game data.
- This free, ROM-free community preview follows the documented distribution
  practice of SpaghettiKart and other Harbour Masters ports. It is not a claim
  that the combined project has a single formal open-source license, and it is
  not clearance for paid, commercial, or official-store distribution. See
  [RIGHTS_AND_LICENSES.md](../RIGHTS_AND_LICENSES.md).
- Preview 4 includes the promoted customizable touch-control system plus
  targeted engine-managed SDL2 sleep/disconnect/reconnect reconciliation. It
  preserves valid player slots, releases stale ownership to neutral input,
  returns a sole controller to player 1, and reconciles after foreground resume.
- Customizable controls and gameplay have been exercised on physical iPhone
  and iPad development builds. The exact published Preview 3 payload was
  temporarily re-signed, update-installed, launched, and verified live on a
  physical iPhone without changing the public IPA.
- The controller ownership regression is automated. Physical Bluetooth,
  wired, natural-sleep, full-mapping, touch-overlay handoff, and two-controller
  acceptance remain explicit hardware gates.
