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

# Premier passage : laisse Godot importer le projet (génère .godot/), sinon les
# class_name ne sont pas encore résolus au premier lancement headless.
"$BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

exec "$BIN" --headless --path "$ROOT" -s res://tests/run_tests.gd
