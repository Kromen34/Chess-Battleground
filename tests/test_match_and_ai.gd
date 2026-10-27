extends TestCase


func test_unit_types_load_from_data_folder() -> void:
	var types := MatchSetup.load_unit_types()
	assert_true(types.size() >= 4, "au moins 4 types dans data/ (obtenu %d)" % types.size())
	assert_true(types.has(&"soldier"))
	assert_true(types.has(&"knight"))
	var k: UnitType = types[&"knight"]
	assert_true(k.can_jump)
	assert_eq(k.move_points, 4)


func test_new_match_places_two_armies() -> void:
	var s := MatchSetup.new_match(PackedStringArray(["human", "human"]), 1)
	assert_not_null(s)
	assert_eq(s.units_of(0).size(), MatchSetup.DEFAULT_ARMY.size())
	assert_eq(s.units_of(1).size(), MatchSetup.DEFAULT_ARMY.size())
	for u in s.units_of(0):
		assert_true(s.board.get_spawn_zone(0).has(u.cell_id), "%s hors zone J0" % u)
	for u in s.units_of(1):
		assert_true(s.board.get_spawn_zone(1).has(u.cell_id), "%s hors zone J1" % u)
	assert_eq(s.board.validate().size(), 0)


func test_new_match_refuses_unsupported_player_count() -> void:
	var s := MatchSetup.new_match(PackedStringArray(["human", "human", "ai"]), 1)
	assert_null(s, "pas encore de plateau 3 joueurs")


func test_ai_vs_ai_game_terminates() -> void:
	var s := MatchSetup.new_match(PackedStringArray(["ai", "ai"]), 7)
	assert_not_null(s)
	var ais := [SimpleAI.new(0), SimpleAI.new(1)]
	var safety := 0
	while not s.is_over() and safety < 400:
		var ai: SimpleAI = ais[s.current_player]
		ai.play_turn(s)
		safety += 1
	assert_true(s.is_over(), "la partie IA vs IA doit se terminer (tours joués : %d)" % safety)
	assert_true(s.winner == 0 or s.winner == 1)


func test_ai_is_deterministic_for_a_seed() -> void:
	var results: Array = []
	for _i in range(2):
		var s := MatchSetup.new_match(PackedStringArray(["ai", "ai"]), 123)
		var ais := [SimpleAI.new(0), SimpleAI.new(1)]
		var safety := 0
		while not s.is_over() and safety < 400:
			(ais[s.current_player] as SimpleAI).play_turn(s)
			safety += 1
		results.append([s.winner, s.turn_number])
	assert_eq(results[0], results[1], "même seed => même partie")
