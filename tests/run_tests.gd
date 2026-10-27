extends SceneTree
## Runner de tests minimal, sans dépendance externe.
## Charge tous les tests/test_*.gd, exécute chaque méthode test_*, et sort avec
## un code non nul s'il y a un échec. Usage : godot --headless -s tests/run_tests.gd

const TEST_DIR := "res://tests/"


func _init() -> void:
	var failures := 0
	var passed := 0
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		printerr("Impossible d'ouvrir %s" % TEST_DIR)
		quit(2)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR + f)
		var suite: TestCase = script.new()
		print("== %s" % f)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			suite.reset()
			suite.setup()
			suite.call(name)
			suite.teardown()
			if suite.errors.is_empty():
				passed += 1
				print("  ok   %s" % name)
			else:
				failures += 1
				print("  FAIL %s" % name)
				for e in suite.errors:
					print("       %s" % e)
	print("")
	print("%d réussi(s), %d échec(s)" % [passed, failures])
	quit(1 if failures > 0 else 0)
