extends SceneTree
## Builds res://scenes/dev/test_room.tscn: a small lit room to exercise the
## player, items, wall lamps, stairs and a crawl tunnel in isolation.

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/dev"))
	var root := Node3D.new()
	root.name = "TestRoom"
	root.set_script(load("res://Scripts/world/level.gd"))

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.008, 0.006)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.09, 0.08, 0.1)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.01
	env.fog_light_color = Color(0.05, 0.035, 0.02)
	env_node.environment = env
	_add(root, env_node)

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.36, 0.3)
	stone.roughness = 0.9
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.22, 0.13)
	# Floor, walls, ceiling (CSG with collision).
	_box(root, "Floor", Vector3(30, 1, 30), Vector3(0, -0.5, 0), stone)
	_box(root, "Ceiling", Vector3(30, 1, 30), Vector3(0, 6.5, 0), stone)
	_box(root, "WallN", Vector3(30, 7, 1), Vector3(0, 3, -15), stone)
	_box(root, "WallS", Vector3(30, 7, 1), Vector3(0, 3, 15), stone)
	_box(root, "WallE", Vector3(1, 7, 30), Vector3(15, 3, 0), stone)
	_box(root, "WallW", Vector3(1, 7, 30), Vector3(-15, 3, 0), stone)
	var table := _box(root, "Table", Vector3(3.0, 1.8, 1.4), Vector3(-6, 0.9, -8), wood)
	table.set_meta(&"surface", "wood")
	# Stairs.
	for i in 6:
		_box(root, "Step%d" % i, Vector3(3, 0.35 * (i + 1), 0.8), Vector3(8, 0.175 * (i + 1), -4 - i * 0.8), stone)
	_box(root, "Landing", Vector3(3, 2.1, 4), Vector3(8, 1.05, -10.8), stone)
	# Crawl tunnel: a low slab you must crawl under.
	_box(root, "TunnelRoof", Vector3(4, 4.5, 6), Vector3(-9, 3.35, 6), stone)
	_box(root, "TunnelWallA", Vector3(1, 1.1, 6), Vector3(-11.5, 0.55, 6), stone)
	_box(root, "TunnelWallB", Vector3(1, 1.1, 6), Vector3(-6.5, 0.55, 6), stone)

	var player: Node3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	_add(root, player)
	player.position = Vector3(0, 0.1, 6)

	var lamp: Node3D = (load("res://scenes/world/lamp_stand.tscn") as PackedScene).instantiate()
	lamp.name = "LampStand"
	_add(root, lamp)
	lamp.position = Vector3(-5.2, 1.8, -8)
	lamp.set(&"oil", 70.0)

	var wall_lamp: Node3D = (load("res://scenes/world/wall_lamp.tscn") as PackedScene).instantiate()
	wall_lamp.name = "WallLamp"
	_add(root, wall_lamp)
	wall_lamp.position = Vector3(4, 3.2, -14.1)
	wall_lamp.rotation_degrees.y = 180

	var wall_lamp2: Node3D = (load("res://scenes/world/wall_lamp.tscn") as PackedScene).instantiate()
	wall_lamp2.name = "WallLamp2"
	_add(root, wall_lamp2)
	wall_lamp2.position = Vector3(-14.1, 3.2, -2)
	wall_lamp2.rotation_degrees.y = -90

	var x := -7.2
	for id in ["chisel", "hammer", "wedge", "ceramic", "cloth"]:
		var p: Node3D = (load("res://scenes/items/pickup.tscn") as PackedScene).instantiate()
		p.name = "Pickup_" + id
		p.set(&"item_id", StringName(id))
		if id == "ceramic":
			p.set(&"count", 3)
		_add(root, p)
		p.position = Vector3(x, 1.82, -7.7)
		x += 0.6

	var packed := PackedScene.new()
	packed.pack(root)
	print("save err=", ResourceSaver.save(packed, "res://scenes/dev/test_room.tscn"))
	root.free()
	quit()

func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = parent

func _box(root: Node, name: String, size: Vector3, pos: Vector3, mat: Material) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = name
	b.size = size
	b.position = pos
	b.use_collision = true
	b.material = mat
	_add(root, b)
	return b
