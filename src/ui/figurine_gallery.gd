extends Node3D
## Galerie des figurines : une figurine à la fois sur un présentoir.
## - panneau de gauche ou flèches haut / bas : famille (un dossier de Figurines/, avec ses sous-dossiers) ;
## - flèches gauche / droite (ou boutons à l'écran) : figurine précédente / suivante ;
## - clic gauche ou droit enfoncé : tourner autour (et monter / descendre) ;
## - molette : zoom ; clic molette : vue de départ ; Échap : menu ;
## - Suppr (ou bouton) : mettre la figurine de côté, dans <famille>/En attente/ (le fichier est
##   déplacé, pas effacé) ; la case « Voir les figurines en attente » permet de les remettre.
## Les modèles viennent des sous-dossiers de res://Figurines/ (absents de git, voir CLAUDE.md).

const MENU_SCENE := "res://scenes/main_menu.tscn"
const FIGURINES_DIR := "res://Figurines/"

const ROTATE_SPEED := 0.008
const SMOOTHING := 12.0
const PITCH_MIN := -10.0
const PITCH_MAX := 80.0
const START_YAW := 0.0
const START_PITCH := 18.0
const FAMILY_PANEL_WIDTH := 260.0
## Famille des .glb posés directement dans Figurines/, hors sous-dossier.
const LOOSE_FAMILY := "Divers"
## Dossier des figurines mises de côté, dans chaque famille : la galerie ne les montre plus.
const ON_HOLD_DIR := "En attente"

## Familles -> chemins de leurs modèles, et famille affichée.
var _families: Dictionary = {}
var _family_names: PackedStringArray = []
var _family: int = 0
var _family_list: ItemList
## true : on parcourt les figurines en attente (pour les remettre) au lieu des autres.
var _on_hold: bool = false
var _hold_button: Button
var _paths: PackedStringArray = []
var _index: int = 0
var _model: Node3D = null
var _camera: Camera3D
var _name_label: Label
var _count_label: Label

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
	_build_ui()
	_reload()


## Relit les dossiers et reste sur la famille [family] et la figurine [index] si possible.
func _reload(family: String = "", index: int = 0) -> void:
	_families = group_by_family(list_models(FIGURINES_DIR, _on_hold), FIGURINES_DIR)
	_family_names = PackedStringArray(_families.keys())
	_family_list.clear()
	for f in _family_names:
		_family_list.add_item("%s  (%d)" % [f, (_families[f] as PackedStringArray).size()])
	_hold_button.text = "Remettre dans la galerie (Suppr)" if _on_hold else "Mettre de côté (Suppr)"
	_select_family(maxi(0, _family_names.find(family)), index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)
	elif event.is_action_pressed("ui_left"):
		_show(_index - 1)
	elif event.is_action_pressed("ui_right"):
		_show(_index + 1)
	elif event.is_action_pressed("ui_up"):
		_select_family(_family - 1)
	elif event.is_action_pressed("ui_down"):
		_select_family(_family + 1)
	elif event is InputEventKey and (event as InputEventKey).pressed 			and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_DELETE and _hold_button.visible:
		_toggle_hold()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(_min_distance, _target_distance * 0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(_max_distance, _target_distance / 0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			_reset_view()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
			_target_yaw -= mm.relative.x * ROTATE_SPEED
			_target_pitch = clampf(_target_pitch + rad_to_deg(mm.relative.y * ROTATE_SPEED),
					PITCH_MIN, PITCH_MAX)


func _process(delta: float) -> void:
	var t := 1.0 - exp(-SMOOTHING * delta)
	_yaw = lerpf(_yaw, _target_yaw, t)
	_pitch = lerpf(_pitch, _target_pitch, t)
	_distance = lerpf(_distance, _target_distance, t)
	_apply_camera()


func _apply_camera() -> void:
	var p := deg_to_rad(_pitch)
	var dir := Vector3(sin(_yaw) * cos(p), sin(p), cos(_yaw) * cos(p))
	_camera.look_at_from_position(_focus + dir * _distance, _focus, Vector3.UP)


func _reset_view() -> void:
	_target_yaw = START_YAW
	_target_pitch = START_PITCH
	_target_distance = _home_distance
	_yaw = wrapf(_yaw, -PI, PI)


## Passe à la famille [i] (la liste boucle) et affiche sa figurine [index].
func _select_family(i: int, index: int = 0) -> void:
	if _family_names.is_empty():
		_paths = []
	else:
		_family = posmod(i, _family_names.size())
		_paths = _families[_family_names[_family]]
		_family_list.select(_family)
		_family_list.ensure_current_is_visible()
	_show(index)


## Met la figurine affichée de côté (ou la remet, en vue « en attente ») en déplaçant son
## .glb et son .import ; la suivante prend sa place.
func _toggle_hold() -> void:
	if _paths.is_empty():
		return
	var path := _paths[_index]
	var dest := restored_path(path) if _on_hold else on_hold_path(path, FIGURINES_DIR)
	var err := move_model(path, dest)
	if err != OK:
		_count_label.text = "Déplacement impossible (%s)" % error_string(err)
		return
	_reload(_family_names[_family], _index)


## Déplace un modèle (et son .import, pour qu'il reste chargeable sans réimport) vers [dest].
static func move_model(path: String, dest: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest.get_base_dir()))
	if err != OK:
		return err
	for ext in ["", ".import"]:
		if not FileAccess.file_exists(path + ext):
			continue
		err = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ext),
				ProjectSettings.globalize_path(dest + ext))
		if err != OK:
			return err
	return OK


## Affiche la figurine [i] (la liste boucle) et cadre la caméra dessus.
func _show(i: int) -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if _paths.is_empty():
		_name_label.text = "Aucune figurine trouvée"
		_count_label.text = "Les modèles vont dans %s (voir CLAUDE.md, « Figurines »)." % FIGURINES_DIR
		return
	_index = posmod(i, _paths.size())
	var path := _paths[_index]
	_name_label.text = display_name(path)
	_count_label.text = "%d / %d" % [_index + 1, _paths.size()]
	var scene := load(path) as PackedScene
	if scene == null:
		_name_label.text += " (illisible)"
		return
	_model = scene.instantiate() as Node3D
	# Les modèles regardent vers -Z : on les tourne vers la caméra de départ (côté +Z).
	_model.rotation.y = PI
	add_child(_model)

	var box := _model_bounds(_model)
	_focus = box.get_center()
	var radius := box.size.length() * 0.5
	_home_distance = radius / sin(deg_to_rad(_camera.fov * 0.5)) * 0.85
	_min_distance = radius * 0.25
	_max_distance = _home_distance * 3.0
	_reset_view()
	# Pas de glissement depuis la figurine précédente : on part directement de la vue de départ.
	_yaw = _target_yaw
	_pitch = _target_pitch
	_distance = _target_distance
	_apply_camera()


func _model_bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Chemins des .glb sous [root] et tous ses sous-dossiers (Dragons/, Dragons/Draconiens/...), triés.
## Les dossiers ON_HOLD_DIR sont écartés, ou au contraire seuls listés si [on_hold].
## Dans un jeu exporté, seuls les .glb.import restent : on les ramène au .glb.
static func list_models(root: String, on_hold: bool = false) -> PackedStringArray:
	var out: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(root):
		return out
	var folders: PackedStringArray = [root]
	while not folders.is_empty():
		var folder: String = folders[folders.size() - 1]
		folders.remove_at(folders.size() - 1)
		for d in DirAccess.get_directories_at(folder):
			folders.append(folder + d + "/")
		var held := ("/%s/" % ON_HOLD_DIR) in folder.trim_prefix(root.get_base_dir())
		if held != on_hold:
			continue
		for f in DirAccess.get_files_at(folder):
			var file := f.trim_suffix(".import")
			if file.get_extension() == "glb" and not out.has(folder + file):
				out.append(folder + file)
	out.sort()
	return out


## Où ranger un modèle mis de côté : <root>/<famille>/En attente/<fichier>.
## « Dragons/Draconiens/onixia.glb » -> « Dragons/En attente/onixia.glb ».
static func on_hold_path(path: String, root: String) -> String:
	var rel := path.trim_prefix(root)
	var family_dir := root if not rel.contains("/") else root + rel.get_slice("/", 0) + "/"
	return family_dir + ON_HOLD_DIR + "/" + path.get_file()


## Où remettre un modèle en attente : dans le dossier de la famille, à côté de En attente/.
static func restored_path(path: String) -> String:
	return path.get_base_dir().get_base_dir() + "/" + path.get_file()


## Famille d'un modèle : le premier dossier sous [root] (« Dragons » pour
## Dragons/Draconiens/onixia.glb), ou LOOSE_FAMILY pour un modèle posé dans [root].
static func family_of(path: String, root: String) -> String:
	var rel := path.trim_prefix(root)
	return LOOSE_FAMILY if not rel.contains("/") else rel.get_slice("/", 0)


## Regroupe les chemins par famille : { "Dragons": [...], ... }, familles triées.
static func group_by_family(paths: PackedStringArray, root: String) -> Dictionary:
	var by_family: Dictionary = {}
	for p in paths:
		var f := family_of(p, root)
		# Un PackedStringArray est copié à la lecture : on réécrit la liste complétée.
		var list: PackedStringArray = by_family.get(f, PackedStringArray())
		list.append(p)
		by_family[f] = list
	var names: Array = by_family.keys()
	names.sort()
	var out: Dictionary = {}
	for f: String in names:
		out[f] = by_family[f]
	return out


## « res://Figurines/Dragons/dragon_a_lancier.glb » -> « Dragons — Dragon A Lancier ».
static func display_name(path: String) -> String:
	var name := path.get_file().get_basename().replace("_", " ").capitalize()
	var folder := path.get_base_dir().get_file()
	return name if folder == "" or folder == "Figurines" else "%s — %s" % [folder, name]


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.09, 0.08, 0.075)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.7, 0.65)
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	add_child(env)

	# Lumière chaude de la suspension du salon, et un contre-jour froid pour détacher la silhouette.
	var key := DirectionalLight3D.new()
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


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 24
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 34)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_name_label)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 20)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.modulate = Color(1, 1, 1, 0.7)
	top.add_child(_count_label)

	_build_family_panel(layer)

	var prev := _arrow_button("◀", Control.PRESET_CENTER_LEFT, FAMILY_PANEL_WIDTH + 40)
	prev.pressed.connect(func() -> void: _show(_index - 1))
	layer.add_child(prev)
	var next := _arrow_button("▶", Control.PRESET_CENTER_RIGHT, -24)
	next.pressed.connect(func() -> void: _show(_index + 1))
	layer.add_child(next)

	var back := Button.new()
	back.text = "Retour au menu"
	back.add_theme_font_size_override("font_size", 18)
	back.position = Vector2(16, 16)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	layer.add_child(back)

	var help := Label.new()
	help.text = "↑ ↓ : famille · ← → : figurine · Suppr : mettre de côté · clic enfoncé : tourner · molette : zoom · clic molette : vue de départ · Échap : menu"
	help.add_theme_font_size_override("font_size", 16)
	help.modulate = Color(1, 1, 1, 0.6)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -48
	help.offset_bottom = -20
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(help)


## Panneau de gauche, sous « Retour au menu » : la liste des familles (défile s'il y en a beaucoup).
func _build_family_panel(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = 64
	panel.offset_right = 16 + FAMILY_PANEL_WIDTH
	panel.offset_bottom = -64
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Familles"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_family_list = ItemList.new()
	_family_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_family_list.add_theme_font_size_override("font_size", 18)
	# Pas de focus clavier : les flèches restent à la galerie (↑ ↓ changent déjà de famille).
	_family_list.focus_mode = Control.FOCUS_NONE
	_family_list.item_selected.connect(func(i: int) -> void:
		if i != _family:
			_select_family(i))
	box.add_child(_family_list)

	var show_held := CheckButton.new()
	show_held.text = "Voir les figurines en attente"
	show_held.focus_mode = Control.FOCUS_NONE
	show_held.toggled.connect(func(on: bool) -> void:
		_on_hold = on
		_reload(_family_names[_family] if not _family_names.is_empty() else ""))
	box.add_child(show_held)
	_hold_button = Button.new()
	_hold_button.focus_mode = Control.FOCUS_NONE
	_hold_button.add_theme_font_size_override("font_size", 18)
	_hold_button.pressed.connect(_toggle_hold)
	# Dans un jeu exporté, res:// est en lecture seule : le tri ne se fait qu'en local.
	_hold_button.visible = not OS.has_feature("template")
	show_held.visible = _hold_button.visible
	box.add_child(_hold_button)


func _arrow_button(text: String, preset: Control.LayoutPreset, x_offset: float) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 40)
	b.custom_minimum_size = Vector2(72, 96)
	# Pas de focus clavier : les flèches restent pour changer de figurine.
	b.focus_mode = Control.FOCUS_NONE
	b.size = b.custom_minimum_size
	b.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
	b.position.x += x_offset
	return b
