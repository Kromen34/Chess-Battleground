extends Node
## Point d'entrée du serveur dédié (scène scenes/server.tscn). Lancement :
##   godot --headless --path . res://scenes/server.tscn -- --port=7777
## Relie le transport ENet (NetServer) à la logique de jeu (MatchServer).
## Options :
##   --db-url=http://postgrest:3000  collections dans PostgreSQL (sinon en mémoire)
##   --dev        serveur local : croit le SteamID annoncé par le client (jamais en production)
##   --dev-cards  serveur local : chaque joueur reçoit une partie des cartes, pour tester
## Variable d'environnement STEAM_WEB_API_KEY : vérification des tickets Steam (production).

var _net := NetServer.new()
const SteamServiceScript := preload("res://src/platform/steam_service.gd")

var _server := MatchServer.new()
var _http := HttpJson.new()


func _ready() -> void:
	# Jeu au tour par tour : inutile de tourner à fond, on économise le CPU du VPS.
	Engine.max_fps = 30
	OS.low_processor_usage_mode = true

	var args := OS.get_cmdline_user_args()
	var port := _port_from_args(args)
	add_child(_http)
	_setup_accounts(args)
	var err := _net.start(port)
	if err != OK:
		push_error("Serveur : impossible d'écouter sur le port %d (%s)" % [port, error_string(err)])
		get_tree().quit(1)
		return
	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)
	_net.message_received.connect(_server.handle_message)
	_server.message_out.connect(_net.send)
	_server.match_finished.connect(_on_match_finished)
	_log("Serveur Chess Battleground à l'écoute sur le port %d (protocole v%d)" % [port, Protocol.VERSION])


## Choisit comment reconnaître les joueurs et où ranger leurs collections.
func _setup_accounts(args: PackedStringArray) -> void:
	var key := OS.get_environment("STEAM_WEB_API_KEY")
	if args.has("--dev"):
		_server.auth = DevPlayerAuth.new()
		_log("Mode --dev : SteamID des clients cru sur parole, à n'utiliser qu'en local")
	elif key != "":
		_server.auth = SteamWebAuth.new(_http, key, int(ProjectSettings.get_setting(SteamServiceScript.APP_ID_SETTING, 0)))
	else:
		_log("STEAM_WEB_API_KEY absente : joueurs non authentifiés, collections indisponibles")

	var db_url := _arg_value(args, "--db-url=")
	if db_url != "":
		_server.collections = PostgrestCollectionStore.new(_http, db_url)
		_log("Collections dans PostgreSQL (via %s)" % db_url)
	else:
		_log("Collections en mémoire : perdues à l'arrêt du serveur")
	if args.has("--dev-cards"):
		_server.collections.starter = dev_starter(CardCatalog.load_dir())


## Pour tester l'écran Collection : une carte sur deux, de 1 à 3 exemplaires.
static func dev_starter(catalog: CardCatalog) -> Dictionary:
	var out: Dictionary = {}
	var i := 0
	for family in catalog.families():
		for card in catalog.cards_of(family):
			if i % 2 == 0:
				out[String(card.id)] = i % 3 + 1
			i += 1
	return out


func _process(_delta: float) -> void:
	_net.poll()


func _exit_tree() -> void:
	_net.stop()


func _on_peer_connected(peer_id: int) -> void:
	_server.peer_connected(peer_id)
	_log("Connexion du client %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_server.peer_disconnected(peer_id)
	_log("Déconnexion du client %d (%d partie(s) en cours)" % [peer_id, _server.match_count()])


func _on_match_finished(match_id: int, winner: int, _peers: Dictionary) -> void:
	_log("Partie %d terminée, vainqueur : joueur %d" % [match_id, winner])


static func _port_from_args(args: PackedStringArray) -> int:
	var p := _arg_value(args, "--port=").to_int()
	return p if p > 0 and p < 65536 else Protocol.DEFAULT_PORT


static func _arg_value(args: PackedStringArray, prefix: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return ""


func _log(text: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(), text])
