extends SceneTree
## Dev tool: clearance (floor-to-ceiling) at sample points along key passages.

const POINTS := {
	"basement_tunnel_N": Vector3(30, -6, -46), "basement_tunnel_E": Vector3(24, -6, -20),
	"basement_tunnel_S": Vector3(15, -6, 22), "basement_to_ladder": Vector3(1, -6, 33),
	"path_corridor_to_mech": Vector3(5, 2, 24), "path_corridor_to_mech_b": Vector3(1, 4, 30),
	"mech_room": Vector3(-5, 9, 50), "path_mech_to_mercury": Vector3(-25, 9, 50),
	"path_mech_to_mercury_b": Vector3(-35, 9, 58), "path_mech_to_treasury": Vector3(-3, 9, 66),
	"treasury": Vector3(5, 9, 80), "drain_tunnel": Vector3(-3, 9, 130), "drain_tunnel_b": Vector3(-3, 9, 150),
	"exit_tunnel": Vector3(-3, 9, 172), "workshop_door_S": Vector3(-63, 1, -2), "archives_door_S": Vector3(4, 1, 0),
	"liang_door_S": Vector3(37, 1, 0), "corridor_W_to_mercury": Vector3(-78, 1, 24),
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var level: Node3D = (load("res://scenes/tomb_layout.tscn") as PackedScene).instantiate()
	get_root().add_child(level)
	await physics_frame
	await physics_frame
	var space := level.get_world_3d().direct_space_state
	for key in POINTS:
		var p: Vector3 = POINTS[key]
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 30.0))
		if down.is_empty():
			print("%-24s no floor" % key)
			continue
		var floor_y: float = down.position.y
		var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, floor_y + 0.2, p.z), Vector3(p.x, floor_y + 40.0, p.z)))
		var clearance: float = (up.position.y - floor_y) if not up.is_empty() else INF
		print("%-24s floor=%6.2f clearance=%6.2f  (%s)" % [key, floor_y, clearance, str(down.collider.name).substr(0, 40)])
	quit()
