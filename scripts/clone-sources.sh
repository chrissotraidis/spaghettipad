#!/usr/bin/env bash
# Fetch the pinned, disposable upstream build inputs into ./sources/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES_DIR="$ROOT/sources"
SPAGHETTIKART_DIR="$SOURCES_DIR/spaghettikart"

SPAGHETTIKART_REPO="https://github.com/HarbourMasters/SpaghettiKart.git"
LIBULTRASHIP_REPO="https://github.com/Kenix3/libultraship.git"
TORCH_REPO="https://github.com/HarbourMasters/Torch.git"

SPAGHETTIKART_PIN="5b28472d477bab101dee2a0f469fe2aee2c58a01"
LIBULTRASHIP_PIN="f5c3843fe937320b64ff754fa6bf71b13ff5e7a1"
TORCH_PIN="2d474ddb8da8b213fbdbb49d0273ce31fa955f35"
DISABLED_PUSH_URL="disabled://spaghettipad-upstream-input"

fail() {
    echo "Source bootstrap failed: $*" >&2
    exit 1
}

require_clean_checkout() {
    local checkout="$1"
    local label="$2"

    git -C "$checkout" diff --quiet ||
        fail "$label has modified files; upstream inputs must remain disposable"
    git -C "$checkout" diff --cached --quiet ||
        fail "$label has staged files; upstream inputs must remain disposable"
}

mkdir -p "$SOURCES_DIR"

if [ ! -d "$SPAGHETTIKART_DIR/.git" ]; then
    if [ -e "$SPAGHETTIKART_DIR" ]; then
        fail "$SPAGHETTIKART_DIR exists but is not a Git checkout"
    fi
    echo "==> Cloning SpaghettiKart"
    git clone "$SPAGHETTIKART_REPO" "$SPAGHETTIKART_DIR"
fi

require_clean_checkout "$SPAGHETTIKART_DIR" "SpaghettiKart"
git -C "$SPAGHETTIKART_DIR" remote set-url origin "$SPAGHETTIKART_REPO"
git -C "$SPAGHETTIKART_DIR" config remote.origin.pushurl "$DISABLED_PUSH_URL"
git -C "$SPAGHETTIKART_DIR" fetch origin "$SPAGHETTIKART_PIN"
git -C "$SPAGHETTIKART_DIR" checkout --detach "$SPAGHETTIKART_PIN"

git -C "$SPAGHETTIKART_DIR" config submodule.libultraship.url "$LIBULTRASHIP_REPO"
git -C "$SPAGHETTIKART_DIR" config submodule.torch.url "$TORCH_REPO"
git -C "$SPAGHETTIKART_DIR" submodule update --init libultraship torch

for input in libultraship torch; do
    require_clean_checkout "$SPAGHETTIKART_DIR/$input" "$input"
    git -C "$SPAGHETTIKART_DIR/$input" config remote.origin.pushurl "$DISABLED_PUSH_URL"
done

actual_spaghettikart="$(git -C "$SPAGHETTIKART_DIR" rev-parse HEAD)"
actual_libultraship="$(git -C "$SPAGHETTIKART_DIR/libultraship" rev-parse HEAD)"
actual_torch="$(git -C "$SPAGHETTIKART_DIR/torch" rev-parse HEAD)"

[ "$actual_spaghettikart" = "$SPAGHETTIKART_PIN" ] ||
    fail "unexpected SpaghettiKart revision: $actual_spaghettikart"
[ "$actual_libultraship" = "$LIBULTRASHIP_PIN" ] ||
    fail "unexpected libultraship revision: $actual_libultraship"
[ "$actual_torch" = "$TORCH_PIN" ] ||
    fail "unexpected Torch revision: $actual_torch"

echo
echo "Pinned upstream inputs are ready:"
echo "  SpaghettiKart  $actual_spaghettikart"
echo "  libultraship   $actual_libultraship"
echo "  Torch          $actual_torch"
echo "All three push URLs are disabled."
