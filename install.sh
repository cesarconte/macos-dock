#!/usr/bin/env bash
set -e

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_DEST="$HOME/.local/share/plasma/plasmoids/com.cesar.cachyosdock"
BIN_DEST="$HOME/.local/bin"

echo "==> Compilando ejecutable nativo macos-dock (C++ / LayerShellQt)..."
cmake -B "$SRC/build" -S "$SRC" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$SRC/build"

echo "==> Instalando ejecutable en $BIN_DEST/macos-dock..."
mkdir -p "$BIN_DEST"
cp -f "$SRC/build/bin/macos-dock" "$BIN_DEST/macos-dock"
chmod +x "$BIN_DEST/macos-dock"

LIB_DEST="$HOME/.local/lib"
echo "==> Instalando biblioteca de integración Unity en $LIB_DEST..."
mkdir -p "$LIB_DEST"
cp -f "$SRC/build/bin/libunity.so.9.0.0" "$LIB_DEST/libunity.so.9.0.0"
ln -sf "libunity.so.9.0.0" "$LIB_DEST/libunity.so.9"
ln -sf "libunity.so.9.0.0" "$LIB_DEST/libunity.so.6"
ln -sf "libunity.so.9.0.0" "$LIB_DEST/libunity.so.4"
ln -sf "libunity.so.9.0.0" "$LIB_DEST/libunity.so"

echo "==> Configurando wrapper de integración de descargas para Brave..."
cat << 'EOF' > "$BIN_DEST/brave-origin"
#!/usr/bin/env bash
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH}"
exec /usr/bin/brave-origin "$@"
EOF
chmod +x "$BIN_DEST/brave-origin"
ln -sf "brave-origin" "$BIN_DEST/brave"
ln -sf "brave-origin" "$BIN_DEST/brave-browser"

echo "==> Configurando environment.d para integración del navegador..."
mkdir -p "$HOME/.config/environment.d"
echo "LD_LIBRARY_PATH=\"$HOME/.local/lib:\${LD_LIBRARY_PATH}\"" > "$HOME/.config/environment.d/10-libunity.conf"

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

if systemctl --user is-active --quiet macos-dock.service; then
    echo "==> Reiniciando servicio de usuario macos-dock..."
    systemctl --user restart macos-dock.service
fi

echo "==> ¡Instalación y actualización completada con éxito!"
