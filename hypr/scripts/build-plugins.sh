#!/usr/bin/env bash
# Rebuild Hyprland plugins against the installed Hyprland headers (no hyprpm).
# Run after every Hyprland update, then log out/in (or `hyprctl reload`).
set -euo pipefail

OUT="$HOME/.local/share/hypr-plugins"
SRC="$(mktemp -d)"
trap 'rm -rf "$SRC"' EXIT
mkdir -p "$OUT"

# Hyprland version -> hyprglass branch (hyprland-X.Y), falling back to main.
VER="$(pkg-config --modversion hyprland | cut -d. -f1,2)"
echo "Hyprland $VER"

echo "== hyprbars =="
git clone -q --depth 1 https://github.com/hyprwm/hyprland-plugins "$SRC/hp"
make -C "$SRC/hp/hyprbars" -j"$(nproc)"
cp "$SRC/hp/hyprbars/hyprbars.so" "$OUT/"

echo "== dynamic-cursors =="
git clone -q --depth 1 https://github.com/VirtCode/hypr-dynamic-cursors "$SRC/dc"
make -C "$SRC/dc" all -j"$(nproc)"
cp "$SRC/dc/out/dynamic-cursors.so" "$OUT/"

#echo "== hyprglass =="
#git clone -q --depth 1 -b "hyprland-$VER" https://github.com/hyprnux/hyprglass "$SRC/hg" \
#  || git clone -q --depth 1 https://github.com/hyprnux/hyprglass "$SRC/hg"
#make -C "$SRC/hg" -j"$(nproc)"
#cp "$SRC/hg/hyprglass.so" "$OUT/"

echo "Done: $OUT"
