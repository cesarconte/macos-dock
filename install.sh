#!/usr/bin/env bash
set -e

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_DEST="$HOME/.local/share/plasma/plasmoids/com.cesar.macosdock"
BIN_DEST="$HOME/.local/bin"

echo "==> Compilando ejecutable nativo macos-dock (C++ / LayerShellQt)..."
cmake -B "$SRC/build" -S "$SRC" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$SRC/build"

echo "==> Instalando ejecutable en $BIN_DEST/macos-dock..."
mkdir -p "$BIN_DEST"
cp -f "$SRC/build/bin/macos-dock" "$BIN_DEST/macos-dock"
chmod +x "$BIN_DEST/macos-dock"

echo "==> Sincronizando plasmoide en $PLASMOID_DEST..."
mkdir -p "$PLASMOID_DEST"
rsync -av --delete \
    --exclude=".git" \
    --exclude="build" \
    --exclude="CMakeFiles" \
    --exclude="src" \
    --exclude="CMakeLists.txt" \
    --exclude="*.swp" \
    --exclude="*~" \
    "$SRC/" "$PLASMOID_DEST/"

echo "==> Actualizando base de datos de servicios Plasma 6..."
kbuildsycoca6 --noincremental

echo "==> ¡Instalación y actualización completada con éxito!"
