extends Node
## Dev runner: frame time at the level tour's spots (slowly turning in place),
## with draw calls, lights and memory. Needs a window; run it in the front.
## godot --path . --resolution 1920x1080 -s res://tools/dev/run.gd -- --runner=res://tools/dev/perf_runner.gd [--quality=0..3] [--exp=name] (experiments: noshadow, nostatic)

const SPOTS := [
	["spawn", Vector3(-75.7, 0.2, -24.2)],
	["workshop", Vector3(-55.0, 0.2, -18.0)],
	["archives", Vector3(10.0, 0.2, -30.0)],
	["corridor", Vector3(-30.0, 0.2, 12.0)],
	["tunnel", Vector3(30.0, -3.0, -30.0)],
	["mechanism", Vector3(0.5, 7.7, 44.5)],
	["mercury", Vector3(-46.0, 7.9, 70.0)],
	["treasury", Vector3(0.6, 7.5, 88.0)],
]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var experiment := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			Settings.set_value(&"quality", int(arg.substr(10)), false)
		elif arg.begins_with("--exp="):
			experiment = arg.substr(6)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_tree().change_scene_to_file("res://scenes/level/mausoleum.tscn")
	await Game.level_ready
	Dialogue.stop()
	var player := get_tree().get_first_node_in_group(&"player") as Player
	player.inventory.take_lamp(90.0, true)
	var n := 0
	for l in Game.level.find_children("*", "OmniLight3D", true, false):
		var light := l as OmniLight3D
		if experiment == "noshadow" and light.shadow_enabled:
			light.shadow_enabled = false
			n += 1
		elif experiment == "nostatic" and light.shadow_enabled and not player.is_ancestor_of(light) and not (light.get_parent() is HeldTorch or light.get_parent().get_parent() is HeldTorch):
			light.shadow_enabled = false
			n += 1
	if experiment != "":
		print("experiment %s: %d shadows off" % [experiment, n])
	print("quality=%d  %s" % [Settings.get_value(&"quality"), RenderingServer.get_video_adapter_name()])
	for spot in SPOTS:
		player.global_position = spot[1]
		player.velocity = Vector3.ZERO
		await get_tree().create_timer(1.5).timeout
		var frames := 0
		var worst := 0.0
		var total := 0.0
		var t0 := Time.get_ticks_usec()
		var last := t0
		while Time.get_ticks_usec() - t0 < 4_000_000:
			player.rotation.y += 0.02
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var dt := (now - last) / 1000.0
			last = now
			frames += 1
			total += dt
			worst = maxf(worst, dt)
		var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("%-10s avg %5.2f ms (%3.0f fps)  worst %5.1f ms  draws %5d  prims %7d" % [spot[0], total / frames, 1000.0 / (total / frames), worst, draws, prims])
	print("video mem %.0f MB" % (RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0))
	Game._delete_save()
	get_tree().quit()
