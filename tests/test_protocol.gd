extends TestCase


func test_encode_decode_roundtrip() -> void:
	var msg := Protocol.action(Actions.move(3, &"c4"))
	var back := Protocol.decode(Protocol.encode(msg), Protocol.MAX_CLIENT_PACKET_BYTES)
	assert_eq(Protocol.type_of(back), Protocol.ACTION)
	assert_eq(int(back["action"]["unit"]), 3, "JSON rend des float : relire avec int()")


func test_decode_rejects_garbage() -> void:
	var max_bytes := Protocol.MAX_CLIENT_PACKET_BYTES
	assert_true(Protocol.decode(PackedByteArray(), max_bytes).is_empty(), "vide")
	assert_true(Protocol.decode("pas du json".to_utf8_buffer(), max_bytes).is_empty(), "illisible")
	assert_true(Protocol.decode("[1, 2]".to_utf8_buffer(), max_bytes).is_empty(), "pas un objet")
	assert_true(Protocol.decode("{\"x\": 1}".to_utf8_buffer(), max_bytes).is_empty(), "sans type")
	assert_true(Protocol.decode("{\"t\": 5}".to_utf8_buffer(), max_bytes).is_empty(), "type non texte")


func test_decode_rejects_oversized_packet() -> void:
	var msg := {"t": Protocol.HELLO, "pad": "x".repeat(Protocol.MAX_CLIENT_PACKET_BYTES)}
	assert_true(Protocol.decode(Protocol.encode(msg), Protocol.MAX_CLIENT_PACKET_BYTES).is_empty())


func test_sanitize_action_keeps_only_expected_fields() -> void:
	var a := Protocol.sanitize_action({"type": "move", "unit": 2.0, "to": "d5", "cheat": true})
	assert_eq(a, Actions.move(2, &"d5"))
	assert_eq(Protocol.sanitize_action({"type": "attack", "unit": 1, "target": 7}), Actions.attack(1, 7))
	assert_eq(Protocol.sanitize_action({"type": "end_turn", "x": 1}), Actions.end_turn())


func test_sanitize_action_rejects_malformed() -> void:
	assert_true(Protocol.sanitize_action("move").is_empty(), "pas un Dictionary")
	assert_true(Protocol.sanitize_action({"type": "move", "unit": {"a": 1}, "to": "d5"}).is_empty())
	assert_true(Protocol.sanitize_action({"type": "move", "unit": 1, "to": 5}).is_empty())
	assert_true(Protocol.sanitize_action({"type": "attack", "unit": 1}).is_empty())
	assert_true(Protocol.sanitize_action({"type": "teleport", "unit": 1}).is_empty())


func test_hello_carries_steam_id_as_text() -> void:
	var big := 76561197960287930
	var msg := Protocol.decode(Protocol.encode(Protocol.hello("0aff", big)), Protocol.MAX_CLIENT_PACKET_BYTES)
	assert_eq(typeof(msg["steam_id"]), TYPE_STRING, "un int64 ne tient pas dans un nombre JSON")
	assert_eq(Protocol.claimed_steam_id(msg), big)
	assert_eq(Protocol.ticket_of(msg), "0aff")
	var bare := Protocol.hello()
	assert_false(bare.has("ticket") or bare.has("steam_id"), "rien sans Steam")


func test_parse_steam_id_rejects_garbage() -> void:
	for bad: Variant in [null, 5, 7.0, "", "abc", "-12", "+12", "12a", "99999999999999999999"]:
		assert_eq(Protocol.parse_steam_id(bad), 0, "refusé : %s" % [bad])
	assert_eq(Protocol.parse_steam_id("42"), 42)


func test_ticket_of_rejects_garbage() -> void:
	for bad: Variant in [null, 12, "xyz", "abc", "-0ff", "0x0f", "ab".repeat(2561)]:
		assert_eq(Protocol.ticket_of({"ticket": bad}), "", "refusé : %s" % [bad])
	assert_eq(Protocol.ticket_of({"ticket": "00FFab"}), "00FFab")
