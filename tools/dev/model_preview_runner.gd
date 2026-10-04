extends Node
## Dev runner: renders a scene/model from four sides under neutral light and
## prints its AABB, to judge assets before using them.
## godot --path . --resolution 800x800 -s res://tools/dev/run.gd -- --runner=res://tools/dev/model_preview_runner.gd --scene=res://x.glb --out=/abs/dir

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene_path := ""
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.substr(8)
		elif arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.18, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(30), 0)
	world.add_child(sun)
	var model: Node3D = (load(scene_path) as PackedScene).instantiate()
	world.add_child(model)
	var anim := model.find_children("*", "AnimationPlayer", true, false)
	if not anim.is_empty():
		var ap := anim[0] as AnimationPlayer
		print("animations: ", ap.get_animation_list())
	await get_tree().process_frame
	var aabb := _aabb(model)
	print("aabb: ", aabb)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	var centre := aabb.get_center()
	var radius := aabb.size.length() * 0.75
	for i in 4:
		var a := i * PI / 2.0 + 0.4
		cam.global_position = centre + Vector3(sin(a) * radius, aabb.size.y * 0.25, cos(a) * radius)
		cam.look_at(centre)
		for k in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("view_%d.png" % i))
	get_tree().quit()

func _aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var v := n as VisualInstance3D
		var b := v.global_transform * v.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
