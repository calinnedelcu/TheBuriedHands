extends SceneTree
## Bootstrap for dev runners (build tools, tests). Game scripts use autoload
## globals, which only resolve after startup, so the runner script is loaded at
## runtime instead of being compiled with this file.
## Usage: godot [--headless] --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/<runner>.gd [--timeout=seconds] [args]
## A runner that errors out would otherwise leave the game (and its window)
## running forever, so the whole run is cut off after --timeout (default 900 s).

func _initialize() -> void:
	var runner_path := ""
	var limit := 900.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runner="):
			runner_path = arg.substr(9)
		elif arg.begins_with("--timeout="):
			limit = float(arg.substr(10))
	create_timer(limit, true, false, true).timeout.connect(func():
		push_error("run.gd: timed out after %d s" % limit)
		quit(2))
	if runner_path == "":
		push_error("run.gd: pass --runner=res://...")
		quit(1)
		return
	_start.call_deferred(runner_path)

func _start(path: String) -> void:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		push_error("run.gd: could not load " + path)
		quit(1)
		return
	var runner: Node = script.new()
	runner.name = "Runner"
	get_root().add_child(runner)
