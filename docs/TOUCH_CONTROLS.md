# Touch controls

The customizable touch controller is SpaghettiPad's default on iPhone and
iPad. The original fixed overlay remains available through **Settings >
Controls > Legacy Touch Controls**.

## Customize the layout

1. Open **Settings > Controls**.
2. Leave **Touch Controls** enabled.
3. Leave **Legacy Touch Controls** disabled.
4. Select **Customize Touch Layout**.

The native editor closes Settings and shows every control over the game:

- drag a control to move it;
- select a control and use **Size** to scale it from 70% to 150%;
- use **Hide** for controls that are not needed;
- use **Reset** to restore the default layout;
- use **Done** to save and return to play.

Phone and tablet layouts are stored separately in the app container. Layouts
saved by the earlier experimental build migrate automatically. Hidden controls
remain faintly visible in the editor so they can always be selected and
restored. Steering cannot be hidden, and the menu button remains fixed so the
layout cannot strand the user outside Settings.

The tablet defaults use the layout physically accepted on a 12.9-inch iPad
Pro: A is 111%, the steering-side Z is 124%, the left cluster follows the
steering grip, and the right face/shoulder controls are grouped for racing.
Normalized positions adapt that arrangement to other iPad sizes.

The phone defaults use the layout physically tuned during a Grand Prix on an
iPhone 14: the steering-side L/Z pair and stick are enlarged, the racing
buttons form a lower-right thumb cluster, and the C controls remain above that
cluster. The fixed menu respects the landscape safe area, with Start directly
underneath it.

## A hold assist

During a race, hold **A** for 0.65 seconds and then lift your finger to keep
accelerating. A short haptic and the `A •` label indicate that it is held.
Tap A again to release it.

The assist is intentionally limited to A:

- **Z always remains momentary** because it uses items;
- **R always remains momentary** because it jumps and power-slides;
- all other buttons retain their existing press/release behavior.

A is force-released when the race ends, Settings opens, the app backgrounds,
a physical controller takes over, touch controls are disabled, or Legacy
Touch Controls is enabled.

## Legacy controls

Enable **Legacy Touch Controls** to restore the original fixed overlay.
Customization and A hold assist are unavailable in legacy mode. Disabling the
toggle returns to the saved customizable layout.

## Validation boundary

- Compact-phone and 11-inch iPad layouts have been inspected at full
  screenshot resolution, including visible gaps between adjacent controls.
- The editor's Hide, Reset, and Done behavior has been exercised in the iPad
  Simulator.
- On a physical 12.9-inch iPad Pro, layout movement, A and Z resizing, hiding
  controls, returning to a live race, engaging A hold assist, and tapping A to
  release it were exercised successfully on 2026-07-29.
- On a physical iPhone 14, the customizable controls, A hold assist, texture
  pack, and Grand Prix play were exercised successfully on 2026-07-29. The
  safe-area menu correction and promoted phone default still require a final
  device recheck.
- A full touch-only Grand Prix remains open.
