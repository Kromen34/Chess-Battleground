extends Control
## Écran principal : titre, boutons, et profil Steam (pseudo + avatar) en haut à droite.

const GAME_SCENE := "res://scenes/main.tscn"
## Serveur rejoint par « Jouer contre l'IA (serveur) » : le VPS OVH. Pour un serveur
## local (tools/lancer_serveur.bat) : godot --path . -- --server=127.0.0.1
const DEFAULT_SERVER_HOST := "51.91.97.41"
const OPTIONS_SCENE := "res://scenes/options_menu.tscn"
const GALLERY_SCENE := "res://scenes/figurine_gallery.tscn"
const COLLECTION_SCENE := "res://scenes/collection.tscn"

@onready var profile_name: Label = %ProfileName
@onready var profile_avatar: TextureRect = %ProfileAvatar
@onready var play_button: Button = %PlayButton
@onready var online_button: Button = %OnlineButton
@onready var collection_button: Button = %CollectionButton
@onready var gallery_button: Button = %GalleryButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	online_button.pressed.connect(_on_online_pressed)
	collection_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(COLLECTION_SCENE))
	gallery_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(GALLERY_SCENE))
	options_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(OPTIONS_SCENE))
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	SteamService.profile_changed.connect(_refresh_profile)
	_refresh_profile()
	play_button.grab_focus()


func _refresh_profile() -> void:
	profile_name.text = SteamService.persona_name
	profile_name.tooltip_text = "" if SteamService.available else "Steam non connecté : %s" % SteamService.unavailable_reason
	if SteamService.avatar != null:
		profile_avatar.texture = SteamService.avatar


func _on_play_pressed() -> void:
	GameController.online_host = ""
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_online_pressed() -> void:
	var address := server_address(OS.get_cmdline_user_args())
	GameController.online_host = address[0]
	GameController.online_port = address[1]
	get_tree().change_scene_to_file(GAME_SCENE)


## Lit --server=hôte[:port] dans les arguments. Retourne [hôte, port].
static func server_address(args: PackedStringArray) -> Array:
	for a in args:
		if a.begins_with("--server="):
			var parts := a.trim_prefix("--server=").split(":")
			var port := parts[1].to_int() if parts.size() > 1 else Protocol.DEFAULT_PORT
			if parts[0] != "" and port > 0 and port < 65536:
				return [parts[0], port]
	return [DEFAULT_SERVER_HOST, Protocol.DEFAULT_PORT]
