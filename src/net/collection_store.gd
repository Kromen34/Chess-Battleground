class_name CollectionStore
extends RefCounted
## Où vivent les collections de cartes des joueurs, indexées par SteamID.
## Cette version de base les garde en mémoire (tests, serveur local) : tout est perdu
## à l'arrêt. En production : PostgrestCollectionStore (PostgreSQL).

## Cartes données à chaque nouveau joueur, { "id": nombre }. Vide en production :
## un joueur commence sans rien (les boosters offerts au départ viendront plus tard).
var starter: Dictionary = {}

## steam_id -> CardCollection
var _collections: Dictionary = {}


## Appelle [done] avec la CardCollection du joueur, ou null si elle est illisible
## (BDD indisponible). Un joueur inconnu a une collection vide.
func load_collection(steam_id: int, done: Callable) -> void:
	if not _collections.has(steam_id):
		_collections[steam_id] = CardCollection.from_dict(starter)
	done.call(CardCollection.from_dict((_collections[steam_id] as CardCollection).to_dict()))
