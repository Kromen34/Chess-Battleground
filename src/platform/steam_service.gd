extends Node
## Autoload "SteamService" : initialise Steam (GodotSteam) et expose le profil du joueur.
##
## Le jeu doit tourner sans Steam (tests headless, PC sans client Steam, plugin absent) :
## on ne référence jamais la classe `Steam` directement, on passe par
## Engine.get_singleton() et des appels dynamiques. Si Steam est indisponible,
## le profil reste celui par défaut et `available` vaut false.

signal profile_changed

## AppID Steam, lu dans le réglage du projet que GodotSteam utilise aussi.
## 480 = Spacewar, l'app de test publique de Valve, en attendant le vrai AppID.
const APP_ID_SETTING := "steam/initialization/app_id"
const DEFAULT_NAME := "Joueur"
## Constante Steam.AVATAR_LARGE (184×184).
const AVATAR_LARGE := 3
## Valeur de Steam.STEAM_API_INIT_RESULT_OK.
const INIT_OK := 0

var available: bool = false
var persona_name: String = DEFAULT_NAME
var steam_id: int = 0
## null tant que l'avatar n'est pas chargé.
var avatar: Texture2D = null
## Raison lisible si Steam n'a pas pu démarrer (pour les logs / l'interface).
var unavailable_reason: String = ""

var _steam: Object = null


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		unavailable_reason = "mode headless"
		return
	if not Engine.has_singleton("Steam"):
		unavailable_reason = "plugin GodotSteam absent"
		push_warning("SteamService : %s, profil par défaut." % unavailable_reason)
		return
	_steam = Engine.get_singleton("Steam")
	# GodotSteam 4.15 : steamInitEx() sans argument, l'AppID vient du réglage du projet.
	# On le pousse aussi dans l'environnement (équivalent de steam_appid.txt).
	var app_id := str(ProjectSettings.get_setting(APP_ID_SETTING, 480))
	OS.set_environment("SteamAppId", app_id)
	OS.set_environment("SteamGameId", app_id)
	var init: Dictionary = _steam.call("steamInitEx")
	if int(init.get("status", -1)) != INIT_OK:
		unavailable_reason = str(init.get("verbal", "échec de l'initialisation"))
		push_warning("SteamService : Steam indisponible (%s), profil par défaut." % unavailable_reason)
		_steam = null
		return
	available = true
	persona_name = str(_steam.call("getPersonaName"))
	steam_id = int(_steam.call("getSteamID"))
	_steam.connect("avatar_loaded", _on_avatar_loaded)
	_steam.call("getPlayerAvatar", AVATAR_LARGE, steam_id)
	profile_changed.emit()


func _process(_delta: float) -> void:
	# Steam ne livre ses réponses (avatar, etc.) que si on pompe ses callbacks.
	if available:
		_steam.call("run_callbacks")


func _on_avatar_loaded(user_id: int, avatar_size: int, buffer: PackedByteArray) -> void:
	if user_id != steam_id:
		return
	avatar = avatar_from_rgba(avatar_size, buffer)
	profile_changed.emit()


## Construit une texture à partir du buffer RGBA8 carré renvoyé par Steam.
## null si le buffer n'a pas la bonne taille.
static func avatar_from_rgba(size: int, buffer: PackedByteArray) -> Texture2D:
	if size <= 0 or buffer.size() != size * size * 4:
		return null
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, buffer)
	return ImageTexture.create_from_image(image)
