class_name MatchServer
extends RefCounted
## Logique du serveur dédié, indépendante du transport (ENet aujourd'hui, autre
## chose demain) : on lui passe les connexions et les messages reçus, elle émet
## les messages à envoyer. Testable sans réseau.
##
## Le serveur fait autorité : le numéro de joueur d'un client vient de sa session,
## jamais du message, et chaque action passe par Rules sur le GameState du serveur.
## De même, son SteamID est celui vérifié par [member auth] à la réception du HELLO.

signal message_out(peer_id: int, msg: Dictionary)
## Émis à la fin d'une partie, avant sa suppression. C'est là qu'on créditera les
## points en BDD. [param peers] : player -> peer_id des humains.
signal match_finished(match_id: int, winner: int, peers: Dictionary)

## Tire la graine de chaque partie. Exposé pour rendre les tests déterministes.
var seed_rng := RandomNumberGenerator.new()
## Vérifie l'identité Steam des clients. Par défaut, personne n'est reconnu (invités).
var auth := PlayerAuth.new()
## Collections de cartes des joueurs. Par défaut en mémoire.
var collections := CollectionStore.new()
## peer_id -> {"ready": bool, "authenticating": bool, "steam_id": int (0 = invité),
## "match": int, "player": int}
var _sessions: Dictionary = {}
## match_id -> ServerMatch
var _matches: Dictionary = {}
var _next_match_id: int = 1


func _init() -> void:
	seed_rng.randomize()


func match_count() -> int:
	return _matches.size()


func get_match(match_id: int) -> ServerMatch:
	return _matches.get(match_id) as ServerMatch


func peer_connected(peer_id: int) -> void:
	_sessions[peer_id] = {"ready": false, "authenticating": false, "steam_id": 0, "match": -1, "player": -1}


func peer_disconnected(peer_id: int) -> void:
	var session: Dictionary = _sessions.get(peer_id, {})
	_sessions.erase(peer_id)
	var m := get_match(int(session.get("match", -1)))
	if m == null:
		return
	m.peers.erase(int(session["player"]))
	# Contre l'IA, la partie est abandonnée. En PvP, l'adversaire gagnera par forfait.
	if m.peers.is_empty():
		_matches.erase(m.id)


func handle_message(peer_id: int, msg: Dictionary) -> void:
	if not _sessions.has(peer_id):
		return
	var session: Dictionary = _sessions[peer_id]
	var t := Protocol.type_of(msg)
	if t == Protocol.HELLO:
		_on_hello(peer_id, session, msg)
		return
	if not session["ready"]:
		_send(peer_id, Protocol.error("hello attendu"))
		return
	match t:
		Protocol.START_VS_AI:
			_on_start_vs_ai(peer_id, session)
		Protocol.ACTION:
			_on_action(peer_id, session, msg)
		Protocol.SYNC:
			_on_sync(peer_id, session)
		Protocol.GET_COLLECTION:
			_on_get_collection(peer_id, session)
		_:
			_send(peer_id, Protocol.error("message inconnu : %s" % t))


func _on_hello(peer_id: int, session: Dictionary, msg: Dictionary) -> void:
	if session["ready"] or session["authenticating"]:
		_send(peer_id, Protocol.error("hello déjà reçu"))
		return
	var version: Variant = msg.get("version")
	if not Protocol.is_number(version) or int(version) != Protocol.VERSION:
		_send(peer_id, Protocol.error("version du jeu incompatible, mets le jeu à jour"))
		return
	session["authenticating"] = true
	auth.authenticate(msg, func(steam_id: int) -> void:
		# Le client a pu se déconnecter pendant la vérification du ticket.
		if not is_same(_sessions.get(peer_id), session):
			return
		session["authenticating"] = false
		session["ready"] = true
		session["steam_id"] = steam_id
		_send(peer_id, Protocol.welcome(steam_id)))


func _on_start_vs_ai(peer_id: int, session: Dictionary) -> void:
	if get_match(int(session["match"])) != null:
		_send(peer_id, Protocol.error("déjà en partie"))
		return
	var state := MatchSetup.new_match(PackedStringArray(["human", "ai"]), seed_rng.randi())
	var m := ServerMatch.new(_next_match_id, state)
	_next_match_id += 1
	m.peers[0] = peer_id
	_matches[m.id] = m
	session["match"] = m.id
	session["player"] = 0
	_send(peer_id, {"t": Protocol.MATCH_STARTED, "match": m.id, "player": 0, "state": state.to_view_dict(0)})
	m.play_ai_turns()
	_flush(m)


func _on_action(peer_id: int, session: Dictionary, msg: Dictionary) -> void:
	var m := get_match(int(session["match"]))
	if m == null:
		_send(peer_id, Protocol.error("pas en partie"))
		return
	var action := Protocol.sanitize_action(msg.get("action"))
	if action.is_empty():
		_send(peer_id, {"t": Protocol.REFUSED, "reason": "action mal formée"})
		return
	var r := Rules.apply(m.state, int(session["player"]), action)
	if not r.ok:
		_send(peer_id, {"t": Protocol.REFUSED, "reason": r.reason})
		return
	m.play_ai_turns()
	_flush(m)


func _on_sync(peer_id: int, session: Dictionary) -> void:
	var m := get_match(int(session["match"]))
	if m == null:
		_send(peer_id, Protocol.error("pas en partie"))
		return
	var player := int(session["player"])
	_send(peer_id, {"t": Protocol.STATE, "player": player, "state": m.state.to_view_dict(player)})


func _on_get_collection(peer_id: int, session: Dictionary) -> void:
	var steam_id := int(session["steam_id"])
	if steam_id == 0:
		_send(peer_id, Protocol.error("collection indisponible : lance le jeu depuis Steam"))
		return
	collections.load_collection(steam_id, func(c: CardCollection) -> void:
		if not is_same(_sessions.get(peer_id), session):
			return
		if c == null:
			_send(peer_id, Protocol.error("collection indisponible pour le moment, réessaie plus tard"))
			return
		_send(peer_id, Protocol.collection(c)))


## Envoie les événements en attente à tous les humains de la partie, et clôt
## la partie si elle est terminée.
func _flush(m: ServerMatch) -> void:
	var events := m.take_events()
	if not events.is_empty():
		for player in m.peers.keys():
			_send(m.peers[player], {"t": Protocol.EVENTS, "events": events})
	if m.state.is_over():
		match_finished.emit(m.id, m.state.winner, m.peers.duplicate())
		for player in m.peers.keys():
			var session: Dictionary = _sessions.get(m.peers[player], {})
			session["match"] = -1
			session["player"] = -1
		_matches.erase(m.id)


func _send(peer_id: int, msg: Dictionary) -> void:
	message_out.emit(peer_id, msg)
