# Experimental iOS game module

This developer command compiles the pinned game sources into a private arm64 iOS
module using LLVM and separately prepared open-source C/C++ headers. It is a
prerequisite for PadMint's Windows/Linux build route, not an IPA builder. The
normal player installation instructions and supported-host declarations do not
change.

The runtime application still needs an Apple SDK build. The module needs a
matching runtime that exports its imported APIs, bundle signing and actual device
validation. An unresolved-import dylib link alone does not establish compatibility.
Do not publish the generated game module or package it as a public runtime asset.

## Inputs

`scripts/ios-game-module.json` records the complete 282-file game source list and
compiler flags for the exact engine commit in `sources.lock.json`. The command
requires a clean Git checkout at that revision. The source list corresponds to the
maintained CMake selection, including its current exclusion behavior. Review and
update the manifest when the engine pin changes.

Pass explicit paths for:

- `--source`: that clean engine checkout.
- `--runtime` and `--torch`: the exact source revisions in `sources.lock.json`.
- `--dependencies`: prepared dependency source/generated-header directories using
  the maintained CMake layout (`nlohmann_json-src`, `libzip-build`, and so on).
- `--imgui`: maintained ImGui sources with the runtime's dependency patch applied.
- `--sdl-compat`: include parent containing the maintained SDL headers under `SDL2/`.
- `--sdk`: the private assembled open-source header/sysroot tree, including libc++
  headers and the minimal linker stubs. This is not an Apple SDK.
- `--clang` and `--linker`: LLVM clang and ld64.lld executable paths.
- `--output`: a separate private directory outside every source/toolchain input.

Fetch the pinned engine/runtime/dependency inputs into a new directory:

```sh
python3 scripts/fetch-ios-module-inputs.py --output "$NEW_MODULE_INPUTS"
```

The resulting directories are `source`, `runtime`, `torch`, `dependencies`,
`dependencies/imgui-src`, `sdl-compat` and `kartpad`. The fetcher checks Git
revisions, preserves LF source bytes, applies the maintained ImGui patch and
verifies downloaded headers and the generated iOS `zipconf.h` by digest. It
refuses an existing output directory. Failed setup is retained in a separate
temporary directory with `fetch.log`; no existing input tree is modified.

Example after preparing those inputs:

```sh
python3 scripts/build-ios-game-module.py \
  --source "$ENGINE" --runtime "$RUNTIME" --torch "$TORCH" \
  --dependencies "$DEPENDENCIES" --imgui "$IMGUI" \
  --sdl-compat "$SDL_INCLUDE_PARENT" --sdk "$OPEN_HEADERS" \
  --clang "$CLANG" --linker "$LD64_LLD" \
  --output "$PRIVATE_OUTPUT" --jobs 4
```

The header assembly step is available separately:

```sh
python3 scripts/prepare-ios-module-headers.py \
  --kartpad-source "$KARTPAD_SOURCE" --output "$NEW_OPEN_HEADERS"
```

It reuses KartPad's hash-checked SDK assembler and helper headers. Supply a KartPad
checkout containing those reviewed files and the source directories installed by
PadMint in `PADMINT_LIBCXX`, `PADMINT_APPLE_LIBC`, `PADMINT_APPLE_XNU`,
`PADMINT_APPLE_LIBPTHREAD`, `PADMINT_APPLE_LIBMALLOC`, `PADMINT_APPLE_LIBPLATFORM`
and `PADMINT_APPLE_AVAILABILITY`. The wrapper fetches two additional headers from
immutable Apple open-source revisions and checks all 20 added headers against
their expected installed hashes. It retains origin, digest and license records in
`SOURCES.json` and refuses to overwrite an existing output directory. Its output
reproduced all 1,915 files of the locally validated sysroot byte-for-byte, excluding
the expanded provenance report.

LLVM and the Apple open-source/libc++ trees still need to be installed by PadMint
before running the header assembler. The source fetcher does not install them.
The module compiler does not
verify all dependency/header contents or download them; it requires the prepared
inputs above. The initial local experiment used LLVM 22, libc++ 21.1.8 and pinned
Apple open-source headers. Native Windows/Linux and packaged PadMint validation
remain required before offering this to players.

Compilation and linking use response files so paths with spaces and large object
lists do not depend on shell quoting or host command-line length limits. Each
attempt retains commands, dependency files and diagnostics in its own directory.
Only a successful complete link atomically replaces `SpaghettiGame.dylib`;
compilation/link failures preserve an existing module. Output is unsigned private
experimental code. Link metadata naming iOS 15 does not prove iOS 15 runtime API
availability or gameplay.

## Experimental runtime host (Mac)

The maintained engine has an opt-in runtime build using the same pinned
libultraship/Torch dependencies and app resources:

```sh
SPAGHETTIPAD_RUNTIME_ONLY=ON scripts/build-ios.sh --device
```

Its default output is `build-ios-runtime/Release-iphoneos/SpaghettiPad.app`,
separate from the normal monolithic build. The normal mode remains the default.
The runtime links the iOS shell and `SpaghettiPadGameLoader.mm` instead of game
translation units. It exposes the reviewed APIs in `ios/runtime-exports.txt`
using explicit archive roots, and loads `Frameworks/SpaghettiGame.dylib` with
immediate symbol resolution. Missing/incompatible modules produce a startup error.

This runtime app alone cannot play a game. Module insertion, complete bundle
signing and actual device loading are still required. The dedicated CI checks the
runtime build, existing app audit and required exports without publishing an app.
Passing those checks does not establish module loading or gameplay. Do not replace
normal player instructions or distribute a runtime on this evidence alone.
