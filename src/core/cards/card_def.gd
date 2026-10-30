class_name CardDef
extends Resource
## Une carte à collectionner. Données pures, éditables en .tres (un fichier par carte
## dans src/core/cards/data/). Provisoire : le modèle de carte (stats, faction, rareté…)
## sera défini avec Nicolas ; pour l'instant une carte = une figurine.

## Identifiant stable, stocké en BDD dans la collection de chaque joueur :
## ne jamais renommer celui d'une carte déjà distribuée.
@export var id: StringName = &""
@export var display_name: String = ""
## Regroupement dans l'écran Collection (comme les familles de la galerie).
@export var family: String = ""

@export_group("Visuel")
## Figurine de la carte. Utilisé par la vue uniquement (le serveur n'a pas les modèles).
@export_file("*.glb") var model_path: String = ""
