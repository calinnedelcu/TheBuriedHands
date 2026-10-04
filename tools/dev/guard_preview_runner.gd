extends Node
## Dev runner: a guard (optionally with a torch) in an empty lit room, shot
## from the front and side while idle and walking, to tune props.
## godot --path . --resolution 1600x900 -s res://tools/dev/run.gd -- --runner=res://tools/dev/guard_preview_runner.gd --out=/abs/dir [--off=x,y,z]

func _ready() -> void:
	_run.call_deferred()

func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _run() -> void:
	var out := ""
	var off := Vector3.INF
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--off="):
			off = _vec(arg.substr(6))
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.05, 0.06)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.25, 0.25, 0.28)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world.add_child(env)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(20, 20)
	world.add_child(floor_mesh)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	world.add_child(ground)
	var guard := (load("res://scenes/ai/guard.tscn") as PackedScene).instantiate() as Guard
	guard.carries_torch = true
	if off != Vector3.INF:
		guard.torch_offset = off
	world.add_child(guard)
	guard.set_scripted(true)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	for anim in [&"idle", &"walk"]:
		guard.play_animation(anim)
		await get_tree().create_timer(0.6).timeout
		for view in [["front", Vector3(0.6, 2.0, -3.6)], ["side", Vector3(3.6, 2.0, 0.4)]]:
			cam.global_position = view[1]
			cam.look_at(Vector3(0, 1.7, 0))
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [anim, view[0]]))
	get_tree().quit()
