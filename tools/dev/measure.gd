extends SceneTree
## Dev tool: prints world-space AABB sizes of named level nodes (meshes merged).

const TARGETS := ["ucenic", "monk", "mester-mestesugar-real", "Rooms/01_TerracottaWorkshop/GuardLive2", "Rooms/01_TerracottaWorkshop/TerracottaGuard01", "Rooms/01_TerracottaWorkshop/WorkshopLamp_W", "MapWithoutTreasure/Ladder2", "Ladder", "MercuryVase", "Rooms/01_TerracottaWorkshop/FunctionalToolPickups/Table_Chisel_N"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var level: Node = (load("res://scenes/tomb_layout.tscn") as PackedScene).instantiate()
	get_root().add_child(level)
	await process_frame
	for path in TARGETS:
		var n := level.get_node_or_null(path)
		if n == null:
			print(path, ": missing")
			continue
		var box := _merged_aabb(n)
		print("%-60s size=(%.2f, %.2f, %.2f) min_y=%.2f max_y=%.2f" % [path, box.size.x, box.size.y, box.size.z, box.position.y, box.end.y])
	# Floor height probes and ceiling heights at a few spots.
	var space := (level as Node3D).get_world_3d().direct_space_state
	for p in [Vector3(-60, 0, -20), Vector3(-45, 0, -27), Vector3(0, 0, -30), Vector3(-30, 0, 12), Vector3(30, 0, -30), Vector3(48, -5, -30), Vector3(-70, 0, 60), Vector3(0, 10, 100)]:
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 20.0))
		var floor_y: float = down.position.y if not down.is_empty() else NAN
		var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, floor_y + 0.5, p.z), Vector3(p.x, floor_y + 40.0, p.z)))
		var ceil_y: float = up.position.y if not up.is_empty() else NAN
		print("probe %s floor=%.2f ceiling=%.2f height=%.2f" % [p, floor_y, ceil_y, ceil_y - floor_y])
	quit()

func _merged_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var box := m.global_transform * m.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result
