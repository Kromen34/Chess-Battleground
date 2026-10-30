extends Node3D
## Atelier de peinture d'une figurine de la collection.
## Outils : pinceau, gomme, brossage à sec (arêtes), lavis (creux), flou, pipette,
## remplissage d'une pièce. Forme de la pointe (BrushTip), commune aux outils qui touchent
## la figurine, avec angle, rondeur et suivi du trait. Réglages : taille, dureté, opacité, métal, brillance,
## symétrie, pièce seule, faces visibles. Calques (visibilité, opacité, mode, ordre,
## fusion), annuler / rétablir, enregistrement automatique, capture d'écran.
## La peinture est locale (user://peintures/), une par carte. Voir FigurinePaint.

const COLLECTION_SCENE := "res://scenes/collection.tscn"
const CAPTURE_DIR := "user://captures/"
## Carte affichée si l'atelier est lancé sans passer par la collection.
const DEFAULT_CARD := &"dragon_a_lancier"
const LEFT_WIDTH := 236.0
const RIGHT_WIDTH := 300.0
const MAX_UNDO := 40
## 1 unité de modèle = 1 case = 1 pouce.
const MM_PER_UNIT := 25.4
const RADIUS_MIN := 0.004
const RADIUS_MAX := 0.4
## Couche de collision des pièces, pour ne toucher qu'elles au lancer de rayon.
const PAINT_COLLISION_LAYER := 1 << 19

enum Tool { BRUSH, ERASER, DRYBRUSH, WASH, BLUR, PICKER, FILL }

## [nom, touche, aide]
const TOOLS := {
	Tool.BRUSH: ["Pinceau", KEY_B, "Peint la couleur choisie (B)"],
	Tool.ERASER: ["Gomme", KEY_E, "Efface le calque actif (E)"],
	Tool.DRYBRUSH: ["Brossage à sec", KEY_D, "Ne dépose la couleur que sur les arêtes et reliefs (D)"],
	Tool.WASH: ["Lavis", KEY_W, "La couleur coule dans les creux (W)"],
	Tool.BLUR: ["Fondu", KEY_R, "Adoucit les transitions du calque actif (R)"],
	Tool.PICKER: ["Pipette", KEY_I, "Prend la couleur sous le pinceau (I, ou Alt + clic)"],
	Tool.FILL: ["Remplissage", KEY_G, "Peint toute la pièce cliquée (G)"],
}

## Peintures de figurinistes : [nom, couleur sRGB, métal, brillance].
const PALETTE := [
	["Noir abyssal", Color(0.05, 0.05, 0.06), 0.0, 0.25], ["Gris pierre", Color(0.45, 0.45, 0.47), 0.0, 0.2],
	["Blanc os", Color(0.87, 0.84, 0.75), 0.0, 0.25], ["Ivoire", Color(0.96, 0.93, 0.84), 0.0, 0.3],
	["Rouge sang", Color(0.55, 0.04, 0.05), 0.0, 0.3], ["Rouge vif", Color(0.80, 0.12, 0.08), 0.0, 0.3],
	["Orange flamme", Color(0.92, 0.42, 0.08), 0.0, 0.3], ["Jaune soleil", Color(0.95, 0.78, 0.15), 0.0, 0.3],
	["Vert gobelin", Color(0.25, 0.50, 0.15), 0.0, 0.3], ["Vert sombre", Color(0.08, 0.22, 0.12), 0.0, 0.3],
	["Turquoise", Color(0.10, 0.55, 0.55), 0.0, 0.35], ["Bleu royal", Color(0.10, 0.22, 0.65), 0.0, 0.3],
	["Bleu nuit", Color(0.05, 0.08, 0.22), 0.0, 0.3], ["Violet", Color(0.35, 0.12, 0.45), 0.0, 0.3],
	["Peau claire", Color(0.92, 0.70, 0.58), 0.0, 0.25], ["Cuir", Color(0.45, 0.26, 0.13), 0.0, 0.35],
	["Bois", Color(0.35, 0.22, 0.12), 0.0, 0.2], ["Lavis brun", Color(0.25, 0.15, 0.08), 0.0, 0.4],
	["Or", Color(1.0, 0.78, 0.34), 1.0, 0.7], ["Argent", Color(0.85, 0.85, 0.88), 1.0, 0.75],
	["Bronze", Color(0.70, 0.45, 0.25), 1.0, 0.6], ["Cuivre", Color(0.85, 0.45, 0.30), 1.0, 0.65],
	["Fer noirci", Color(0.25, 0.25, 0.27), 1.0, 0.4], ["Gemme rouge", Color(0.75, 0.02, 0.10), 0.0, 0.95],
]

## Carte à peindre, posée par l'écran Collection avant d'ouvrir l'atelier.
static var card_id: StringName = &""

var _card: CardDef
var _paint: FigurinePaint
var _grid: VertexGrid
var _stage: FigurineStage
var _active: int = 0
var _tool: Tool = Tool.BRUSH
## Couleurs principale et secondaire, en sRGB (comme dans le sélecteur).
var _color := Color(0.55, 0.04, 0.05)
var _secondary := Color(0.87, 0.84, 0.75)
var _metal: float = 0.0
var _gloss: float = 0.3
var _radius: float = 0.04
var _hardness: float = 0.5
var _flow: float = 0.6
var _mirror: bool = false
var _lock_part: bool = false
var _facing_only: bool = true
var _tip := BrushTip.new()
## Rotation de la pointe sur la surface, en degrés.
var _angle: float = 0.0
## La pointe s'oriente selon la direction du trait (pinceau plat, poils).
var _follow: bool = false

var _stroke: bool = false
var _stroke_part: int = -1
var _last_dab: Vector3 = Vector3.INF
## Direction du trait en cours (repère du modèle), ZERO au premier point.
var _stroke_dir: Vector3 = Vector3.ZERO
## Tirages propres à chaque trait et à chaque touche (poils, moucheté, éponge).
var _stroke_seed: int = 0
var _dab_count: int = 0
## Valeurs d'avant le coup de pinceau, pour l'annuler : sommet codé -> [Color, Vector2].
var _stroke_changes: Dictionary = {}
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _unsaved: bool = false

var _layer_ui: CanvasLayer
var _cursor: MeshInstance3D
var _cursor_material: StandardMaterial3D
var _title: Label
var _status: Label
var _tool_buttons: Dictionary = {}
var _size_slider: HSlider
var _hardness_slider: HSlider
var _flow_slider: HSlider
var _metal_slider: HSlider
var _gloss_slider: HSlider
var _mirror_check: CheckBox
var _shape_buttons: Dictionary = {}
var _follow_check: CheckBox
var _angle_slider: HSlider
var _round_slider: HSlider
var _picker: ColorPicker
var _primary_rect: ColorRect
var _secondary_rect: ColorRect
var _layer_list: VBoxContainer
var _layer_name: LineEdit
var _layer_opacity: HSlider
var _layer_blend: OptionButton


func _ready() -> void:
	_stage = FigurineStage.new()
	_stage.rotate_mask = MOUSE_BUTTON_MASK_RIGHT
	_stage.pan = true
	_stage.min_zoom = 0.06
	add_child(_stage)
	_stage.set_neutral_light(true)
	_build_cursor()
	_build_ui()
	_set_status("Préparation de la figurine…")
	# Laisse s'afficher le message : la préparation prend quelques secondes.
	await get_tree().process_frame
	await get_tree().process_frame
	_prepare()


func _prepare() -> void:
	var catalog := CardCatalog.load_dir()
	_card = catalog.get_card(card_id if card_id != &"" else DEFAULT_CARD)
	if _card == null:
		_set_status("Carte inconnue : %s" % card_id)
		return
	_title.text = "Atelier de peinture : %s" % _card.display_name
	if not _stage.show_model(_card.model_path):
		_set_status("Modèle absent sur ce PC : %s" % _card.model_path)
		return
	var t := Time.get_ticks_msec()
	_paint = FigurinePaint.attach(_stage.model())
	if not _paint.load_saved(_card.id):
		_paint.layers.append(_paint.new_layer("Sous-couche"))
	_active = _paint.layers.size() - 1
	var positions: Array[PackedVector3Array] = []
	for p in _paint.parts.size():
		var part := _paint.parts[p]
		positions.append(part.positions)
		var body := StaticBody3D.new()
		body.collision_layer = PAINT_COLLISION_LAYER
		body.collision_mask = 0
		body.set_meta("part", p)
		var shape := CollisionShape3D.new()
		shape.shape = part.mesh.create_trimesh_shape()
		body.add_child(shape)
		part.node.add_child(body)
	_grid = VertexGrid.new(positions)
	_paint.flush()
	_refresh_layers()
	_set_status("Prêt (%.1f s). Clic gauche pour peindre, clic droit pour tourner." % ((Time.get_ticks_msec() - t) / 1000.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


# --- Entrées -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _paint != null:
			_begin_stroke(mb.alt_pressed)
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_end_stroke()
		return
	if not (event is InputEventKey and (event as InputEventKey).pressed):
		return
	var k := event as InputEventKey
	var ctrl := k.ctrl_pressed or k.meta_pressed
	if k.keycode == KEY_ESCAPE:
		_leave()
	elif ctrl and k.keycode == KEY_Z and k.shift_pressed:
		_redo_step()
	elif ctrl and k.keycode == KEY_Z:
		_undo_step()
	elif ctrl and k.keycode == KEY_Y:
		_redo_step()
	elif ctrl and k.keycode == KEY_S:
		_save()
	elif ctrl:
		return
	elif k.keycode in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		var up := k.keycode == KEY_BRACKETRIGHT
		if k.shift_pressed:
			_hardness_slider.value = clampf(_hardness + (0.1 if up else -0.1), 0.0, 1.0)
		else:
			_size_slider.value += 6.0 if up else -6.0
	elif k.keycode >= KEY_0 and k.keycode <= KEY_9:
		# Comme Photoshop : 1 = 10 %, ..., 0 = 100 %.
		var n := k.keycode - KEY_0
		_flow_slider.value = 1.0 if n == 0 else n / 10.0
	elif k.keycode in [KEY_COMMA, KEY_SEMICOLON]:
		_angle_slider.value += 15.0 if k.keycode == KEY_SEMICOLON else -15.0
	elif k.keycode == KEY_X:
		var c := _color
		_set_color(_secondary)
		_secondary = c
		_secondary_rect.color = c
	elif k.keycode == KEY_M:
		_mirror_check.button_pressed = not _mirror_check.button_pressed
	elif k.keycode == KEY_F:
		_stage.reset_view()
	else:
		for t: Tool in TOOLS:
			if k.keycode == TOOLS[t][1]:
				_select_tool(t)


func _physics_process(_delta: float) -> void:
	if _paint == null:
		return
	var hit := _raycast(get_viewport().get_mouse_position())
	_update_cursor(hit)
	if _stroke:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_stroke()
		elif hit.is_empty():
			_last_dab = Vector3.INF
		else:
			_stroke_to(hit)
	_paint.flush()


## Point de la figurine sous [screen_pos], dans le repère du modèle :
## {"position", "normal", "part", "world", "world_normal"}, ou {} si on ne touche rien.
func _raycast(screen_pos: Vector2) -> Dictionary:
	var cam := _stage.camera()
	var from := cam.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen_pos) * 100.0,
			PAINT_COLLISION_LAYER)
	var r := get_world_3d().direct_space_state.intersect_ray(query)
	if r.is_empty():
		return {}
	var inv := _stage.model().global_transform.affine_inverse()
	var world: Vector3 = r["position"]
	var world_normal: Vector3 = r["normal"]
	return {"position": inv * world, "normal": (inv.basis * world_normal).normalized(),
			"part": int((r["collider"] as Node).get_meta("part")), "world": world, "world_normal": world_normal}


# --- Coups de pinceau -------------------------------------------------------------

func _begin_stroke(alt: bool) -> void:
	var hit := _raycast(get_viewport().get_mouse_position())
	if hit.is_empty():
		return
	if alt or _tool == Tool.PICKER:
		_pick(hit)
		return
	if _paint.layers.is_empty():
		_set_status("Aucun calque : ajoute un calque pour peindre.")
		return
	if not _paint.layers[_active].visible:
		_set_status("Le calque actif est masqué.")
		return
	if _tool == Tool.FILL:
		_fill_part(int(hit["part"]))
		return
	_stroke = true
	_stroke_part = int(hit["part"])
	_stroke_changes = {}
	_last_dab = Vector3.INF
	_stroke_dir = Vector3.ZERO
	_stroke_seed = randi()
	_stroke_to(hit)


func _end_stroke() -> void:
	if not _stroke:
		return
	_stroke = false
	if not _stroke_changes.is_empty():
		_push_undo({"type": "paint", "layer": _paint.layers[_active], "changes": _stroke_changes})
		_stroke_changes = {}


## Pose des touches de pinceau régulièrement espacées jusqu'au point [hit].
func _stroke_to(hit: Dictionary) -> void:
	var target: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var spacing := maxf(_radius * 0.3, 0.002)
	if _last_dab == Vector3.INF:
		_dab_with_mirror(target, normal)
		_last_dab = target
		return
	var dist := _last_dab.distance_to(target)
	# Grand saut (passage d'un bord à l'autre) : on repart du nouveau point.
	if dist > _radius * 6.0:
		_dab_with_mirror(target, normal)
		_last_dab = target
		return
	if dist > 0.0001:
		_stroke_dir = (target - _last_dab) / dist
	var steps := int(dist / spacing)
	for s in steps:
		var pos := _last_dab.move_toward(target, spacing)
		_dab_with_mirror(pos, normal)
		_last_dab = pos


func _dab_with_mirror(center: Vector3, normal: Vector3) -> void:
	var u := _tip_axis(normal, false)
	_dab(center, normal, u, true)
	if _mirror:
		# Les figurines sont tournées vers -Z : le plan de symétrie est x = 0.
		_dab(Vector3(-center.x, center.y, center.z), Vector3(-normal.x, normal.y, normal.z),
				Vector3(-u.x, u.y, u.z), false)


## Axe x de la pointe sur la surface de normale [normal] : en travers du trait s'il est
## suivi, sinon horizontal à l'écran ; puis tourné de l'angle choisi. [world] : repère du
## monde (curseur) au lieu de celui du modèle.
func _tip_axis(normal: Vector3, world: bool) -> Vector3:
	var model_basis := _stage.model().global_transform.basis
	var ref: Vector3
	if _follow and _stroke and _stroke_dir != Vector3.ZERO:
		var dir := model_basis * _stroke_dir if world else _stroke_dir
		ref = normal.cross(dir)
	else:
		var right := _stage.camera().global_transform.basis.x
		ref = right if world else model_basis.inverse() * right
	var u := ref - normal * ref.dot(normal)
	if u.length_squared() < 0.000001:
		u = normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT)
	return u.normalized().rotated(normal, deg_to_rad(_angle))


## Une touche de pinceau autour de [center] sur le calque actif. [u_axis] : axe x de la pointe.
func _dab(center: Vector3, normal: Vector3, u_axis: Vector3, use_lock: bool) -> void:
	_dab_count += 1
	_grid.query(center, _radius * _tip.reach())
	var found := _grid.found
	if found.is_empty():
		return
	var layer := _paint.layers[_active]
	var color := _color.srgb_to_linear()
	color.a = 1.0
	var finish := Vector2(_metal, 1.0 - _gloss)
	var lock := _stroke_part if use_lock and _lock_part else -1
	var v_axis := normal.cross(u_axis)
	var bits := FigurinePaint.INDEX_BITS
	var mask := FigurinePaint.INDEX_MASK

	# Poids de chaque sommet (0 = non touché), calculé une fois pour toutes les pièces.
	var weights := PackedFloat32Array()
	weights.resize(found.size())
	var touched := {}
	for k in found.size():
		var p := found[k] >> bits
		var i := found[k] & mask
		if lock >= 0 and p != lock:
			continue
		if _facing_only and _paint.parts[p].normals[i].dot(normal) < 0.1:
			continue
		var d := _paint.parts[p].positions[i] - center
		# Pas de peinture à travers une partie fine : on reste près de la surface touchée.
		if absf(d.dot(normal)) > _radius:
			continue
		var noise := 0.0
		if _tip.shape == BrushTip.Shape.SPONGE:
			# Texture fixée dans l'espace mais décalée à chaque touche : grain d'éponge.
			var q := (d + center) / (_radius * 0.22)
			noise = BrushTip.hash3(floori(q.x) + _dab_count * 31, floori(q.y), floori(q.z))
		elif _tip.shape == BrushTip.Shape.SPRAY:
			noise = BrushTip.hash3(found[k], _dab_count, 11)
		var w := _tip.weight(d.dot(u_axis) / _radius, d.dot(v_axis) / _radius, noise, _stroke_seed)
		match _tool:
			Tool.DRYBRUSH:
				w *= _paint.edge_factor(p, i)
			Tool.WASH:
				w *= 0.15 + 0.85 * _paint.recess_factor(p, i)
		w *= _flow
		if w > 0.001:
			weights[k] = w
			touched[p] = true

	# Fondu : moyenne pondérée du calque sous le pinceau, vers laquelle on tire chaque sommet.
	var avg_color := Color(0, 0, 0, 0)
	var avg_finish := Vector2.ZERO
	if _tool == Tool.BLUR:
		var total := 0.0
		for k in found.size():
			if weights[k] > 0.0:
				var p := found[k] >> bits
				var i := found[k] & mask
				avg_color += layer.colors[p][i] * weights[k]
				avg_finish += layer.finishes[p][i] * weights[k]
				total += weights[k]
		if total <= 0.0:
			return
		avg_color /= total
		avg_finish /= total

	for p: int in touched:
		# Sorti de l'Array pour être modifié sans recopie (voir FigurinePaint.Layer).
		var colors := layer.colors[p]
		var finishes := layer.finishes[p]
		layer.colors[p] = PackedColorArray()
		layer.finishes[p] = PackedVector2Array()
		for k in found.size():
			var w := weights[k]
			if w <= 0.0 or found[k] >> bits != p:
				continue
			var i := found[k] & mask
			var code := found[k]
			if not _stroke_changes.has(code):
				_stroke_changes[code] = [colors[i], finishes[i]]
			var c := colors[i]
			match _tool:
				Tool.ERASER:
					c.a = maxf(0.0, c.a - w)
				Tool.BLUR:
					c = c.lerp(avg_color, w)
					finishes[i] = finishes[i].lerp(avg_finish, w)
				_:
					var out_a := w + c.a * (1.0 - w)
					var keep := c.a * (1.0 - w)
					c = Color((color.r * w + c.r * keep) / out_a, (color.g * w + c.g * keep) / out_a,
							(color.b * w + c.b * keep) / out_a, out_a)
					finishes[i] = (finish * w + finishes[i] * keep) / out_a
			colors[i] = c
		layer.colors[p] = colors
		layer.finishes[p] = finishes

	for k in found.size():
		if weights[k] > 0.0:
			_paint.composite(found[k] >> bits, found[k] & mask)
	_unsaved = true


## Peint toute une pièce sur le calque actif, à l'opacité choisie.
func _fill_part(p: int) -> void:
	var layer := _paint.layers[_active]
	var old_colors := layer.colors[p].duplicate()
	var old_finishes := layer.finishes[p].duplicate()
	var color := _color.srgb_to_linear()
	var finish := Vector2(_metal, 1.0 - _gloss)
	var colors := layer.colors[p]
	var finishes := layer.finishes[p]
	layer.colors[p] = PackedColorArray()
	layer.finishes[p] = PackedVector2Array()
	for i in colors.size():
		var c := colors[i]
		var out_a := _flow + c.a * (1.0 - _flow)
		var keep := c.a * (1.0 - _flow)
		colors[i] = Color((color.r * _flow + c.r * keep) / out_a, (color.g * _flow + c.g * keep) / out_a,
				(color.b * _flow + c.b * keep) / out_a, out_a)
		finishes[i] = (finish * _flow + finishes[i] * keep) / out_a
	layer.colors[p] = colors
	layer.finishes[p] = finishes
	for i in colors.size():
		_paint.composite(p, i)
	_push_undo({"type": "part", "layer": layer, "part": p, "colors": old_colors, "finishes": old_finishes})
	_unsaved = true
	_set_status("Pièce « %s » remplie." % _paint.parts[p].name)


func _pick(hit: Dictionary) -> void:
	var p := int(hit["part"])
	_grid.query(hit["position"], 0.02)
	var best := -1
	var best_d := INF
	for k in _grid.found.size():
		if _grid.found[k] >> FigurinePaint.INDEX_BITS == p and _grid.found_dist[k] < best_d:
			best_d = _grid.found_dist[k]
			best = _grid.found[k] & FigurinePaint.INDEX_MASK
	if best < 0:
		return
	_set_color(_paint.paint_color(p, best).linear_to_srgb())
	var f := _paint.final_finish(p, best)
	_metal_slider.value = f.x
	_gloss_slider.value = 1.0 - f.y
	_set_status("Couleur prise sur « %s »." % _paint.parts[p].name)


# --- Annuler / rétablir ------------------------------------------------------------

func _push_undo(entry: Dictionary) -> void:
	_undo.append(entry)
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()


func _undo_step() -> void:
	if _undo.is_empty() or _stroke:
		return
	_redo.append(_apply_entry(_undo.pop_back()))
	_unsaved = true


func _redo_step() -> void:
	if _redo.is_empty() or _stroke:
		return
	_undo.append(_apply_entry(_redo.pop_back()))
	_unsaved = true


## Remet l'état noté dans [entry] et retourne l'entrée inverse (pour refaire / défaire).
func _apply_entry(entry: Dictionary) -> Dictionary:
	match String(entry["type"]):
		"paint":
			var layer: FigurinePaint.Layer = entry["layer"]
			var changes: Dictionary = entry["changes"]
			var inverse := {}
			for p in _paint.parts.size():
				var colors := layer.colors[p]
				var finishes := layer.finishes[p]
				layer.colors[p] = PackedColorArray()
				layer.finishes[p] = PackedVector2Array()
				for code: int in changes:
					if code >> FigurinePaint.INDEX_BITS != p:
						continue
					var i := code & FigurinePaint.INDEX_MASK
					inverse[code] = [colors[i], finishes[i]]
					colors[i] = changes[code][0]
					finishes[i] = changes[code][1]
				layer.colors[p] = colors
				layer.finishes[p] = finishes
			for code: int in changes:
				_paint.composite(code >> FigurinePaint.INDEX_BITS, code & FigurinePaint.INDEX_MASK)
			return {"type": "paint", "layer": layer, "changes": inverse}
		"part":
			var layer: FigurinePaint.Layer = entry["layer"]
			var p: int = entry["part"]
			var inverse := {"type": "part", "layer": layer, "part": p,
					"colors": layer.colors[p], "finishes": layer.finishes[p]}
			layer.colors[p] = entry["colors"]
			layer.finishes[p] = entry["finishes"]
			for i in _paint.parts[p].vertex_count():
				_paint.composite(p, i)
			return inverse
		_:
			# "layers" : ajout, suppression, déplacement ou fusion de calques.
			var inverse := _layers_snapshot(entry.get("modified", []) as Array)
			_paint.layers = entry["layers"]
			for saved: Array in entry["saved"]:
				var layer: FigurinePaint.Layer = saved[0]
				layer.colors = saved[1]
				layer.finishes = saved[2]
			_active = clampi(int(entry["active"]), 0, maxi(0, _paint.layers.size() - 1))
			_paint.composite_all()
			_refresh_layers()
			return inverse


## État des calques avant une opération sur eux. [modified] : calques dont les données
## vont changer (fusion), copiés en entier.
func _layers_snapshot(modified: Array) -> Dictionary:
	var saved: Array = []
	for layer: FigurinePaint.Layer in modified:
		var colors: Array[PackedColorArray] = []
		var finishes: Array[PackedVector2Array] = []
		for p in _paint.parts.size():
			colors.append(layer.colors[p].duplicate())
			finishes.append(layer.finishes[p].duplicate())
		saved.append([layer, colors, finishes])
	return {"type": "layers", "layers": _paint.layers.duplicate(), "saved": saved,
			"modified": modified, "active": _active}


# --- Calques ------------------------------------------------------------------------

func _add_layer() -> void:
	_push_undo(_layers_snapshot([]))
	_paint.layers.insert(_active + 1, _paint.new_layer("Calque %d" % (_paint.layers.size() + 1)))
	_active += 1
	_refresh_layers()


func _duplicate_layer() -> void:
	if _paint.layers.is_empty():
		return
	_push_undo(_layers_snapshot([]))
	var src := _paint.layers[_active]
	var copy := _paint.new_layer(src.name + " (copie)")
	copy.visible = src.visible
	copy.opacity = src.opacity
	copy.blend = src.blend
	for p in _paint.parts.size():
		copy.colors[p] = src.colors[p].duplicate()
		copy.finishes[p] = src.finishes[p].duplicate()
	_paint.layers.insert(_active + 1, copy)
	_active += 1
	_paint.composite_all()
	_refresh_layers()


func _delete_layer() -> void:
	if _paint.layers.is_empty():
		return
	_push_undo(_layers_snapshot([]))
	_paint.layers.remove_at(_active)
	_active = clampi(_active - 1, 0, maxi(0, _paint.layers.size() - 1))
	_paint.composite_all()
	_refresh_layers()
	_unsaved = true


func _clear_layer() -> void:
	if _paint.layers.is_empty():
		return
	var layer := _paint.layers[_active]
	_push_undo(_layers_snapshot([layer]))
	for p in _paint.parts.size():
		var c := PackedColorArray()
		c.resize(_paint.parts[p].vertex_count())
		c.fill(Color(0, 0, 0, 0))
		layer.colors[p] = c
	_paint.composite_all()
	_unsaved = true


func _move_layer(delta: int) -> void:
	var to := _active + delta
	if to < 0 or to >= _paint.layers.size():
		return
	_push_undo(_layers_snapshot([]))
	var layer := _paint.layers[_active]
	_paint.layers.remove_at(_active)
	_paint.layers.insert(to, layer)
	_active = to
	_paint.composite_all()
	_refresh_layers()
	_unsaved = true


func _merge_down() -> void:
	if _active <= 0:
		_set_status("Pas de calque en dessous.")
		return
	var snapshot := _layers_snapshot([_paint.layers[_active - 1]])
	if not _paint.merge_down(_active):
		_set_status("Fusion possible seulement entre deux calques en mode Normal.")
		return
	_push_undo(snapshot)
	_active -= 1
	_refresh_layers()
	_unsaved = true


## Reconstruit la liste des calques (le plus haut en premier, comme Photoshop).
func _refresh_layers() -> void:
	for c in _layer_list.get_children():
		c.queue_free()
	for idx in range(_paint.layers.size() - 1, -1, -1):
		var layer := _paint.layers[idx]
		var row := HBoxContainer.new()
		var eye := CheckBox.new()
		eye.button_pressed = layer.visible
		eye.tooltip_text = "Afficher / masquer"
		eye.focus_mode = Control.FOCUS_NONE
		eye.toggled.connect(func(on: bool) -> void:
			layer.visible = on
			_paint.composite_all()
			_unsaved = true)
		row.add_child(eye)
		var b := Button.new()
		b.text = "%s%s" % [layer.name, "" if layer.blend == FigurinePaint.BLEND_NORMAL else "  (%s)" % FigurinePaint.BLEND_NAMES[layer.blend]]
		b.toggle_mode = true
		b.button_pressed = idx == _active
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.pressed.connect(func() -> void:
			_active = idx
			_refresh_layers())
		row.add_child(b)
		_layer_list.add_child(row)
	var has := not _paint.layers.is_empty()
	_layer_name.editable = has
	_layer_opacity.editable = has
	_layer_blend.disabled = not has
	if has:
		var layer := _paint.layers[_active]
		_layer_name.text = layer.name
		_layer_opacity.set_value_no_signal(layer.opacity)
		_layer_blend.select(layer.blend)


# --- Divers -------------------------------------------------------------------------

func _select_shape(shape: BrushTip.Shape) -> void:
	_tip.shape = shape
	# Les pointes allongées sont faites pour suivre le trait.
	_follow_check.button_pressed = shape in BrushTip.FOLLOWS_STROKE
	_refresh_tip()
	_set_status("Pointe : %s. %s." % BrushTip.SHAPES[shape])


func _select_tool(t: Tool) -> void:
	_tool = t
	for k: Tool in _tool_buttons:
		(_tool_buttons[k] as Button).button_pressed = k == t
	_set_status(TOOLS[t][2])


func _set_color(c: Color) -> void:
	_color = c
	_picker.color = c
	_primary_rect.color = c


func _save() -> void:
	if _paint == null or _card == null:
		return
	var err := _paint.save(_card.id)
	if err == OK:
		_unsaved = false
		_set_status("Peinture enregistrée.")
	else:
		_set_status("Enregistrement impossible (%s)." % error_string(err))


func _leave() -> void:
	if _unsaved:
		_save()
	get_tree().change_scene_to_file(COLLECTION_SCENE)


func _capture() -> void:
	_layer_ui.visible = false
	_cursor.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_layer_ui.visible = true
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := CAPTURE_DIR + "%s_%s.png" % [_card.id if _card != null else &"figurine", stamp]
	var err := image.save_png(path)
	_set_status("Capture : %s" % ProjectSettings.globalize_path(path) if err == OK else "Capture impossible.")


func _set_status(text: String) -> void:
	_status.text = text


func _build_cursor() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_cursor_material = StandardMaterial3D.new()
	_cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cursor_material.no_depth_test = true
	_cursor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = _cursor_material
	_cursor = MeshInstance3D.new()
	_cursor.mesh = quad
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.visible = false
	add_child(_cursor)
	_refresh_tip()


## Redessine le curseur et les icônes après un changement de pointe.
func _refresh_tip() -> void:
	_tip.hardness = _hardness
	_cursor_material.albedo_texture = ImageTexture.create_from_image(_tip.make_image(128))
	for shape: BrushTip.Shape in _shape_buttons:
		(_shape_buttons[shape] as Button).button_pressed = shape == _tip.shape


func _update_cursor(hit: Dictionary) -> void:
	var show := not hit.is_empty() and _tool != Tool.PICKER and _tool != Tool.FILL
	_cursor.visible = show
	if not show:
		return
	var n: Vector3 = hit["world_normal"]
	var u := _tip_axis(n, true)
	# QuadMesh : face vers +Z, x = largeur de la pointe, y = son épaisseur.
	var basis := Basis(u, n.cross(u), n)
	_cursor.global_transform = Transform3D(basis.scaled(Vector3.ONE * _radius), hit["world"] + n * 0.002)


# --- Interface --------------------------------------------------------------------

func _build_ui() -> void:
	_layer_ui = CanvasLayer.new()
	add_child(_layer_ui)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = LEFT_WIDTH + 24
	top.offset_right = -RIGHT_WIDTH - 24
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer_ui.add_child(top)
	_title = _label(top, 24, "Atelier de peinture")
	_status = _label(top, 16, "")
	_status.modulate = Color(1, 1, 1, 0.75)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var help := _label(null, 14, "Clic gauche : peindre · clic droit : tourner · clic molette : déplacer · molette : zoom · F : recentrer · [ ] : taille · Maj+[ ] : dureté · , ; : angle · 1…0 : opacité · Alt+clic : pipette · X : couleurs · M : symétrie · Ctrl+Z / Ctrl+Y · Ctrl+S · Échap : collection")
	help.modulate = Color(1, 1, 1, 0.55)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_left = LEFT_WIDTH + 24
	help.offset_right = -RIGHT_WIDTH - 24
	help.offset_top = -52
	help.offset_bottom = -8
	help.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_layer_ui.add_child(help)

	_build_left_panel()
	_build_right_panel()
	_select_tool(Tool.BRUSH)


func _side_panel(left: bool, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	if left:
		panel.anchor_left = 0.0
		panel.anchor_right = 0.0
		panel.offset_left = 8
		panel.offset_right = 8 + width
	else:
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.offset_left = -8 - width
		panel.offset_right = -8
	panel.offset_top = 8
	panel.offset_bottom = -8
	_layer_ui.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	return box


func _build_left_panel() -> void:
	var box := _side_panel(true, LEFT_WIDTH)
	var back := _button(box, "◀ Collection (Échap)", _leave)
	back.add_theme_font_size_override("font_size", 15)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row, "Annuler", _undo_step).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "Rétablir", _redo_step).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row = HBoxContainer.new()
	box.add_child(row)
	_button(row, "Enregistrer", _save).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "Capture", _capture).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_section(box, "Outils")
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for t: Tool in TOOLS:
		var b := Button.new()
		b.text = TOOLS[t][0]
		b.tooltip_text = TOOLS[t][2]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_select_tool.bind(t))
		grid.add_child(b)
		_tool_buttons[t] = b

	_section(box, "Pinceau")
	_size_slider = _slider(box, "Taille", 0.0, 100.0, 0.5, _radius_to_slider(_radius),
			func(v: float) -> String: return "%.1f mm" % (_slider_to_radius(v) * 2.0 * MM_PER_UNIT),
			func(v: float) -> void: _radius = _slider_to_radius(v))
	_hardness_slider = _slider(box, "Dureté", 0.0, 1.0, 0.01, _hardness,
			func(v: float) -> String: return "%d %%" % roundi(v * 100.0),
			func(v: float) -> void:
				_hardness = v
				_refresh_tip())
	_flow_slider = _slider(box, "Opacité", 0.02, 1.0, 0.01, _flow,
			func(v: float) -> String: return "%d %%" % roundi(v * 100.0),
			func(v: float) -> void: _flow = v)

	_section(box, "Forme de la pointe")
	var shapes := GridContainer.new()
	shapes.columns = 4
	box.add_child(shapes)
	for shape: BrushTip.Shape in BrushTip.SHAPES:
		var icon_tip := BrushTip.new()
		icon_tip.shape = shape
		icon_tip.hardness = 0.75
		var b := Button.new()
		b.icon = ImageTexture.create_from_image(icon_tip.make_image(40, false))
		b.tooltip_text = "%s : %s" % BrushTip.SHAPES[shape]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(50, 48)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true
		b.pressed.connect(_select_shape.bind(shape))
		shapes.add_child(b)
		_shape_buttons[shape] = b
	_angle_slider = _slider(box, "Angle", -90.0, 90.0, 1.0, _angle,
			func(v: float) -> String: return "%d°" % roundi(v),
			func(v: float) -> void: _angle = v)
	_round_slider = _slider(box, "Rondeur", 0.1, 1.0, 0.01, _tip.roundness,
			func(v: float) -> String: return "%d %%" % roundi(v * 100.0),
			func(v: float) -> void:
				_tip.roundness = v
				_refresh_tip())
	_follow_check = _check(box, "Suivre le trait", _follow, func(on: bool) -> void: _follow = on)
	_follow_check.tooltip_text = "La pointe tourne avec la direction du trait (pinceau plat, poils)"

	_section(box, "Finition")
	_metal_slider = _slider(box, "Métal", 0.0, 1.0, 0.01, _metal,
			func(v: float) -> String: return "%d %%" % roundi(v * 100.0),
			func(v: float) -> void: _metal = v)
	_gloss_slider = _slider(box, "Brillance", 0.0, 1.0, 0.01, _gloss,
			func(v: float) -> String: return "%d %%" % roundi(v * 100.0),
			func(v: float) -> void: _gloss = v)

	_section(box, "Options")
	_mirror_check = _check(box, "Symétrie gauche / droite (M)", _mirror, func(on: bool) -> void: _mirror = on)
	var c := _check(box, "Rester sur la pièce", _lock_part, func(on: bool) -> void: _lock_part = on)
	c.tooltip_text = "Le pinceau ne déborde pas sur les autres pièces (corps, ailes, armes…)"
	c = _check(box, "Faces visibles seulement", _facing_only, func(on: bool) -> void: _facing_only = on)
	c.tooltip_text = "Ne peint pas l'autre côté des parties fines (ailes, lames)"
	c = _check(box, "Lumière neutre", true, func(on: bool) -> void: _stage.set_neutral_light(on))
	c.tooltip_text = "Lumière blanche pour juger les couleurs (sinon : lumière chaude du salon)"


func _build_right_panel() -> void:
	var box := _side_panel(false, RIGHT_WIDTH)
	_section(box, "Couleur")
	var swatches := HBoxContainer.new()
	box.add_child(swatches)
	_primary_rect = _swatch_rect(swatches, _color, "Couleur principale")
	_secondary_rect = _swatch_rect(swatches, _secondary, "Couleur secondaire (X pour inverser)")
	var swap := _button(swatches, "⇄", func() -> void:
		var c := _color
		_set_color(_secondary)
		_secondary = c
		_secondary_rect.color = c)
	swap.tooltip_text = "Inverser (X)"

	_picker = ColorPicker.new()
	_picker.color = _color
	_picker.edit_alpha = false
	_picker.picker_shape = ColorPicker.SHAPE_VHS_CIRCLE
	_picker.presets_visible = false
	_picker.sampler_visible = false
	_picker.color_modes_visible = false
	_picker.custom_minimum_size = Vector2(RIGHT_WIDTH - 24, 0)
	_picker.color_changed.connect(func(c: Color) -> void:
		_color = c
		_primary_rect.color = c)
	box.add_child(_picker)

	_section(box, "Peintures")
	var palette := GridContainer.new()
	palette.columns = 8
	box.add_child(palette)
	for entry: Array in PALETTE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 26)
		b.tooltip_text = "%s%s" % [entry[0], " (métal)" if float(entry[2]) > 0.5 else ""]
		b.focus_mode = Control.FOCUS_NONE
		var style := StyleBoxFlat.new()
		style.bg_color = entry[1]
		style.set_corner_radius_all(4)
		if float(entry[2]) > 0.5:
			style.border_color = Color(1, 1, 1, 0.8)
			style.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_stylebox_override("hover", style)
		b.add_theme_stylebox_override("pressed", style)
		b.pressed.connect(func() -> void:
			_set_color(entry[1])
			_metal_slider.value = float(entry[2])
			_gloss_slider.value = float(entry[3])
			_set_status("Peinture : %s" % entry[0]))
		palette.add_child(b)

	_section(box, "Calques")
	_layer_list = VBoxContainer.new()
	box.add_child(_layer_list)
	_layer_name = LineEdit.new()
	_layer_name.placeholder_text = "Nom du calque"
	_layer_name.text_submitted.connect(func(t: String) -> void:
		if not _paint.layers.is_empty() and t.strip_edges() != "":
			_paint.layers[_active].name = t.strip_edges()
			_unsaved = true
			_refresh_layers()
		_layer_name.release_focus())
	box.add_child(_layer_name)
	_layer_opacity = _slider(box, "Opacité du calque", 0.0, 1.0, 0.01, 1.0,
			func(v: float) -> String: return "%d %%" % roundi(v * 100.0),
			func(v: float) -> void:
				if _paint != null and not _paint.layers.is_empty():
					_paint.layers[_active].opacity = v
					_unsaved = true)
	# Recomposer toute la figurine est long : seulement au relâchement du curseur.
	_layer_opacity.drag_ended.connect(func(_changed: bool) -> void:
		if _paint != null:
			_paint.composite_all())
	_layer_blend = OptionButton.new()
	for n in FigurinePaint.BLEND_NAMES:
		_layer_blend.add_item("Mode : %s" % n)
	_layer_blend.focus_mode = Control.FOCUS_NONE
	_layer_blend.tooltip_text = "Normal : couvre. Produit : assombrit (ombres, glacis)."
	_layer_blend.item_selected.connect(func(i: int) -> void:
		if _paint != null and not _paint.layers.is_empty():
			_paint.layers[_active].blend = i
			_paint.composite_all()
			_unsaved = true
			_refresh_layers())
	box.add_child(_layer_blend)
	var row := HBoxContainer.new()
	box.add_child(row)
	for spec: Array in [["+", "Nouveau calque", _add_layer], ["Copie", "Dupliquer le calque", _duplicate_layer],
			["▲", "Monter", _move_layer.bind(1)], ["▼", "Descendre", _move_layer.bind(-1)]]:
		var b := _button(row, spec[0], spec[2])
		b.tooltip_text = spec[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row = HBoxContainer.new()
	box.add_child(row)
	for spec: Array in [["Fusionner", "Fusionner avec le calque du dessous", _merge_down],
			["Vider", "Effacer tout le calque", _clear_layer], ["Suppr.", "Supprimer le calque", _delete_layer]]:
		var b := _button(row, spec[0], spec[2])
		b.tooltip_text = spec[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _radius_to_slider(r: float) -> float:
	return log(r / RADIUS_MIN) / log(RADIUS_MAX / RADIUS_MIN) * 100.0


func _slider_to_radius(v: float) -> float:
	return RADIUS_MIN * pow(RADIUS_MAX / RADIUS_MIN, v / 100.0)


func _section(parent: Control, text: String) -> void:
	var l := _label(parent, 17, text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.55))


func _label(parent: Control, font_size: int, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	return l


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _check(parent: Control, text: String, on: bool, on_toggle: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 14)
	c.toggled.connect(on_toggle)
	parent.add_child(c)
	return c


## Curseur avec son libellé et sa valeur affichée par [format].
func _slider(parent: Control, text: String, min_v: float, max_v: float, step_v: float, value: float,
		format: Callable, on_change: Callable) -> HSlider:
	var head := HBoxContainer.new()
	parent.add_child(head)
	var name_label := _label(head, 14, text)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _label(head, 14, format.call(value))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step_v
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float) -> void:
		value_label.text = format.call(v)
		on_change.call(v))
	parent.add_child(s)
	return s


func _swatch_rect(parent: Control, color: Color, tip: String) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(44, 28)
	r.tooltip_text = tip
	parent.add_child(r)
	return r
