## Rend un modèle de figurine sous 4 angles dans une image, sans lancer le jeu.
##
## Usage (pas en headless : il faut le rendu) :
##   godot --path . -s tools/rendu_figurine.gd -- res://chemin/modele.glb sortie.png [res://autre.glb sortie2.png ...]
## Le .glb doit déjà être importé par Godot (ouvrir l'éditeur une fois, ou --editor --quit).
extends SceneTree

const VIEW := 700
const ANGLES: Array[float] = [0.0, 90.0, 180.0, 270.0]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	DisplayServer.window_set_size(Vector2i(VIEW, VIEW))

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.2, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.7, 0.65)
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	root.add_child(env)

	# Lumière chaude du dessus, comme la suspension du salon, et un contre-jour froid.
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.72)
	key.light_energy = 1.6
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-55, 30, 0)
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.6, 0.7, 1.0)
	rim.light_energy = 0.5
	rim.rotation_degrees = Vector3(-20, 200, 0)
	root.add_child(rim)

	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)

	var i := 0
	while i + 1 < args.size():
		await _render(args[i], args[i + 1], cam)
		i += 2
	quit()


func _render(path: String, out: String, cam: Camera3D) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Modèle introuvable ou pas importé : %s" % path)
		return
	var model := scene.instantiate() as Node3D
	root.add_child(model)
	await process_frame

	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var center := box.get_center()
	var radius := box.size.length() * 0.5
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 0.8

	var sheet := Image.create(VIEW * 2, VIEW * 2, false, Image.FORMAT_RGBA8)
	for k in ANGLES.size():
		# Angle 0 : vue de face (le modèle regarde vers -Z, la caméra est donc côté -Z).
		var yaw := deg_to_rad(ANGLES[k] + 180.0)
		var dir := Vector3(sin(yaw), 0.45, cos(yaw)).normalized()
		cam.look_at_from_position(center + dir * dist, center)
		for _f in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		# La fenêtre n'a pas toujours la taille demandée : carré central, remis à VIEW.
		var side := mini(img.get_width(), img.get_height())
		img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
		img.resize(VIEW, VIEW, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, VIEW, VIEW), Vector2i((k % 2) * VIEW, (k / 2) * VIEW))
	sheet.save_png(out)
	print("Rendu : %s" % out)
	model.queue_free()
	await process_frame
