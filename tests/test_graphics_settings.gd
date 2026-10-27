extends TestCase
## Partie données de GraphicsSettings (valeurs, préréglages, sauvegarde) : sans rendu.

const GS := preload("res://src/platform/graphics_settings.gd")
const TMP := "user://test_settings.cfg"


func teardown() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func test_defaults_are_valid_values() -> void:
	var d := GS.defaults()
	for s: Dictionary in GS.SETTINGS:
		assert_eq(GS.sanitize(s.key, d[s.key]), d[s.key], "défaut invalide pour %s" % s.key)


func test_presets_only_use_valid_values() -> void:
	for preset: String in GS.PRESETS.keys():
		var p: Dictionary = GS.PRESETS[preset]
		for key: String in p.keys():
			assert_ne(GS.sanitize(key, p[key]), null, "%s : valeur invalide pour %s" % [preset, key])
	# Tous les préréglages règlent les mêmes paramètres.
	var keys: Array = (GS.PRESETS["high"] as Dictionary).keys()
	keys.sort()
	for preset: String in GS.PRESETS.keys():
		var other: Array = (GS.PRESETS[preset] as Dictionary).keys()
		other.sort()
		assert_eq(other, keys, "paramètres du préréglage %s" % preset)


func test_sanitize_rejects_and_clamps() -> void:
	assert_null(GS.sanitize("inconnu", 1))
	assert_null(GS.sanitize("msaa", 7), "pas d'option MSAA 7")
	assert_null(GS.sanitize("vsync", "turbo"))
	assert_eq(GS.sanitize("render_scale", 9.0), 2.0, "borné au maximum")
	assert_eq(GS.sanitize("msaa", 2.0), 2, "ConfigFile peut rendre des float")


func test_apply_preset_sets_quality_values() -> void:
	var v := GS.defaults()
	GS.apply_preset_to(v, "low")
	assert_eq(v["preset"], "low")
	assert_eq(v["shadow_size"], 1024)
	assert_eq(v["ssao"], -1)
	assert_eq(v["window_mode"], "windowed", "un préréglage ne touche pas à l'affichage")


func test_save_and_load_roundtrip_ignores_garbage() -> void:
	var v := GS.defaults()
	GS.apply_preset_to(v, "ultra")
	v["brightness"] = 1.2
	assert_eq(GS.save_values(TMP, v), OK)
	var cfg := ConfigFile.new()
	cfg.load(TMP)
	cfg.set_value(GS.SECTION, "msaa", 99)
	cfg.set_value(GS.SECTION, "pirate", true)
	cfg.save(TMP)
	var back := GS.load_values(TMP)
	assert_eq(back["preset"], "ultra")
	assert_eq(back["brightness"], 1.2)
	assert_false(back.has("msaa"), "valeur invalide ignorée")
	assert_false(back.has("pirate"), "clé inconnue ignorée")
