class_name NetClient
extends RefCounted
## Transport ENet côté client : se connecte au serveur, envoie des messages et
## émet ceux reçus. À utiliser avec poll() appelé à chaque frame.

signal connected
## Émis à la déconnexion, ou si la connexion n'a jamais abouti.
signal disconnected
signal message_received(msg: Dictionary)

var _peer: ENetMultiplayerPeer
var _connected: bool = false


func connect_to(host: String, port: int) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host, port)
	if err != OK:
		_peer = null
	return err


func is_connected_to_server() -> bool:
	return _connected


func poll() -> void:
	if _peer == null:
		return
	_peer.poll()
	var status := _peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_CONNECTED and not _connected:
		_connected = true
		connected.emit()
	elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_peer = null
		_connected = false
		disconnected.emit()
		return
	while _peer != null and _peer.get_available_packet_count() > 0:
		var msg := Protocol.decode(_peer.get_packet(), Protocol.MAX_SERVER_PACKET_BYTES)
		if not msg.is_empty():
			message_received.emit(msg)


func send(msg: Dictionary) -> void:
	if not _connected:
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_peer.put_packet(Protocol.encode(msg))


func close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	_connected = false
