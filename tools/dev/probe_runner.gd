extends Node
## Dev runner: lists the visual and collision nodes whose bounds touch a box,
## with their scene paths and sizes. For finding what makes up a spot.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/probe_runner.gd --box="minx,miny,minz;maxx,maxy,maxz"

func _ready() -> void:
	_run.call_deferred()

func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _run() -> void:
	var box := AABB()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--box="):
			var parts := arg.substr(6).split(";")
			var a := _vec(parts[0])
			box = AABB(a, _vec(parts[1]) - a)
	var root := (load("res://scenes/level/mausoleum.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var v := n as VisualInstance3D
		if v is Light3D or not v.is_visible_in_tree():
			continue
		var aabb := v.global_transform * v.get_aabb()
		if aabb.intersects(box):
			print("%-60s %s from %s to %s" % [str(root.get_path_to(v)), v.get_class(), aabb.position.snapped(Vector3.ONE * 0.1), aabb.end.snapped(Vector3.ONE * 0.1)])
			var mi := v as MeshInstance3D
			if mi != null and mi.mesh != null:
				for i in mi.mesh.get_surface_count():
					var m := mi.get_active_material(i)
					print("    surface %d: %s" % [i, m.resource_path if m != null else "none"])
	for n in root.find_children("*", "CollisionShape3D", true, false):
		var c := n as CollisionShape3D
		if c.disabled or c.shape == null:
			continue
		var aabb := c.global_transform * c.shape.get_debug_mesh().get_aabb()
		if aabb.intersects(box):
			print("COL %-86s %s size %s" % [str(root.get_path_to(c)), c.shape.get_class(), aabb.size.snapped(Vector3.ONE * 0.1)])
	for n in root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if box.grow(8.0).has_point(l.global_position):
			print("LIGHT %-84s %s at %s" % [str(root.get_path_to(l)), l.get_class(), l.global_position.snapped(Vector3.ONE * 0.1)])
	get_tree().quit()
