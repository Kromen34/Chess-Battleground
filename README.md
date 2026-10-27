# TD Battleground

Jeu de plateau tactique en 3D, tour par tour. Godot 4.3 · GDScript · Steam.

1v1 (PvP ou PvE), et 2v1 / 3v1 / 4v1 contre une IA sur des plateaux dont la forme
dépend du nombre de joueurs.

## Démarrer

```sh
git clone https://github.com/Kromen34/TD-Battleground.git
cd TD-Battleground
git lfs install && git lfs pull
./tests.sh          # Linux/macOS : télécharge Godot dans tools/bin/ puis lance les tests
```

Sur Windows : installer Godot 4.3, puis `set GODOT=C:\chemin\vers\godot.exe` et
`bash tests.sh` (Git Bash), ou ouvrir le projet dans l'éditeur et lancer `scenes/main.tscn`.

## État actuel

- Plateau = graphe de cases (`src/core/board.gd`), générateur carré 8×8 pour le 1v1.
- Figurines avec PM / PA / PV / dégâts / portée propres, définies en `.tres`
  (`src/core/units/data/`). Quatre types provisoires : Soldat, Cavalier, Archer, Gardien.
- Règles (déplacement, attaque, fin de tour, victoire) centralisées dans `src/core/rules.gd`,
  30 tests headless.
- IA de référence (`src/ai/simple_ai.gd`) : une partie IA vs IA se termine et est déterministe.
- Scène 3D placeholder : clic figurine → sélection, clic case → déplacement,
  clic ennemi → attaque, Entrée → fin de tour. L'IA joue le joueur 1.

Voir `CLAUDE.md` pour l'architecture et les conventions.
