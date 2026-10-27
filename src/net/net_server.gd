class_name NetServer
extends RefCounted
## Transport ENet côté serveur : accepte les connexions, décode les messages
## entrants et envoie les messages sortants. Aucune logique de jeu ici (voir MatchServer).
## On utilise ENetMultiplayerPeer en paquets bruts, sans RPC : le client ne peut
## donc appeler aucune méthode du serveur, seulement envoyer des messages.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal message_received(peer_id: int, msg: Dictionary)

var _peer: ENetMultiplayerPeer


func start(port: int, max_clients: int = 256) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, max_clients)
	if err != OK:
		_peer = null
		return err
	_peer.peer_connected.connect(peer_connected.emit)
	_peer.peer_disconnected.connect(peer_disconnected.emit)
	return OK


func is_running() -> bool:
	return _peer != null


## À appeler régulièrement (chaque frame) : traite le réseau et émet les signaux.
func poll() -> void:
	if _peer == null:
		return
	_peer.poll()
	while _peer != null and _peer.get_available_packet_count() > 0:
		var from := _peer.get_packet_peer()
		var msg := Protocol.decode(_peer.get_packet(), Protocol.MAX_CLIENT_PACKET_BYTES)
		if msg.is_empty():
			# Message illisible ou trop gros : un client honnête n'envoie jamais ça.
			_peer.disconnect_peer(from)
			continue
		message_received.emit(from, msg)


func send(peer_id: int, msg: Dictionary) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(peer_id)
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_peer.put_packet(Protocol.encode(msg))


func stop() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
