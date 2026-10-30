extends TestCase


func _card(id: StringName, name: String, family: String) -> CardDef:
	var c := CardDef.new()
	c.id = id
	c.display_name = name
	c.family = family
	return c


func test_data_dir_loads_valid_cards() -> void:
	var catalog := CardCatalog.load_dir()
	assert_true(catalog.size() > 0, "des cartes dans %s" % CardCatalog.DATA_DIR)
	for family in catalog.families():
		assert_ne(family, "", "chaque carte a une famille")
		for card in catalog.cards_of(family):
			assert_ne(card.display_name, "", "%s a un nom" % card.id)
			assert_true(card.model_path.begins_with("res://") and card.model_path.ends_with(".glb"),
					"%s : modèle .glb" % card.id)
			assert_eq(String(card.id), card.resource_path.get_file().get_basename(),
					"le fichier porte l'identifiant de la carte")


func test_lookup_and_families() -> void:
	var catalog := CardCatalog.new()
	catalog.add(_card(&"b", "Bêta", "Nains"))
	catalog.add(_card(&"a", "alpha", "Dragons"))
	catalog.add(_card(&"c", "Gamma", "Dragons"))
	assert_eq(catalog.size(), 3)
	assert_true(catalog.has(&"a"))
	assert_false(catalog.has(&"z"))
	assert_null(catalog.get_card(&"z"))
	assert_eq(catalog.get_card(&"b").display_name, "Bêta")
	assert_eq(catalog.families(), PackedStringArray(["Dragons", "Nains"]))
	var names := catalog.cards_of("Dragons").map(func(c: CardDef) -> String: return c.display_name)
	assert_eq(names, ["alpha", "Gamma"], "triées par nom, sans tenir compte de la casse")


func test_duplicate_id_is_ignored() -> void:
	var catalog := CardCatalog.new()
	catalog.add(_card(&"a", "Premier", "X"))
	catalog.add(_card(&"a", "Doublon", "X"))
	assert_eq(catalog.size(), 1)
	assert_eq(catalog.get_card(&"a").display_name, "Premier")
