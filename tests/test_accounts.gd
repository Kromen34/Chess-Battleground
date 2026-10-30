extends TestCase
## Comptes joueurs : lecture des réponses de l'API Web Steam et de PostgREST (sans
## réseau), stockage des collections en mémoire, ticket Steam.

const SteamServiceScript := preload("res://src/platform/steam_service.gd")


func test_steam_ticket_response_ok() -> void:
	var data: Variant = JSON.parse_string('{"response":{"params":{"result":"OK",'
			+ '"steamid":"76561197960287930","ownersteamid":"76561197960287930",'
			+ '"vacbanned":false,"publisherbanned":false}}}')
	assert_eq(SteamWebAuth.steam_id_from_response(data), 76561197960287930,
			"SteamID lu en texte, sans perte de précision")


func test_steam_ticket_response_refused() -> void:
	var error: Variant = JSON.parse_string('{"response":{"error":{"errorcode":101,"errordesc":"Invalid ticket"}}}')
	assert_eq(SteamWebAuth.steam_id_from_response(error), 0)
	var banned: Variant = JSON.parse_string('{"response":{"params":{"result":"OK",'
			+ '"steamid":"76561197960287930","publisherbanned":true}}}')
	assert_eq(SteamWebAuth.steam_id_from_response(banned), 0, "banni par l'éditeur")
	assert_eq(SteamWebAuth.steam_id_from_response(null), 0)
	assert_eq(SteamWebAuth.steam_id_from_response({"response": "x"}), 0)


func test_postgrest_rows_to_collection() -> void:
	var rows: Variant = JSON.parse_string('[{"card_id":"onixia","quantity":2},'
			+ '{"card_id":"dragon_a_lancier","quantity":1},{"quantity":4},"x"]')
	var c := PostgrestCollectionStore.collection_from_rows(rows)
	assert_eq(c.to_dict(), {"onixia": 2, "dragon_a_lancier": 1})
	assert_eq(PostgrestCollectionStore.collection_from_rows([]).distinct_count(), 0)
	assert_null(PostgrestCollectionStore.collection_from_rows({"message": "erreur"}),
			"une erreur PostgREST n'est pas une collection vide")


func test_memory_store_gives_starter_once() -> void:
	var store := CollectionStore.new()
	store.starter = {"onixia": 1}
	var got: Array = []
	store.load_collection(7, func(c: CardCollection) -> void: got.append(c))
	assert_eq((got[0] as CardCollection).to_dict(), {"onixia": 1})
	(got[0] as CardCollection).add(&"onixia", 5)
	store.load_collection(7, func(c: CardCollection) -> void: got.append(c))
	assert_eq((got[1] as CardCollection).count_of(&"onixia"), 1, "le joueur reçoit une copie")


func test_steam_ticket_to_hex() -> void:
	assert_eq(SteamServiceScript.ticket_to_hex(PackedByteArray([1, 171, 255, 0]), 3), "01abff")
	assert_eq(SteamServiceScript.ticket_to_hex([16, 32], 2), "1020")
	assert_eq(SteamServiceScript.ticket_to_hex(null, 4), "")
