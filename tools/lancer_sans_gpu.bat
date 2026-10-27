@echo off
rem Lance le jeu (ou l'editeur avec -e) en rendu Compatibility, pour un PC sans carte graphique.
rem OpenGL passe par ANGLE (Direct3D 11), qui marche aussi avec le pilote graphique de base de Windows.
rem Sur un PC avec carte graphique, lancer Godot normalement (rendu Forward+).
rem   tools\lancer_sans_gpu.bat       -> le jeu
rem   tools\lancer_sans_gpu.bat -e    -> l'editeur
cd /d "%~dp0.."
if not exist "tools\bin\Godot_v4.3-stable_win64.exe" bash tools/get_godot.sh
start "" "tools\bin\Godot_v4.3-stable_win64.exe" --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle %*
