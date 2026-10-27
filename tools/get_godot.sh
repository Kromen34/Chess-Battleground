#!/usr/bin/env bash
# Télécharge le binaire Godot (Linux x86_64, version standard) dans tools/bin/ pour les tests headless.
# Sur Windows, installe Godot et passe le chemin via la variable GODOT.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.3-stable}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/tools/bin"
BIN="$BIN_DIR/godot"

if [[ -x "$BIN" ]]; then
  echo "$BIN"
  exit 0
fi

mkdir -p "$BIN_DIR"
ZIP="Godot_v${VERSION}_linux.x86_64.zip"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}/${ZIP}"
echo "Téléchargement de Godot ${VERSION}..." >&2
curl -fsSL -o "$BIN_DIR/$ZIP" "$URL"
unzip -q -o "$BIN_DIR/$ZIP" -d "$BIN_DIR"
mv "$BIN_DIR/Godot_v${VERSION}_linux.x86_64" "$BIN"
chmod +x "$BIN"
rm -f "$BIN_DIR/$ZIP"
echo "$BIN"
