extends SceneTree
## Dev tool: prints selected subtrees of the old level with global transforms.

const ROOTS := ["Rooms/01_TerracottaWorkshop/WorkshopQuestProps", "Rooms/01_TerracottaWorkshop/GuardWaypoints", "Rooms/01_TerracottaWorkshop/GuardExitPath", "ApprenticeInteractBody", "LiangInteractBody", "MapWithoutTreasure/TunnelEntrance2", "SqueezeTunnelCollapse", "TunnelCeilingColliders"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var root: Node3D = (load("res://scenes/tomb_layout.tscn") as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	for path in ROOTS:
		var n := root.get_node_or_null(path)
		if n == null:
			print("MISSING ", path)
			continue
		_dump(n, 0, root)
	quit()

func _dump(n: Node, depth: int, root: Node) -> void:
	var info := ""
	if n is Node3D:
		var g := (n as Node3D).global_transform
		info = "pos=%s rot=%s scale=%s" % [g.origin.snapped(Vector3.ONE * 0.01), (n as Node3D).global_rotation_degrees.snapped(Vector3.ONE * 0.1), g.basis.get_scale().snapped(Vector3.ONE * 0.01)]
	var script_name := (n.get_script() as Script).resource_path.get_file() if n.get_script() != null else ""
	print("  ".repeat(depth), n.name, " [", n.get_class(), (" " + script_name) if script_name != "" else "", "] ", info)
	if depth < 3:
		for c in n.get_children():
			_dump(c, depth + 1, root)
