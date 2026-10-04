extends SceneTree
## Bootstrap for dev test runners: game scripts reference autoloads, which are
## only resolvable after startup, so the runner is loaded at runtime.
## Usage: godot --path . --resolution 1600x900 -s res://tools/dev/test_player.gd -- [--runner=res://...] --out=/abs/dir

func _initialize() -> void:
	var runner_path := "res://tools/dev/test_player_runner.gd"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runner="):
			runner_path = arg.substr(9)
	_start.call_deferred(runner_path)

func _start(path: String) -> void:
	var runner: Node = load(path).new()
	runner.name = "TestRunner"
	get_root().add_child(runner)
