extends TestCase
## Partie sans rendu de la galerie : liste des modèles et noms affichés.

const Gallery := preload("res://src/ui/figurine_gallery.gd")
const TMP := "user://test_galerie/"


func teardown() -> void:
	if not DirAccess.dir_exists_absolute(TMP):
		return
	for d in ["", "Dragons/"]:
		for f in DirAccess.get_files_at(TMP + d):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + d + f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + "Dragons"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _touch(path: String) -> void:
	FileAccess.open(path, FileAccess.WRITE).close()


func test_list_models_merges_glb_and_import_and_sorts() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP + "Dragons"))
	_touch(TMP + "Dragons/b.glb")
	_touch(TMP + "Dragons/b.glb.import")
	_touch(TMP + "Dragons/a.glb.import")  # jeu exporté : seul le .import reste
	_touch(TMP + "Dragons/notes.txt")
	_touch(TMP + "c.glb")
	var got := Gallery.list_models(TMP)
	assert_eq(got, PackedStringArray([TMP + "Dragons/a.glb", TMP + "Dragons/b.glb", TMP + "c.glb"]))


func test_list_models_of_missing_folder_is_empty() -> void:
	assert_eq(Gallery.list_models("user://dossier_qui_n_existe_pas/").size(), 0)


func test_display_name() -> void:
	assert_eq(Gallery.display_name("res://Figurines/Dragons/dragon_a_lancier.glb"), "Dragons — Dragon A Lancier")
	assert_eq(Gallery.display_name("res://Figurines/azgrathok.glb"), "Azgrathok")
