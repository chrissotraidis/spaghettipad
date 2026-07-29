# Physical-device acceptance

Simulator results never close SpaghettiPad's hardware gates. Run this workflow
from the Mac that can see the physical iPhone or iPad in Xcode.

## Phase 6: signed install and ten-minute boot

Prerequisites:

- the device is paired, unlocked, and has Developer Mode enabled;
- Xcode can select the device;
- the app's existing Files container already contains your locally generated
  `mk64.o2r`, imported through Files;
- `DEVELOPMENT_TEAM` is your Apple team identifier and `BUNDLE_ID` is a bundle
  identifier that team can sign.

For a first install, run the signed app once from Xcode, import the desktop
`mk64.o2r` through Files, and confirm that it reaches the title screen. The
automated run below installs the same bundle identifier as an update, which
preserves that Files container, then performs the controlled cold-launch gate.

Build the signed device app:

```sh
DEVELOPMENT_TEAM=ABCDE12345 \
BUNDLE_ID=com.yourname.spaghettipad \
scripts/build-ios.sh --device
```

Then run the automated install, cold-launch, and ten-minute process monitor:

```sh
SPAGHETTIPAD_DEVICE="Chris's iPad" \
scripts/run-phase6-hardware-smoke.sh
```

`SPAGHETTIPAD_DEVICE` may be the device name, UDID, serial number, or another
identifier accepted by `xcrun devicectl`. The script refuses an unsigned app,
installs without deleting the existing container, cold-launches the bundle,
checks the process every 30 seconds for at least ten minutes, and saves
CoreDevice JSON, signing metadata, hashes, and a manifest under the ignored
`ref/evidence/` directory.

Watch the device throughout the run. At the prompt, type `YES` only if the
Mario Kart 64 title/demo remained visible and responsive with no watchdog
termination. Save a device screenshot or recording beside the generated
evidence. A process surviving does not, by itself, prove a rendered title
screen.

For a short diagnostic while developing:

```sh
SPAGHETTIPAD_DEVICE="Chris's iPad" \
SPAGHETTIPAD_STABILITY_SECONDS=60 \
scripts/run-phase6-hardware-smoke.sh
```

Any run shorter than 600 seconds is labeled diagnostic and cannot close Phase
6. Never commit the generated evidence directory: it may contain device
identifiers and local signing metadata.

## Later hardware gates

After Phase 6 is reviewed and recorded, continue in plan order:

1. Phase 7: repeat first-run Files extraction on a clean container; record
   extraction wall time, peak RSS, failure recovery, archive hash, and relaunch.
2. Phase 8: complete a touch-only Grand Prix and every touch acceptance check.
3. Phase 9: import MK64 Reloaded HD through Files and verify the complete
   switch cycle by touch. With the pack on, switch it off, accept the
   restart warning, confirm the app closes, relaunch, and capture original
   textures plus `Status: Loaded - currently off`. Repeat in the other
   direction and capture Reloaded plus `Status: Loaded - currently on`.
   Complete a Grand Prix at the Phase 6 baseline; attempt 4K only on an
   M-series iPad.
4. Phase 10: pair two supported Bluetooth controllers before launch and
   verify automatic connection-order assignment. On player 1, check the left
   stick, A, B, Start, L, R, C inputs, and especially left-trigger Z while A
   remains held. Confirm touch parks while hardware is connected. Complete
   controller-only GP, VS, and battle sessions; disconnect and reconnect each
   controller, verify the same player order and restored touch after the last
   disconnect, record a frame-time capture, then attempt 3P/4P.
5. Phase 11: complete a Grand Prix with tilt plus on-screen buttons and verify
   persistence, recentering, and no foreground drift.

Record each result in [`remaining-work.md`](remaining-work.md) with the device
model, OS, exact executable hash, measured values, visible evidence, and a
clear boundary around anything not tested.
