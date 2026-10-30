class_name PostgrestCollectionStore
extends CollectionStore
## Collections stockées dans PostgreSQL, lues via PostgREST (conteneur de la stack,
## sans port publié). Godot n'a pas de pilote PostgreSQL : PostgREST expose les tables
## du schéma « api » en HTTP. Schéma et droits : deploy/db/*.sql. Le rôle du serveur
## de jeu (game_server) ne peut que lire les collections pour l'instant.

var _http: HttpJson
var _base_url: String


func _init(http: HttpJson, base_url: String) -> void:
	_http = http
	_base_url = base_url.trim_suffix("/")


func load_collection(steam_id: int, done: Callable) -> void:
	var url := "%s/card_collection?steam_id=eq.%d&select=card_id,quantity" % [_base_url, steam_id]
	_http.request(url, func(code: int, data: Variant) -> void:
		if code != 200:
			push_warning("PostgREST : lecture de la collection %d impossible (HTTP %d) %s"
					% [steam_id, code, JSON.stringify(data)])
			done.call(null)
			return
		done.call(collection_from_rows(data)))


## [{"card_id": "x", "quantity": 2}, ...] -> CardCollection. null si ce n'est pas une liste.
static func collection_from_rows(data: Variant) -> CardCollection:
	if typeof(data) != TYPE_ARRAY:
		return null
	var counts: Dictionary = {}
	for row: Variant in data:
		if typeof(row) == TYPE_DICTIONARY and typeof((row as Dictionary).get("card_id")) == TYPE_STRING:
			counts[row["card_id"]] = (row as Dictionary).get("quantity")
	return CardCollection.from_dict(counts)
