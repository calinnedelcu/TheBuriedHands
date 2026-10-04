extends Node
## Bakes the NavigationMesh of every NavigationRegion3D in a scene from its
## static colliders (including colliders added at runtime by import helpers)
## and saves it as <scene>_navmesh.res, then re-saves the scene.
## Usage: godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/bake_navmesh_runner.gd --scene=res://scenes/level/mausoleum.tscn

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			path = arg.substr(8)
	var root := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	get_tree().root.add_child(root)
	for i in 4:
		await get_tree().physics_frame
	for region in root.find_children("*", "NavigationRegion3D", true, false):
		var r := region as NavigationRegion3D
		var nm := r.navigation_mesh
		var source := NavigationMeshSourceGeometryData3D.new()
		var t0 := Time.get_ticks_msec()
		NavigationServer3D.parse_source_geometry_data(nm, source, root)
		var t1 := Time.get_ticks_msec()
		NavigationServer3D.bake_from_source_geometry_data(nm, source)
		var out := path.get_basename() + "_navmesh.res"
		ResourceSaver.save(nm, out)
		print("baked %s: %d polygons, %d vertices (parse %d ms, bake %d ms) -> %s" % [r.name, nm.get_polygon_count(), nm.get_vertices().size(), t1 - t0, Time.get_ticks_msec() - t1, out])
		r.navigation_mesh = load(out)
	get_tree().root.remove_child(root)
	var packed := PackedScene.new()
	packed.pack(root)
	print("scene save err=", ResourceSaver.save(packed, path))
	root.free()
	get_tree().quit()
