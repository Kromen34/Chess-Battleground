# Chess Battleground — guide pour les sessions Claude Code

Jeu de plateau tactique en 3D (Godot 4.3, GDScript), tour par tour, publié sur Steam.
1v1 uniquement (PvP ou PvE), sur un plateau 8×8 avec une zone de spawn de 8×2 par
joueur. Le plateau reste modélisé comme un **graphe de cases**, jamais comme une
grille 8×8 en dur (obstacles, variantes de plateau futures).

Ce fichier est lu par chaque session Claude Code, sur chaque PC. Il doit rester
court et à jour : si tu changes une convention, mets-la à jour ici.

## Où on en est (mis à jour le 27/10/2026)

À relire en début de session : c'est la mémoire partagée entre les PC.

**Fait :**
- Cœur du jeu : plateau-graphe 8×8, 4 figurines provisoires, règles, IA de référence,
  scène 3D placeholder (`scenes/main.tscn`). 32 tests verts.
- Menu principal (`scenes/main_menu.tscn`, scène de démarrage) : « Jouer contre l'IA »,
  « Quitter », pseudo + avatar Steam en haut à droite (validé : ça marche). Échap en partie → menu.
- Projet renommé **Chess Battleground** (ex-TD Battleground), dépôt `Kromen34/Chess-Battleground`.
- `tests.sh` : télécharge Godot sous Windows aussi ; premier import GodotSteam débloqué.
- Serveur dédié + VPS OVH : branche `feat/serveur-dedie`, PR #6 (pas encore fusionnée).
- Branche `feat/decor-plateau` (PR séparée, partie de `main`) :
  - Décor « soirée jeu de rôle au salon » (`src/view/tabletop_decor.gd`) : plateau en bois
    posé sur une table **laissée libre** (Nicolas y mettra compteurs, dés, cartes : ne pas
    y ajouter d'accessoires), suspension, chaises, tapis, parquet, bibliothèque, fenêtre.
    Le premier jet « champ de bataille » a été jugé moche et abandonné.
  - Caméra (`src/view/camera_rig.gd`) : molette = zoom, clic droit enfoncé = rotation,
    clic gauche enfoncé = avancer/reculer, clic molette = vue de départ. Les clics du
    plateau sont pris au **relâchement** (un glisser de caméra avale le relâchement).
  - Menu Options graphiques (`src/ui/options_menu.gd` + autoload `GraphicsSettings`).
  - Premières figurines : dragons Artisan Guild (voir « Figurines »). 37 tests verts.

**Prochaines pistes (au choix de Nicolas) :** autres kits de dragons (B, C, D), système de
cartes/deck, factions et stats, dés de mouvement, compteurs sur la table.

**Prévu en priorité (demandé par Nicolas) :** les dragons manquent de détails (~100k triangles
sur 2,4 M, clustering grossier qui écrase écailles, dents, griffes). À faire, puis comparer
avant / après sur la même capture : (1) monter à ~300-400k triangles par figurine, Godot
génère les LOD à l'import ; (2) meilleure simplification par fusion d'arêtes (Blender ou
bibliothèque Python : leur téléchargement a été bloqué par le mode auto, demander à Nicolas
d'autoriser) ; (3) « lavis » : assombrir les creux (cavité / occlusion calculée sur le
modèle d'origine, en couleurs de sommets), comme une figurine peinte.
À décider aussi : passer le dépôt en privé pour versionner les modèles (LFS), mail de
demande de licence jeu vidéo à Artisan Guild.

**Mettre en route un nouveau PC :**
1. `git clone https://github.com/Kromen34/Chess-Battleground.git` puis `git lfs install && git lfs pull`
   (sinon les DLL de GodotSteam sont des pointeurs LFS et Steam ne marche pas).
   Ancien clone : `git remote set-url origin https://github.com/Kromen34/Chess-Battleground.git`.
2. `bash tests.sh` (Git Bash) : télécharge Godot 4.3 dans `tools/bin/` et lance les tests.
3. Jouer : éditeur Godot 4.3 → F5. Le client Steam doit être lancé et connecté avant le jeu.
   PC sans carte graphique (Vulkan/D3D12 absents, ex. VM) : `tools\lancer_sans_gpu.bat`
   (`-e` pour l'éditeur). Godot 4.3 ne bascule pas seul en OpenGL (seulement à partir de 4.4).
4. Sans `gh` : les PR se font via l'API GitHub avec le jeton de Git Credential Manager.
5. Figurines (absentes de git, voir « Figurines ») : les regénérer depuis les STL du Google
   Drive de Nicolas, pour chaque kit : `python tools/assembler_figurine.py tools/kits/<kit>.json`
   (+ le dossier des STL en 2e argument si le Drive n'est pas sur `I:`). Sans elles, le jeu
   affiche des cylindres à la place.
6. Identité git : `git config user.name "Rips Nico"` et `git config user.email "kromen34@hotmail.com"`.

## Figurines

- Source : kits STL d'impression **Artisan Guild** (Draconian Scourge, juin 2023) sur le
  Google Drive de Nicolas : `I:\Mon Drive\3D\Miniatures\Artisan guild\...`. Ne pas utiliser
  les `.blend` / `.fbx` qui s'y trouvent (essais ratés de Nicolas).
- **Licence** : le PDF fourni par Artisan Guild limite l'usage au personnel et interdit les
  jeux ; Nicolas dit avoir des droits commerciaux. Tant qu'une licence couvrant le jeu vidéo
  n'est pas confirmée par écrit, `assets/models/draconian/` reste dans `.gitignore` (le
  dépôt est public : pousser les modèles = les distribuer). Ne jamais les commiter.
- `tools/assembler_figurine.py` (numpy seul, pas de Blender) : les pièces d'un kit partagent
  le même repère, on les fusionne telles quelles ; allègement par clustering de sommets à
  quadriques (~100k triangles par figurine) ; socle = 0,85 case, figurine tournée vers -Z.
  Un fichier par kit dans `tools/kits/` (pièces, matériau, triangles visés). Les membranes
  fines (ailes) ont besoin de plus de triangles, sinon elles se trouent.
- Matériaux : couleurs unies (un STL n'a pas de textures). Le nœud `base` du GLB prend la
  couleur de l'équipe dans `BoardView`.
- Test provisoire : Cavalier = Spear Dragonrider, Gardien = Wild Dragon (`model_path` des `.tres`).
- Vérifier un modèle sans lancer le jeu : rendu sous 4 angles par un script `-s` qui
  instancie le GLB et sauve `root.get_texture().get_image()` (le PC a une RTX 5080).

## Lancer les tests (à faire avant tout push)

```sh
./tests.sh            # télécharge Godot dans tools/bin/ si besoin, puis lance la suite
```

Le téléchargement auto gère Linux et Windows (Git Bash). Sinon : `GODOT=/chemin/vers/godot ./tests.sh`.

Les tests tournent en headless (`godot --headless -s tests/run_tests.gd`), sans
rendu. Tout ce qui est dans `src/core/` doit être testable ainsi.

## Structure

```
src/core/         Logique pure (RefCounted / Resource) — ZÉRO nœud 3D, zéro Input, zéro réseau
  board.gd        Graphe de cases : Cell (id, position 3D, voisins par direction)
  generators/     Un générateur par forme de plateau (square_generator.gd = 1v1 8×8)
  units/          UnitType (Resource : PM, PA, PV, dégâts, portée) + Unit (instance en jeu)
  game_state.gd   État complet d'une partie : plateau, unités, tour, joueur actif
  rules.gd        Validation des actions (déplacement, attaque) — seule source de vérité
  actions.gd      Actions sérialisables (Dictionary) : Move, Attack, EndTurn
src/net/          Réseau (GodotSteam P2P / ENet). Le serveur applique Rules, les clients affichent.
src/ai/           IA PvE. Un joueur comme un autre : reçoit un GameState, renvoie une Action.
src/view/         Rendu 3D : lit le GameState, ne le modifie jamais directement.
  board_view.gd   Cases, figurines (GLB ou cylindre), clics ; signal board_built(bounds)
  tabletop_decor.gd  Table, pièce et lumière, construits autour du plateau
  camera_rig.gd   Caméra orbitale (souris)
src/ui/           Menus et écrans 2D (main_menu.gd = scène de démarrage, options_menu.gd)
src/platform/     steam_service.gd : autoload SteamService (init Steam, pseudo, avatar)
                  graphics_settings.gd : autoload GraphicsSettings (user://settings.cfg)
addons/godotsteam GodotSteam 4.15 GDExtension (dernière version compatible Godot 4.3), binaires en LFS
scenes/           Scènes .tscn
assets/           models/ (GLB), textures/, audio/ — tout en Git LFS
tests/            run_tests.gd (runner) + test_*.gd
tools/            get_godot.sh, assembler_figurine.py + kits/, lancer_sans_gpu.bat
```

## Règles d'architecture (non négociables)

1. **Autorité serveur.** Un client ne décide jamais si une action est valide. Il envoie
   une Action, le serveur la passe à `Rules`, applique ou refuse, et diffuse le nouvel état.
   En solo/PvE, le "serveur" tourne en local dans le même process : même code.
2. **`src/core/` ne dépend de rien d'autre.** Pas de `Node3D`, pas de `get_tree()`, pas de
   signaux vers la vue. Communication par valeurs de retour et par signaux déclarés dans
   `GameState` uniquement.
3. **Le plateau est un graphe.** Les règles parlent de "voisin dans la direction D",
   jamais de `x+1`. Les coordonnées n'existent que dans les générateurs et dans la vue.
4. **Une Action est un Dictionary sérialisable** (`{"type": "move", "unit": id, "to": cell_id}`).
   C'est ce qui transite sur le réseau et ce que l'IA produit.
5. **Déterminisme.** Tout aléa (dégâts, etc.) passe par un `RandomNumberGenerator` seedé
   dans `GameState`, jamais par `randi()` global. Sinon le replay et la synchro cassent.

## Steam

- Ne jamais référencer la classe `Steam` directement : passer par `SteamService`, qui utilise
  `Engine.get_singleton("Steam")`. Le jeu et les tests doivent tourner sans Steam ni plugin
  (profil par défaut « Joueur »). En headless, SteamService n'initialise pas Steam.
- AppID provisoire : 480 (Spacewar, app de test de Valve), réglage `steam/initialization/app_id`
  dans `project.godot`. GodotSteam 4.15 : `steamInitEx()` sans argument, et `run_callbacks()`
  appelé à chaque frame par SteamService.

## Conventions GDScript

- GDScript **typé** partout (`var x: int`, `func f(a: Cell) -> bool`). Les warnings
  `untyped_declaration` sont activés dans `project.godot`.
- `class_name` sur toutes les classes de `src/core/`.
- Nommage : `snake_case` fichiers et fonctions, `PascalCase` classes, `UPPER_CASE` constantes.
- Pas de `print()` dans `src/core/` ; utiliser `push_warning` / `push_error` ou retourner un résultat.
- Un fichier de test par classe de `src/core/` : `tests/test_<nom>.gd`.
- Les Resources de données (types d'unités, formes de plateau) sont des `.tres` dans
  `src/core/units/data/` — éditables sans toucher au code.

## Workflow Git

- `main` doit toujours passer `./tests.sh` et s'exporter.
- Une branche par chantier : `feat/<sujet>`, `fix/<sujet>`, `docs/<sujet>`. Petits commits, messages en français,
  à l'impératif : `Ajoute la portée d'attaque aux UnitType`.
- Avant de commencer une tâche : `git pull --rebase origin main`.
- Avant de push : `./tests.sh` vert.
- Les assets binaires passent par Git LFS (`.gitattributes` déjà configuré). Ne jamais
  commiter un `.glb` sans que `git lfs ls-files` le liste.
- Ne jamais commiter `.godot/`.

## Décisions prises

- Pas de plateaux multijoueurs (2v1, 3v1…) : triangle et croix ont été essayés puis
  abandonnés (octobre 2026). Le jeu reste en 1v1 sur 8×8, spawn 8×2.
- Ambiance : le plateau est posé sur une table de salon, comme une partie de jeu de rôle
  entre amis. Échelle : 1 case = 1 pouce (2,5 cm).
- Réglages graphiques : décrits une seule fois dans `GraphicsSettings.SETTINGS` (le menu
  se construit à partir de cette liste) ; un nouveau réglage s'ajoute là. FSR 2.2 de
  Godot 4.3 émet une erreur bénigne à la fermeture et refuse le TAA : FSR 1.0 par défaut.

## Ce qui n'est pas encore décidé (ne pas inventer)

- La liste finale des figurines et leurs stats (voir `src/core/units/data/` pour les
  valeurs provisoires de test).
- Le transport réseau définitif (GodotSteam P2P prévu, ENet pour le dev local).
