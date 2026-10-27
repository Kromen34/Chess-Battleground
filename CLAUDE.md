# Chess Battleground — guide pour les sessions Claude Code

Jeu de plateau tactique en 3D (Godot 4.3, GDScript), tour par tour, publié sur Steam.
1v1 uniquement (PvP ou PvE), sur un plateau 8×8 avec une zone de spawn de 8×2 par
joueur. Le plateau reste modélisé comme un **graphe de cases**, jamais comme une
grille 8×8 en dur (obstacles, variantes de plateau futures).

Ce fichier est lu par chaque session Claude Code, sur chaque PC. Il doit rester
court et à jour : si tu changes une convention, mets-la à jour ici.

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
src/ui/           Menus et écrans 2D (main_menu.gd = scène de démarrage)
src/platform/     steam_service.gd : autoload SteamService (init Steam, pseudo, avatar)
addons/godotsteam GodotSteam 4.15 GDExtension (dernière version compatible Godot 4.3), binaires en LFS
scenes/           Scènes .tscn
assets/           models/ (GLB), textures/, audio/ — tout en Git LFS
tests/            run_tests.gd (runner) + test_*.gd
tools/            scripts utilitaires (get_godot.sh, conversion d'assets)
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
- Une branche par chantier : `feat/<sujet>`, `fix/<sujet>`. Petits commits, messages en français,
  à l'impératif : `Ajoute la portée d'attaque aux UnitType`.
- Avant de commencer une tâche : `git pull --rebase origin main`.
- Avant de push : `./tests.sh` vert.
- Les assets binaires passent par Git LFS (`.gitattributes` déjà configuré). Ne jamais
  commiter un `.glb` sans que `git lfs ls-files` le liste.
- Ne jamais commiter `.godot/`.

## Décisions prises

- Pas de plateaux multijoueurs (2v1, 3v1…) : triangle et croix ont été essayés puis
  abandonnés (octobre 2026). Le jeu reste en 1v1 sur 8×8, spawn 8×2.

## Ce qui n'est pas encore décidé (ne pas inventer)

- La liste finale des figurines et leurs stats (voir `src/core/units/data/` pour les
  valeurs provisoires de test).
- Le transport réseau définitif (GodotSteam P2P prévu, ENet pour le dev local).
