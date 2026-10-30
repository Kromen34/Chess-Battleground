class_name FigurinePaint
extends RefCounted
## Peinture d'une figurine en couleurs de sommets (les modèles n'ont pas d'UV).
## Une figurine non peinte est toute grise (sous-couche, PRIMER), lavis compris ; des calques de peinture
## (couleur + opacité + métal + rugosité par sommet) s'y empilent ; le résultat est multiplié
## par le lavis d'origine (creux assombris, arêtes éclaircies) qu'on garde intact.
## Sert à l'atelier de peinture et à l'affichage d'une figurine peinte dans la collection.
## Les couleurs des calques sont en linéaire ; l'affichage passe par un shader qui lit la
## couleur (sRGB 8 bits) et la finition (CUSTOM0 : métal, rugosité) de chaque sommet.

const SAVE_DIR := "user://peintures/"
const SAVE_VERSION := 1
const BLEND_NORMAL := 0
const BLEND_MULTIPLY := 1
const BLEND_NAMES: PackedStringArray = ["Normal", "Produit"]
## Gris d'une figurine non peinte (sRGB), mat, comme une sous-couche grise.
const PRIMER := Color(0.6, 0.6, 0.61)
const PRIMER_FINISH := Vector2(0.0, 0.75)
## Les sommets sont codés part << INDEX_BITS | index dans la grille et l'historique.
const INDEX_BITS := 20
const INDEX_MASK := (1 << INDEX_BITS) - 1

const SHADER_CODE := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec2 finish;
void vertex() {
	finish = CUSTOM0.rg;
}
void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
	METALLIC = finish.x;
	ROUGHNESS = max(finish.y, 0.04);
}
"""


## Une pièce de la figurine (un MeshInstance3D du modèle).
class Part:
	var name: String
	var node: MeshInstance3D
	## Sommets et normales dans le repère de la figurine.
	var positions: PackedVector3Array
	var normals: PackedVector3Array
	## Lavis d'origine (multiplicateur, linéaire) et sa luminance.
	var wash: PackedColorArray
	var wash_luma: PackedFloat32Array
	## Couleur (linéaire) et finition (métal, rugosité) avant peinture : la sous-couche grise.
	var base_color: Color
	var base_finish: Vector2
	var mesh: ArrayMesh
	## Copie du tampon d'attributs du GPU (couleur + finition), réécrite puis renvoyée.
	var attr: PackedByteArray
	var stride: int = 0
	var color_offset: int = 0
	var custom_offset: int = 0
	## Plage de sommets à renvoyer au GPU (-1 : rien).
	var dirty_min: int = -1
	var dirty_max: int = -1

	func vertex_count() -> int:
		return positions.size()


## Un calque de peinture : une couleur (rgb linéaire, a = couverture) et une finition
## (métal, rugosité) par sommet de chaque pièce.
## Attention : un tableau rangé dans un Array est recopié en entier à la première écriture
## (copie sur écriture). Pour peindre, le sortir de l'Array (var c := colors[p] puis
## colors[p] = PackedColorArray()), le modifier, puis l'y remettre.
class Layer:
	var name: String = "Calque"
	var visible: bool = true
	var opacity: float = 1.0
	var blend: int = 0
	var colors: Array[PackedColorArray] = []
	var finishes: Array[PackedVector2Array] = []


var parts: Array[Part] = []
var layers: Array[Layer] = []
## Seuils de luminance du lavis (10 %, 50 %, 90 % des sommets) : creux et arêtes.
var luma_low: float = 0.2
var luma_mid: float = 0.5
var luma_high: float = 0.8

static var _shader: Shader


## Prépare la peinture d'un modèle déjà instancié : remplace ses maillages par des copies
## peignables. [root] peut être hors de l'arbre de scènes.
static func attach(root: Node3D) -> FigurinePaint:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var paint := FigurinePaint.new()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var part := _make_part(mi, _relative_transform(mi, root))
		if part != null:
			paint.parts.append(part)
	paint._compute_luma_thresholds()
	paint.composite_all()
	paint.flush()
	return paint


static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func _make_part(mi: MeshInstance3D, xf: Transform3D) -> Part:
	var src := mi.mesh
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n := verts.size()
	if n == 0 or n > INDEX_MASK:
		push_warning("FigurinePaint : pièce %s ignorée (%d sommets)" % [mi.name, n])
		return null
	var part := Part.new()
	part.name = String(mi.name)
	part.node = mi
	part.base_color = PRIMER.srgb_to_linear()
	part.base_finish = PRIMER_FINISH

	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	normals.resize(n)
	part.positions.resize(n)
	part.normals.resize(n)
	var basis := xf.basis
	for i in n:
		part.positions[i] = xf * verts[i]
		part.normals[i] = (basis * normals[i]).normalized()
	if arrays[Mesh.ARRAY_COLOR] != null:
		part.wash = arrays[Mesh.ARRAY_COLOR]
	else:
		part.wash.resize(n)
		part.wash.fill(Color.WHITE)
	part.wash_luma.resize(n)
	for i in n:
		var w := part.wash[i]
		part.wash_luma[i] = 0.2126 * w.r + 0.7152 * w.g + 0.0722 * w.b

	# Nouveau maillage : mêmes sommets, couleur + finition (CUSTOM0) réécrites par la peinture.
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
	out[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	var colors := PackedColorArray()
	colors.resize(n)
	colors.fill(Color.WHITE)
	out[Mesh.ARRAY_COLOR] = colors
	var custom := PackedByteArray()
	custom.resize(n * 4)
	out[Mesh.ARRAY_CUSTOM0] = custom
	var flags := Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	part.mesh = ArrayMesh.new()
	part.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, flags)
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = _shader
	part.mesh.surface_set_material(0, shader_mat)
	mi.mesh = part.mesh
	mi.material_override = null

	# Disposition du tampon d'attributs, pour y écrire directement couleur et finition.
	var fmt := part.mesh.surface_get_format(0)
	part.stride = RenderingServer.mesh_surface_get_format_attribute_stride(fmt, n)
	part.color_offset = RenderingServer.mesh_surface_get_format_offset(fmt, n, Mesh.ARRAY_COLOR)
	part.custom_offset = RenderingServer.mesh_surface_get_format_offset(fmt, n, Mesh.ARRAY_CUSTOM0)
	var surface := RenderingServer.mesh_get_surface(part.mesh.get_rid(), 0)
	var attr: Variant = surface.get("attribute_data")
	if typeof(attr) == TYPE_PACKED_BYTE_ARRAY and (attr as PackedByteArray).size() == part.stride * n:
		part.attr = attr
	else:
		# Pas de GPU (tests headless) : la peinture est calculée mais pas affichée.
		part.attr = PackedByteArray()
	return part


func _compute_luma_thresholds() -> void:
	var sample := PackedFloat32Array()
	for part in parts:
		var step := maxi(1, part.vertex_count() / 4000)
		for i in range(0, part.vertex_count(), step):
			sample.append(part.wash_luma[i])
	if sample.size() < 10:
		return
	sample.sort()
	luma_low = sample[int(sample.size() * 0.1)]
	luma_mid = sample[int(sample.size() * 0.5)]
	luma_high = maxf(sample[int(sample.size() * 0.9)], luma_mid + 0.01)


## Part d'une arête (0 dans les creux, 1 sur les arêtes) : pour le brossage à sec.
func edge_factor(p: int, i: int) -> float:
	return smoothstep(luma_mid, luma_high, parts[p].wash_luma[i])


## Part d'un creux (1 au fond, 0 sur le plat et les arêtes) : pour le lavis.
func recess_factor(p: int, i: int) -> float:
	return 1.0 - smoothstep(luma_low, luma_mid, parts[p].wash_luma[i])


## Matériau d'une figurine non peinte, sans préparer la peinture (affichage rapide) :
## le gris de la sous-couche multiplié par le lavis.
static func primer_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PRIMER
	mat.vertex_color_use_as_albedo = true
	mat.metallic = PRIMER_FINISH.x
	mat.roughness = PRIMER_FINISH.y
	return mat


# --- Calques ---------------------------------------------------------------------

func new_layer(name: String) -> Layer:
	var layer := Layer.new()
	layer.name = name
	for part in parts:
		var c := PackedColorArray()
		c.resize(part.vertex_count())
		# resize() remplit avec Color(), noir opaque : un calque neuf doit être transparent.
		c.fill(Color(0, 0, 0, 0))
		var f := PackedVector2Array()
		f.resize(part.vertex_count())
		layer.colors.append(c)
		layer.finishes.append(f)
	return layer


## Fusionne le calque [index] dans celui du dessous (deux calques « Normal » seulement).
## Retourne false si c'est impossible.
func merge_down(index: int) -> bool:
	if index <= 0 or index >= layers.size():
		return false
	var top := layers[index]
	var below := layers[index - 1]
	if top.blend != BLEND_NORMAL or below.blend != BLEND_NORMAL:
		return false
	for p in parts.size():
		var tc := top.colors[p]
		var tf := top.finishes[p]
		var bc := below.colors[p]
		var bf := below.finishes[p]
		for i in tc.size():
			var a := tc[i].a * top.opacity * (1.0 if top.visible else 0.0)
			if a <= 0.0:
				continue
			var b := bc[i].a * below.opacity
			var out_a := a + b * (1.0 - a)
			var mixed := (tc[i] * a + bc[i] * b * (1.0 - a)) / out_a
			mixed.a = clampf(out_a / maxf(below.opacity, 0.001), 0.0, 1.0)
			bc[i] = mixed
			bf[i] = (tf[i] * a + bf[i] * b * (1.0 - a)) / out_a
		below.colors[p] = bc
		below.finishes[p] = bf
	layers.remove_at(index)
	composite_all()
	return true


# --- Composition -----------------------------------------------------------------

## Couleur finale (linéaire, lavis compris) et finition d'un sommet.
func final_color(p: int, i: int) -> Color:
	var part := parts[p]
	var c := part.base_color
	for layer in layers:
		if not layer.visible:
			continue
		var lc := layer.colors[p][i]
		var a := lc.a * layer.opacity
		if a <= 0.0:
			continue
		if layer.blend == BLEND_MULTIPLY:
			c = c.lerp(Color(c.r * lc.r, c.g * lc.g, c.b * lc.b), a)
		else:
			c = c.lerp(lc, a)
	var w := part.wash[i]
	return Color(c.r * w.r, c.g * w.g, c.b * w.b)


## Couleur de peinture (sans lavis) d'un sommet : ce que prend la pipette.
func paint_color(p: int, i: int) -> Color:
	var c := final_color(p, i)
	var w := parts[p].wash[i]
	return Color(c.r / maxf(w.r, 0.05), c.g / maxf(w.g, 0.05), c.b / maxf(w.b, 0.05)).clamp()


func final_finish(p: int, i: int) -> Vector2:
	var f := parts[p].base_finish
	for layer in layers:
		if not layer.visible or layer.blend != BLEND_NORMAL:
			continue
		var a := layer.colors[p][i].a * layer.opacity
		if a > 0.0:
			f = f.lerp(layer.finishes[p][i], a)
	return f


## Recalcule l'affichage d'un sommet (à renvoyer au GPU par flush()).
func composite(p: int, i: int) -> void:
	var part := parts[p]
	if part.attr.is_empty():
		return
	var c := final_color(p, i).clamp().linear_to_srgb()
	var f := final_finish(p, i)
	var o := i * part.stride + part.color_offset
	part.attr[o] = c.r8
	part.attr[o + 1] = c.g8
	part.attr[o + 2] = c.b8
	part.attr[o + 3] = 255
	o = i * part.stride + part.custom_offset
	part.attr[o] = int(clampf(f.x, 0.0, 1.0) * 255.0)
	part.attr[o + 1] = int(clampf(f.y, 0.0, 1.0) * 255.0)
	if part.dirty_min < 0 or i < part.dirty_min:
		part.dirty_min = i
	if i > part.dirty_max:
		part.dirty_max = i


func composite_all() -> void:
	for p in parts.size():
		for i in parts[p].vertex_count():
			composite(p, i)


## Envoie au GPU les sommets modifiés depuis le dernier appel.
func flush() -> void:
	for part in parts:
		if part.dirty_min < 0:
			continue
		var start := part.dirty_min * part.stride
		var end := (part.dirty_max + 1) * part.stride
		RenderingServer.mesh_surface_update_attribute_region(part.mesh.get_rid(), 0, start, part.attr.slice(start, end))
		part.dirty_min = -1
		part.dirty_max = -1


# --- Enregistrement --------------------------------------------------------------

static func save_path(card_id: StringName) -> String:
	return SAVE_DIR + String(card_id) + ".peinture"


static func has_save(card_id: StringName) -> bool:
	return FileAccess.file_exists(save_path(card_id))


func to_dict() -> Dictionary:
	var counts: Array = []
	for part in parts:
		counts.append(part.vertex_count())
	var out_layers: Array = []
	for layer in layers:
		out_layers.append({"name": layer.name, "visible": layer.visible, "opacity": layer.opacity,
				"blend": layer.blend, "colors": layer.colors.duplicate(), "finishes": layer.finishes.duplicate()})
	return {"version": SAVE_VERSION, "vertex_counts": counts, "layers": out_layers}


## Recharge des calques enregistrés. false si l'enregistrement ne correspond pas au
## modèle (figurine regénérée entre-temps) : les calques actuels restent alors en place.
func load_dict(d: Dictionary) -> bool:
	var counts: Variant = d.get("vertex_counts")
	if int(d.get("version", 0)) != SAVE_VERSION or typeof(counts) != TYPE_ARRAY or (counts as Array).size() != parts.size():
		return false
	for p in parts.size():
		if int((counts as Array)[p]) != parts[p].vertex_count():
			return false
	var loaded: Array[Layer] = []
	for v: Variant in d.get("layers", []):
		if typeof(v) != TYPE_DICTIONARY:
			return false
		var ld: Dictionary = v
		var layer := Layer.new()
		layer.name = String(ld.get("name", "Calque"))
		layer.visible = bool(ld.get("visible", true))
		layer.opacity = clampf(float(ld.get("opacity", 1.0)), 0.0, 1.0)
		layer.blend = clampi(int(ld.get("blend", BLEND_NORMAL)), 0, BLEND_NAMES.size() - 1)
		var colors: Array = ld.get("colors", [])
		var finishes: Array = ld.get("finishes", [])
		if colors.size() != parts.size() or finishes.size() != parts.size():
			return false
		for p in parts.size():
			if typeof(colors[p]) != TYPE_PACKED_COLOR_ARRAY or typeof(finishes[p]) != TYPE_PACKED_VECTOR2_ARRAY \
					or (colors[p] as PackedColorArray).size() != parts[p].vertex_count() \
					or (finishes[p] as PackedVector2Array).size() != parts[p].vertex_count():
				return false
			layer.colors.append(colors[p])
			layer.finishes.append(finishes[p])
		loaded.append(layer)
	layers = loaded
	composite_all()
	return true


func save(card_id: StringName) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open_compressed(save_path(card_id), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var(to_dict())
	f.close()
	return OK


func load_saved(card_id: StringName) -> bool:
	if not has_save(card_id):
		return false
	var f := FileAccess.open_compressed(save_path(card_id), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var data: Variant = f.get_var()
	f.close()
	return typeof(data) == TYPE_DICTIONARY and load_dict(data)
