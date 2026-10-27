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

## Reprendre sur un autre PC

### 0. À installer une fois

- **Git for Windows** (avec Git Bash et Git LFS, inclus) : https://git-scm.com
- **Python 3** avec numpy (`pip install numpy`) : pour regénérer les figurines.
- **Steam** (client lancé et connecté pour voir son profil dans le jeu).
- **Google Drive pour ordinateur**, avec « Mon Drive » synchronisé (STL des figurines).
- Godot n'est pas à installer : `tests.sh` le télécharge dans `tools/bin/`.

### 1. Récupérer le projet

Dans Git Bash :

```sh
cd /c
git clone https://github.com/Kromen34/Chess-Battleground.git
cd Chess-Battleground
git lfs install && git lfs pull
git config user.name "Rips Nico"
git config user.email "kromen34@hotmail.com"
```

Le travail récent est sur deux branches, pas encore fusionnées dans `main` :

| Branche | Contenu | PR |
|---|---|---|
| `feat/serveur-dedie` | Serveur dédié, jeu contre l'IA en ligne, déploiement sur le VPS | #6 |
| `feat/decor-plateau` | Table de salon, caméra à la souris, menu Options, dragons | #7 |

Pour reprendre le travail visuel : `git checkout feat/decor-plateau`.
Le plus simple est de fusionner les deux PR sur GitHub, puis de rester sur `main`.

### 2. Vérifier que tout marche

```sh
bash tests.sh
```

### 3. Regénérer les figurines

Les modèles des dragons ne sont **pas dans git** (licence Artisan Guild, voir `CLAUDE.md`).
On les reconstruit depuis les STL du Google Drive, une commande par kit :

```sh
python tools/assembler_figurine.py tools/kits/dragon_a_spear_rider.json
python tools/assembler_figurine.py tools/kits/dragon_a_wild.json
```

Si le Drive n'est pas sur `I:`, ajouter le dossier des STL en 2e argument
(le chemin attendu est dans `"source"` de chaque fichier de `tools/kits/`).
Sans cette étape, le jeu marche mais affiche des cylindres à la place des dragons.

### 4. Jouer

```sh
tools/bin/Godot_v4.3-stable_win64.exe --path .
```

Ou ouvrir le projet dans l'éditeur Godot 4.3 (`tools/bin/Godot_v4.3-stable_win64.exe -e --path .`) et F5.

Caméra : molette = zoom, clic droit enfoncé = tourner, clic gauche enfoncé = avancer /
reculer, clic molette = vue de départ.

### 5. Accès au VPS (si besoin de redéployer le serveur)

La clé SSH du VPS est propre à chaque PC. Sur le nouveau PC :

```sh
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_chessbg -N "" -C chess-battleground-vps
cat ~/.ssh/id_ed25519_chessbg.pub
```

Puis ajouter cette ligne sur le VPS, dans `/home/ubuntu/.ssh/authorized_keys`, depuis l'ancien
PC (`ssh chessbg`) ou depuis la console KVM du manager OVH. Ajouter enfin à `~/.ssh/config` :

```
Host chessbg
    HostName 51.91.97.41
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519_chessbg
    IdentitiesOnly yes
```

Test : `ssh chessbg`. Déploiement : `bash tools/deployer_serveur.sh` (branche `feat/serveur-dedie`).

### 6. Avec Claude Code

Ouvrir Claude Code dans le dossier du projet : il lit `CLAUDE.md` (état du projet, décisions,
conventions) au démarrage, rien d'autre à faire.

## État actuel

- Plateau = graphe de cases (`src/core/board.gd`), générateur carré 8×8 pour le 1v1.
- Figurines avec PM / PA / PV / dégâts / portée propres, définies en `.tres`
  (`src/core/units/data/`). Quatre types provisoires : Soldat, Cavalier, Archer, Gardien.
- Règles (déplacement, attaque, fin de tour, victoire) centralisées dans `src/core/rules.gd`,
  tests headless (`./tests.sh`).
- IA de référence (`src/ai/simple_ai.gd`) : une partie IA vs IA se termine et est déterministe.
- Menu principal avec le pseudo et l'avatar Steam (GodotSteam 4.15, AppID de test 480).
- Scène 3D : plateau posé sur une table de salon (soirée jeu de rôle), caméra à la souris.
  Clic figurine → sélection, clic case → déplacement, clic ennemi → attaque,
  Entrée → fin de tour, Échap → menu. L'IA joue le joueur 1.
- Menu Options : affichage, qualité (préréglages Bas à Ultra), ombres, effets.
- Premières figurines : dragons assemblés depuis des kits STL (`tools/assembler_figurine.py`).

Voir `CLAUDE.md` pour l'architecture et les conventions.
