class_name Board
extends RefCounted
## Plateau de jeu modélisé comme un graphe de cases.
##
## Aucune hypothèse sur la forme : un carré 8x8, un hexagone ou un plateau en étoile
## à 5 branches sont tous des graphes de Cell reliées par des directions nommées.
## Les générateurs (src/core/generators/) construisent le graphe ; les règles
## (rules.gd) ne font que le parcourir.

## Directions "canoniques" utilisées par les règles. Un générateur peut en
## définir d'autres (ex. hexagonal) mais celles-ci couvrent le cas carré.
const DIR_N := &"n"
const DIR_S := &"s"
const DIR_E := &"e"
const DIR_W := &"w"
const DIR_NE := &"ne"
const DIR_NW := &"nw"
const DIR_SE := &"se"
const DIR_SW := &"sw"

const ORTHOGONAL: Array[StringName] = [DIR_N, DIR_S, DIR_E, DIR_W]
const DIAGONAL: Array[StringName] = [DIR_NE, DIR_NW, DIR_SE, DIR_SW]
const ALL_DIRS: Array[StringName] = [DIR_N, DIR_S, DIR_E, DIR_W, DIR_NE, DIR_NW, DIR_SE, DIR_SW]

## cell_id -> Cell
var _cells: Dictionary = {}
## Zones de départ : player_index -> Array[cell_id]
var _spawn_zones: Dictionary = {}
## Identifiant du générateur qui a produit ce plateau (utile pour le réseau / le replay)
var shape_id: StringName = &""


func add_cell(cell: Cell) -> void:
	assert(not _cells.has(cell.id), "Cell id déjà présent : %s" % cell.id)
	_cells[cell.id] = cell


func has_cell(cell_id: StringName) -> bool:
	return _cells.has(cell_id)


func get_cell(cell_id: StringName) -> Cell:
	return _cells.get(cell_id) as Cell


func get_cells() -> Array[Cell]:
	var out: Array[Cell] = []
	for c in _cells.values():
		out.append(c as Cell)
	return out


func cell_count() -> int:
	return _cells.size()


## Relie deux cases dans une direction. Si [param opposite] est fourni, la liaison
## inverse est créée aussi (cas normal pour un plateau plat).
func link(from_id: StringName, dir: StringName, to_id: StringName, opposite: StringName = &"") -> void:
	var a := get_cell(from_id)
	var b := get_cell(to_id)
	assert(a != null and b != null, "link() sur une case inconnue")
	a.set_neighbor(dir, to_id)
	if opposite != &"":
		b.set_neighbor(opposite, from_id)


## Voisin de [param cell_id] dans la direction [param dir], ou null.
func neighbor(cell_id: StringName, dir: StringName) -> Cell:
	var c := get_cell(cell_id)
	if c == null:
		return null
	var nid := c.get_neighbor(dir)
	if nid == &"":
		return null
	return get_cell(nid)


## Avance de [param steps] cases en ligne droite. Retourne les cases traversées
## (hors départ), en s'arrêtant au bord du plateau.
func ray(cell_id: StringName, dir: StringName, steps: int) -> Array[Cell]:
	var out: Array[Cell] = []
	var current := cell_id
	for _i in range(steps):
		var n := neighbor(current, dir)
		if n == null:
			break
		out.append(n)
		current = n.id
	return out


## Distance en nombre de pas (BFS) entre deux cases, en suivant [param dirs].
## -1 si inaccessible. [param blocked] : ids de cases infranchissables.
func distance(from_id: StringName, to_id: StringName, dirs: Array[StringName] = ORTHOGONAL, blocked: Dictionary = {}) -> int:
	if from_id == to_id:
		return 0
	var dist: Dictionary = {from_id: 0}
	var queue: Array[StringName] = [from_id]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		for d in dirs:
			var n := neighbor(cur, d)
			if n == null or dist.has(n.id) or blocked.has(n.id):
				continue
			dist[n.id] = dist[cur] + 1
			if n.id == to_id:
				return dist[n.id]
			queue.append(n.id)
	return -1


## Toutes les cases atteignables en au plus [param max_steps] pas (BFS),
## sans traverser [param blocked]. Retourne cell_id -> coût.
func reachable(from_id: StringName, max_steps: int, dirs: Array[StringName] = ORTHOGONAL, blocked: Dictionary = {}) -> Dictionary:
	var dist: Dictionary = {from_id: 0}
	var queue: Array[StringName] = [from_id]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		var cost: int = dist[cur]
		if cost >= max_steps:
			continue
		for d in dirs:
			var n := neighbor(cur, d)
			if n == null or dist.has(n.id) or blocked.has(n.id):
				continue
			dist[n.id] = cost + 1
			queue.append(n.id)
	dist.erase(from_id)
	return dist


func set_spawn_zone(player: int, cell_ids: Array[StringName]) -> void:
	_spawn_zones[player] = cell_ids.duplicate()


func get_spawn_zone(player: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _spawn_zones.get(player, []):
		out.append(id)
	return out


func player_slots() -> int:
	return _spawn_zones.size()


## Vérifie la cohérence du graphe : chaque lien vers une case existante,
## et symétrie n/s, e/w, etc. Retourne la liste des problèmes (vide = OK).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var opposites := {
		DIR_N: DIR_S, DIR_S: DIR_N, DIR_E: DIR_W, DIR_W: DIR_E,
		DIR_NE: DIR_SW, DIR_SW: DIR_NE, DIR_NW: DIR_SE, DIR_SE: DIR_NW,
	}
	for c in get_cells():
		for d in c.directions():
			var nid := c.get_neighbor(d)
			if not has_cell(nid):
				problems.append("%s --%s--> %s : case inconnue" % [c.id, d, nid])
				continue
			if opposites.has(d):
				var back := get_cell(nid).get_neighbor(opposites[d])
				if back != c.id:
					problems.append("%s --%s--> %s non symétrique (retour=%s)" % [c.id, d, nid, back])
	return problems
