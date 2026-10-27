extends TestCase

var board: Board


func setup() -> void:
	board = SquareGenerator.new(8).generate()


func test_square_has_64_cells_and_is_consistent() -> void:
	assert_eq(board.cell_count(), 64)
	assert_eq(board.validate().size(), 0, "graphe incohérent : %s" % [board.validate()])
	assert_eq(board.player_slots(), 2)


func test_neighbors_and_edges() -> void:
	assert_eq(board.neighbor(&"a1", Board.DIR_N).id, &"a2")
	assert_eq(board.neighbor(&"a1", Board.DIR_E).id, &"b1")
	assert_eq(board.neighbor(&"a1", Board.DIR_NE).id, &"b2")
	assert_null(board.neighbor(&"a1", Board.DIR_S), "a1 n'a pas de voisin au sud")
	assert_null(board.neighbor(&"a1", Board.DIR_W))
	assert_null(board.neighbor(&"h8", Board.DIR_N))
	assert_eq(board.neighbor(&"h8", Board.DIR_SW).id, &"g7")


func test_ray_stops_at_edge() -> void:
	var r := board.ray(&"a1", Board.DIR_N, 10)
	assert_eq(r.size(), 7)
	assert_eq(r[-1].id, &"a8")
	var d := board.ray(&"a1", Board.DIR_NE, 3)
	assert_eq(d.size(), 3)
	assert_eq(d[2].id, &"d4")


func test_distance_orthogonal_and_diagonal() -> void:
	assert_eq(board.distance(&"a1", &"a1"), 0)
	assert_eq(board.distance(&"a1", &"c3", Board.ORTHOGONAL), 4)
	assert_eq(board.distance(&"a1", &"c3", Board.ALL_DIRS), 2)
	assert_eq(board.distance(&"a1", &"h8", Board.ALL_DIRS), 7)


func test_distance_respects_blocked_cells() -> void:
	# Mur complet sur la colonne b : a1 -> c1 impossible en orthogonal.
	var blocked := {}
	for y in range(1, 9):
		blocked[StringName("b%d" % y)] = true
	assert_eq(board.distance(&"a1", &"c1", Board.ORTHOGONAL, blocked), -1)
	# Avec un trou en b8, on contourne par le haut.
	blocked.erase(&"b8")
	assert_eq(board.distance(&"a1", &"c1", Board.ORTHOGONAL, blocked), 16)


func test_reachable_counts() -> void:
	var r := board.reachable(&"d4", 1, Board.ORTHOGONAL)
	assert_eq(r.size(), 4)
	r = board.reachable(&"d4", 1, Board.ALL_DIRS)
	assert_eq(r.size(), 8)
	r = board.reachable(&"a1", 2, Board.ORTHOGONAL)
	assert_eq(r.size(), 5)
	assert_false(r.has(&"a1"), "la case de départ n'est pas dans reachable")


func test_spawn_zones() -> void:
	var z0 := board.get_spawn_zone(0)
	var z1 := board.get_spawn_zone(1)
	assert_eq(z0.size(), 16)
	assert_eq(z1.size(), 16)
	assert_true(z0.has(&"a1") and z0.has(&"h2"))
	assert_true(z1.has(&"a8") and z1.has(&"h7"))


func test_cell_tags_alternate() -> void:
	assert_true(board.get_cell(&"a1").has_tag("dark"))
	assert_true(board.get_cell(&"b1").has_tag("light"))
	assert_true(board.get_cell(&"b2").has_tag("dark"))


func test_validate_detects_asymmetric_link() -> void:
	var b := Board.new()
	b.add_cell(Cell.new(&"x"))
	b.add_cell(Cell.new(&"y"))
	b.link(&"x", Board.DIR_N, &"y")  # pas de retour
	assert_eq(b.validate().size(), 1)


func test_no_generator_for_unsupported_player_counts_yet() -> void:
	assert_null(BoardGenerator.for_player_count(3))
	assert_null(BoardGenerator.for_player_count(5))
	assert_not_null(BoardGenerator.for_player_count(2))
