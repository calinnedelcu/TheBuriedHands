extends SceneTree
## Dev check: loads every script under the given folders and reports which
## fail to compile. Usage: godot --headless --path . -s res://tools/dev/check_scripts.gd

const FOLDERS := ["res://Scripts/core", "res://Scripts/player", "res://Scripts/items", "res://Scripts/interaction", "res://Scripts/ui", "res://Scripts/world", "res://Scripts/data", "res://Scripts/ai"]

func _initialize() -> void:
	var failed := 0
	var total := 0
	for folder in FOLDERS:
		for file in ResourceLoader.list_directory(folder):
			if not file.ends_with(".gd"):
				continue
			total += 1
			var script := load(folder.path_join(file)) as GDScript
			if script == null or not script.can_instantiate():
				failed += 1
				print("FAIL ", folder.path_join(file))
	print("checked %d scripts, %d failed" % [total, failed])
	quit()
