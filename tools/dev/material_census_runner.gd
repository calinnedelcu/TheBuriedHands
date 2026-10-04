extends Node
## Dev runner: lists the materials used in a scene (name, colour, textures)
## with how many surfaces use them and which meshes, to plan a texture pass.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/material_census_runner.gd --scene=res://x.tscn

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			path = arg.substr(8)
	var root: Node = (load(path) as PackedScene).instantiate()
	var stats := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var key := _describe(mat)
			if not stats.has(key):
				stats[key] = {"count": 0, "meshes": []}
			stats[key].count += 1
			if stats[key].meshes.size() < 4:
				stats[key].meshes.append(String(mi.name))
	var keys := stats.keys()
	keys.sort_custom(func(a, b): return stats[a].count > stats[b].count)
	for k in keys:
		print("%4d  %s   e.g. %s" % [stats[k].count, k, ", ".join(stats[k].meshes)])
	root.free()
	get_tree().quit()

func _describe(mat: Material) -> String:
	if mat == null:
		return "<none>"
	var s := "%s [%s]" % [mat.resource_name, mat.get_class()]
	var bm := mat as BaseMaterial3D
	if bm != null:
		s += " col=%s" % bm.albedo_color.to_html(false)
		if bm.albedo_texture != null:
			s += " tex=%s" % bm.albedo_texture.resource_path.get_file()
		if bm.normal_enabled:
			s += " +normal"
		s += " rough=%.2f metal=%.2f" % [bm.roughness, bm.metallic]
	var sm := mat as ShaderMaterial
	if sm != null and sm.shader != null:
		s += " shader=%s" % sm.shader.resource_path.get_file()
	return s
