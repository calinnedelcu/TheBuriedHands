extends Node
## Dev runner: renders a contact sheet of every animation in a character
## model (4 poses each, side and front view) so tracks can be identified.
## godot --path . --resolution 1800x260 -s res://tools/dev/run.gd -- --runner=res://tools/dev/anim_sheet_runner.gd --model=res://TripoModels/samurai.glb --out=/abs/sheet.png

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var model_path := ""
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model_path = arg.substr(8)
		elif arg.begins_with("--out="):
			out = arg.substr(6)
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.16, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	root.add_child(sun)
	var model: Node3D = (load(model_path) as PackedScene).instantiate()
	root.add_child(model)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.3
	root.add_child(cam)
	cam.make_current()
	var label := Label3D.new()
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.08, 0)
	label.modulate = Color(1, 1, 0)
	root.add_child(label)
	var rows: Array[Image] = []
	for anim_name in ap.get_animation_list():
		var anim := ap.get_animation(anim_name)
		var frames: Array[Image] = []
		label.text = "%s (%.1fs)" % [anim_name, anim.length]
		for view in [0.0, 90.0]:
			cam.global_position = Vector3(sin(deg_to_rad(view)) * 4.0, 0.5, cos(deg_to_rad(view)) * 4.0)
			cam.look_at(Vector3(0, 0.5, 0))
			for k in 4:
				ap.play(anim_name)
				ap.seek(anim.length * k / 4.0, true)
				ap.pause()
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				var w8 := img.get_width() / 8
				frames.append(img.get_region(Rect2i(img.get_width() / 2 - w8 / 2, 0, w8, img.get_height())))
		var w := frames[0].get_width()
		var h := frames[0].get_height()
		var row := Image.create(w * frames.size(), h, false, frames[0].get_format())
		for i in frames.size():
			row.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
		rows.append(row)
	var sheet := Image.create(rows[0].get_width(), rows[0].get_height() * rows.size(), false, rows[0].get_format())
	for i in rows.size():
		sheet.blit_rect(rows[i], Rect2i(Vector2i.ZERO, rows[i].get_size()), Vector2i(0, i * rows[i].get_height()))
	sheet.save_png(out)
	print("saved ", out, " anims=", ap.get_animation_list())
	get_tree().quit()
