class_name SteamWebAuth
extends PlayerAuth
## Authentification de production : le client joint à son HELLO un ticket Steam
## (getAuthTicketForWebApi), que l'API Web de Steam valide et échange contre le SteamID.
## Le SteamID annoncé par le client n'est jamais utilisé.
## Clé Web API éditeur : variable d'environnement STEAM_WEB_API_KEY (secret du VPS).

const URL := "https://partner.steam-api.com/ISteamUserAuth/AuthenticateUserTicket/v1/"
## Doit être identique côté client (SteamService.WEB_API_IDENTITY).
const IDENTITY := "chessbg-server"

var _http: HttpJson
var _key: String
var _app_id: int


func _init(http: HttpJson, key: String, app_id: int) -> void:
	_http = http
	_key = key
	_app_id = app_id


func authenticate(hello: Dictionary, done: Callable) -> void:
	var ticket := Protocol.ticket_of(hello)
	if ticket == "":
		done.call(0)
		return
	var url := "%s?key=%s&appid=%d&ticket=%s&identity=%s" % [URL, _key, _app_id, ticket, IDENTITY]
	_http.request(url, func(code: int, data: Variant) -> void:
		var steam_id := steam_id_from_response(data) if code == 200 else 0
		if steam_id == 0:
			# Jamais l'URL dans les logs : elle contient la clé.
			push_warning("SteamWebAuth : ticket refusé (HTTP %d) %s" % [code, JSON.stringify(data)])
		done.call(steam_id))


## Lit la réponse d'AuthenticateUserTicket. 0 si le ticket est refusé ou le compte banni
## par l'éditeur. Le SteamID arrive en texte (un int64 ne tient pas dans un nombre JSON).
static func steam_id_from_response(data: Variant) -> int:
	if typeof(data) != TYPE_DICTIONARY:
		return 0
	var response: Variant = (data as Dictionary).get("response")
	if typeof(response) != TYPE_DICTIONARY or typeof((response as Dictionary).get("params")) != TYPE_DICTIONARY:
		return 0
	var p: Dictionary = (response as Dictionary)["params"]
	if p.get("result") != "OK" or p.get("publisherbanned", false) == true:
		return 0
	return Protocol.parse_steam_id(p.get("steamid"))
