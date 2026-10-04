extends SceneTree
## Dev tool: renders a scene/model from three angles in a neutral studio.
## Usage: godot --path . --resolution 1200x400 -s res://tools/dev/preview_model.gd -- res://path/model.glb /abs/out.png

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0]
	var out_path: String = args[1]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.18, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	root.add_child(sun)
	var model: Node3D = (load(scene_path) as PackedScene).instantiate()
	root.add_child(model)
	await process_frame
	var box := _aabb(model)
	print("AABB size=", box.size, " center=", box.get_center())
	var viewport_size := get_root().size
	var tiles: Array[Image] = []
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var radius := box.size.length() * 0.9
	for yaw in [0.0, 90.0, 210.0]:
		var dir := Vector3(sin(deg_to_rad(yaw)), 0.45, cos(deg_to_rad(yaw))).normalized()
		cam.global_position = box.get_center() + dir * radius
		cam.look_at(box.get_center())
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		tiles.append(get_root().get_texture().get_image())
	var w := viewport_size.x
	var h := viewport_size.y
	var sheet := Image.create(w * 3, h, false, tiles[0].get_format())
	for i in tiles.size():
		sheet.blit_rect(tiles[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	sheet.save_png(out_path)
	print("saved ", out_path)
	quit()

func _aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		result = b if first else result.merge(b)
		first = false
	return result
