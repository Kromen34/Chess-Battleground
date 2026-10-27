@echo off
rem Lance le serveur dedie en local (headless, sans fenetre), pour tester le jeu en ligne.
rem Dans le jeu : menu > "Jouer contre l'IA (serveur)".
rem   tools\lancer_serveur.bat              -> port 7777
rem   tools\lancer_serveur.bat --port=8000  -> autre port
cd /d "%~dp0.."
if not exist "tools\bin\Godot_v4.3-stable_win64_console.exe" bash tools/get_godot.sh
"tools\bin\Godot_v4.3-stable_win64_console.exe" --headless --path . res://scenes/server.tscn -- %*
