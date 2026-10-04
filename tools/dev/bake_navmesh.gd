extends SceneTree
## Bakes the NavigationMesh of every NavigationRegion3D in a scene from its
## static colliders and saves it next to the scene as <scene>_navmesh.res.
## Usage: godot --headless --path . -s res://tools/dev/bake_navmesh.gd -- res://scenes/level/mausoleum.tscn

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var packed := load(path) as PackedScene
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	get_root().add_child(root)
	for i in 4:
		await physics_frame
	var regions := root.find_children("*", "NavigationRegion3D", true, false)
	if regions.is_empty():
		print("no NavigationRegion3D in ", path)
		quit()
		return
	for region in regions:
		var r := region as NavigationRegion3D
		var nm := r.navigation_mesh if r.navigation_mesh != null else NavigationMesh.new()
		var source := NavigationMeshSourceGeometryData3D.new()
		var t0 := Time.get_ticks_msec()
		NavigationServer3D.parse_source_geometry_data(nm, source, root)
		NavigationServer3D.bake_from_source_geometry_data(nm, source)
		var out := path.get_basename() + "_navmesh.res"
		if r.name != "NavigationRegion":
			out = path.get_basename() + "_" + String(r.name).to_snake_case() + "_navmesh.res"
		ResourceSaver.save(nm, out)
		print("baked %s: %d polygons, %d vertices in %d ms -> %s" % [r.name, nm.get_polygon_count(), nm.get_vertices().size(), Time.get_ticks_msec() - t0, out])
		# Point the region at the saved resource and re-save the scene.
		r.navigation_mesh = load(out)
	root.get_parent().remove_child(root)
	var repacked := PackedScene.new()
	repacked.pack(root)
	print("scene save err=", ResourceSaver.save(repacked, path))
	root.free()
	quit()
