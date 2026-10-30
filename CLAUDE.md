# Chess Battleground — guide pour les sessions Claude Code

Jeu de plateau tactique en 3D (Godot 4.3, GDScript), tour par tour, publié sur Steam.
1v1 uniquement (PvP ou PvE), sur un plateau 8×8 avec une zone de spawn de 8×2 par
joueur. Le plateau reste modélisé comme un **graphe de cases**, jamais comme une
grille 8×8 en dur (obstacles, variantes de plateau futures).

Ce fichier est lu par chaque session Claude Code, sur chaque PC. Il doit rester
court et à jour : si tu changes une convention, mets-la à jour ici.

## Où on en est (mis à jour le 30/10/2026)

À relire en début de session : c'est la mémoire partagée entre les PC.

**Fait :**
- Cœur du jeu : plateau-graphe 8×8, 4 figurines provisoires, règles, IA de référence,
  scène 3D placeholder (`scenes/main.tscn`).
- Menu principal (`scenes/main_menu.tscn`, scène de démarrage) : « Jouer contre l'IA »,
  « Quitter », pseudo + avatar Steam en haut à droite (validé : ça marche). Échap en partie → menu.
- Projet renommé **Chess Battleground** (ex-TD Battleground), dépôt `Kromen34/Chess-Battleground`.
- `tests.sh` : télécharge Godot sous Windows aussi ; premier import GodotSteam débloqué.
- Serveur dédié : partie contre l'IA jouée entièrement côté serveur, client en ENet,
  bouton « Jouer contre l'IA (serveur) ».
- VPS OVH en service (voir « Serveur dédié ») : serveur + PostgreSQL en Docker, le bouton
  « Jouer contre l'IA (serveur) » s'y connecte.
- Décor « soirée jeu de rôle au salon » (`src/view/tabletop_decor.gd`) : plateau en bois
  posé sur une table **laissée libre** (Nicolas y mettra compteurs, dés, cartes : ne pas
  y ajouter d'accessoires), suspension, chaises, tapis, parquet, bibliothèque, fenêtre.
  Le premier jet « champ de bataille » a été jugé moche et abandonné.
- Caméra (`src/view/camera_rig.gd`) : molette = zoom, clic droit enfoncé = rotation,
  clic gauche enfoncé = avancer/reculer, clic molette = vue de départ. Les clics du
  plateau sont pris au **relâchement** (un glisser de caméra avale le relâchement).
- Menu Options graphiques (`src/ui/options_menu.gd` + autoload `GraphicsSettings`).
- Figurines : les 14 variantes de dragons Artisan Guild (kits d'assaut A à D sauvage /
  harnaché / monté, Azgrathok 1 ou 5 têtes) dans `Figurines/Dragons/`, détaillées
  (350-500k triangles, LOD Godot) avec lavis des creux. Nicolas trie celles qu'il garde.
- Les 23 variantes de draconiens, elles aussi dans `Figurines/Dragons/` (même famille) (Shock Troops A à F ailé /
  sans ailes, Commander Drakvarr, Flamagath Blackflame, Onixia), 300-400k triangles.
  Toutes les figurines du pack Draconian Scourge sont faites (37 en tout).
- Galerie des figurines (`scenes/figurine_gallery.tscn`, bouton du menu ; 29/10, branche
  `feat/galerie-familles` partie de `feat/steampipe`, pas encore fusionnée) : panneau des familles
  à gauche (↑ ↓) et liste cliquable des figurines de la famille (← →), clic enfoncé pour tourner,
  molette pour zoomer. Pas encore vue à l'écran par Nicolas (mise en page à valider).
  Une famille = un dossier de `res://Figurines/` (sous-dossiers compris) ; une nouvelle famille
  = un nouveau dossier, rien à coder. Suppr / « Mettre de côté » déplace le .glb (et son .import)
  dans `<famille>/En attente/`, que la galerie ignore (case « Voir les figurines en attente »
  pour les remettre) : c'est le tri de Nicolas, rien n'est effacé. Désactivé dans un jeu exporté.
- Steam (29/10, branche `feat/steampipe`, partie de `feat/details-figurines`, pas encore fusionnée) :
  Steam Direct payé, app **Chess Battleground 4303740**, package 1505054 (renommé), dépôt
  Windows 4303742. Première build envoyée avec `tools/envoyer_build_steam.sh` (BuildID
  26298844), mise en ligne sur la branche default. Jeu non publié (page du store non soumise).
  En cours : le client Steam n'installait rien (dépôt pas encore ajouté au package 1505054) ;
  vérifier que l'installation depuis la bibliothèque marche après l'ajout.
- Collection de cartes par joueur (30/10, branche `feat/collection` partie de `feat/galerie-familles`,
  pas encore fusionnée ni déployée) : écran « Collection » au menu (`scenes/collection.tscn`), tout le
  catalogue, cartes possédées avec « ×N », les autres grisées (figurine en silhouette), consultation seule.
  Un joueur commence **sans aucune carte** (Nicolas offrira des boosters au départ, plus tard).
  Collection stockée sur le serveur par SteamID **vérifié** : le client joint un ticket Steam Web API
  à HELLO, le serveur le fait valider par l'API Web Steam (`SteamWebAuth`). Catalogue provisoire : une
  carte = une figurine (les 21 dragons gardés), en attendant le modèle de carte de Nicolas.
  Reste à faire pour la production : clé Web API éditeur (Steamworks) dans
  `/opt/chessbg/secrets/steam.env` (`STEAM_WEB_API_KEY=...`), puis `bash tools/deployer_serveur.sh`.
- Tests : 84 tests verts (`./tests.sh`).

**Reprise le 30/10 :** d'abord la galerie (`feat/galerie-familles`) : Nicolas la teste, trie ses
figurines avec « Mettre de côté », on ajuste la mise en page si besoin. Attention : Cavalier et
Gardien utilisent `dragon_a_lancier` / `dragon_a_sauvage` (cylindres s'ils sont mis de côté).
On travaille en local pour l'instant, pas de nouvel envoi sur Steam.

**Après la collection :** la galerie déplace les .glb mis de côté, ce qui force Godot à les
réimporter (cache indexé par chemin) : noter la mise de côté dans une liste au lieu de déplacer.

**Ensuite :** le **JcJ 1v1** sur le serveur, branche `feat/pvp` :
mise en relation (file d'attente ou code de partie), `ServerMatch` avec deux joueurs humains au
lieu de l'IA, bouton « Jouer contre un ami » au menu, et deux fenêtres du jeu sans Steam sur un
même PC pour tester. Ensuite : clé Steam pour un 2e compte (`Demander des clés Steam` dans
Steamworks ; deux clients Steam ne tournent pas sur un même PC). Clé à un ami = distribution des
figurines : pas sans licence écrite d'Artisan Guild.

**Prochaines étapes du serveur :** boosters (fonction SQL d'ajout atomique, pas de droit d'écriture
libre ; paiement via Steam ; boosters payants aléatoires = loot boxes : taux affichés, interdits en
Belgique), decks, points, stats des figurines servies par le serveur.

**Prochaines pistes (au choix de Nicolas) :** associer les dragons retenus aux unités,
système de cartes/deck, factions et stats, dés de mouvement, compteurs sur la table.

**Prévu (Nicolas, 28/10) :** passer le dépôt en privé (GitHub Pro), puis versionner
`Figurines/` en Git LFS : retirer `Figurines/` du `.gitignore`, ajouter `*.glb` au suivi LFS
s'il n'y est pas, vérifier avec `git lfs ls-files` avant de pousser. **Pas avant** que le
dépôt soit privé (sinon = distribution des modèles sous licence).

**Idée à long terme :** outil de peinture des figurines dans le jeu, style Photoshop (pas
Paint) : dépliage UV (xatlas) dans `assembler_figurine.py`, peinture projetée écran -> texture,
calques, pinceaux, pression tablette, canaux métal / brillance, et pinceaux de figuriniste
qui exploitent creux et arêtes (lavis, brossage à sec). À concevoir avec Nicolas.

À décider : passer le dépôt en privé pour versionner les modèles (LFS), mail de
demande de licence jeu vidéo à Artisan Guild.

**Mettre en route un nouveau PC :**
1. `git clone https://github.com/Kromen34/Chess-Battleground.git` puis `git lfs install && git lfs pull`
   (sinon les DLL de GodotSteam sont des pointeurs LFS et Steam ne marche pas).
   Ancien clone : `git remote set-url origin https://github.com/Kromen34/Chess-Battleground.git`.
2. `bash tests.sh` (Git Bash) : télécharge Godot 4.3 dans `tools/bin/` et lance les tests.
3. Jouer : double-clic sur `Lancer_le_jeu.cmd` (`-e` : l'éditeur), ou éditeur Godot 4.3 → F5. Le client Steam doit être lancé et connecté avant le jeu.
   PC sans carte graphique (Vulkan/D3D12 absents, ex. VM) : `tools\lancer_sans_gpu.bat`
   (`-e` pour l'éditeur). Godot 4.3 ne bascule pas seul en OpenGL (seulement à partir de 4.4).
4. Sans `gh` : les PR se font via l'API GitHub avec le jeton de Git Credential Manager.
5. Figurines (absentes de git, voir « Figurines ») : `pip install pymeshlab numpy`, puis les
   regénérer depuis les STL du Google Drive de Nicolas, pour chaque kit :
   `python tools/assembler_figurine.py tools/kits/<kit>.json` (+ le dossier des STL en 2e
   argument si le Drive n'est pas sur `I:`, `-` sinon ; + des noms de variantes pour n'en
   faire que certaines). Sans elles, le jeu
   affiche des cylindres à la place.
6. Identité git : `git config user.name "Rips Nico"` et `git config user.email "kromen34@hotmail.com"`.

## Figurines

- Source : kits STL d'impression **Artisan Guild** (Draconian Scourge, juin 2023) sur le
  Google Drive de Nicolas : `I:\Mon Drive\3D\Miniatures\Artisan guild\...`. Ne pas utiliser
  les `.blend` / `.fbx` qui s'y trouvent (essais ratés de Nicolas).
- **Licence** : le PDF fourni par Artisan Guild limite l'usage au personnel et interdit les
  jeux ; Nicolas dit avoir des droits commerciaux. Tant qu'une licence couvrant le jeu vidéo
  n'est pas confirmée par écrit, `Figurines/` (et l'ancien `assets/models/draconian/`) reste dans `.gitignore` (le
  dépôt est public : pousser les modèles = les distribuer). Ne jamais les commiter.
- `tools/assembler_figurine.py` (numpy + pymeshlab) : les pièces d'un kit partagent le même
  repère, on les fusionne telles quelles ; allègement par fusion d'arêtes à quadriques
  (350k triangles par dragon, 500k pour Azgrathok ; Godot fait les LOD à l'import) ;
  socle = 0,85 case, figurine tournée vers -Z. Lavis en couleurs de sommets : occlusion
  ambiante (GPU) sur la figurine entière + creux fins assombris, arêtes éclaircies.
- Un fichier par kit dans `tools/kits/` : pièces (fichier, matériau, `weight` = part de
  triangles en plus, ex. ailes) et variantes (liste de pièces) -> un GLB par variante dans
  `Figurines/<output_dir>/` (dossier = famille dans la galerie : Dragons pour tout Draconian Scourge). Dragons B et D : socle modélisé ailleurs, `"snap_under": true` le recale
  sous les pattes (vérifier les socles au rendu pour tout nouveau kit).
  Armes à rotule (boule au poignet, creux au bout du bras) parfois mal placées dans leur
  fichier (lance du draconien A) : `"fit_balljoint": true` sur la pièce détecte boules et
  creux (même rayon) et déplace l'arme pour qu'ils s'emboîtent. Pour repérer une arme mal
  placée : distance mini arme / porteur, ~0,01 mm quand c'est bon.
- Matériaux : couleurs unies (un STL n'a pas de textures) multipliées par le lavis. Le nœud
  `base` du GLB prend la couleur de l'équipe dans `BoardView` (en gardant le lavis).
- Test provisoire : Cavalier = `dragon_a_lancier`, Gardien = `dragon_a_sauvage` (`model_path` des `.tres`).
- Vérifier un modèle sans lancer le jeu : `tools/rendu_figurine.gd` (4 angles dans un PNG,
  voir l'en-tête ; importer d'abord avec `godot --headless --path . --editor --quit`).

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
  cards/          CardDef (.tres dans cards/data/, un par carte), CardCatalog, CardCollection
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
  player_auth.gd  Identité des clients : SteamWebAuth (prod), DevPlayerAuth (--dev, local)
  collection_store.gd  Collections en mémoire ; PostgrestCollectionStore (prod, PostgreSQL)
  http_json.gd    Requêtes HTTP du serveur (API Web Steam, PostgREST)
  server_main.gd  Point d'entrée de scenes/server.tscn
src/ai/           IA PvE. Un joueur comme un autre : reçoit un GameState, renvoie une Action.
src/view/         Rendu 3D : lit le GameState, ne le modifie jamais directement.
  board_view.gd   Cases, figurines (GLB ou cylindre), clics ; signal board_built(bounds)
  tabletop_decor.gd  Table, pièce et lumière, construits autour du plateau
  camera_rig.gd   Caméra orbitale (souris)
src/ui/           Menus et écrans (main_menu.gd = scène de démarrage, options_menu.gd,
                  figurine_gallery.gd, collection_screen.gd ; figurine_stage.gd = présentoir 3D commun)
src/platform/     steam_service.gd : autoload SteamService (init Steam, pseudo, avatar)
                  graphics_settings.gd : autoload GraphicsSettings (user://settings.cfg)
addons/godotsteam GodotSteam 4.15 GDExtension (dernière version compatible Godot 4.3), binaires en LFS
scenes/           Scènes .tscn
assets/           models/ (GLB), textures/, audio/ — tout en Git LFS
tests/            run_tests.gd (runner) + test_*.gd
tools/            get_godot.sh, lancer_sans_gpu.bat, lancer_serveur.bat, deployer_serveur.sh,
                  assembler_figurine.py + kits/, rendu_figurine.gd, envoyer_build_steam.sh
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
- Changement incompatible du protocole : incrémenter `Protocol.VERSION` (v2 : identité Steam, collection).
- Identité : le SteamID d'une session est celui renvoyé par l'API Web Steam pour le ticket du
  HELLO, jamais celui annoncé par le client. Un SteamID voyage en texte (int64 > précision d'un
  nombre JSON). Sans ticket valide : invité (pas de collection). Serveur local `--dev` : SteamID
  annoncé cru sur parole (client `--steam-id=N` pour deux comptes sur un PC), `--dev-cards` : une
  carte sur deux pour chaque joueur. Jamais `--dev` en production.
- Collections : le client n'en reçoit qu'une copie pour l'affichage. Un `card_id` en BDD est
  l'`id` d'un CardDef : ne jamais renommer l'id d'une carte déjà distribuée.
- BDD (PostgreSQL) côté serveur uniquement, jamais accessible par le client. Le serveur Godot y
  accède via PostgREST (conteneur sans port publié, schéma `api`, rôle `game_server` aux droits
  minimaux). Schéma : `deploy/db/NNN_*.sql`, appliqués une fois par `deploy/migrer_bdd.sh` au
  déploiement ; ne jamais modifier une migration déployée, en ajouter une.
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
  `/opt/chessbg/secrets` (mots de passe BDD et PostgREST générés ; `steam.env` = clé Web API à poser à la main), `/opt/chessbg/backups` (dump quotidien 04:30,
  14 jours). Pas encore de copie des sauvegardes hors du VPS.
- Docker contourne ufw pour les ports publiés : ne publier que 7777/udp.

## Steam

- Ne jamais référencer la classe `Steam` directement : passer par `SteamService`, qui utilise
  `Engine.get_singleton("Steam")`. Le jeu et les tests doivent tourner sans Steam ni plugin
  (profil par défaut « Joueur »). En headless, SteamService n'initialise pas Steam.
- AppID : **4303740** (Chess Battleground, Steam Direct payé), réglage `steam/initialization/app_id`
  dans `project.godot`. Le compte doit posséder l'app (licence développeur de l'organisation
  Steamworks), sinon Steam refuse l'init et le jeu prend le profil par défaut. GodotSteam 4.15 : `steamInitEx()` sans argument, et `run_callbacks()`
  appelé à chaque frame par SteamService.
- Envoyer une build : `bash tools/envoyer_build_steam.sh` (Git Bash, dans une vraie fenêtre :
  steamcmd demande mot de passe et Steam Guard). Exporte avec le preset « Windows Desktop »
  (`export_presets.cfg`) dans `build/windows/`, puis SteamPipe vers le dépôt 4303742.
  `--export` : exporte seulement. La mise en ligne (« Set build live ») se fait dans Steamworks.
  Tant que le jeu n'est pas sorti, seuls les comptes de l'organisation et les détenteurs de
  clés y ont accès. La build contient `Figurines/` : pas de clé à des tiers sans licence écrite.

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
- Ambiance : le plateau est posé sur une table de salon, comme une partie de jeu de rôle
  entre amis. Échelle : 1 case = 1 pouce (2,5 cm).
- Réglages graphiques : décrits une seule fois dans `GraphicsSettings.SETTINGS` (le menu
  se construit à partir de cette liste) ; un nouveau réglage s'ajoute là. FSR 2.2 de
  Godot 4.3 émet une erreur bénigne à la fermeture et refuse le TAA : FSR 1.0 par défaut.

## Ce qui n'est pas encore décidé (ne pas inventer)

- La liste finale des figurines et leurs stats (voir `src/core/units/data/` pour les
  valeurs provisoires de test).
- Les règles détaillées des cartes, du deck, des factions et des dés de mouvement.
