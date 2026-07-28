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
its platform, minimum OS, architecture, resources, clean archive hash,
controller database hash, game-data boundary, and signing state.

## Version and identity

The defaults are:

| Field | Value |
|---|---|
| App version | `0.1.0` |
| Build number | `1` |
| Bundle identifier | `com.chrissotraidis.spaghettipad` |
| Minimum OS | iOS/iPadOS 15.0 |

Override them only for a deliberate build:

```sh
SPAGHETTIPAD_VERSION=0.1.0 \
SPAGHETTIPAD_BUILD_NUMBER=2 \
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

Package a clean unsigned developer artifact:

```sh
scripts/package-ios.sh
```

Require a valid signature and embedded profile when packaging a locally signed
app:

```sh
REQUIRE_SIGNED=1 scripts/package-ios.sh
```

Both modes reject Simulator products, ROMs, `mk64*.o2r`, `.otr`, a changed
`spaghetti.o2r`, and stale signing material. The IPA also carries the project
rights notice and discovered third-party licenses.

## First launch

Launch SpaghettiPad once, then place your legally acquired supported ROM in
the Files-visible SpaghettiPad folder and return to the app. Extraction happens
inside the app container. The generated `mk64.o2r` remains local and is never
part of a build or published IPA.

Physical-device acceptance remains separate from a successful build. See the
[live proof queue](remaining-work.md) for the exact open hardware checks.
