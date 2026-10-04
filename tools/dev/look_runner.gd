extends Node
## Dev runner: free-camera shots of the level, to check placements. A small
## warm light rides with the camera, like the player's lamp. The HUD is hidden.
## godot --path . --resolution 1280x720 -s res://tools/dev/run.gd -- --runner=res://tools/dev/look_runner.gd --out=/abs/dir --shot="name;fx,fy,fz;tx,ty,tz" [--shot=...] [--tipped]

func _ready() -> void:
	_run.call_deferred()

func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _run() -> void:
	var out := ""
	var shots := []
	var tipped := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--shot="):
			var parts := arg.substr(7).split(";")
			shots.append([parts[0], _vec(parts[1]), _vec(parts[2])])
		elif arg == "--tipped":
			tipped = true
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().change_scene_to_file("res://scenes/level/mausoleum.tscn")
	await Game.level_ready
	Dialogue.stop()
	if tipped:
		Game.level.get_node("MapWithoutTreasure/Balanta").call(&"snap_to_end")
	var player := get_tree().get_first_node_in_group(&"player") as Player
	player.lock_controls(&"look", true)
	var hud := player.get_node_or_null("HUD")
	if hud != null:
		hud.set(&"visible", false)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.03
	Game.level.add_child(cam)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1, 0.62, 0.3)
	lamp.light_energy = 1.6
	lamp.omni_range = 9.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(-0.25, -0.2, -0.3)
	cam.add_child(lamp)
	cam.make_current()
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		await get_tree().create_timer(0.6).timeout
		var atmo := Game.level.get_node_or_null("Atmosphere")
		if atmo != null:
			atmo.call(&"snap")
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(String(s[0]) + ".png"))
		print("shot ", s[0])
	get_tree().quit()
