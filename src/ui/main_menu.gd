extends Control
## Écran principal : titre, boutons, et profil Steam (pseudo + avatar) en haut à droite.

const GAME_SCENE := "res://scenes/main.tscn"

@onready var profile_name: Label = %ProfileName
@onready var profile_avatar: TextureRect = %ProfileAvatar
@onready var play_button: Button = %PlayButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
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
	get_tree().change_scene_to_file(GAME_SCENE)
