extends TestCase
## Bout en bout sur une vraie connexion ENet en local : NetClient -> NetServer -> MatchServer.

const PORT := 47777
const TIMEOUT_MS := 5000

var net: NetServer
var logic: MatchServer
var client: NetClient
var received: Array[Dictionary] = []


func setup() -> void:
	received = []
	net = NetServer.new()
	logic = MatchServer.new()
	net.peer_connected.connect(logic.peer_connected)
	net.peer_disconnected.connect(logic.peer_disconnected)
	net.message_received.connect(logic.handle_message)
	logic.message_out.connect(net.send)
	client = NetClient.new()
	# Méthode et non lambda : une lambda garderait le test en vie (cycle de références).
	client.message_received.connect(_on_message)


func _on_message(msg: Dictionary) -> void:
	received.append(msg)


func teardown() -> void:
	client.close()
	net.stop()


## Fait tourner le réseau jusqu'à ce que [param done] soit vrai, ou jusqu'au délai.
func _pump(done: Callable) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < TIMEOUT_MS:
		net.poll()
		client.poll()
		if done.call():
			return true
		OS.delay_msec(5)
	return false


func _received(t: String) -> Callable:
	return func() -> bool: return received.any(func(m: Dictionary) -> bool: return Protocol.type_of(m) == t)


func test_play_a_turn_against_the_server_ai() -> void:
	assert_eq(net.start(PORT), OK, "le port %d doit être libre" % PORT)
	assert_eq(client.connect_to("127.0.0.1", PORT), OK)
	assert_true(_pump(client.is_connected_to_server), "connexion au serveur")
	client.send(Protocol.hello())
	assert_true(_pump(_received(Protocol.WELCOME)), "WELCOME reçu")
	client.send(Protocol.start_vs_ai())
	assert_true(_pump(_received(Protocol.MATCH_STARTED)), "MATCH_STARTED reçu")
	client.send(Protocol.action(Actions.end_turn()))
	assert_true(_pump(_received(Protocol.EVENTS)), "EVENTS reçus après la fin de tour")
	assert_eq(logic.match_count(), 1)
	client.close()
	assert_true(_pump(func() -> bool: return logic.match_count() == 0), "partie supprimée à la déconnexion")
