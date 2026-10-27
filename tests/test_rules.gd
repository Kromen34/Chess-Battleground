extends TestCase

var state: GameState
var soldier: UnitType
var knight: UnitType
var archer: UnitType


func _type(id: StringName, hp: int, pm: int, pa: int, dmg: int, rng: int, dirs: Array[StringName], jump: bool) -> UnitType:
	var t := UnitType.new()
	t.id = id
	t.display_name = String(id)
	t.max_hp = hp
	t.move_points = pm
	t.attack_points = pa
	t.damage = dmg
	t.attack_range = rng
	t.move_directions = dirs
	t.can_jump = jump
	return t


func setup() -> void:
	state = GameState.new(SquareGenerator.new(8).generate(), 2, 42)
	soldier = _type(&"soldier", 8, 2, 1, 3, 1, Board.ORTHOGONAL, false)
	knight = _type(&"knight", 10, 4, 1, 3, 1, [], true)
	archer = _type(&"archer", 6, 2, 1, 2, 3, [], false)
	for t in [soldier, knight, archer]:
		state.register_type(t)


func test_move_within_points_and_cost_deducted() -> void:
	var u := state.spawn(&"soldier", 0, &"d1")
	assert_ok(Rules.apply(state, 0, Actions.move(u.id, &"d3")))
	assert_eq(u.cell_id, &"d3")
	assert_eq(u.move_left, 0)
	assert_refused(Rules.apply(state, 0, Actions.move(u.id, &"d4")), "plus de PM")


func test_move_too_far_refused() -> void:
	var u := state.spawn(&"soldier", 0, &"d1")
	assert_refused(Rules.apply(state, 0, Actions.move(u.id, &"d4")))
	assert_eq(u.cell_id, &"d1", "l'unité n'a pas bougé")


func test_soldier_cannot_move_diagonally_but_knight_can() -> void:
	var s := state.spawn(&"soldier", 0, &"a1")
	var k := state.spawn(&"knight", 0, &"h1")
	# a1 -> c3 : 2 pas en diagonale, 4 pas en orthogonal. Le soldat (2 PM orthogonaux) ne peut pas.
	assert_refused(Rules.apply(state, 0, Actions.move(s.id, &"c3")), "le soldat ne va pas en diagonale")
	assert_ok(Rules.apply(state, 0, Actions.move(k.id, &"f3")), "le cavalier va en diagonale")
	assert_eq(k.move_left, 2)


func test_soldier_blocked_by_unit_knight_jumps() -> void:
	var s := state.spawn(&"soldier", 0, &"a1")
	var k := state.spawn(&"knight", 0, &"h1")
	state.spawn(&"soldier", 1, &"a2")  # bloque le soldat
	state.spawn(&"soldier", 1, &"h2")  # "bloque" le cavalier
	assert_refused(Rules.apply(state, 0, Actions.move(s.id, &"a3")), "soldat bloqué par a2")
	assert_ok(Rules.apply(state, 0, Actions.move(k.id, &"h3")), "cavalier saute par-dessus h2")


func test_cannot_move_onto_occupied_cell() -> void:
	var u := state.spawn(&"soldier", 0, &"d1")
	state.spawn(&"soldier", 0, &"d2")
	assert_refused(Rules.apply(state, 0, Actions.move(u.id, &"d2")))


func test_reachable_cells_excludes_occupied() -> void:
	var k := state.spawn(&"knight", 0, &"d4")
	state.spawn(&"soldier", 1, &"d5")
	var r := Rules.reachable_cells(state, k)
	assert_false(r.has(&"d5"))
	assert_true(r.has(&"d6"), "le cavalier peut s'arrêter derrière d5")
	assert_false(r.has(&"d4"))


func test_wrong_player_turn_refused() -> void:
	var u := state.spawn(&"soldier", 1, &"d8")
	assert_refused(Rules.apply(state, 1, Actions.move(u.id, &"d7")), "c'est le tour de J0")
	assert_refused(Rules.apply(state, 0, Actions.move(u.id, &"d7")), "J0 ne bouge pas une unité de J1")


func test_melee_attack_damage_and_range() -> void:
	var a := state.spawn(&"soldier", 0, &"d4")
	var b := state.spawn(&"soldier", 1, &"d5")
	var c := state.spawn(&"soldier", 1, &"d7")
	assert_refused(Rules.apply(state, 0, Actions.attack(a.id, c.id)), "d7 hors de portée")
	assert_ok(Rules.apply(state, 0, Actions.attack(a.id, b.id)))
	assert_eq(b.hp, 5)
	assert_eq(a.attack_left, 0)
	assert_refused(Rules.apply(state, 0, Actions.attack(a.id, b.id)), "plus de PA")


func test_diagonal_melee_counts_as_adjacent() -> void:
	var a := state.spawn(&"soldier", 0, &"d4")
	var b := state.spawn(&"soldier", 1, &"e5")
	assert_ok(Rules.apply(state, 0, Actions.attack(a.id, b.id)))


func test_ranged_attack() -> void:
	var a := state.spawn(&"archer", 0, &"d1")
	var b := state.spawn(&"soldier", 1, &"d4")
	var c := state.spawn(&"soldier", 1, &"d5")
	assert_ok(Rules.apply(state, 0, Actions.attack(a.id, b.id)), "portée 3")
	a.refresh()
	assert_refused(Rules.apply(state, 0, Actions.attack(a.id, c.id)), "portée 4 > 3")


func test_cannot_attack_own_unit() -> void:
	var a := state.spawn(&"soldier", 0, &"d4")
	var b := state.spawn(&"soldier", 0, &"d5")
	assert_refused(Rules.apply(state, 0, Actions.attack(a.id, b.id)))


func test_kill_and_victory() -> void:
	var a := state.spawn(&"soldier", 0, &"d4")
	var b := state.spawn(&"archer", 1, &"d5")  # 6 PV, soldat fait 3
	var died: Array[Unit] = []
	state.unit_died.connect(func(u: Unit) -> void: died.append(u))
	assert_ok(Rules.apply(state, 0, Actions.attack(a.id, b.id)))
	assert_true(b.is_alive())
	assert_ok(Rules.apply(state, 0, Actions.end_turn()))
	assert_ok(Rules.apply(state, 1, Actions.end_turn()))
	assert_ok(Rules.apply(state, 0, Actions.attack(a.id, b.id)))
	assert_false(b.is_alive())
	assert_eq(died.size(), 1)
	assert_true(state.is_over())
	assert_eq(state.winner, 0)
	assert_null(state.unit_at(&"d5"), "une unité morte n'occupe plus sa case")


func test_end_turn_refreshes_points_and_increments_turn() -> void:
	var a := state.spawn(&"soldier", 0, &"d1")
	var b := state.spawn(&"soldier", 1, &"d8")
	Rules.apply(state, 0, Actions.move(a.id, &"d3"))
	assert_eq(a.move_left, 0)
	assert_ok(Rules.apply(state, 0, Actions.end_turn()))
	assert_eq(state.current_player, 1)
	assert_eq(state.turn_number, 1)
	assert_eq(b.move_left, 2)
	assert_ok(Rules.apply(state, 1, Actions.end_turn()))
	assert_eq(state.current_player, 0)
	assert_eq(state.turn_number, 2)
	assert_eq(a.move_left, 2, "PM restaurés au nouveau tour")


func test_legal_actions_contains_moves_attacks_and_end_turn() -> void:
	var a := state.spawn(&"soldier", 0, &"d4")
	state.spawn(&"soldier", 1, &"d5")
	var acts := Rules.legal_actions(state)
	var types := {}
	for act in acts:
		types[Actions.type_of(act)] = types.get(Actions.type_of(act), 0) + 1
	assert_eq(types.get(Actions.END_TURN, 0), 1)
	assert_eq(types.get(Actions.ATTACK, 0), 1)
	# d4 -> orthogonal 2 PM, d5 occupée : c4 e4 d3 b4 f4 d2 c3 e3 c5 e5 = 10
	assert_eq(types.get(Actions.MOVE, 0), 10)
	assert_eq(a.move_left, 2, "legal_actions ne modifie pas l'état")


func test_state_serialization_roundtrip() -> void:
	var a := state.spawn(&"soldier", 0, &"d4")
	var b := state.spawn(&"archer", 1, &"d5")
	Rules.apply(state, 0, Actions.attack(a.id, b.id))
	Rules.apply(state, 0, Actions.end_turn())
	var d := state.to_dict()
	var json := JSON.stringify(d)
	var back: Dictionary = JSON.parse_string(json)
	var s2 := GameState.from_dict(back, state.board)
	assert_eq(s2.current_player, 1)
	assert_eq(s2.get_unit(b.id).hp, 3)
	assert_eq(s2.get_unit(a.id).cell_id, &"d4")
	assert_eq(s2.unit_types.size(), 3)
	# Le state restauré accepte les mêmes actions.
	assert_ok(Rules.apply(s2, 1, Actions.move(b.id, &"d7")))
