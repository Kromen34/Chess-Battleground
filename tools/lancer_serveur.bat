@echo off
rem Lance le serveur dedie en local (headless, sans fenetre), pour tester le jeu en ligne.
rem Dans le jeu : menu > "Jouer contre l'IA (serveur)".
rem   tools\lancer_serveur.bat              -> port 7777
rem   tools\lancer_serveur.bat --port=8000  -> autre port
rem   tools\lancer_serveur.bat --dev --dev-cards
rem       -> SteamID cru sur parole et une carte sur deux pour chaque joueur, pour tester
rem          l'ecran Collection (jeu lance avec -- --server=127.0.0.1 [--steam-id=N]).
cd /d "%~dp0.."
if not exist "tools\bin\Godot_v4.3-stable_win64_console.exe" bash tools/get_godot.sh
"tools\bin\Godot_v4.3-stable_win64_console.exe" --headless --path . res://scenes/server.tscn -- %*
