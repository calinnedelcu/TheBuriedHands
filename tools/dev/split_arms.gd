extends SceneTree
## One-off tool: splits the bound_arms_pov.glb mesh into separate left/right
## arm meshes (by triangle centroid X) so each hand can animate on its own.
## Output: res://assets/models/viewmodel/arm_left.res, arm_right.res

func _initialize() -> void:
	var scene: Node = (load("res://TripoModels/viewmodel/bound_arms_pov.glb") as PackedScene).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := mi.mesh
	var arrays := mesh.surface_get_arrays(0)
	var material := mesh.surface_get_material(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var box := mesh.get_aabb()
	print("aabb ", box, " verts ", verts.size(), " tris ", indices.size() / 3)
	var center_x := box.get_center().x
	for side in ["left", "right"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var src := SurfaceTool.new()
		src.create_from(mesh, 0)
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(mesh as ArrayMesh, 0)
		var kept := 0
		for f in mdt.get_face_count():
			var c := Vector3.ZERO
			for k in 3:
				c += mdt.get_vertex(mdt.get_face_vertex(f, k))
			c /= 3.0
			var is_left := c.x < center_x
			if (side == "left") != is_left:
				continue
			kept += 1
			for k in 3:
				var vi := mdt.get_face_vertex(f, k)
				st.set_normal(mdt.get_vertex_normal(vi))
				st.set_uv(mdt.get_vertex_uv(vi))
				st.add_vertex(mdt.get_vertex(vi))
		st.index()
		var out := st.commit()
		out.surface_set_material(0, material)
		var b := out.get_aabb()
		print(side, ": tris=", kept, " aabb=", b)
		ResourceSaver.save(out, "res://assets/models/viewmodel/arm_%s.res" % side)
	scene.free()
	quit()
