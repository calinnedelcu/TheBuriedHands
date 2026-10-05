extends Node
## Dev runner: renders every animation of a rigged model at a few moments
## (front and side), to see what each clip is.
## godot --path . --resolution 800x800 -s res://tools/dev/run.gd -- --runner=res://tools/dev/anim_sheet_runner.gd --scene=res://x.glb --out=/abs/dir [--frames=6] [--scale=3.25]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := ""
	var out := ""
	var frames := 6
	var model_scale := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			path = arg.substr(8)
		elif arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--frames="):
			frames = int(arg.substr(9))
		elif arg.begins_with("--scale="):
			model_scale = float(arg.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.18, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	world.add_child(model)
	var anim := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var box := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var a := mi.global_transform * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	var centre := box.get_center()
	var h := box.size.y
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 40.0
	cam.make_current()
	for name in anim.get_animation_list():
		var a := anim.get_animation(name)
		anim.play(name)
		for i in frames:
			var t := a.length * float(i) / float(frames)
			anim.seek(t, true)
			for side in 2:
				var dir := Vector3(1, 0.15, 0) if side == 0 else Vector3(0, 0.15, 1)
				cam.global_position = centre + dir.normalized() * h * 1.9
				cam.look_at(centre)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out.path_join("%s_%02d_%s.png" % [name, i, "a" if side == 0 else "b"]))
		print("anim ", name, " length ", a.length)
	get_tree().quit()
