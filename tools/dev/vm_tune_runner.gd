extends Node
## Dev runner: renders the first-person view (lamp + an item) in the test room.
## Overrides viewmodel exports via --vm='{"left_grip":[x,y,z], ...}' and item
## socket transform via --socket='[rx,ry,rz, x,y,z]' (degrees, metres).
## Run with: godot --path . --resolution 1600x900 -s res://tools/dev/test_player.gd -- --runner=res://tools/dev/vm_tune_runner.gd --out=/abs/file.png [--item=chisel]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	var out := ""
	var vm_json := ""
	var socket_json := ""
	var item := "chisel"
	var raised := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--vm="):
			vm_json = arg.substr(5)
		elif arg.begins_with("--socket="):
			socket_json = arg.substr(9)
		elif arg.begins_with("--item="):
			item = arg.substr(7)
		elif arg == "--raised":
			raised = true
	get_tree().change_scene_to_file("res://scenes/dev/test_room.tscn")
	for i in 10:
		await get_tree().process_frame
	var player := get_tree().get_first_node_in_group(&"player") as Player
	player.global_position = Vector3(0, 0.1, 5)
	player.rotation.y = 0.0
	player.inventory.take_lamp(80.0, true)
	if item != "none":
		player.inventory.add(StringName(item))
	var vm := player.viewmodel as Viewmodel
	if vm_json != "":
		var data: Dictionary = JSON.parse_string(vm_json)
		for key in data:
			var v = data[key]
			vm.set(key, Vector3(v[0], v[1], v[2]) if v is Array else v)
		vm.relayout()
	if socket_json != "":
		var a: Array = JSON.parse_string(socket_json)
		var socket := vm.get_node("RightArm/ItemSocket") as Node3D
		socket.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(a[0]), deg_to_rad(a[1]), deg_to_rad(a[2]))) * Basis.from_scale(Vector3.ONE * (a[6] if a.size() > 6 else 1.0)), Vector3(a[3], a[4], a[5]))
	if raised:
		player.inventory.lamp().is_raised = true
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
