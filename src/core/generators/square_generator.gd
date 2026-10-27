class_name SquareGenerator
extends BoardGenerator
## Plateau carré classique pour 2 joueurs. Joueur 0 en bas (rangs 0-1),
## joueur 1 en haut (rangs size-2, size-1).
##
## Les ids de cases sont "a1".."h8" comme aux échecs pour la lisibilité des
## tests et des logs. Les règles n'en dépendent pas.

const FILES := "abcdefghijklmnopqrstuvwxyz"

var size: int
var cell_size: float


func _init(p_size: int = 8, p_cell_size: float = 1.0) -> void:
	size = p_size
	cell_size = p_cell_size


func shape_id() -> StringName:
	return StringName("square_%d" % size)


func player_count() -> int:
	return 2


static func cell_id_at(x: int, y: int) -> StringName:
	return StringName("%s%d" % [FILES[x], y + 1])


func generate() -> Board:
	var board := Board.new()
	board.shape_id = shape_id()
	var half := (size - 1) * cell_size * 0.5

	for y in range(size):
		for x in range(size):
			var cell := Cell.new(cell_id_at(x, y), Vector3(x * cell_size - half, 0.0, -(y * cell_size - half)))
			cell.tags.append("dark" if (x + y) % 2 == 0 else "light")
			board.add_cell(cell)

	for y in range(size):
		for x in range(size):
			var id := cell_id_at(x, y)
			if y + 1 < size:
				board.link(id, Board.DIR_N, cell_id_at(x, y + 1), Board.DIR_S)
			if x + 1 < size:
				board.link(id, Board.DIR_E, cell_id_at(x + 1, y), Board.DIR_W)
			if y + 1 < size and x + 1 < size:
				board.link(id, Board.DIR_NE, cell_id_at(x + 1, y + 1), Board.DIR_SW)
			if y + 1 < size and x - 1 >= 0:
				board.link(id, Board.DIR_NW, cell_id_at(x - 1, y + 1), Board.DIR_SE)

	var p0: Array[StringName] = []
	var p1: Array[StringName] = []
	for x in range(size):
		p0.append(cell_id_at(x, 0))
		p0.append(cell_id_at(x, 1))
		p1.append(cell_id_at(x, size - 1))
		p1.append(cell_id_at(x, size - 2))
	board.set_spawn_zone(0, p0)
	board.set_spawn_zone(1, p1)
	return board
