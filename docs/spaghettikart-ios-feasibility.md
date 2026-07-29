# Historical iOS feasibility note

This short record preserves the technical conclusion reached before
SpaghettiPad implementation began. It is historical context, not current
validation or release documentation. The current public status is maintained
in the [README](../README.md#current-validation).

## Conclusion

A native iOS/iPadOS SpaghettiKart integration was feasible using:

- SpaghettiKart's Metal-capable libultraship renderer;
- a native arm64 iPhoneOS application target;
- an iOS lifecycle and audio bridge;
- Files-visible, user-supplied ROM import;
- SpaghettiKart's existing Torch extraction path;
- SDL touch and physical-controller input; and
- pinned upstream revisions with maintained, reviewable patches.

Publicly available iOS SpaghettiKart work predated SpaghettiPad. For that
reason, SpaghettiPad does not claim to be the first SpaghettiKart or Mario Kart
64 port for iOS. Its scope is an iPhone-compatible, iPad-focused integration
with grip-designed touch controls, local multiplayer routing, optional tilt,
and user-imported texture packs.

## Inputs selected for implementation

| Component | Pinned revision |
|---|---|
| SpaghettiKart | `5b28472d477bab101dee2a0f469fe2aee2c58a01` |
| libultraship | `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` |
| Torch | `2d474ddb8da8b213fbdbb49d0273ce31fa955f35` |

The maintained implementation is documented by the build scripts, patches,
[README](../README.md), and chronological
[evidence ledger](remaining-work.md). Those sources supersede estimates and
design assumptions from the original investigation.
