# Chess Battleground

Jeu de plateau tactique en 3D, tour par tour. Godot 4.3 · GDScript · Steam.

1v1 (PvP ou PvE) sur un plateau 8×8, avec une zone de spawn de 8×2 par joueur.

## Démarrer

```sh
git clone https://github.com/Kromen34/Chess-Battleground.git
cd Chess-Battleground
git lfs install && git lfs pull
./tests.sh          # télécharge Godot dans tools/bin/ si besoin, puis lance les tests
```

Le téléchargement automatique marche sous Linux et sous Windows (lancer `bash tests.sh`
depuis Git Bash). Ailleurs, ou pour utiliser un Godot déjà installé, passer son chemin
via la variable `GODOT`. Pour jouer : ouvrir le projet dans l'éditeur Godot 4.3 et lancer (F5),
avec le client Steam ouvert. Sur un PC sans carte graphique : `tools\lancer_sans_gpu.bat`.

## État actuel

- Plateau = graphe de cases (`src/core/board.gd`), générateur carré 8×8 pour le 1v1.
- Figurines avec PM / PA / PV / dégâts / portée propres, définies en `.tres`
  (`src/core/units/data/`). Quatre types provisoires : Soldat, Cavalier, Archer, Gardien.
- Règles (déplacement, attaque, fin de tour, victoire) centralisées dans `src/core/rules.gd`,
  tests headless (`./tests.sh`).
- IA de référence (`src/ai/simple_ai.gd`) : une partie IA vs IA se termine et est déterministe.
- Menu principal avec le pseudo et l'avatar Steam (GodotSteam 4.15, AppID de test 480).
- Scène 3D placeholder : clic figurine → sélection, clic case → déplacement,
  clic ennemi → attaque, Entrée → fin de tour, Échap → menu. L'IA joue le joueur 1.

Voir `CLAUDE.md` pour l'architecture et les conventions.
