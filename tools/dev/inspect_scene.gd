extends SceneTree
func _initialize() -> void:
	for path in OS.get_cmdline_user_args():
		var n: Node = (load(path) as PackedScene).instantiate()
		print("== ", path)
		_dump(n, 0)
		n.free()
	quit()
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		var m := (n as MeshInstance3D).mesh
		extra = " surfaces=%d aabb=%s skin=%s" % [m.get_surface_count(), (n as MeshInstance3D).get_aabb().size, (n as MeshInstance3D).skin != null]
	if n is Skeleton3D:
		extra = " bones=%d" % (n as Skeleton3D).get_bone_count()
	if n is AnimationPlayer:
		extra = " anims=%s" % [(n as AnimationPlayer).get_animation_list()]
	if n is Node3D:
		extra += " pos=%s rot=%s scale=%s" % [(n as Node3D).position, (n as Node3D).rotation_degrees, (n as Node3D).scale]
	print("  ".repeat(d), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		_dump(c, d + 1)
