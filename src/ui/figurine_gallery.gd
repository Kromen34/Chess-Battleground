extends Node3D
## Galerie des figurines : une figurine à la fois sur un présentoir.
## - panneau de gauche ou flèches haut / bas : famille (un dossier de Figurines/, avec ses sous-dossiers) ;
##   sous la famille, la liste de ses figurines : un clic affiche la figurine ;
## - flèches gauche / droite (ou boutons à l'écran) : figurine précédente / suivante ;
## - souris : voir FigurineStage (tourner, zoomer) ; Échap : menu ;
## - Suppr (ou bouton) : mettre la figurine de côté, dans <famille>/En attente/ (le fichier est
##   déplacé, pas effacé) ; la case « Voir les figurines en attente » permet de les remettre.
## Les modèles viennent des sous-dossiers de res://Figurines/ (absents de git, voir CLAUDE.md).

const MENU_SCENE := "res://scenes/main_menu.tscn"
const FIGURINES_DIR := "res://Figurines/"

const FAMILY_PANEL_WIDTH := 300.0
## Famille des .glb posés directement dans Figurines/, hors sous-dossier.
const LOOSE_FAMILY := "Divers"
## Dossier des figurines mises de côté, dans chaque famille : la galerie ne les montre plus.
const ON_HOLD_DIR := "En attente"

## Familles -> chemins de leurs modèles, et famille affichée.
var _families: Dictionary = {}
var _family_names: PackedStringArray = []
var _family: int = 0
var _family_list: ItemList
var _figurine_list: ItemList
## true : on parcourt les figurines en attente (pour les remettre) au lieu des autres.
var _on_hold: bool = false
var _hold_button: Button
var _paths: PackedStringArray = []
var _index: int = 0
var _stage: FigurineStage
var _name_label: Label
var _count_label: Label


func _ready() -> void:
	_stage = FigurineStage.new()
	add_child(_stage)
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


## Passe à la famille [i] (la liste boucle) et affiche sa figurine [index].
func _select_family(i: int, index: int = 0) -> void:
	if _family_names.is_empty():
		_paths = []
	else:
		_family = posmod(i, _family_names.size())
		_paths = _families[_family_names[_family]]
		_family_list.select(_family)
		_family_list.ensure_current_is_visible()
	_figurine_list.clear()
	for p in _paths:
		_figurine_list.add_item(figurine_name(p))
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
	_stage.clear()
	if _paths.is_empty():
		_name_label.text = "Aucune figurine trouvée"
		_count_label.text = "Les modèles vont dans %s (voir CLAUDE.md, « Figurines »)." % FIGURINES_DIR
		return
	_index = posmod(i, _paths.size())
	var path := _paths[_index]
	_name_label.text = display_name(path)
	_figurine_list.select(_index)
	_figurine_list.ensure_current_is_visible()
	_count_label.text = "%d / %d" % [_index + 1, _paths.size()]
	if not _stage.show_model(path):
		_name_label.text += " (illisible)"


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


## « res://Figurines/Dragons/dragon_a_lancier.glb » -> « Dragon A Lancier ».
static func figurine_name(path: String) -> String:
	return path.get_file().get_basename().replace("_", " ").capitalize()


## « res://Figurines/Dragons/dragon_a_lancier.glb » -> « Dragons — Dragon A Lancier ».
static func display_name(path: String) -> String:
	var name := figurine_name(path)
	var folder := path.get_base_dir().get_file()
	return name if folder == "" or folder == "Figurines" else "%s — %s" % [folder, name]


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
	_family_list = _panel_list(box, 1.0)
	_family_list.item_selected.connect(func(i: int) -> void:
		if i != _family:
			_select_family(i))

	var fig_title := title.duplicate() as Label
	fig_title.text = "Figurines"
	box.add_child(fig_title)
	# Deux fois plus haute que celle des familles : une famille compte des dizaines de figurines.
	_figurine_list = _panel_list(box, 2.0)
	_figurine_list.item_selected.connect(func(i: int) -> void:
		if i != _index:
			_show(i))

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


## Liste du panneau de gauche, qui prend [ratio] parts de la hauteur libre.
func _panel_list(box: VBoxContainer, ratio: float) -> ItemList:
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = ratio
	list.add_theme_font_size_override("font_size", 17)
	# Pas de focus clavier : les flèches restent à la galerie (↑ ↓ famille, ← → figurine).
	list.focus_mode = Control.FOCUS_NONE
	box.add_child(list)
	return list


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
