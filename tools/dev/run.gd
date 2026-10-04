extends SceneTree
## Bootstrap for dev runners (build tools, tests). Game scripts use autoload
## globals, which only resolve after startup, so the runner script is loaded at
## runtime instead of being compiled with this file.
## Usage: godot [--headless] --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/<runner>.gd [args]

func _initialize() -> void:
	var runner_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runner="):
			runner_path = arg.substr(9)
	if runner_path == "":
		push_error("run.gd: pass --runner=res://...")
		quit(1)
		return
	_start.call_deferred(runner_path)

func _start(path: String) -> void:
	var runner: Node = load(path).new()
	runner.name = "Runner"
	get_root().add_child(runner)
