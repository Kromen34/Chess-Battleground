extends TestCase


func test_add_and_count() -> void:
	var c := CardCollection.new()
	assert_eq(c.count_of(&"onixia"), 0)
	assert_false(c.owns(&"onixia"))
	assert_true(c.add(&"onixia"))
	assert_true(c.add(&"onixia", 2))
	assert_true(c.add(&"flamagath_aile"))
	assert_eq(c.count_of(&"onixia"), 3)
	assert_true(c.owns(&"onixia"))
	assert_eq(c.distinct_count(), 2)
	assert_eq(c.total_count(), 4)


func test_add_rejects_invalid() -> void:
	var c := CardCollection.new()
	assert_false(c.add(&"", 1), "id vide")
	assert_false(c.add(&"onixia", 0), "zéro exemplaire")
	assert_false(c.add(&"onixia", -3), "nombre négatif")
	assert_eq(c.distinct_count(), 0)


func test_copies_are_capped() -> void:
	var c := CardCollection.new()
	c.add(&"onixia", CardCollection.MAX_COPIES)
	c.add(&"onixia", 5)
	assert_eq(c.count_of(&"onixia"), CardCollection.MAX_COPIES)


func test_json_roundtrip() -> void:
	var c := CardCollection.new()
	c.add(&"onixia", 2)
	c.add(&"dragon_a_lancier")
	var json: Variant = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := CardCollection.from_dict(json)
	assert_eq(back.count_of(&"onixia"), 2, "JSON rend des float : relus en int")
	assert_eq(back.count_of(&"dragon_a_lancier"), 1)
	assert_eq(back.distinct_count(), 2)


func test_from_dict_ignores_bad_entries() -> void:
	var back := CardCollection.from_dict({"onixia": 2, "x": "beaucoup", "y": -1, "z": 0, "w": null})
	assert_eq(back.to_dict(), {"onixia": 2})
	assert_eq(CardCollection.from_dict("pas un dictionnaire").distinct_count(), 0)
	assert_eq(CardCollection.from_dict(null).distinct_count(), 0)


func test_to_dict_is_a_copy() -> void:
	var c := CardCollection.new()
	c.add(&"onixia")
	var d := c.to_dict()
	d["onixia"] = 50
	assert_eq(c.count_of(&"onixia"), 1)
