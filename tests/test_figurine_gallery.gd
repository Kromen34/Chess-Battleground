extends TestCase
## Partie sans rendu de la galerie : liste des modèles et noms affichés.

const Gallery := preload("res://src/ui/figurine_gallery.gd")
const TMP := "user://test_galerie/"


func teardown() -> void:
	if not DirAccess.dir_exists_absolute(TMP):
		return
	for d in ["Dragons/En attente/", "Dragons/Draconiens/", "Dragons/", ""]:
		if not DirAccess.dir_exists_absolute(TMP + d):
			continue
		for f in DirAccess.get_files_at(TMP + d):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + d + f))
		if d != "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + d))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _touch(path: String) -> void:
	FileAccess.open(path, FileAccess.WRITE).close()


func test_list_models_merges_glb_and_import_and_sorts() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP + "Dragons/Draconiens"))
	_touch(TMP + "Dragons/Draconiens/onixia.glb")  # sous-dossier d'une famille
	_touch(TMP + "Dragons/b.glb")
	_touch(TMP + "Dragons/b.glb.import")
	_touch(TMP + "Dragons/a.glb.import")  # jeu exporté : seul le .import reste
	_touch(TMP + "Dragons/notes.txt")
	_touch(TMP + "c.glb")
	var got := Gallery.list_models(TMP)
	assert_eq(got, PackedStringArray([TMP + "Dragons/Draconiens/onixia.glb", TMP + "Dragons/a.glb",
			TMP + "Dragons/b.glb", TMP + "c.glb"]))


func test_list_models_of_missing_folder_is_empty() -> void:
	assert_eq(Gallery.list_models("user://dossier_qui_n_existe_pas/").size(), 0)


func test_display_name() -> void:
	assert_eq(Gallery.display_name("res://Figurines/Dragons/dragon_a_lancier.glb"), "Dragons — Dragon A Lancier")
	assert_eq(Gallery.display_name("res://Figurines/azgrathok.glb"), "Azgrathok")


func test_family_is_first_folder_under_root() -> void:
	var root := "res://Figurines/"
	assert_eq(Gallery.family_of(root + "Dragons/dragon_a_lancier.glb", root), "Dragons")
	assert_eq(Gallery.family_of(root + "Dragons/Draconiens/onixia.glb", root), "Dragons")
	assert_eq(Gallery.family_of(root + "azgrathok.glb", root), Gallery.LOOSE_FAMILY)


func test_group_by_family_sorts_families_and_keeps_order() -> void:
	var root := "res://Figurines/"
	var got := Gallery.group_by_family(PackedStringArray([
			root + "Nains/x.glb", root + "Dragons/Draconiens/a.glb", root + "Dragons/b.glb"]), root)
	assert_eq(PackedStringArray(got.keys()), PackedStringArray(["Dragons", "Nains"]))
	assert_eq(got["Dragons"], PackedStringArray([root + "Dragons/Draconiens/a.glb", root + "Dragons/b.glb"]))


func test_on_hold_folder_is_listed_apart() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP + "Dragons/En attente"))
	_touch(TMP + "Dragons/a.glb")
	_touch(TMP + "Dragons/En attente/b.glb")
	assert_eq(Gallery.list_models(TMP), PackedStringArray([TMP + "Dragons/a.glb"]))
	assert_eq(Gallery.list_models(TMP, true), PackedStringArray([TMP + "Dragons/En attente/b.glb"]))


func test_on_hold_and_restored_paths() -> void:
	var root := "res://Figurines/"
	assert_eq(Gallery.on_hold_path(root + "Dragons/onixia.glb", root), root + "Dragons/En attente/onixia.glb")
	assert_eq(Gallery.on_hold_path(root + "Dragons/Draconiens/onixia.glb", root),
			root + "Dragons/En attente/onixia.glb")
	assert_eq(Gallery.on_hold_path(root + "azgrathok.glb", root), root + "En attente/azgrathok.glb")
	assert_eq(Gallery.restored_path(root + "Dragons/En attente/onixia.glb"), root + "Dragons/onixia.glb")


func test_move_model_moves_glb_and_import_and_back() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP + "Dragons"))
	_touch(TMP + "Dragons/a.glb")
	_touch(TMP + "Dragons/a.glb.import")
	var held := Gallery.on_hold_path(TMP + "Dragons/a.glb", TMP)
	assert_eq(Gallery.move_model(TMP + "Dragons/a.glb", held), OK)
	assert_true(FileAccess.file_exists(held) and FileAccess.file_exists(held + ".import"))
	assert_false(FileAccess.file_exists(TMP + "Dragons/a.glb.import"))
	assert_eq(Gallery.move_model(held, Gallery.restored_path(held)), OK)
	assert_true(FileAccess.file_exists(TMP + "Dragons/a.glb"))
	assert_false(FileAccess.file_exists(held))
