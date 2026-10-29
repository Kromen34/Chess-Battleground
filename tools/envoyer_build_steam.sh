#!/usr/bin/env bash
# Exporte le jeu pour Windows puis l'envoie sur Steam (SteamPipe). Windows (Git Bash) seulement.
#   bash tools/envoyer_build_steam.sh            -> exporte dans build/windows/ puis envoie
#   bash tools/envoyer_build_steam.sh --export   -> exporte seulement (tester l'exe en local)
#   STEAM_USER=moncompte bash tools/envoyer_build_steam.sh   -> sans question sur l'identifiant
# steamcmd demande le mot de passe et le code Steam Guard au premier envoi (ensuite il garde la
# session) : à lancer dans une fenêtre Git Bash, pas depuis Claude Code.
# La build n'est pas mise en ligne : dans Steamworks, SteamPipe > Builds > « Set build live ».
set -euo pipefail

APP_ID=4303740
DEPOT_ID=4303741  # dépôt Windows de l'app, déclaré dans Steamworks (SteamPipe > Dépôts)
PRESET="Windows Desktop"
GODOT_VERSION_DIR="4.3.stable"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/build/windows"
STEAMPIPE="$ROOT/build/steampipe"
BIN_DIR="$ROOT/tools/bin"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *) echo "Script prévu pour Windows (Git Bash)." >&2; exit 1 ;;
esac

if ! grep -q "^initialization/app_id=$APP_ID$" project.godot; then
  echo "project.godot n'a pas l'AppID $APP_ID (steam/initialization/app_id)." >&2
  exit 1
fi

# --- Modèles d'export Godot (une fois, ~1,2 Go à télécharger) ---
TPL_DIR="$APPDATA/Godot/export_templates/$GODOT_VERSION_DIR"
if [[ ! -f "$TPL_DIR/windows_release_x86_64.exe" ]]; then
  TPZ="$BIN_DIR/Godot_v4.3-stable_export_templates.tpz"
  if [[ ! -f "$TPZ" ]]; then
    echo "Téléchargement des modèles d'export Godot 4.3 (~1,2 Go)..."
    mkdir -p "$BIN_DIR"
    curl -fL --progress-bar -o "$TPZ.part" \
      "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
    mv "$TPZ.part" "$TPZ"
  fi
  mkdir -p "$TPL_DIR"
  unzip -q -o -j "$TPZ" templates/version.txt templates/windows_release_x86_64.exe \
    templates/windows_debug_x86_64.exe -d "$TPL_DIR"
  rm -f "$TPZ"
fi

# --- Export ---
if [[ ! -d Figurines ]]; then
  echo "Attention : pas de dossier Figurines/, le jeu exporté affichera des cylindres." >&2
fi
GODOT="${GODOT:-$(bash tools/get_godot.sh)}"
rm -rf "$OUT"
mkdir -p "$OUT"
echo "Export de la build Windows..."
"$GODOT" --headless --path . --export-release "$PRESET" "$OUT/ChessBattleground.exe"
for f in ChessBattleground.exe ChessBattleground.pck steam_api64.dll; do
  if [[ ! -f "$OUT/$f" ]]; then
    echo "Export incomplet : $f manque dans build/windows/." >&2
    exit 1
  fi
done
echo "Build exportée : build/windows/ ($(du -sh "$OUT" | cut -f1))"
if [[ "${1:-}" == "--export" ]]; then
  exit 0
fi

# --- Envoi SteamPipe ---
STEAMCMD="$BIN_DIR/steamcmd/steamcmd.exe"
if [[ ! -f "$STEAMCMD" ]]; then
  echo "Téléchargement de steamcmd..."
  mkdir -p "$BIN_DIR/steamcmd"
  curl -fsSL -o "$BIN_DIR/steamcmd/steamcmd.zip" \
    "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
  unzip -q -o "$BIN_DIR/steamcmd/steamcmd.zip" -d "$BIN_DIR/steamcmd"
  rm -f "$BIN_DIR/steamcmd/steamcmd.zip"
fi

STEAM_USER="${STEAM_USER:-}"
if [[ -z "$STEAM_USER" ]]; then
  read -rp "Identifiant Steam (compte Steamworks) : " STEAM_USER
fi

DESC="$(git rev-parse --short HEAD)"
if [[ -n "$(git status --porcelain)" ]]; then
  DESC="$DESC + modifications locales"
fi
mkdir -p "$STEAMPIPE"
cat > "$STEAMPIPE/app_build.vdf" <<EOF
"AppBuild"
{
	"AppID" "$APP_ID"
	"Desc" "$DESC"
	"ContentRoot" "$(cygpath -m "$OUT")"
	"BuildOutput" "$(cygpath -m "$STEAMPIPE/output")"
	"Depots"
	{
		"$DEPOT_ID"
		{
			"FileMapping"
			{
				"LocalPath" "*"
				"DepotPath" "."
				"Recursive" "1"
			}
		}
	}
}
EOF

# Dans la console mintty de Git Bash, steamcmd ne lit pas le clavier sans winpty.
RUN=()
if [[ "${TERM_PROGRAM:-}" == "mintty" ]] && command -v winpty >/dev/null; then
  RUN=(winpty)
fi
echo "Envoi sur Steam ($DESC)..."
"${RUN[@]}" "$STEAMCMD" +login "$STEAM_USER" +run_app_build "$(cygpath -w "$STEAMPIPE/app_build.vdf")" +quit
echo "Envoyé. Steamworks > SteamPipe > Builds : « Set build live » sur la branche default."
