extends SceneTree
## Dev tool: prints global positions of gameplay-relevant nodes in the level.
## Usage: godot --headless --path . -s res://tools/dev/dump_positions.gd

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/tomb_layout.tscn")
	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	_dump(root, root)
	quit()

func _dump(node: Node, root: Node) -> void:
	if node is Node3D:
		var n3 := node as Node3D
		var script_name := ""
		if node.get_script() != null:
			script_name = (node.get_script() as Script).resource_path.get_file()
		var interesting := script_name != "" or node is Camera3D or node is CharacterBody3D or node is Area3D or node is Marker3D
		var depth := str(root.get_path_to(node)).count("/")
		if interesting and depth < 6 and not script_name in ["static_lamp_flicker.gd", "static_lamp_loop_audio.gd", "oil_reservoir.gd"]:
			var p := n3.global_position
			print("%-70s %-34s (%7.2f, %7.2f, %7.2f) yaw=%6.1f" % [str(root.get_path_to(node)).substr(0, 70), script_name if script_name != "" else node.get_class(), p.x, p.y, p.z, rad_to_deg(n3.global_rotation.y)])
	for c in node.get_children():
		_dump(c, root)
