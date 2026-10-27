# TD Battleground

Jeu de plateau tactique en 3D, tour par tour. Godot 4.3 · GDScript · Steam.

1v1 (PvP ou PvE) sur un plateau 8×8, avec une zone de spawn de 8×2 par joueur.

## Démarrer

```sh
git clone https://github.com/Kromen34/TD-Battleground.git
cd TD-Battleground
git lfs install && git lfs pull
./tests.sh          # télécharge Godot dans tools/bin/ si besoin, puis lance les tests
```

Le téléchargement automatique marche sous Linux et sous Windows (lancer `bash tests.sh`
depuis Git Bash). Ailleurs, ou pour utiliser un Godot déjà installé, passer son chemin
via la variable `GODOT`. Pour jouer : ouvrir le projet dans l'éditeur et lancer `scenes/main.tscn`.

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
