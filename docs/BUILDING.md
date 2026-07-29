# Build SpaghettiPad for iOS and iPadOS

SpaghettiPad is a patch overlay over pinned SpaghettiKart, libultraship, and
Torch revisions. Upstream checkouts under `sources/` are disposable build
inputs with push URLs disabled.

## Requirements

- macOS with Xcode and its command-line tools
- [Homebrew](https://brew.sh)
- for physical-device installation: an Apple development team, a unique bundle
  identifier, and a registered iPhone or iPad
- for gameplay after installation: your own legally acquired Mario Kart 64
  US 1.0 big-endian `.z64`

Install the host build dependencies:

```sh
brew install cmake ninja pkgconf sdl2 glew nlohmann-json libpng \
  libzip tinyxml2 libogg libvorbis opus opusfile sdl2_net ripgrep
```

ROMs, `mk64.o2r`, imported texture packs, signing material, apps, and IPAs are
ignored local data. Never add them to Git.

## One-command build

From a clean SpaghettiPad checkout:

```sh
scripts/build-ios.sh --simulator
```

The wrapper fetches the pinned sources, generates the ROM-free
`spaghetti.o2r`, applies the maintained patches, configures Xcode, and builds
the arm64 Simulator app. A ROM is not a build input.

Build the unsigned arm64 device product with:

```sh
scripts/build-ios.sh --device
```

The result is `build-ios/Release-iphoneos/SpaghettiPad.app`. The wrapper audits
its platform, minimum OS, architecture, resources, clean archive content hash,
controller database hash, game-data boundary, and signing state. The content
hash covers every sorted path and its uncompressed bytes while ignoring
Torch's build-time ZIP timestamps.

## Version and identity

The defaults are:

| Field | Value |
|---|---|
| App version | `0.1.0` |
| Build number | `3` |
| Bundle identifier | `com.chrissotraidis.spaghettipad` |
| Minimum OS | iOS/iPadOS 15.0 |

Override them only for a deliberate build:

```sh
SPAGHETTIPAD_VERSION=0.1.0 \
SPAGHETTIPAD_BUILD_NUMBER=3 \
BUNDLE_ID=com.yourname.spaghettipad \
scripts/build-ios.sh --device
```

Versions must use numeric `major.minor.patch` form. Build numbers must be
positive integers.

## Sign for a physical device

Supply the development-team identifier shown in Xcode and a bundle identifier
you control:

```sh
DEVELOPMENT_TEAM=ABCDE12345 \
BUNDLE_ID=com.yourname.spaghettipad \
scripts/build-ios.sh --device
```

If automatic signing needs to register the device or create a profile, open
`build-ios/Spaghettify.xcodeproj`, select the `Spaghettify` scheme and your
device, then confirm the team under Signing & Capabilities.

On the Mac paired with the device, follow the
[physical-device acceptance workflow](HARDWARE_ACCEPTANCE.md) to install the
signed app and capture the Phase 6 ten-minute boot evidence.

Package a clean unsigned developer artifact:

```sh
scripts/package-ios.sh
```

This default command requires an unsigned app and refuses signed input.
Maintainers may explicitly require a valid signature and embedded profile
when packaging a locally signed app:

```sh
REQUIRE_SIGNED=1 scripts/package-ios.sh
```

Both modes reject Simulator products, ROMs, `mk64*.o2r`, `.otr`, a changed
`spaghetti.o2r`, and stale signing material. Signed mode also requires an
unexpired, decodable provisioning profile whose team and application
identifier authorize the signed bundle. The IPA carries the project rights
notice, discovered third-party licenses, and the pinned controller database's
Zlib notice.

The pinned SpaghettiKart revision has no top-level license. An unsigned
artifact solves code-signing portability, not that upstream licensing gap.
Review [RIGHTS_AND_LICENSES.md](../RIGHTS_AND_LICENSES.md) and confirm the
applicable terms with the SpaghettiKart maintainers before redistribution.

## First launch

Launch SpaghettiPad once, then place your legally acquired supported ROM in
the Files-visible SpaghettiPad folder and return to the app. Extraction happens
inside the app container. The generated `mk64.o2r` remains local and is never
part of a build or published IPA.

Physical-device acceptance remains separate from a successful build. See the
[live proof queue](remaining-work.md) for the exact open hardware checks.
