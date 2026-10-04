extends SceneTree
## Generates the hand/world visuals for small tools out of primitive meshes and
## saves them as scenes in res://scenes/items/visuals/. Re-run after tweaking.
## Usage: godot --headless --path . -s res://tools/dev/build_item_visuals.gd

const OUT := "res://scenes/items/visuals"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save("chisel", _chisel())
	_save("hammer", _hammer())
	_save("wedge", _wedge())
	_save("ceramic", _ceramic())
	_save("cloth", _cloth())
	_save("register", _register())
	_save("jar", _jar(false))
	_save("jar_full", _jar(true))
	quit()

# --- Materials ------------------------------------------------------------------

func _noise_tex(freq: Vector2, c1: Color, c2: Color, seed := 1) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, c1)
	ramp.set_color(1, c2)
	tex.color_ramp = ramp
	return tex

func _wood(dark := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var a := Color(0.36, 0.22, 0.12) if not dark else Color(0.24, 0.14, 0.08)
	var b := Color(0.5, 0.33, 0.18) if not dark else Color(0.34, 0.21, 0.12)
	m.albedo_texture = _noise_tex(Vector2.ONE, a, b, 7 if dark else 3)
	m.uv1_scale = Vector3(1.0, 6.0, 1.0)  # stretch the noise into grain
	m.roughness = 0.82
	return m

func _bronze() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(Vector2.ONE, Color(0.42, 0.33, 0.17), Color(0.55, 0.45, 0.25), 11)
	m.metallic = 0.75
	m.roughness = 0.42
	return m

func _clay(light := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var a := Color(0.55, 0.29, 0.17) if not light else Color(0.68, 0.42, 0.26)
	m.albedo_texture = _noise_tex(Vector2.ONE, a, a.lightened(0.15), 5)
	m.roughness = 0.95
	return m

func _cloth_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(Vector2.ONE, Color(0.52, 0.47, 0.38), Color(0.62, 0.57, 0.47), 9)
	m.uv1_scale = Vector3(6.0, 6.0, 1.0)
	m.roughness = 1.0
	return m

func _bamboo() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(Vector2.ONE, Color(0.62, 0.53, 0.32), Color(0.72, 0.63, 0.4), 13)
	m.uv1_scale = Vector3(1.0, 8.0, 1.0)
	m.roughness = 0.7
	return m

func _ink() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.06, 0.05)
	m.roughness = 0.9
	return m

# --- Shapes ---------------------------------------------------------------------

func _mesh(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO, name := "Part") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	root.add_child(mi)
	mi.owner = root
	return mi

func _cyl(r_bottom: float, r_top: float, h: float, segments := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r_bottom
	c.top_radius = r_top
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	return c

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _prism(size: Vector3, left := 0.5) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = size
	p.left_to_right = left
	return p

# Items are modelled along -Z (pointing away from the hand) with the grip at the origin.

func _chisel() -> Node3D:
	var root := Node3D.new()
	root.name = "Chisel"
	var wood := _wood()
	var bronze := _bronze()
	_mesh(root, _cyl(0.034, 0.03, 0.2, 10), wood, Vector3(0, 0, 0.04), Vector3(90, 0, 0), "Handle")
	_mesh(root, _cyl(0.036, 0.036, 0.03, 10), _wood(true), Vector3(0, 0, 0.145), Vector3(90, 0, 0), "Butt")
	_mesh(root, _cyl(0.037, 0.034, 0.035, 10), bronze, Vector3(0, 0, -0.075), Vector3(90, 0, 0), "Ferrule")
	_mesh(root, _box(Vector3(0.042, 0.016, 0.17)), bronze, Vector3(0, 0, -0.17), Vector3.ZERO, "Blade")
	_mesh(root, _prism(Vector3(0.042, 0.06, 0.016), 0.5), bronze, Vector3(0, 0, -0.284), Vector3(-90, 0, 0), "Edge")
	return root

func _hammer() -> Node3D:
	var root := Node3D.new()
	root.name = "Mallet"
	_mesh(root, _cyl(0.024, 0.028, 0.42, 8), _wood(), Vector3(0, 0, 0.0), Vector3(90, 0, 0), "Handle")
	_mesh(root, _cyl(0.075, 0.075, 0.22, 12), _wood(true), Vector3(0, 0, -0.23), Vector3(0, 0, 90), "Head")
	_mesh(root, _cyl(0.078, 0.078, 0.02, 12), _bronze(), Vector3(0.1, 0, -0.23), Vector3(0, 0, 90), "BandA")
	_mesh(root, _cyl(0.078, 0.078, 0.02, 12), _bronze(), Vector3(-0.1, 0, -0.23), Vector3(0, 0, 90), "BandB")
	return root

func _wedge() -> Node3D:
	var root := Node3D.new()
	root.name = "Wedge"
	_mesh(root, _prism(Vector3(0.09, 0.26, 0.07), 0.5), _wood(), Vector3(0, 0, -0.08), Vector3(-90, 0, 0), "Body")
	return root

func _ceramic() -> Node3D:
	var root := Node3D.new()
	root.name = "Shards"
	var a := _clay()
	var b := _clay(true)
	_mesh(root, _prism(Vector3(0.11, 0.08, 0.016), 0.2), a, Vector3(-0.03, 0, 0), Vector3(-80, 20, 0), "ShardA")
	_mesh(root, _prism(Vector3(0.09, 0.1, 0.014), 0.8), b, Vector3(0.035, 0.008, -0.02), Vector3(-95, -35, 10), "ShardB")
	_mesh(root, _prism(Vector3(0.07, 0.06, 0.013), 0.4), a, Vector3(0.0, 0.016, -0.06), Vector3(-70, 60, -15), "ShardC")
	return root

func _cloth() -> Node3D:
	var root := Node3D.new()
	root.name = "Cloth"
	var m := _cloth_mat()
	_mesh(root, _box(Vector3(0.2, 0.03, 0.14)), m, Vector3.ZERO, Vector3(0, 8, 0), "Fold1")
	_mesh(root, _box(Vector3(0.18, 0.026, 0.12)), m, Vector3(0.01, 0.026, 0.005), Vector3(0, -6, 2), "Fold2")
	_mesh(root, _box(Vector3(0.14, 0.022, 0.1)), m, Vector3(-0.005, 0.048, 0.0), Vector3(0, 14, -2), "Fold3")
	return root

func _register() -> Node3D:
	var root := Node3D.new()
	root.name = "BambooSlips"
	var bamboo := _bamboo()
	var ink := _ink()
	for i in 9:
		var x := -0.064 + i * 0.016
		_mesh(root, _box(Vector3(0.014, 0.006, 0.3)), bamboo, Vector3(x, 0.0, 0.0), Vector3(0, 0, randf_range(-2, 2)), "Slip%d" % i)
		for k in 5:
			_mesh(root, _box(Vector3(0.007, 0.0015, 0.012)), ink, Vector3(x, 0.0035, -0.11 + k * 0.05), Vector3.ZERO, "Ink%d_%d" % [i, k])
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.3, 0.22, 0.14)
	cord.roughness = 1.0
	_mesh(root, _box(Vector3(0.16, 0.012, 0.008)), cord, Vector3(0, 0.002, -0.09), Vector3.ZERO, "CordA")
	_mesh(root, _box(Vector3(0.16, 0.012, 0.008)), cord, Vector3(0, 0.002, 0.09), Vector3.ZERO, "CordB")
	return root

## The jar model is authored far from its origin; recentre it on its base.
func _jar(full: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "JarFull" if full else "Jar"
	var model: Node3D = (load("res://scenes/items/MercuryVase.glb") as PackedScene).instantiate()
	model.name = "Model"
	model.position = Vector3(8.885, -0.01, -3.269)
	root.add_child(model)
	model.owner = root
	if full:
		var mercury := StandardMaterial3D.new()
		mercury.albedo_color = Color(0.78, 0.8, 0.84)
		mercury.metallic = 1.0
		mercury.roughness = 0.08
		var disc := _cyl(0.2, 0.2, 0.01, 18)
		_mesh(root, disc, mercury, Vector3(0, 1.13, 0), Vector3.ZERO, "Mercury")
	return root

func _save(name: String, root: Node3D) -> void:
	var packed := PackedScene.new()
	packed.pack(root)
	var path := OUT.path_join(name + ".tscn")
	var err := ResourceSaver.save(packed, path)
	print("saved ", path, " err=", err)
	root.free()
