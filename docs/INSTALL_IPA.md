# Install a SpaghettiPad developer preview

SpaghettiPad publishes a ROM-free unsigned developer-preview IPA. It is not
an App Store or TestFlight build.

An unsigned IPA must be re-signed for your own iPhone or iPad with an Apple
development identity or a compatible personal-signing tool. The IPA contains
no Mario Kart 64 ROM, extracted game archive, or texture pack.

## Build or obtain the IPA

Download
[SpaghettiPad 0.1.0 preview 3](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.3)
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
replace an app container; save preservation is not claimed until the exact
physical-device update gate passes.

## Preview boundaries

- No jailbreak or JIT is required by SpaghettiPad.
- The user supplies all game data.
- Preview 3 includes the promoted customizable touch-control system, separate
  phone and tablet layouts, control move/resize/hide/reset tools, and A-button
  hold assist.
- Customizable controls and gameplay have been exercised on physical iPhone
  and iPad development builds. Exact-payload installation is recorded
  separately in the release notes.
- Long-session stability, controller behavior, performance, and final in-place
  update/save preservation remain explicit acceptance gates.
