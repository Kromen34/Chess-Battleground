class_name VertexGrid
extends RefCounted
## Index spatial des sommets d'une figurine (grille de cubes) : retrouve vite ceux qui sont
## à portée d'un coup de pinceau. Un sommet est codé part << INDEX_BITS | index
## (voir FigurinePaint).

var cell_size: float
## Vector3i -> Array (sommets codés de ce cube)
var _cells: Dictionary = {}
var _positions: Array[PackedVector3Array] = []

## Résultat du dernier query() : sommets codés et leur distance au centre.
var found := PackedInt32Array()
var found_dist := PackedFloat32Array()


func _init(positions: Array[PackedVector3Array], cell: float = 0.04) -> void:
	cell_size = cell
	_positions = positions
	for p in positions.size():
		var pos := positions[p]
		for i in pos.size():
			var key := _key(pos[i])
			var list: Variant = _cells.get(key)
			if list == null:
				_cells[key] = [p << FigurinePaint.INDEX_BITS | i]
			else:
				(list as Array).append(p << FigurinePaint.INDEX_BITS | i)


func _key(v: Vector3) -> Vector3i:
	return Vector3i(floori(v.x / cell_size), floori(v.y / cell_size), floori(v.z / cell_size))


## Sommets à moins de [radius] de [center], dans found / found_dist.
func query(center: Vector3, radius: float) -> void:
	found.clear()
	found_dist.clear()
	var lo := _key(center - Vector3.ONE * radius)
	var hi := _key(center + Vector3.ONE * radius)
	var r2 := radius * radius
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var list: Variant = _cells.get(Vector3i(x, y, z))
				if list == null:
					continue
				for code: int in list:
					var d2 := _positions[code >> FigurinePaint.INDEX_BITS][code & FigurinePaint.INDEX_MASK].distance_squared_to(center)
					if d2 <= r2:
						found.append(code)
						found_dist.append(sqrt(d2))
