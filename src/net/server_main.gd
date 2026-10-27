extends Node
## Point d'entrée du serveur dédié (scène scenes/server.tscn). Lancement :
##   godot --headless --path . res://scenes/server.tscn -- --port=7777
## Relie le transport ENet (NetServer) à la logique de jeu (MatchServer).

var _net := NetServer.new()
var _server := MatchServer.new()


func _ready() -> void:
	# Jeu au tour par tour : inutile de tourner à fond, on économise le CPU du VPS.
	Engine.max_fps = 30
	OS.low_processor_usage_mode = true

	var port := _port_from_args(OS.get_cmdline_user_args())
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
	for a in args:
		if a.begins_with("--port="):
			var p := a.trim_prefix("--port=").to_int()
			if p > 0 and p < 65536:
				return p
	return Protocol.DEFAULT_PORT


func _log(text: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(), text])
