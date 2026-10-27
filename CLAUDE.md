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
- Serveur dédié (branche `feat/serveur-dedie`) : partie contre l'IA jouée entièrement côté
  serveur, client en ENet, bouton « Jouer contre l'IA (serveur) ». 48 tests verts.
- VPS OVH en service (voir « Serveur dédié ») : serveur + PostgreSQL en Docker, le bouton
  « Jouer contre l'IA (serveur) » s'y connecte.

**Prochaines étapes du serveur :** authentification par ticket de session Steam, PostgreSQL (joueurs, decks, points), stats des figurines servies
par le serveur.

**Prochaines pistes (au choix de Nicolas) :** système de cartes/deck, factions et stats,
dés de mouvement, menus suivants (options, multijoueur).

**Mettre en route un nouveau PC :**
1. `git clone https://github.com/Kromen34/Chess-Battleground.git` puis `git lfs install && git lfs pull`
   (sinon les DLL de GodotSteam sont des pointeurs LFS et Steam ne marche pas).
   Ancien clone : `git remote set-url origin https://github.com/Kromen34/Chess-Battleground.git`.
2. `bash tests.sh` (Git Bash) : télécharge Godot 4.3 dans `tools/bin/` et lance les tests.
3. Jouer : éditeur Godot 4.3 → F5. Le client Steam doit être lancé et connecté avant le jeu.
   PC sans carte graphique (Vulkan/D3D12 absents, ex. VM) : `tools\lancer_sans_gpu.bat`
   (`-e` pour l'éditeur). Godot 4.3 ne bascule pas seul en OpenGL (seulement à partir de 4.4).
4. Sans `gh` : les PR se font via l'API GitHub avec le jeton de Git Credential Manager.

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
src/net/          Serveur dédié et client réseau (voir « Serveur dédié »)
  protocol.gd     Messages JSON client <-> serveur, nettoyage des actions reçues
  match_server.gd Logique serveur sans transport (sessions, parties) — testable sans réseau
  server_match.gd Une partie côté serveur : GameState de référence + IA, signaux -> événements
  state_mirror.gd Côté client : applique les événements du serveur à la copie locale
  net_server.gd / net_client.gd  Transport ENet (paquets bruts, pas de RPC)
  server_main.gd  Point d'entrée de scenes/server.tscn
src/ai/           IA PvE. Un joueur comme un autre : reçoit un GameState, renvoie une Action.
src/view/         Rendu 3D : lit le GameState, ne le modifie jamais directement.
src/ui/           Menus et écrans 2D (main_menu.gd = scène de démarrage)
src/platform/     steam_service.gd : autoload SteamService (init Steam, pseudo, avatar)
addons/godotsteam GodotSteam 4.15 GDExtension (dernière version compatible Godot 4.3), binaires en LFS
scenes/           Scènes .tscn
assets/           models/ (GLB), textures/, audio/ — tout en Git LFS
tests/            run_tests.gd (runner) + test_*.gd
tools/            scripts utilitaires (get_godot.sh, lancer_serveur.bat, conversion d'assets)
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

## Serveur dédié

- **Anti-triche = serveur autoritaire**, pas la BDD : toute partie qui compte (PvP et contre
  l'IA, qui rapporte des points) tourne sur le serveur. Le client envoie des actions et
  affiche les événements renvoyés ; il ne recalcule jamais un résultat.
- Le numéro de joueur vient de la session serveur, jamais du message. Toute action reçue
  passe par `Protocol.sanitize_action` puis `Rules`.
- Le client ne reçoit que `GameState.to_view_dict(player)` : jamais la graine ni l'état du
  RNG (il prédirait les dés). La main et le deck adverses y seront aussi cachés.
- Dés et tirages : uniquement côté serveur, via le RNG seedé du GameState.
- Le menu rejoint le VPS par défaut. Serveur local : `tools\lancer_serveur.bat`, puis lancer
  le jeu avec `-- --server=127.0.0.1`. Port par défaut : 7777 (UDP).
- Changement incompatible du protocole : incrémenter `Protocol.VERSION`.
- BDD (PostgreSQL) côté serveur uniquement, jamais accessible par le client.
- Infra : d'abord un VPS OVH avec Docker Compose (serveur Godot headless qui gère N parties
  + PostgreSQL). Kubernetes/Agones seulement si la charge le justifie : le serveur ne garde
  en mémoire que les parties en cours, pour pouvoir passer à plusieurs instances.

## VPS (production)

- OVH VPS-1, Ubuntu 26.04, IP `51.91.97.41`. Accès : `ssh chessbg` (alias dans `~/.ssh/config`,
  clé `~/.ssh/id_ed25519_chessbg` à recréer et autoriser sur un nouveau PC). Secours : console
  KVM du manager OVH avec le mot de passe de `ubuntu`.
- Sécurité : SSH par clé uniquement, root interdit, ufw (22/tcp + 7777/udp seulement),
  fail2ban, mises à jour de sécurité automatiques (sans redémarrage auto).
- Déployer : `bash tools/deployer_serveur.sh` (envoie le commit HEAD, reconstruit l'image,
  relance). Stack dans `deploy/` : conteneur de jeu en lecture seule et sans privilèges,
  PostgreSQL sans port publié. Logs : `ssh chessbg 'cd /opt/chessbg/src/deploy && docker compose logs -f game'`.
- Sur le VPS : `/opt/chessbg/src` (code déployé, écrasé à chaque déploiement),
  `/opt/chessbg/secrets` (mot de passe BDD), `/opt/chessbg/backups` (dump quotidien 04:30,
  14 jours). Pas encore de copie des sauvegardes hors du VPS.
- Docker contourne ufw pour les ports publiés : ne publier que 7777/udp.

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
- Serveur dédié autoritaire, transport ENet (octobre 2026). Le P2P GodotSteam est écarté
  pour les parties qui comptent : l'hôte pourrait tricher.
- Figurines jouées via un deck de cartes construit par le joueur ; chaque figurine a une
  faction (elfes, nains, démons…) et des stats (attaque, défense) ; déplacement selon des
  dés de mouvement. Le détail reste à définir avec Nicolas.

## Ce qui n'est pas encore décidé (ne pas inventer)

- La liste finale des figurines et leurs stats (voir `src/core/units/data/` pour les
  valeurs provisoires de test).
- Les règles détaillées des cartes, du deck, des factions et des dés de mouvement.
