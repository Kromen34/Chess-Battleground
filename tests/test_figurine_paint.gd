extends TestCase
## Moteur de peinture (FigurinePaint, VertexGrid) sur un petit modèle construit à la main.
## En headless le GPU est factice : on vérifie les calculs, pas l'affichage.

var root: Node3D
var paint: FigurinePaint
## Sous-couche grise (linéaire) multipliée par le lavis du modèle de test (0,5).
var grey: Color = FigurinePaint.PRIMER.srgb_to_linear() * 0.5


func setup() -> void:
	root = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "body"
	var box := BoxMesh.new()
	var arrays := box.get_mesh_arrays()
	var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var wash := PackedColorArray()
	wash.resize(n)
	wash.fill(Color(0.5, 0.5, 0.5))
	arrays[Mesh.ARRAY_COLOR] = wash
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.metallic = 0.2
	mat.roughness = 0.8
	mesh.surface_set_material(0, mat)
	mi.mesh = mesh
	root.add_child(mi)
	paint = FigurinePaint.attach(root)


func teardown() -> void:
	root.free()


## Le lavis est stocké sur 8 bits dans le maillage (0,5 devient 128/255) : tolérance de 1 %.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func test_attach_reads_parts() -> void:
	assert_eq(paint.parts.size(), 1)
	var part := paint.parts[0]
	assert_eq(part.name, "body")
	assert_true(part.vertex_count() > 0)
	assert_true(part.base_finish.is_equal_approx(FigurinePaint.PRIMER_FINISH), "mat, quel que soit le matériau d'origine")
	assert_true(_near(paint.final_color(0, 0), grey), "non peinte : sous-couche grise × lavis")


func test_new_layer_is_transparent() -> void:
	paint.layers.append(paint.new_layer("A"))
	assert_eq(paint.layers[0].colors[0][0].a, 0.0, "resize() remplirait de noir opaque")
	assert_true(_near(paint.final_color(0, 0), grey), "un calque vide ne change rien")


func test_normal_and_multiply_layers() -> void:
	var red := paint.new_layer("rouge")
	red.colors[0][0] = Color(1, 0, 0, 1)
	red.finishes[0][0] = Vector2(1.0, 0.1)
	paint.layers.append(red)
	assert_true(_near(paint.final_color(0, 0), Color(0.5, 0, 0)), "couvre, puis lavis")
	assert_true(paint.final_finish(0, 0).is_equal_approx(Vector2(1.0, 0.1)))
	red.opacity = 0.5
	assert_true(_near(paint.final_color(0, 0), Color(0.5, 0, 0).lerp(grey, 0.5)), "opacité du calque")
	red.opacity = 1.0
	var shade := paint.new_layer("ombre")
	shade.blend = FigurinePaint.BLEND_MULTIPLY
	shade.colors[0][0] = Color(0.5, 0.5, 0.5, 1)
	paint.layers.append(shade)
	assert_true(_near(paint.final_color(0, 0), Color(0.25, 0, 0)), "produit : assombrit")
	assert_true(paint.final_finish(0, 0).is_equal_approx(Vector2(1.0, 0.1)), "un calque Produit ne change pas la finition")
	shade.visible = false
	assert_true(_near(paint.final_color(0, 0), Color(0.5, 0, 0)), "calque masqué")


func test_merge_down_keeps_the_look() -> void:
	var a := paint.new_layer("a")
	a.colors[0][0] = Color(0, 0, 1, 0.5)
	var b := paint.new_layer("b")
	b.colors[0][0] = Color(1, 0, 0, 0.5)
	b.opacity = 0.8
	paint.layers.append(a)
	paint.layers.append(b)
	var before := paint.final_color(0, 0)
	assert_true(paint.merge_down(1))
	assert_eq(paint.layers.size(), 1)
	assert_true(_near(paint.final_color(0, 0), before), "%s contre %s" % [paint.final_color(0, 0), before])
	assert_false(paint.merge_down(0), "rien sous le calque du bas")


func test_save_roundtrip_and_mismatch() -> void:
	var layer := paint.new_layer("Base")
	layer.colors[0][1] = Color(0, 1, 0, 0.7)
	layer.blend = FigurinePaint.BLEND_MULTIPLY
	paint.layers.append(layer)
	var d := paint.to_dict()
	paint.layers.clear()
	assert_true(paint.load_dict(d))
	assert_eq(paint.layers.size(), 1)
	assert_eq(paint.layers[0].name, "Base")
	assert_eq(paint.layers[0].blend, FigurinePaint.BLEND_MULTIPLY)
	assert_eq(paint.layers[0].colors[0][1], Color(0, 1, 0, 0.7))
	var wrong := d.duplicate(true)
	wrong["vertex_counts"] = [1]
	assert_false(paint.load_dict(wrong), "figurine regénérée : enregistrement refusé")
	assert_eq(paint.layers.size(), 1, "les calques actuels restent")


func test_one_save_per_copy() -> void:
	assert_ne(FigurinePaint.save_path(&"onixia", 1), FigurinePaint.save_path(&"onixia", 2))
	var layer := paint.new_layer("Rouge")
	layer.colors[0][0] = Color(1, 0, 0, 1)
	paint.layers.append(layer)
	var card := &"test_exemplaires"
	assert_eq(paint.save(card, 2), OK)
	assert_true(FigurinePaint.has_save(card, 2))
	assert_false(FigurinePaint.has_save(card, 1), "l'exemplaire 1 n'est pas peint")
	paint.layers.clear()
	assert_true(paint.load_saved(card, 2))
	assert_eq(paint.layers[0].colors[0][0], Color(1, 0, 0, 1))
	DirAccess.remove_absolute(FigurinePaint.save_path(card, 2))


func test_vertex_grid_matches_brute_force() -> void:
	var positions: Array[PackedVector3Array] = [paint.parts[0].positions]
	var grid := VertexGrid.new(positions, 0.1)
	var center := Vector3(0.4, 0.3, -0.2)
	grid.query(center, 0.5)
	var expected := 0
	for v in positions[0]:
		if v.distance_to(center) <= 0.5:
			expected += 1
	assert_eq(grid.found.size(), expected)
	for k in grid.found.size():
		var i := grid.found[k] & FigurinePaint.INDEX_MASK
		assert_true(absf(positions[0][i].distance_to(center) - grid.found_dist[k]) < 0.0001)
