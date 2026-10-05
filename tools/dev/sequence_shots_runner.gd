extends Node
## Dev runner: frames of a scripted moment, to review how it plays.
## --seq=opening : a new game from the title, the first seconds
## --seq=sealing : the sealing cutscene, from the last chisel strike
## --seq=causeway : pouring the mercury, the causeway rising
## --seq=chase : an archive guard spots the lit lamp, levels his ji, attacks
## --seq=ending : the walk down the last tunnel into the light, the epilogue
## (run it with --fixed-fps 30 so game time doesn't depend on the frame rate)
## godot --path . --resolution 1280x720 -s res://tools/dev/run.gd -- --runner=res://tools/dev/sequence_shots_runner.gd --seq=opening --out=/abs/dir

var out := ""
var _n := 0

func _ready() -> void:
	_run.call_deferred()

func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("%02d_%s.png" % [_n, tag]))
	_n += 1

func _frames(seconds: float, every: float, tag: String) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().create_timer(every).timeout
		t += every
		await _shot("%s_%04.1f" % [tag, t])

## The capture window can catch the real mouse; keep the view the script's.
func _hold_view() -> void:
	await Game.level_ready
	var player := get_tree().get_first_node_in_group(&"player") as Player
	player.set_process_unhandled_input(false)

func _run() -> void:
	var seq := "opening"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--seq="):
			seq = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_hold_view()
	match seq:
		"opening":
			Game.new_game()
			await Game.level_ready
			await _frames(16.0, 1.6, "open")
		"sealing":
			Game.new_game()
			await Game.level_ready
			Dialogue.stop()
			var player := get_tree().get_first_node_in_group(&"player") as Player
			player.global_position = Vector3(-66.5, 0.2, -4.2)
			player.rotation.y = deg_to_rad(40.0)
			player.inventory.take_lamp(90.0, true)
			Quest.start_at(&"finish_statue")
			Quest.complete(&"finish_statue")
			await _frames(40.0, 2.0, "seal")
		"causeway":
			Game.new_game()
			await Game.level_ready
			Dialogue.stop()
			var player := get_tree().get_first_node_in_group(&"player") as Player
			Game.set_flag(&"guards_hostile")
			Game.advance_sealing(1)
			Quest.start_at(&"pour_mercury")
			player.inventory.take_lamp(90.0, true)
			player.inventory.add(&"vase_full")
			player.inventory.add(&"cloth")
			player.global_position = Vector3(4.2, 12.6, 47.4)
			player.rotation.y = deg_to_rad(-60.0)
			await get_tree().create_timer(1.0).timeout
			var cw := Game.level.get_node("Mechanism/Counterweight/Body/Usable") as Usable
			cw.complete_hold(player)
			await _frames(14.0, 1.4, "pour")
		"chase":
			# Seen by an archive guard with the lamp lit: he levels his ji,
			# comes on and thrusts.
			Game.new_game()
			await Game.level_ready
			Dialogue.stop()
			var player := get_tree().get_first_node_in_group(&"player") as Player
			Game.set_flag(&"guards_hostile")
			Quest.start_at(&"find_liang")
			player.inventory.take_lamp(90.0, true)
			var guard := Game.level.get_node("Guards/ArchiveGuard1") as Guard
			var fwd := -guard.global_basis.z
			fwd.y = 0.0
			player.global_position = guard.global_position + fwd.normalized() * 9.0 + Vector3.UP * 0.1
			player.look_at_point(guard.global_position + Vector3.UP * 2.0, 0.01)
			await _frames(9.0, 0.45, "chase")
		"climb":
			# Hands on a ladder, then crawling along a passage.
			Game.new_game()
			await Game.level_ready
			Dialogue.stop()
			var player := get_tree().get_first_node_in_group(&"player") as Player
			player.inventory.take_lamp(90.0, true)
			player.inventory.add(&"chisel")
			player.inventory.select(0)
			var ladder := Game.level.get_node("Mechanism/Ladder1") as Node3D
			var foot := (ladder.get_node("Bottom") as Node3D).global_position
			player.global_position = foot + ladder.global_basis.z * 0.8 + Vector3.UP * 0.1
			player.look_at_point(foot + Vector3.UP * 2.6, 0.01)
			await get_tree().create_timer(0.5).timeout
			ladder.call(&"_on_used", player)
			Input.action_press(&"move_forward")
			await _frames(2.4, 0.2, "climb")
			Input.action_release(&"move_forward")
			player.exit_ladder()
			player.global_position = Vector3(27.5, -8.5, -20.0)
			player.rotation.y = PI
			player._set_stance(Player.Stance.CRAWL, true)
			await get_tree().create_timer(0.6).timeout
			Input.action_press(&"move_forward")
			await _frames(1.6, 0.2, "crawl")
			Input.action_release(&"move_forward")
		"ending":
			Game.new_game()
			await Game.level_ready
			Dialogue.stop()
			var player := get_tree().get_first_node_in_group(&"player") as Player
			Game.set_flag(&"guards_hostile")
			Game.set_flag(&"has_evidence")
			Game.set_flag(&"gave_lamp")
			for id in [&"gong_jiang", &"xianyang_yi", &"gong_shui"]:
				Game.set_flag(NamesDB.flag(id))
			Quest.start_at(&"escape")
			player.inventory.take_lamp(90.0, true)
			player.global_position = Vector3(-1.75, 7.6, 146.0)
			player.rotation.y = PI
			await get_tree().create_timer(1.0).timeout
			Game.level.get_node("Atmosphere").call(&"snap")
			await _shot("corridor")
			Input.action_press(&"move_forward")
			await _frames(9.0, 1.0, "walk")
			Input.action_release(&"move_forward")
			await _frames(100.0, 2.0, "end")
	Game._delete_save()
	get_tree().quit()
