# Source-maintenance handoff

Checked 2026-09-15 against `chrissotraidis/spaghettipad` main
`2f7a54ee16a55c5c394c5907e83ab0ad7d3c66e3`.

The production build still replays patches. Migration is **not complete**.
The immediate boundary is the unresolved grant for the complete SpaghettiKart
source; see [Rights and licenses](../RIGHTS_AND_LICENSES.md). No new engine
fork, license, binary release, or hardware acceptance is asserted here.

## Components and build paths

| Component | Upstream and immutable base | Effective integration |
|---|---|---|
| SpaghettiKart | [HarbourMasters/SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart) at `5b28472d477bab101dee2a0f469fe2aee2c58a01` | Seven wrapper patches; no top-level license at this pin |
| libultraship | [Kenix3/libultraship](https://github.com/Kenix3/libultraship) at `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` | Three wrapper patches; MIT license retained |
| Torch | [HarbourMasters/Torch](https://github.com/HarbourMasters/Torch) at `2d474ddb8da8b213fbdbb49d0273ce31fa955f35` | Unmodified pinned source; MIT license retained |

The app repository is standalone on GitHub. Its identity and release URLs
remain unchanged. Dependencies live in ignored `sources/spaghettikart`, with
libultraship and Torch nested underneath. These are prepared working sources,
not maintained downstream commits or public source bundles.

- `build-ios.sh` → `configure-ios.sh` → `apply-patches.sh` builds the shipped
  arm64 iPhoneOS app and the development arm64 Simulator app. Both compile the
  same prepared engine and libultraship, plus tracked `ios/` shell files.
- `build-ios-lus.sh` also replays the wrapper patches for its library-only check.
- `build-oracle.sh` requires the **unmodified** engine tree and builds the macOS
  oracle/GenerateO2R tooling. This is a preparation path, not a shipped Mac app.
  `generate-port-archive.sh` handles privately supplied game inputs; preserve
  its game-material boundary and deterministic archive checks.
- Torch and CMake FetchContent dependencies are further build inputs. Do not
  equate the three top-level pins with a complete offline source graph.

libultraship's `cmake/dependencies/common.cmake` also applies
`imgui-fixes-and-config.patch` to ImGui `v1.91.9b-docking`. Its optional
`stormlib-optimizations.patch` targets StormLib `v9.25`; the inspected device,
Simulator and oracle caches all have `INCLUDE_MPQ_SUPPORT=OFF`. These are
upstream dependency-package patches, separate from the ten wrapper patches.
Any retained exception needs a documented owner, purpose and validation when
the migration is implemented. Ordinary builds also fetch tag-based dependencies
and raw headers; record resolved commits and bytes before claiming offline
reproducibility. Optional documentation/Blender submodules are not initialized
by the wrapper bootstrap and are not current app build inputs.

## Verified baseline

Fresh local clones at the three base pins accepted all ten patches in the
existing script order. Comparison against the existing working sources matched
file content and modes for 1,599 engine, 424 libultraship and 638 Torch files.
The comparison covers tracked and non-ignored untracked regular source files;
it excludes Git metadata, nested components (compared separately), and ignored
generated/private outputs. It is source parity, not a new build or output-parity
claim. The controller slot regression and repository safety checks passed in
the isolated app clone. The original checkout's unrelated untracked guide was
preserved and excluded from this documentation change.

The anonymously downloaded [Preview 4 IPA](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.4)
matched SHA-256
`61cd25268e98d2e638d1d94c5a3486ffb64b81ed4cb572fe60a12c5b97eadf69`.
ZIP integrity passed: 293 entries, 33 dependency notices, version `0.1.0`, build
`4`, bundle `com.chrissotraidis.spaghettipad`, minimum OS `15.0`, no provisioning
profile, and only the bundled `spaghetti.o2r` archive. The release has an IPA
and checksum file, without a corresponding-source asset or source-bundle link
in its body. The automatic wrapper archive omits ignored engine and nested
FetchContent sources. Source delivery has **not** been qualified.

No device was accessed in this audit. Earlier release hardware evidence and
its explicit limitations remain in [Hardware acceptance](HARDWARE_ACCEPTANCE.md)
and the release notes. No new build, installation or gameplay test is claimed.

## Bounded implementation plan

1. Resolve/document the applicable grant for the complete selected engine and
   the intended terms for original integration code. On 2026-09-15 the live
   GitHub API reports [issue 731](https://github.com/HarbourMasters/SpaghettiKart/issues/731)
   closed, but its comments still point to the earlier decomp consent discussion;
   no top-level license is present at the selected pin or current upstream root.
   Closure alone does not supply the missing grant. Do not blanket-license code
   or treat general owner authorization as third-party permission.
2. Once that boundary is resolved, use upstream-connected per-app branches for
   the engine and modified libultraship, preserving history and these exact base
   versions. Keep Torch directly pinned upstream. Verify actual GitHub parent
   metadata before selecting forks; no fork has been selected by this audit.
3. Import the seven engine patches in order: `ios`, `ios-firstrun`, `ios-touch`,
   `ios-ux`, `ios-tilt`, `ios-texture-packs`, `ios-custom-touch`. Import the three
   libultraship patches in order: `ios`, `ios-touch`, `ios-controller-ports`.
   Record each replacement commit and compare file bytes/modes before changing
   bootstrap. Preserve the separate unmodified oracle path.
4. Replace production replay with exact maintained pins and clear dirty-input
   failures. Update CI caches, source checks, notices and provenance together.
   Keep historical patches until all source and generated-output comparisons
   pass; do not silently update another app's libultraship pin.
5. Assemble and restore a rights-reviewed source bundle including required
   nested inputs, resolved FetchContent sources, build scripts and notices.
   Rebuild device and Simulator targets and compare deterministic outputs.
   Qualify package identity separately from physical gameplay. A new release
   requires separate release authorization.

## Recovery and contribution routing

A private full-checkout archive includes Git history, nested working sources,
local changes, ignored builds and existing packages. Its restoration manifest
and recovery commands are retained outside the checkout; it is on the same
physical disk and is not protection against disk loss. Private archives must
never be uploaded as public corresponding source: they can contain game inputs,
local profiles and other restricted material.

The build-script correction restores the oracle header already named by its
existing checksum; engine/app sources remain unchanged. The documentation-only
checkpoint was rehearsed separately. To rehearse its reversal, clone the app
into a disposable directory, check out the documentation commit, and run
`git revert --no-edit <documentation-commit>`. Verify `git diff --exit-code 2f7a54ee16a55c5c394c5907e83ab0ad7d3c66e3 --` there. Never reset the owner's working
dependencies to reproduce that test. Follow [installation instructions](INSTALL_IPA.md)
for an in-place update; retain the existing bundle/signing identity and durable
app data, and stop if those identities do not match.

File app-specific build, controller, graphics and crash reports in this app's
issue tracker with the app version, dependency pins and useful sanitized logs.
Route upstream only when evidence identifies an upstream issue; this audit does
not authorize contacting upstream maintainers.

## Oracle download correction

The first hosted check of this handoff failed before compilation because
upstream CMake unconditionally downloads sse2neon from `master`. The existing
oracle checksum rejected those changed bytes. `build-oracle.sh` now restores
the already-reviewed revision `8f03de354e8a87426b94dadd57dbd55b544810c3` into the
build directory after configure and before compilation, checking the unchanged
SHA-256 `44fa833125ba4671b6c2bc0c520f11dbc22f02e9ca223f9d3e04af0db09fcfc6`.
The immutable download was independently verified against that checksum.
This is a build-input restoration exception, owned by the app build scripts;
it does not modify upstream source or upgrade the oracle. The checksum gate
must remain, and a complete future source bundle must carry these exact bytes.
