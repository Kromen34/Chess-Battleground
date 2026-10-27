class_name TestCase
extends RefCounted
## Classe de base des tests. Assertions simples qui accumulent les erreurs
## au lieu de planter, pour avoir un rapport complet.

var errors: PackedStringArray = PackedStringArray()


func reset() -> void:
	errors = PackedStringArray()


func setup() -> void:
	pass


func teardown() -> void:
	pass


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		errors.append("attendu vrai" + (" — " + msg if msg != "" else ""))


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		errors.append("attendu faux" + (" — " + msg if msg != "" else ""))


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		errors.append("attendu %s, obtenu %s" % [expected, actual] + (" — " + msg if msg != "" else ""))


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	if actual == unexpected:
		errors.append("ne devait pas valoir %s" % [unexpected] + (" — " + msg if msg != "" else ""))


func assert_null(v: Variant, msg: String = "") -> void:
	if v != null:
		errors.append("attendu null, obtenu %s" % [v] + (" — " + msg if msg != "" else ""))


func assert_not_null(v: Variant, msg: String = "") -> void:
	if v == null:
		errors.append("attendu non null" + (" — " + msg if msg != "" else ""))


func assert_ok(result: Dictionary, msg: String = "") -> void:
	if not result.get("ok", false):
		errors.append("action refusée : %s" % result.get("reason", "?") + (" — " + msg if msg != "" else ""))


func assert_refused(result: Dictionary, msg: String = "") -> void:
	if result.get("ok", false):
		errors.append("action acceptée alors qu'elle devait être refusée" + (" — " + msg if msg != "" else ""))
