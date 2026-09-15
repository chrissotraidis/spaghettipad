# Maintained source workflow

The app retains its repository, release URLs, bundle identity and upstream
versions. `sources/spaghettikart` is a pinned Git submodule; its libultraship
and Torch gitlinks form the app source graph. [sources.lock.json](../sources.lock.json)
records the exact repositories, selected commits and upstream bases.

| Component | Upstream base | Maintained change |
|---|---|---|
| [SpaghettiKart fork](https://github.com/chrissotraidis/SpaghettiKart/tree/codex/spaghettipad-ios) | `5b28472d477bab101dee2a0f469fe2aee2c58a01` | Seven existing patches imported as `67bb88c07c4c7c0b769286bc93dc0e39c9caec5c`; later graph commit selects the matching libultraship gitlink |
| [libultraship fork](https://github.com/chrissotraidis/libultraship/tree/codex/spaghettipad-ios) | `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` | Three existing patches imported as `bd9c2dde3f92bb260f49350048c261a02050023f` |
| [Torch](https://github.com/HarbourMasters/Torch) | `2d474ddb8da8b213fbdbb49d0273ce31fa955f35` | Unmodified; directly pinned upstream |

GitHub confirms the two forks' parents as HarbourMasters/SpaghettiKart and
Kenix3/libultraship. The app-specific branches do not change any other app's
pins or the forks' default branches. Existing component notices remain intact.

## Build and update

Run `scripts/clone-sources.sh`, then `scripts/build-ios.sh --device` or
`--simulator`. Normal app configuration checks the lock, gitlinks, URLs,
ancestry, and dirty files; it does not rewrite engine source. On mismatch,
preserve local changes and use a fresh checkout rather than resetting them.
The compatibility `scripts/apply-patches.sh` now only verifies source inputs.

The macOS oracle is preparation tooling, not a shipped Mac app. Its pristine
upstream graph lives separately in ignored `sources/oracle`, created by
`scripts/clone-oracle-sources.sh` when `build-oracle.sh` needs it. This preserves
the old unmodified oracle path while the app uses maintained source.
`generate-port-archive.sh` continues to use private user-supplied game inputs;
never include those inputs or generated playable archives in public source.

To update source, commit the fix on the appropriate app-specific component
branch, preserve upstream authorship/notices, update the selected gitlink and
lock together, and run source checks and affected platform builds. Compare
against the recorded upstream base with `git diff <base> <selected-commit>`.
Propose upstream changes only when explicitly authorized. App-specific or
uncertain controller, graphics and crash reports stay with SpaghettiPad.

## Baseline and validation boundaries

Before migration, clean replay matched 1,599 engine, 424 libultraship and 638
Torch regular source files and modes against the working checkout. The two
import commits also matched those manifests and independently restored from
complete-history Git bundles. Comparisons exclude Git metadata, nested
components (checked separately), and ignored/generated/private outputs.
The selected graph changes `.gitmodules` and the libultraship gitlink only
beyond those imported source bytes. Git-derived version metadata can change;
source parity is not itself proof of generated-output or binary equivalence.

[Historical patches](../patches/README.md) remain for comparison and rollback.
libultraship still carries its upstream ImGui package patch; StormLib's optional
patch is inactive with `INCLUDE_MPQ_SUPPORT=OFF` in the inspected builds.
These are dependency-package exceptions owned by upstream libultraship,
separate from the retired wrapper replay. Full package-patch and generated-output
qualification remains part of migration acceptance.

The oracle downloads a mutable sse2neon header during upstream configure.
The wrapper then restores the already-reviewed revision
`8f03de354e8a87426b94dadd57dbd55b544810c3` in the build directory, verifies unchanged
SHA-256 `44fa833125ba4671b6c2bc0c520f11dbc22f02e9ca223f9d3e04af0db09fcfc6`, and only
then compiles. This app-owned build-input exception fixes the observed clean
build failure without modifying upstream source or upgrading the dependency.

## Source delivery and rights

GitHub's [licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)
and [Terms D.5](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#5-license-grant-to-other-users)
permit viewing and forking public repositories through GitHub. That is the
limited basis for these GitHub-hosted forks. It is not a new open-source
license, a claim that all underlying contributions are cleared, or a grant
for broader binary/commercial/store distribution. Preserve
[RIGHTS_AND_LICENSES.md](../RIGHTS_AND_LICENSES.md); no blanket license is added.
The complete SpaghettiKart licensing question remains documented upstream.

[Preview 4](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.4)
is unchanged: version `0.1.0` build `4`, bundle
`com.chrissotraidis.spaghettipad`, IPA SHA-256
`61cd25268e98d2e638d1d94c5a3486ffb64b81ed4cb572fe60a12c5b97eadf69`.
Its anonymous download passed ZIP integrity and the arm64 unsigned app audit,
with 33 dependency notices. No new release is authorized by this migration.
The existing release has no complete source bundle. GitHub's automatic app
archive omits nested sources; even a recursive component checkout still needs
resolved FetchContent/header/toolchain inputs for offline reproduction.
Do not claim complete source delivery until its archive restoration/build is
verified and its distribution terms reviewed.

## Recovery

The private full-checkout archive restored all 38,454 manifest entries,
including Git history, nested sources, local changes and ignored builds.
It is outside the checkout on the same physical disk, so does not protect
against disk loss. Recovery commands and manifests remain private because
that archive may contain game data and signing-related material.

Rehearse reversal in a disposable clone by reverting the app migration commits
in reverse order and comparing the tracked tree with
`2f7a54ee16a55c5c394c5907e83ab0ad7d3c66e3`. Use the preserved baseline sources;
never reset the owner's working dependencies. No device was accessed by this
migration. Follow [installation guidance](INSTALL_IPA.md) for future in-place
updates; preserve bundle/signing identity and complete durable data. Build and
startup checks do not substitute for the remaining gameplay acceptance.
