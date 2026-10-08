extends Node
## Dev runner: screenshots of the title screen (menu, credits, options, RO,
## the co-op panel).
## godot --path . --resolution 1600x900 -s res://tools/dev/run.gd -- --runner=res://tools/dev/title_shots_runner.gd --out=/abs/dir

func _ready() -> void:
	_run.call_deferred()

func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)

func _run() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Settings.set_value(&"language", "en", false)
	get_tree().change_scene_to_file("res://scenes/menu/title.tscn")
	await get_tree().create_timer(5.0).timeout
	var title := get_tree().current_scene
	await _shot(out, "t1_menu")
	await get_tree().create_timer(6.0).timeout
	await _shot(out, "t2_later")
	title.call(&"_show_credits")
	await get_tree().create_timer(0.4).timeout
	await _shot(out, "t3_credits")
	title.call(&"_close_overlay")
	title.call(&"_show_options")
	await get_tree().create_timer(0.4).timeout
	await _shot(out, "t4_options")
	title.call(&"_close_overlay")
	Settings.set_value(&"language", "ro", false)
	await get_tree().create_timer(0.5).timeout
	await _shot(out, "t5_ro")
	# Together (online co-op): the panel (with a friend's game heard on the
	# network, made up), then hosting.
	title.call(&"_show_coop")
	Net.link.hosts["192.168.1.23"] = {"name": "Andrei", "code": CoopCode.encode("192.168.1.23", Net.PORT), "port": Net.PORT, "seen": Time.get_ticks_msec() / 1000.0}
	Net.link.hosts_changed.emit()
	await get_tree().create_timer(0.4).timeout
	await _shot(out, "t6_coop")
	title.call(&"_on_coop_host")
	await get_tree().create_timer(0.4).timeout
	await _shot(out, "t7_coop_hosting")
	title.call(&"_close_overlay")
	Settings.set_value(&"language", "auto", false)
	get_tree().quit()
