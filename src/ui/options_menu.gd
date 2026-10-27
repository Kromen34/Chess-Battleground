extends Control
## Écran Options : un onglet par catégorie de GraphicsSettings.SETTINGS, une ligne
## par réglage. Chaque changement est appliqué et sauvegardé immédiatement.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const ROW_HEIGHT := 40

## key -> contrôle (OptionButton, CheckButton ou HSlider), pour rafraîchir l'affichage.
var _controls: Dictionary = {}
var _value_labels: Dictionary = {}
var _refreshing: bool = false


func _ready() -> void:
	_build()
	GraphicsSettings.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.15, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(760, 620)
	root.add_theme_constant_override("separation", 14)
	center.add_child(root)

	var title := Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 18)
	root.add_child(tabs)
	var pages: Dictionary = {}
	for s: Dictionary in GraphicsSettings.SETTINGS:
		var tab: String = s.tab
		if not pages.has(tab):
			var margin := MarginContainer.new()
			margin.name = tab
			for side in ["left", "right", "top", "bottom"]:
				margin.add_theme_constant_override("margin_" + side, 18)
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 24)
			grid.add_theme_constant_override("v_separation", 10)
			margin.add_child(grid)
			tabs.add_child(margin)
			pages[tab] = grid
		_add_row(pages[tab], s)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	root.add_child(buttons)
	var reset := _button("Valeurs par défaut")
	reset.pressed.connect(GraphicsSettings.reset_to_defaults)
	buttons.add_child(reset)
	var back := _button("Retour")
	back.pressed.connect(_back)
	buttons.add_child(back)
	back.grab_focus.call_deferred()


func _add_row(grid: GridContainer, s: Dictionary) -> void:
	var label := Label.new()
	label.text = s.label
	label.custom_minimum_size = Vector2(340, ROW_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	grid.add_child(label)
	var key: String = s.key
	match s.type:
		"choice":
			var ob := OptionButton.new()
			ob.custom_minimum_size = Vector2(320, ROW_HEIGHT)
			ob.add_theme_font_size_override("font_size", 18)
			for opt: Array in s.options:
				ob.add_item(String(opt[0]))
			ob.item_selected.connect(func(i: int) -> void: _on_changed(key, s.options[i][1]))
			grid.add_child(ob)
			_controls[key] = ob
		"toggle":
			var cb := CheckButton.new()
			cb.custom_minimum_size = Vector2(320, ROW_HEIGHT)
			cb.toggled.connect(func(on: bool) -> void: _on_changed(key, on))
			grid.add_child(cb)
			_controls[key] = cb
		"slider":
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(320, ROW_HEIGHT)
			var slider := HSlider.new()
			slider.min_value = s.min
			slider.max_value = s.max
			slider.step = s.step
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var value_label := Label.new()
			value_label.custom_minimum_size = Vector2(64, 0)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.add_theme_font_size_override("font_size", 18)
			# Appliqué au relâchement : changer la résolution du rendu à chaque pixel saccade.
			slider.value_changed.connect(func(v: float) -> void: value_label.text = _format(s, v))
			slider.drag_ended.connect(func(_changed: bool) -> void: _on_changed(key, slider.value))
			row.add_child(slider)
			row.add_child(value_label)
			grid.add_child(row)
			_controls[key] = slider
			_value_labels[key] = value_label


func _on_changed(key: String, value: Variant) -> void:
	if not _refreshing:
		GraphicsSettings.set_value(key, value)


## Recopie les valeurs courantes dans les contrôles (après un préréglage, par exemple).
func _refresh() -> void:
	_refreshing = true
	for s: Dictionary in GraphicsSettings.SETTINGS:
		var key: String = s.key
		var v: Variant = GraphicsSettings.values[key]
		var c: Control = _controls[key]
		match s.type:
			"choice":
				for i in range((s.options as Array).size()):
					if GraphicsSettings.sanitize(key, s.options[i][1]) == v:
						(c as OptionButton).select(i)
			"toggle":
				(c as CheckButton).set_pressed_no_signal(bool(v))
			"slider":
				(c as HSlider).set_value_no_signal(float(v))
				(_value_labels[key] as Label).text = _format(s, float(v))
	# La taille de fenêtre ne s'applique qu'en mode fenêtré.
	(_controls["resolution"] as OptionButton).disabled = GraphicsSettings.values.window_mode != "windowed"
	_refreshing = false


static func _format(s: Dictionary, v: float) -> String:
	return "%d %%" % roundi(v * 100.0) if s.get("percent", false) else str(v)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 48)
	b.add_theme_font_size_override("font_size", 20)
	return b


func _back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
