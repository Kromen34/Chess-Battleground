#!/usr/bin/env bash
# Télécharge le binaire Godot (version standard) dans tools/bin/ pour les tests headless.
# Linux x86_64 et Windows (Git Bash / MSYS2). Ailleurs, passe le chemin via la variable GODOT.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.3-stable}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/tools/bin"

case "$(uname -s)" in
  Linux*)
    ZIP="Godot_v${VERSION}_linux.x86_64.zip"
    EXTRACTED="Godot_v${VERSION}_linux.x86_64"
    BIN="$BIN_DIR/godot"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    ZIP="Godot_v${VERSION}_win64.exe.zip"
    EXTRACTED=""
    # La version _console écrit sur stdout/stderr ; elle lance l'exe principal à côté d'elle.
    BIN="$BIN_DIR/Godot_v${VERSION}_win64_console.exe"
    ;;
  *)
    echo "OS non géré par get_godot.sh : installe Godot et passe son chemin via GODOT." >&2
    exit 1
    ;;
esac

if [[ -x "$BIN" ]]; then
  echo "$BIN"
  exit 0
fi

mkdir -p "$BIN_DIR"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}/${ZIP}"
echo "Téléchargement de Godot ${VERSION}..." >&2
curl -fsSL -o "$BIN_DIR/$ZIP" "$URL"
unzip -q -o "$BIN_DIR/$ZIP" -d "$BIN_DIR"
if [[ -n "$EXTRACTED" ]]; then
  mv "$BIN_DIR/$EXTRACTED" "$BIN"
  chmod +x "$BIN"
fi
rm -f "$BIN_DIR/$ZIP"
echo "$BIN"
