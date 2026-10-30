extends Node3D
## Écran Collection : toutes les cartes du jeu, celles du joueur en couleur avec leur
## nombre d'exemplaires, les autres grisées (figurine en silhouette). Consultation seule.
## La collection vient du serveur (elle y est stockée, par SteamID vérifié) : l'écran se
## connecte, envoie HELLO avec le ticket Steam, demande la collection, puis se déconnecte.
## - panneau de gauche ou flèches haut / bas : famille ; liste des cartes cliquable ;
## - flèches gauche / droite (ou boutons à l'écran) : carte précédente / suivante ;
## - souris : voir FigurineStage (tourner, zoomer) ; Échap : menu.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const MainMenu := preload("res://src/ui/main_menu.gd")
const PaintStudio := preload("res://src/ui/paint_studio.gd")
const PAINT_SCENE := "res://scenes/paint_studio.tscn"
const PANEL_WIDTH := 300.0
const LOCKED_COLOR := Color(1, 1, 1, 0.38)

var _catalog: CardCatalog
## null tant que le serveur ne l'a pas envoyée.
var _collection: CardCollection = null
var _client: NetClient

var _families: PackedStringArray = []
var _family: int = 0
var _cards: Array[CardDef] = []
var _index: int = 0

var _stage: FigurineStage
var _silhouette: StandardMaterial3D
var _family_list: ItemList
var _card_list: ItemList
var _total_label: Label
var _name_label: Label
var _owned_label: Label
var _status_label: Label
var _paint_button: Button


func _ready() -> void:
	_catalog = CardCatalog.load_dir()
	_families = _catalog.families()
	_stage = FigurineStage.new()
	add_child(_stage)
	_silhouette = StandardMaterial3D.new()
	_silhouette.albedo_color = Color(0.2, 0.2, 0.22)
	_silhouette.roughness = 0.9
	_build_ui()
	_select_card(PaintStudio.card_id)
	_refresh_lists()
	_connect()


func _exit_tree() -> void:
	if _client != null:
		_client.close()


func _process(_delta: float) -> void:
	if _client != null:
		_client.poll()


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


# --- Serveur ---------------------------------------------------------------------

func _connect() -> void:
	var address := MainMenu.server_address(OS.get_cmdline_user_args())
	_set_status("Connexion au serveur…")
	_client = NetClient.new()
	_client.connected.connect(func() -> void:
		SteamService.request_server_ticket(func(ticket: String) -> void:
			_client.send(Protocol.hello(ticket, SteamService.claimed_steam_id()))))
	_client.disconnected.connect(func() -> void:
		if _collection == null:
			_set_status("Serveur injoignable : collection indisponible."))
	_client.message_received.connect(_on_server_message)
	var err := _client.connect_to(String(address[0]), int(address[1]))
	if err != OK:
		_set_status("Connexion impossible (%s)." % error_string(err))


func _on_server_message(msg: Dictionary) -> void:
	match Protocol.type_of(msg):
		Protocol.WELCOME:
			_set_status("Chargement de la collection…")
			_client.send(Protocol.get_collection())
		Protocol.COLLECTION:
			_collection = CardCollection.from_dict(msg.get("cards"))
			_set_status("")
			_client.close()
			_refresh_lists()
		Protocol.ERROR:
			_set_status("Collection indisponible : %s" % msg.get("reason", "?"))
			_client.close()


func _set_status(text: String) -> void:
	_status_label.text = text
	_status_label.visible = text != ""


# --- Affichage -------------------------------------------------------------------

func _count_of(card: CardDef) -> int:
	return _collection.count_of(card.id) if _collection != null else 0


## Se place sur la carte [id] (retour de l'atelier de peinture).
func _select_card(id: StringName) -> void:
	var card := _catalog.get_card(id)
	if card == null:
		return
	_family = maxi(0, _families.find(card.family))
	_index = maxi(0, _catalog.cards_of(card.family).find(card))


## Remplit le panneau en gardant la famille et la carte affichées.
func _refresh_lists() -> void:
	var owned := 0
	_family_list.clear()
	for f in _families:
		var cards := _catalog.cards_of(f)
		var n := 0
		for card in cards:
			if _count_of(card) > 0:
				n += 1
		owned += n
		_family_list.add_item("%s  (%d / %d)" % [f, n, cards.size()])
	_total_label.text = "Collection : %d / %d cartes" % [owned, _catalog.size()]
	_select_family(_family, _index)


## Passe à la famille [i] (la liste boucle) et affiche sa carte [index].
func _select_family(i: int, index: int = 0) -> void:
	_cards = []
	if not _families.is_empty():
		_family = posmod(i, _families.size())
		_cards = _catalog.cards_of(_families[_family])
		_family_list.select(_family)
		_family_list.ensure_current_is_visible()
	_card_list.clear()
	for card in _cards:
		var n := _count_of(card)
		var item := _card_list.add_item("%s  ×%d" % [card.display_name, n] if n > 0 else card.display_name)
		if n == 0:
			_card_list.set_item_custom_fg_color(item, LOCKED_COLOR)
	_show(index)


## Affiche la carte [i] de la famille (la liste boucle).
func _show(i: int) -> void:
	if _cards.is_empty():
		_stage.clear()
		_name_label.text = "Aucune carte"
		_owned_label.text = ""
		return
	_index = posmod(i, _cards.size())
	var card := _cards[_index]
	var n := _count_of(card)
	_card_list.select(_index)
	_card_list.ensure_current_is_visible()
	_name_label.text = card.display_name
	_name_label.modulate = Color.WHITE if n > 0 else LOCKED_COLOR
	if n > 0:
		_owned_label.text = "Possédée : %d exemplaire%s" % [n, "s" if n > 1 else ""]
	else:
		_owned_label.text = "Pas encore obtenue"
	var shown := _stage.show_model(card.model_path, null if n > 0 else _silhouette)
	if not shown:
		_owned_label.text += " · modèle absent sur ce PC"
	elif n > 0 and FigurinePaint.has_save(card.id):
		var paint := FigurinePaint.attach(_stage.model())
		paint.load_saved(card.id)
		paint.flush()
	# Seules les figurines possédées se peignent.
	_paint_button.visible = n > 0 and shown


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 24
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	_name_label = _label(top, 34)
	_owned_label = _label(top, 20)
	_owned_label.modulate = Color(1, 1, 1, 0.75)
	_paint_button = Button.new()
	_paint_button.text = "Peindre cette figurine"
	_paint_button.add_theme_font_size_override("font_size", 18)
	_paint_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_paint_button.focus_mode = Control.FOCUS_NONE
	_paint_button.visible = false
	_paint_button.pressed.connect(func() -> void:
		PaintStudio.card_id = _cards[_index].id
		get_tree().change_scene_to_file(PAINT_SCENE))
	top.add_child(_paint_button)

	# Messages de connexion, au-dessus de l'aide en bas de l'écran.
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_status_label.offset_top = -100
	_status_label.offset_bottom = -60
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_status_label)

	_build_panel(layer)

	var prev := _arrow_button("◀", Control.PRESET_CENTER_LEFT, PANEL_WIDTH + 40)
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
	help.text = "↑ ↓ : famille · ← → : carte · clic enfoncé : tourner · molette : zoom · clic molette : vue de départ · Échap : menu"
	help.add_theme_font_size_override("font_size", 16)
	help.modulate = Color(1, 1, 1, 0.6)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -48
	help.offset_bottom = -20
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(help)


## Panneau de gauche : total, familles (possédées / total) et cartes de la famille.
func _build_panel(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = 64
	panel.offset_right = 16 + PANEL_WIDTH
	panel.offset_bottom = -64
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_total_label = _label(box, 20)
	_label(box, 22).text = "Familles"
	_family_list = _panel_list(box, 1.0)
	_family_list.item_selected.connect(func(i: int) -> void:
		if i != _family:
			_select_family(i))
	_label(box, 22).text = "Cartes"
	# Deux fois plus haute que celle des familles : une famille compte des dizaines de cartes.
	_card_list = _panel_list(box, 2.0)
	_card_list.item_selected.connect(func(i: int) -> void:
		if i != _index:
			_show(i))


func _label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


## Liste du panneau de gauche, qui prend [ratio] parts de la hauteur libre.
func _panel_list(box: VBoxContainer, ratio: float) -> ItemList:
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = ratio
	list.add_theme_font_size_override("font_size", 17)
	# Pas de focus clavier : les flèches restent à l'écran (↑ ↓ famille, ← → carte).
	list.focus_mode = Control.FOCUS_NONE
	box.add_child(list)
	return list


func _arrow_button(text: String, preset: Control.LayoutPreset, x_offset: float) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 40)
	b.custom_minimum_size = Vector2(72, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.size = b.custom_minimum_size
	b.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
	b.position.x += x_offset
	return b
