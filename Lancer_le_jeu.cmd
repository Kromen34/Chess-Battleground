@echo off
rem Lance le jeu pour le tester (double-clic). Le client Steam doit etre lance avant.
rem   Lancer_le_jeu.cmd       -> le jeu
rem   Lancer_le_jeu.cmd -e    -> l'editeur Godot
rem PC sans carte graphique : tools\lancer_sans_gpu.bat
cd /d "%~dp0"
if not exist "tools\bin\Godot_v4.3-stable_win64.exe" bash tools/get_godot.sh
start "" "tools\bin\Godot_v4.3-stable_win64.exe" --path . %*
