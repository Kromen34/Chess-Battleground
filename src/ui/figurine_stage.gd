class_name FigurineStage
extends Node3D
## Présentoir d'une figurine, partagé par la galerie et l'écran Collection : décor,
## lumières, socle en bois et caméra orbitale.
## Souris : clic gauche ou droit enfoncé = tourner autour (et monter / descendre),
## molette = zoom, clic molette = vue de départ. L'atelier de peinture garde le clic gauche
## pour le pinceau ([member rotate_mask]) et déplace la vue au clic molette ([member pan]).

const ROTATE_SPEED := 0.008
const SMOOTHING := 12.0
const PITCH_MIN := -10.0
const PITCH_MAX := 80.0
const START_YAW := 0.0
const START_PITCH := 18.0

## Boutons qui font tourner la vue.
var rotate_mask: int = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
## Clic molette enfoncé = déplacer la vue (au lieu de revenir à la vue de départ).
var pan: bool = false
## Zoom avant maximal, en fraction de la taille de la figurine.
var min_zoom: float = 0.25

var _model: Node3D = null
var _env: Environment
var _key: DirectionalLight3D
var _home_focus: Vector3 = Vector3.ZERO
var _camera: Camera3D

var _focus: Vector3 = Vector3.ZERO
var _yaw: float = START_YAW
var _pitch: float = START_PITCH
var _distance: float = 3.0
var _target_yaw: float = START_YAW
var _target_pitch: float = START_PITCH
var _target_distance: float = 3.0
var _home_distance: float = 3.0
var _min_distance: float = 0.3
var _max_distance: float = 10.0


func _ready() -> void:
	_build_stage()
	_apply_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(_min_distance, _target_distance * 0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(_max_distance, _target_distance / 0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE and not pan:
			reset_view()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if pan and mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var b := _camera.global_transform.basis
			var k := _distance * tan(deg_to_rad(_camera.fov * 0.5)) * 2.0 / maxf(1.0, get_viewport().get_visible_rect().size.y)
			_focus += (-b.x * mm.relative.x + b.y * mm.relative.y) * k
		elif mm.button_mask & rotate_mask:
			_target_yaw -= mm.relative.x * ROTATE_SPEED
			_target_pitch = clampf(_target_pitch + rad_to_deg(mm.relative.y * ROTATE_SPEED),
					PITCH_MIN, PITCH_MAX)


func _process(delta: float) -> void:
	var t := 1.0 - exp(-SMOOTHING * delta)
	_yaw = lerpf(_yaw, _target_yaw, t)
	_pitch = lerpf(_pitch, _target_pitch, t)
	_distance = lerpf(_distance, _target_distance, t)
	_apply_camera()


func camera() -> Camera3D:
	return _camera


## La figurine affichée (null si aucune).
func model() -> Node3D:
	return _model


## Lumière neutre (blanche) pour juger les couleurs en peignant, ou chaude du salon.
func set_neutral_light(on: bool) -> void:
	_key.light_color = Color.WHITE if on else Color(1.0, 0.88, 0.72)
	_env.ambient_light_color = Color(0.72, 0.72, 0.72) if on else Color(0.75, 0.7, 0.65)


## Retire la figurine affichée.
func clear() -> void:
	if _model != null:
		_model.queue_free()
		_model = null


## Affiche le modèle [path] et cadre la caméra dessus. [material] remplace tous ses
## matériaux s'il est donné (silhouette d'une carte non possédée). false si le modèle
## est absent ou illisible (le présentoir reste vide).
func show_model(path: String, material: Material = null) -> bool:
	clear()
	if path == "" or not ResourceLoader.exists(path):
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		return false
	_model = scene.instantiate() as Node3D
	# Les modèles regardent vers -Z : on les tourne vers la caméra de départ (côté +Z).
	_model.rotation.y = PI
	add_child(_model)
	if material != null:
		for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = material

	var box := _model_bounds(_model)
	_home_focus = box.get_center()
	var radius := box.size.length() * 0.5
	_home_distance = radius / sin(deg_to_rad(_camera.fov * 0.5)) * 0.85
	_min_distance = radius * min_zoom
	_max_distance = _home_distance * 3.0
	reset_view()
	# Pas de glissement depuis la figurine précédente : on part directement de la vue de départ.
	_yaw = _target_yaw
	_pitch = _target_pitch
	_distance = _target_distance
	_apply_camera()
	return true


func _apply_camera() -> void:
	var p := deg_to_rad(_pitch)
	var dir := Vector3(sin(_yaw) * cos(p), sin(p), cos(_yaw) * cos(p))
	_camera.look_at_from_position(_focus + dir * _distance, _focus, Vector3.UP)


func reset_view() -> void:
	_focus = _home_focus
	_target_yaw = START_YAW
	_target_pitch = START_PITCH
	_target_distance = _home_distance
	_yaw = wrapf(_yaw, -PI, PI)


func _model_bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	_env = env.environment
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.09, 0.08, 0.075)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.7, 0.65)
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	# Ciel neutre invisible (le fond reste uni) : il donne aux métaux quelque chose à refléter,
	# sinon l'or et l'argent peints paraissent noirs.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.62, 0.62, 0.66)
	sky_mat.sky_horizon_color = Color(0.78, 0.75, 0.7)
	sky_mat.ground_horizon_color = Color(0.45, 0.42, 0.38)
	sky_mat.ground_bottom_color = Color(0.16, 0.14, 0.12)
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = sky_mat
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	add_child(env)

	# Lumière chaude de la suspension du salon, et un contre-jour froid pour détacher la silhouette.
	var key := DirectionalLight3D.new()
	_key = key
	key.light_color = Color(1.0, 0.88, 0.72)
	key.light_energy = 1.6
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 20.0
	key.rotation_degrees = Vector3(-55, 30, 0)
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.6, 0.7, 1.0)
	rim.light_energy = 0.5
	rim.rotation_degrees = Vector3(-20, 200, 0)
	add_child(rim)

	# Présentoir en bois sombre sous la figurine.
	var stand := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.8
	cyl.height = 0.08
	cyl.radial_segments = 96
	stand.mesh = cyl
	stand.position.y = -0.04
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.13, 0.08)
	wood.roughness = 0.55
	stand.material_override = wood
	add_child(stand)

	_camera = Camera3D.new()
	_camera.fov = 35.0
	_camera.near = 0.02
	add_child(_camera)
