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

Example after preparing those inputs:

```sh
python3 scripts/build-ios-game-module.py \
  --source "$ENGINE" --runtime "$RUNTIME" --torch "$TORCH" \
  --dependencies "$DEPENDENCIES" --imgui "$IMGUI" \
  --sdl-compat "$SDL_INCLUDE_PARENT" --sdk "$OPEN_HEADERS" \
  --clang "$CLANG" --linker "$LD64_LLD" \
  --output "$PRIVATE_OUTPUT" --jobs 4
```

Input provisioning is not yet automated by this repository. The command does not
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
