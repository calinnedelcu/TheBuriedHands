extends Node
## Dev runner: loads the real level, gives the player a lit lamp and saves
## first-person screenshots at a list of spots (player position + view).
## godot --path . --resolution 1600x900 -s res://tools/dev/run.gd -- --runner=res://tools/dev/level_tour_runner.gd --out=/abs/dir [--only=a,b]

const SPOTS := [
	["a_spawn", Vector3(-75.7, 0.2, -24.2), -90.6, -5.0],
	["b_workshop", Vector3(-62.0, 0.2, -20.0), -60.0, -4.0],
	["c_statue", Vector3(-64.5, 0.2, -4.0), 55.0, -18.0],
	["d_bowl_end", Vector3(-30.0, 0.2, -30.0), 120.0, -10.0],
	["e_archives", Vector3(6.0, 0.2, -6.0), 10.0, -3.0],
	["f_archives_deep", Vector3(10.0, 0.2, -30.0), 0.0, -3.0],
	["g_liang", Vector3(33.0, 0.2, -28.0), -120.0, -8.0],
	["h_corridor", Vector3(-30.0, 0.2, 12.0), -90.0, -6.0],
	["i_tunnel", Vector3(30.0, -5.2, -46.0), 90.0, -4.0],
	["j_mechanism", Vector3(0.5, 7.7, 44.5), 180.0, -8.0],
	["k_mercury", Vector3(-46.0, 7.9, 70.0), 90.0, -18.0],
	["l_treasury", Vector3(0.6, 7.5, 88.0), 180.0, -4.0],
	["m_drain", Vector3(-3.0, 7.6, 132.0), 180.0, -2.0],
]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := ""
	var only: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().change_scene_to_file("res://scenes/level/mausoleum.tscn")
	await Game.level_ready
	var player := get_tree().get_first_node_in_group(&"player") as Player
	player.inventory.take_lamp(90.0, true)
	Dialogue.stop()
	for spot in SPOTS:
		if not only.is_empty() and not only.has(spot[0]):
			continue
		player.global_position = spot[1]
		player.velocity = Vector3.ZERO
		player.rotation.y = deg_to_rad(spot[2])
		player._set_pitch(deg_to_rad(spot[3]))
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(out.path_join(spot[0] + ".png"))
		print("shot ", spot[0], " at ", player.global_position)
	get_tree().quit()
