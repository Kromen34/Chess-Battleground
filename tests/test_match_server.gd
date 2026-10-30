extends TestCase
## Logique du serveur dédié, sans réseau. Les messages passent quand même par
## encode/decode pour reproduire la conversion JSON (nombres en float).

const PEER := 42

var server: MatchServer
## Messages reçus par chaque client : peer_id -> Array[Dictionary]
var inbox: Dictionary = {}
var finished: Array = []


func setup() -> void:
	server = MatchServer.new()
	server.seed_rng.seed = 1234
	inbox = {}
	finished = []
	server.message_out.connect(_on_message_out)
	# Méthodes et non lambdas : une lambda garderait le test en vie (cycle de références).
	server.match_finished.connect(_on_match_finished)


func _on_message_out(peer_id: int, msg: Dictionary) -> void:
	if not inbox.has(peer_id):
		inbox[peer_id] = []
	inbox[peer_id].append(Protocol.decode(Protocol.encode(msg), Protocol.MAX_SERVER_PACKET_BYTES))


func _on_match_finished(match_id: int, winner: int, _peers: Dictionary) -> void:
	finished.append([match_id, winner])


func _send(peer_id: int, msg: Dictionary) -> void:
	server.handle_message(peer_id, Protocol.decode(Protocol.encode(msg), Protocol.MAX_CLIENT_PACKET_BYTES))


func _take(peer_id: int) -> Array:
	var out: Array = inbox.get(peer_id, [])
	inbox[peer_id] = []
	return out


func _last(peer_id: int) -> Dictionary:
	var msgs: Array = inbox.get(peer_id, [])
	return msgs.back() if not msgs.is_empty() else {}


## Connecte un client et démarre une partie contre l'IA. Retourne le message MATCH_STARTED.
func _join_vs_ai(peer_id: int = PEER) -> Dictionary:
	server.peer_connected(peer_id)
	_send(peer_id, Protocol.hello())
	_send(peer_id, Protocol.start_vs_ai())
	for m: Dictionary in _take(peer_id):
		if Protocol.type_of(m) == Protocol.MATCH_STARTED:
			return m
	return {}


func test_hello_is_required_first() -> void:
	server.peer_connected(PEER)
	_send(PEER, Protocol.start_vs_ai())
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.ERROR)
	assert_eq(server.match_count(), 0)


func test_wrong_version_is_rejected() -> void:
	server.peer_connected(PEER)
	_send(PEER, {"t": Protocol.HELLO, "version": Protocol.VERSION + 1})
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.ERROR)
	_send(PEER, Protocol.start_vs_ai())
	assert_eq(server.match_count(), 0, "toujours pas de hello valide")


func test_start_vs_ai_sends_view_without_rng_secrets() -> void:
	var started := _join_vs_ai()
	assert_false(started.is_empty(), "MATCH_STARTED reçu")
	assert_eq(int(started["player"]), 0)
	var view: Dictionary = started["state"]
	assert_false(view.has("seed"), "la graine ne doit pas quitter le serveur")
	assert_false(view.has("rng_state"), "l'état du RNG ne doit pas quitter le serveur")
	assert_eq(server.match_count(), 1)
	assert_not_null(StateMirror.state_from_view(view))


func test_cannot_start_two_matches() -> void:
	_join_vs_ai()
	_send(PEER, Protocol.start_vs_ai())
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.ERROR)
	assert_eq(server.match_count(), 1)


func test_cannot_command_the_ai_units() -> void:
	_join_vs_ai()
	var m := server.get_match(1)
	# Le client (joueur 0) essaie de bouger une figurine de l'IA vers une case qui
	# lui serait accessible : le serveur doit refuser, l'unité ne lui appartient pas.
	var ai_unit: Unit = m.state.units_of(1)[3]
	var before := ai_unit.cell_id
	var reach := Rules.reachable_cells(m.state, ai_unit)
	assert_false(reach.is_empty(), "l'unité de l'IA a des cases accessibles")
	_send(PEER, Protocol.action(Actions.move(ai_unit.id, reach.keys()[0])))
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.REFUSED)
	assert_eq(ai_unit.cell_id, before)


func test_malformed_action_is_refused() -> void:
	_join_vs_ai()
	_send(PEER, {"t": Protocol.ACTION, "action": {"type": "move", "unit": {"x": 1}, "to": 3}})
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.REFUSED)
	_send(PEER, {"t": Protocol.ACTION, "action": "end_turn"})
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.REFUSED)


func test_end_turn_makes_the_ai_play_and_sends_events() -> void:
	_join_vs_ai()
	_send(PEER, Protocol.action(Actions.end_turn()))
	var msg := _last(PEER)
	assert_eq(Protocol.type_of(msg), Protocol.EVENTS)
	var kinds: Array = (msg["events"] as Array).map(func(e: Dictionary) -> String: return e["e"])
	assert_true(kinds.count("turn_started") >= 2, "tour de l'IA puis retour au joueur : %s" % [kinds])
	assert_eq(server.get_match(1).state.current_player, 0, "l'IA a fini son tour")


## Partie complète : le client joue avec une IA sur SA copie, applique les événements
## du serveur, et sa copie doit rester identique à la vue du serveur à chaque étape.
func test_client_mirror_stays_in_sync_until_game_over() -> void:
	var started := _join_vs_ai()
	var mirror := StateMirror.state_from_view(started["state"])
	var brain := SimpleAI.new(0)
	var m := server.get_match(1)
	var safety := 0
	while not mirror.is_over() and safety < 2000:
		safety += 1
		_send(PEER, Protocol.action(brain.choose_action(mirror)))
		for msg: Dictionary in _take(PEER):
			assert_eq(Protocol.type_of(msg), Protocol.EVENTS, "action refusée : %s" % [msg])
			for e: Dictionary in msg.get("events", []):
				assert_true(StateMirror.apply_event(mirror, e), "événement inapplicable : %s" % [e])
		if not m.state.is_over():
			assert_eq(mirror.to_view_dict(0), m.state.to_view_dict(0), "copie désynchronisée")
		if not errors.is_empty():
			return
	assert_true(mirror.is_over(), "la partie doit se terminer")
	assert_eq(mirror.winner, m.state.winner)
	assert_eq(finished, [[1, m.state.winner]], "match_finished émis une fois")
	assert_eq(server.match_count(), 0, "partie terminée supprimée")


func test_sync_resends_state() -> void:
	_join_vs_ai()
	_send(PEER, Protocol.sync())
	var msg := _last(PEER)
	assert_eq(Protocol.type_of(msg), Protocol.STATE)
	assert_false((msg["state"] as Dictionary).has("seed"))


func test_disconnect_removes_vs_ai_match() -> void:
	_join_vs_ai()
	server.peer_disconnected(PEER)
	assert_eq(server.match_count(), 0)
	_send(PEER, Protocol.hello())
	assert_false(inbox.get(PEER, []).any(func(m: Dictionary) -> bool: return Protocol.type_of(m) == Protocol.WELCOME),
		"un client déconnecté n'a plus de session")


# --- Comptes et collections -------------------------------------------------------

## Connecte un client authentifié par DevPlayerAuth sous [steam_id]. Retourne le WELCOME.
func _hello_as(steam_id: int, peer_id: int = PEER) -> Dictionary:
	server.auth = DevPlayerAuth.new()
	server.peer_connected(peer_id)
	_send(peer_id, Protocol.hello("", steam_id))
	return _last(peer_id)


func test_default_auth_makes_guests() -> void:
	server.peer_connected(PEER)
	_send(PEER, Protocol.hello("", 76561197960287930))
	var welcome := _last(PEER)
	assert_eq(Protocol.type_of(welcome), Protocol.WELCOME)
	assert_eq(Protocol.parse_steam_id(welcome.get("steam_id")), 0, "SteamID annoncé non cru sans vérification")
	_send(PEER, Protocol.get_collection())
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.ERROR, "pas de collection pour un invité")


func test_collection_of_authenticated_player() -> void:
	var big := 76561197960287930
	server.collections.starter = {"onixia": 2}
	var welcome := _hello_as(big)
	assert_eq(Protocol.parse_steam_id(welcome.get("steam_id")), big)
	_send(PEER, Protocol.get_collection())
	var msg := _last(PEER)
	assert_eq(Protocol.type_of(msg), Protocol.COLLECTION)
	assert_eq(CardCollection.from_dict(msg.get("cards")).to_dict(), {"onixia": 2})


func test_collections_are_per_player() -> void:
	_hello_as(111, 1)
	_hello_as(222, 2)
	# Simule un gain de cartes pour le joueur 111 seulement.
	server.collections.load_collection(111, _ignore)
	(server.collections._collections[111] as CardCollection).add(&"onixia")
	_send(1, Protocol.get_collection())
	_send(2, Protocol.get_collection())
	assert_eq(CardCollection.from_dict(_last(1).get("cards")).count_of(&"onixia"), 1)
	assert_eq(CardCollection.from_dict(_last(2).get("cards")).count_of(&"onixia"), 0)


func _ignore(_c: CardCollection) -> void:
	pass


func test_second_hello_is_refused() -> void:
	_hello_as(111)
	_send(PEER, Protocol.hello("", 222))
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.ERROR, "on ne change pas d'identité en cours de session")


func test_messages_wait_for_authentication() -> void:
	var pending := PendingAuth.new()
	server.auth = pending
	server.peer_connected(PEER)
	_send(PEER, Protocol.hello())
	_send(PEER, Protocol.get_collection())
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.ERROR, "rien avant la fin de la vérification")
	pending.finish(333)
	assert_eq(Protocol.type_of(_last(PEER)), Protocol.WELCOME)


func test_disconnect_during_authentication() -> void:
	var pending := PendingAuth.new()
	server.auth = pending
	server.peer_connected(PEER)
	_send(PEER, Protocol.hello())
	server.peer_disconnected(PEER)
	_take(PEER)
	pending.finish(333)
	assert_true(_take(PEER).is_empty(), "rien envoyé à un client parti")


## Vérification qui ne répond que quand le test appelle finish() (comme une requête HTTP).
class PendingAuth extends PlayerAuth:
	var _done: Callable

	func authenticate(_hello: Dictionary, done: Callable) -> void:
		_done = done

	func finish(steam_id: int) -> void:
		# On lâche le rappel : il référence le serveur, qui référence cette vérification.
		var done := _done
		_done = Callable()
		done.call(steam_id)
