#!/usr/bin/env bash
# Lance la suite de tests en headless. Sortie 0 = tout vert.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ -n "${GODOT:-}" ]]; then
  BIN="$GODOT"
else
  BIN="$(bash tools/get_godot.sh)"
fi

# Godot 4.3 reste bloqué au premier import headless quand il découvre une
# GDExtension (GodotSteam) absente de .godot/extension_list.cfg. On déclare donc
# les extensions avant l'import pour qu'elles soient chargées dès le départ.
if [[ ! -f .godot/extension_list.cfg ]]; then
  mkdir -p .godot
  find addons -name '*.gdextension' 2>/dev/null | sed 's|^|res://|' > .godot/extension_list.cfg
fi

# Premier passage : laisse Godot importer le projet (génère .godot/), sinon les
# class_name ne sont pas encore résolus au premier lancement headless.
# Limite de temps par sécurité : un import bloqué ne doit pas geler la suite.
IMPORT=("$BIN" --headless --path "$ROOT" --import)
if command -v timeout >/dev/null 2>&1; then
  IMPORT=(timeout 300 "${IMPORT[@]}")
fi
"${IMPORT[@]}" >/dev/null 2>&1 || echo "Avertissement : l'import Godot a échoué ou dépassé 5 min." >&2

exec "$BIN" --headless --path "$ROOT" -s res://tests/run_tests.gd
