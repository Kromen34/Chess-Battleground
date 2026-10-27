class_name CameraRig
extends Node3D
## Caméra orbitale autour d'un point visé (la position de ce nœud) :
## - molette : zoom avant / arrière ;
## - clic droit enfoncé, souris gauche / droite : tourne autour du point visé ;
## - clic gauche enfoncé, souris haut / bas : avance / recule sur la table.
## Plus on zoome, plus la caméra s'abaisse pour voir les figurines de profil.
## Un clic gauche sans glisser reste un clic de jeu : la vue réagit au relâchement,
## et on avale ce relâchement quand la souris a glissé (voir DRAG_THRESHOLD).

@export var min_distance: float = 3.5
@export var max_distance: float = 28.0
@export var distance: float = 13.0
## Inclinaison (degrés au-dessus de l'horizontale) au zoom maximal et minimal.
@export var pitch_near: float = 28.0
@export var pitch_far: float = 58.0
## Zone où le point visé peut se déplacer (demi-largeurs en x et z), centrée sur l'origine.
@export var move_limit: Vector2 = Vector2(18.0, 12.0)
@export var rotate_speed: float = 0.006
@export var move_speed: float = 0.0025
## Vitesse de lissage des mouvements (plus grand = plus réactif).
@export var smoothing: float = 12.0
## Distance (pixels) au-delà de laquelle un clic gauche devient un glisser de caméra.
const DRAG_THRESHOLD := 6.0

@onready var camera: Camera3D = $Camera3D

var _yaw: float = 0.0
var _target_yaw: float = 0.0
var _target_distance: float
var _target_position: Vector3
var _left_travel: float = 0.0
var _left_dragging: bool = false


func _ready() -> void:
	_target_distance = distance
	_target_position = position
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(min_distance, _target_distance * 0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(max_distance, _target_distance / 0.88)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if not mb.pressed and _left_dragging:
				# Fin d'un glisser : ce relâchement n'est pas un clic sur le plateau.
				get_viewport().set_input_as_handled()
			_left_travel = 0.0
			_left_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_target_yaw -= mm.relative.x * rotate_speed
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_left_travel += mm.relative.length()
			if _left_travel > DRAG_THRESHOLD:
				_left_dragging = true
			if _left_dragging:
				# Avant = direction du regard projetée sur la table. Souris vers le haut : on avance.
				var forward := Vector3(-sin(_target_yaw), 0.0, -cos(_target_yaw))
				_target_position -= forward * mm.relative.y * move_speed * _target_distance
				_target_position.x = clampf(_target_position.x, -move_limit.x, move_limit.x)
				_target_position.z = clampf(_target_position.z, -move_limit.y, move_limit.y)
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var t := 1.0 - exp(-smoothing * delta)
	_yaw = lerpf(_yaw, _target_yaw, t)
	distance = lerpf(distance, _target_distance, t)
	position = position.lerp(_target_position, t)
	_apply()


func _apply() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	var zoom := inverse_lerp(min_distance, max_distance, distance)
	var pitch := deg_to_rad(lerpf(pitch_near, pitch_far, zoom))
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance
	camera.look_at(global_position, Vector3.UP)
