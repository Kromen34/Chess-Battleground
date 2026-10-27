class_name Protocol
extends RefCounted
## Messages échangés entre client et serveur : des Dictionary encodés en JSON.
## JSON plutôt que var_to_bytes : rien d'exécutable ne peut transiter, et un
## futur serveur ou outil dans un autre langage pourra lire le même format.
##
## Champ "t" = type du message. Client -> serveur : HELLO, START_VS_AI, ACTION, SYNC.
## Serveur -> client : WELCOME, MATCH_STARTED, EVENTS, REFUSED, STATE, ERROR.
## Attention : JSON rend tous les nombres en float, toujours relire avec int().

## À incrémenter à chaque changement incompatible du protocole.
const VERSION := 1
const DEFAULT_PORT := 7777
## Taille max d'un message reçu par le serveur (un client n'a rien de gros à envoyer).
const MAX_CLIENT_PACKET_BYTES := 4096
## Taille max d'un message reçu par le client (état complet de la partie).
const MAX_SERVER_PACKET_BYTES := 1 << 20

const HELLO := "hello"
const START_VS_AI := "start_vs_ai"
const ACTION := "action"
const SYNC := "sync"

const WELCOME := "welcome"
const MATCH_STARTED := "match_started"
const EVENTS := "events"
const REFUSED := "refused"
const STATE := "state"
const ERROR := "error"


static func encode(msg: Dictionary) -> PackedByteArray:
	return JSON.stringify(msg).to_utf8_buffer()


## Décode un message. Retourne {} s'il est trop gros, illisible ou sans type.
static func decode(bytes: PackedByteArray, max_bytes: int) -> Dictionary:
	if bytes.is_empty() or bytes.size() > max_bytes:
		return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return {}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var msg: Dictionary = data
	if typeof(msg.get("t")) != TYPE_STRING:
		return {}
	return msg


static func type_of(msg: Dictionary) -> String:
	return String(msg.get("t", ""))


## Reconstruit une action reçue d'un client en ne gardant que les champs attendus,
## avec le bon type. Retourne {} si elle est mal formée. Rules ne voit ainsi jamais
## de données arbitraires venant du réseau.
static func sanitize_action(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var a: Dictionary = v
	match Actions.type_of(a):
		Actions.MOVE:
			if not (is_number(a.get("unit")) and typeof(a.get("to")) == TYPE_STRING):
				return {}
			return Actions.move(int(a["unit"]), StringName(a["to"]))
		Actions.ATTACK:
			if not (is_number(a.get("unit")) and is_number(a.get("target"))):
				return {}
			return Actions.attack(int(a["unit"]), int(a["target"]))
		Actions.END_TURN:
			return Actions.end_turn()
		_:
			return {}


static func is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


# --- Messages ------------------------------------------------------------------

static func hello() -> Dictionary:
	return {"t": HELLO, "version": VERSION}


static func start_vs_ai() -> Dictionary:
	return {"t": START_VS_AI}


static func action(a: Dictionary) -> Dictionary:
	return {"t": ACTION, "action": a}


static func sync() -> Dictionary:
	return {"t": SYNC}


static func error(reason: String) -> Dictionary:
	return {"t": ERROR, "reason": reason}
