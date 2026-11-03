#!/usr/bin/env bash
set -e

DEST="$HOME/.local/share/plasma/plasmoids/com.cesar.macosdock"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Instalando macOS Dock (Golden Gate) en $DEST..."
mkdir -p "$DEST"
rsync -av --delete --exclude=".git" --exclude="*.swp" --exclude="*~" "$SRC/" "$DEST/"

echo "==> Actualizando base de datos de servicios Plasma 6..."
kbuildsycoca6 --noincremental

echo "==> Reiniciando plasmashell..."
systemctl --user restart plasma-plasmashell.service

echo "==> ¡Instalación y actualización completada con éxito!"
