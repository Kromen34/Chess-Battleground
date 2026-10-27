class_name GameController
extends Node3D
## Boucle de jeu, en deux modes :
## - local (solo hors ligne, hot-seat) : le GameState et les IA tournent ici, via Rules ;
## - en ligne : le serveur dédié fait autorité. On lui envoie les actions et on
##   applique à notre copie du GameState les événements qu'il renvoie (StateMirror).
## La vue ne voit pas la différence : elle réagit aux mêmes signaux du GameState.

const MENU_SCENE := "res://scenes/main_menu.tscn"
## Délai entre deux événements rejoués, pour voir le tour de l'IA se dérouler.
const EVENT_DELAY := 0.35

## Adresse du serveur à rejoindre ("" = partie locale). Réglée par le menu avant
## de charger la scène.
static var online_host: String = ""
static var online_port: int = Protocol.DEFAULT_PORT

@export var player_kinds: PackedStringArray = PackedStringArray(["human", "ai"])
@export var seed_value: int = 0

@onready var board_view: BoardView = $BoardView
@onready var hud: Label = $HUD/Status

var state: GameState
var selected_unit: Unit
var _ais: Dictionary = {}  # player -> SimpleAI (mode local uniquement)
var _client: NetClient
## Numéro de joueur attribué par le serveur (mode en ligne).
var _my_player: int = -1
var _event_queue: Array[Dictionary] = []
var _replaying: bool = false


func _ready() -> void:
	if online_host != "":
		_start_online()
	else:
		_start_local()


func _process(_delta: float) -> void:
	if _client != null:
		_client.poll()


func _exit_tree() -> void:
	if _client != null:
		_client.close()


func _is_online() -> bool:
	return _client != null


# --- Mode local ------------------------------------------------------------------

func _start_local() -> void:
	state = MatchSetup.new_match(player_kinds, seed_value)
	if state == null:
		hud.text = "Aucun plateau pour %d joueurs." % player_kinds.size()
		return
	for p in range(state.player_count):
		if state.player_kinds[p] == "ai":
			_ais[p] = SimpleAI.new(p)
	_bind_state()
	_maybe_play_ai()


func _maybe_play_ai() -> void:
	if _is_online() or state.is_over() or not _ais.has(state.current_player):
		return
	# Petit délai pour que l'humain voie le tour de l'IA se jouer.
	await get_tree().create_timer(0.4).timeout
	var ai: SimpleAI = _ais[state.current_player]
	while not state.is_over() and _ais.has(state.current_player):
		var a := ai.choose_action(state)
		var r := Rules.apply(state, state.current_player, a)
		if not r.ok or Actions.type_of(a) == Actions.END_TURN:
			break
		await get_tree().create_timer(EVENT_DELAY).timeout
	if not state.is_over() and _ais.has(state.current_player):
		Rules.apply(state, state.current_player, Actions.end_turn())


# --- Mode en ligne ---------------------------------------------------------------

func _start_online() -> void:
	hud.text = "Connexion au serveur %s:%d…" % [online_host, online_port]
	_client = NetClient.new()
	_client.connected.connect(func() -> void: _client.send(Protocol.hello()))
	_client.disconnected.connect(_on_disconnected)
	_client.message_received.connect(_on_server_message)
	var err := _client.connect_to(online_host, online_port)
	if err != OK:
		hud.text = "Connexion impossible (%s). Échap : menu" % error_string(err)


func _on_disconnected() -> void:
	hud.text = "Déconnecté du serveur. Échap : menu"


func _on_server_message(msg: Dictionary) -> void:
	match Protocol.type_of(msg):
		Protocol.WELCOME:
			hud.text = "Connecté, création de la partie…"
			_client.send(Protocol.start_vs_ai())
		Protocol.MATCH_STARTED, Protocol.STATE:
			_load_view(msg)
		Protocol.EVENTS:
			var events: Variant = msg.get("events")
			if typeof(events) == TYPE_ARRAY:
				for e: Variant in events:
					if typeof(e) == TYPE_DICTIONARY:
						_event_queue.append(e)
				_replay_events()
		Protocol.REFUSED:
			hud.text = "Refusé : %s" % msg.get("reason", "?")
		Protocol.ERROR:
			hud.text = "Erreur serveur : %s" % msg.get("reason", "?")


func _load_view(msg: Dictionary) -> void:
	var view: Variant = msg.get("state")
	var s: GameState = StateMirror.state_from_view(view) if typeof(view) == TYPE_DICTIONARY else null
	if s == null:
		hud.text = "État reçu du serveur illisible."
		return
	_my_player = int(msg.get("player", -1))
	state = s
	selected_unit = null
	_event_queue.clear()
	_bind_state()


## Rejoue les événements du serveur un par un, avec un délai pour suivre l'action.
func _replay_events() -> void:
	if _replaying:
		return
	_replaying = true
	while not _event_queue.is_empty():
		var e: Dictionary = _event_queue.pop_front()
		if not StateMirror.apply_event(state, e):
			# Notre copie ne correspond plus au serveur : on redemande l'état complet.
			_event_queue.clear()
			_client.send(Protocol.sync())
			break
		if String(e.get("e", "")) in ["moved", "attacked"] and not _event_queue.is_empty():
			await get_tree().create_timer(EVENT_DELAY).timeout
	_replaying = false
	_update_highlights()
	_refresh_hud()


# --- Commun ----------------------------------------------------------------------

func _bind_state() -> void:
	board_view.bind(state)
	if not board_view.cell_clicked.is_connected(_on_cell_clicked):
		board_view.cell_clicked.connect(_on_cell_clicked)
		board_view.unit_clicked.connect(_on_unit_clicked)
	state.turn_started.connect(func(_p: int, _t: int) -> void: _refresh_hud(); _maybe_play_ai())
	state.game_over.connect(func(w: int) -> void: hud.text = "Victoire du joueur %d !" % w)
	_refresh_hud()


func _submit(action: Dictionary) -> void:
	if _is_online():
		# Le serveur décide ; on attend ses événements pour mettre la vue à jour.
		_client.send(Protocol.action(action))
		return
	var r := Rules.apply(state, state.current_player, action)
	if not r.ok:
		hud.text = "Refusé : %s" % r.reason
	else:
		_refresh_hud()
	if Actions.type_of(action) != Actions.END_TURN:
		_update_highlights()


## Vrai quand le joueur local ne peut pas agir : tour de l'IA ou de l'adversaire,
## ou événements du serveur en cours de lecture.
func _is_input_locked() -> bool:
	if state == null or state.is_over() or _replaying:
		return true
	if _is_online():
		return state.current_player != _my_player
	return _ais.has(state.current_player)


func _on_unit_clicked(unit_id: int) -> void:
	if _is_input_locked():
		return
	var u := state.get_unit(unit_id)
	if u.owner == state.current_player:
		selected_unit = u
		_update_highlights()
	elif selected_unit != null:
		_submit(Actions.attack(selected_unit.id, u.id))


func _on_cell_clicked(cell_id: StringName) -> void:
	if _is_input_locked() or selected_unit == null:
		return
	_submit(Actions.move(selected_unit.id, cell_id))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	if event.is_action_pressed("ui_accept") and not _is_input_locked():
		selected_unit = null
		_submit(Actions.end_turn())
		_update_highlights()


func _update_highlights() -> void:
	if state == null or selected_unit == null or not selected_unit.is_alive():
		board_view.highlight_cells([])
		return
	board_view.highlight_cells(Rules.reachable_cells(state, selected_unit).keys())


func _refresh_hud() -> void:
	if state.is_over():
		return
	var kind: String = state.player_kinds[state.current_player]
	var where := " · en ligne" if _is_online() else ""
	hud.text = "Tour %d — Joueur %d (%s)%s\nClic figurine : sélectionner · clic case : déplacer · clic ennemi : attaquer · Entrée : fin de tour · Échap : menu" % [state.turn_number, state.current_player, kind, where]
