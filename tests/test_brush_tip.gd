extends TestCase


func _tip(shape: BrushTip.Shape, hardness: float = 1.0) -> BrushTip:
	var t := BrushTip.new()
	t.shape = shape
	t.hardness = hardness
	return t


func test_envelopes() -> void:
	var round := _tip(BrushTip.Shape.ROUND)
	assert_eq(round.weight(0.0, 0.0, 0.0), 1.0)
	assert_eq(round.weight(0.75, 0.75, 0.0), 0.0, "hors du cercle")
	var square := _tip(BrushTip.Shape.SQUARE)
	assert_eq(square.weight(0.95, 0.95, 0.0), 1.0, "coin du carré")
	var diamond := _tip(BrushTip.Shape.DIAMOND)
	assert_eq(diamond.weight(0.6, 0.6, 0.0), 0.0, "hors du losange")
	assert_eq(diamond.weight(0.9, 0.0, 0.0), 1.0)
	var flat := _tip(BrushTip.Shape.FLAT)
	assert_eq(flat.weight(0.9, 0.0, 0.0), 1.0, "large en x")
	assert_eq(flat.weight(0.0, 0.5, 0.0), 0.0, "fin en y")


func test_hardness_softens_edges() -> void:
	var soft := _tip(BrushTip.Shape.ROUND, 0.0)
	var w1 := soft.weight(0.3, 0.0, 0.0)
	var w2 := soft.weight(0.8, 0.0, 0.0)
	assert_true(w1 > w2 and w2 > 0.0, "dégradé du centre vers le bord")


func test_roundness_squashes() -> void:
	var t := _tip(BrushTip.Shape.ROUND)
	t.roundness = 0.3
	assert_eq(t.weight(0.0, 0.5, 0.0), 0.0, "écrasé en y")
	assert_eq(t.weight(0.9, 0.0, 0.0), 1.0, "intact en x")


func test_textured_tips_use_noise() -> void:
	var sponge := _tip(BrushTip.Shape.SPONGE)
	assert_eq(sponge.weight(0.0, 0.0, 0.1), 0.0, "trou de l'éponge")
	assert_eq(sponge.weight(0.0, 0.0, 0.9), 1.0)
	var spray := _tip(BrushTip.Shape.SPRAY)
	assert_eq(spray.weight(0.0, 0.0, 0.1), 1.0, "un point")
	assert_eq(spray.weight(0.0, 0.0, 0.9), 0.0, "pas de point")
	var bristle := _tip(BrushTip.Shape.BRISTLE)
	var values := {}
	for x in 20:
		values[snappedf(bristle.weight(-0.95 + x * 0.1, 0.0, 0.0, 5), 0.01)] = true
	assert_true(values.size() > 3, "des poils plus ou moins chargés")


func test_hash_is_stable_and_in_range() -> void:
	assert_eq(BrushTip.hash3(1, 2, 3), BrushTip.hash3(1, 2, 3))
	for i in 200:
		var h := BrushTip.hash3(i, -i, i * 7)
		assert_true(h >= 0.0 and h <= 1.0)


func test_image_has_shape() -> void:
	var img := _tip(BrushTip.Shape.ROUND, 0.8).make_image(32)
	assert_true(img.get_pixel(16, 16).a > 0.4, "plein au centre")
	assert_eq(img.get_pixel(0, 0).a, 0.0, "vide dans le coin")
