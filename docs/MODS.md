# Optional mod candidates

The Mods page is under **••• → Enhancements → Mods**. Packs stay
in the app's Documents/mods folder; they are not included in the IPA or source.
Selections take effect on the next launch. The existing HD selection is preserved.

| Pack / author source | Replaces | Combination rule |
|---|---|---|
| [Ocarina NPC Racers — RoboRich](https://gamebanana.com/mods/701263) | All eight racers | Exclusive with other racer packs; can layer over HD |
| [Child Link](https://gamebanana.com/mods/655866) | Luigi | Conflicts with NPC roster or another Luigi replacement |
| [Kris — sitton76](https://thunderstore.io/c/spaghetti-kart/p/sitton76/Kris_over_Yoshi/) | Yoshi | Conflicts with NPC roster or another Yoshi replacement |
| [Ralsei — sitton76](https://thunderstore.io/c/spaghetti-kart/p/sitton76/Ralsei_with_hat_over_toad/) | Toad | Conflicts with NPC roster or another Toad replacement |
| [MK64 Reloaded](https://evilgames.eu/texture-packs/mk64-reloaded.htm) | Broad HD textures | Base layer beneath character packs |

NPC Racers already uses the current resource paths. The other three original
character downloads use older paths and need conversion; private test copies
have been mapped to this engine's resources. Those copies and their conversion
records are not distributed here. Matching resource paths establishes loader
compatibility, not gameplay acceptance or new redistribution permission.

The selector accepts readable `mods.toml` manifests and supported texture,
model, track or sound replacement paths. Dependencies must target installed
core archives at compatible versions. Optional-mod dependencies are currently
unsupported and shown as unavailable rather than partially loaded.

Overlapping racer slots are exclusive. Broad track-texture packs load first;
a character pack can override their textures. Other shared resource paths are
exclusive. Replacing a file under the same name requires relaunching even if
its switch stays on. Back up saves before experimenting with other authors'
gameplay-changing packs; the selector cannot infer every semantic conflict.

Validation: `scripts/test-mod-selection.sh` tests resource conflict rules.
After fetching build dependencies, `scripts/test-mod-catalog.sh` tests the
actual catalog with synthetic archives, including invalid ZIPs, invalid or
unsupported dependencies, HD preference migration, persistence and load order.
The latter uses a host C++ compiler and libzip via pkg-config. Real private
candidate archives pass the same catalog checks; the owner accepted build 6 on the attached iPhone 14. This does not establish
that every third-party pack works on every supported device.
