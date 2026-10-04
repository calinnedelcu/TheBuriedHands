extends Node
## Dev test: guard patrol, light-based sight, darkness, noise and attack in
## the test room. Run through run.gd with --runner=this --out=/dir.

var _out := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	_run.call_deferred()

func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/dev/test_room.tscn")
	for i in 10:
		await get_tree().process_frame
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var guard := get_tree().get_first_node_in_group(&"guards") as Guard
	_check("guard exists", guard != null)
	var g0 := guard.global_position
	await _wait(4.0)
	_check("guard patrols (moved %.1fm)" % g0.distance_to(guard.global_position), g0.distance_to(guard.global_position) > 3.0)
	_check("not hostile before the sealing: state=%s" % Guard.State.keys()[guard.state], guard.state == Guard.State.PATROL)

	Game.set_flag(&"guards_hostile", true)
	# Darkness, crouched, 9 m in front of the guard: should stay unseen.
	player.inventory.take_lamp(80.0, false)
	player._set_stance(Player.Stance.CROUCH, true)
	_place_in_front(player, guard, 9.0)
	await _wait(3.0)
	_check("unseen in darkness (awareness %.2f, state %s)" % [guard.awareness, Guard.State.keys()[guard.state]], guard.awareness < 0.2)
	await _shot("guard_01_dark")

	# Light the lamp: should be spotted.
	player.inventory.lamp().set_state(80.0, true)
	await _wait(2.5)
	_check("spotted with lamp lit (awareness %.2f, state %s)" % [guard.awareness, Guard.State.keys()[guard.state]], guard.state in [Guard.State.CHASE, Guard.State.ATTACK])
	await _shot("guard_02_spotted")
	var hp0 := player.health
	await _wait(3.0)
	_check("guard attacks (health %.1f -> %.1f)" % [hp0, player.health], player.health < hp0)

	# Reset: guard calm, player hidden far away; a thrown pot lands near the guard.
	player.inventory.lamp().snuff()
	player.global_position = Vector3(-12, 0.1, 12)
	player.health = player.max_health
	guard.awareness = 0.0
	guard._set_state(Guard.State.RETURN)
	await _wait(1.0)
	Stealth.make_noise(guard.global_position + Vector3(4, 0, 0), 14.0, null)
	await _wait(0.3)
	_check("noise makes guard investigate (state %s)" % Guard.State.keys()[guard.state], guard.state in [Guard.State.SUSPICIOUS, Guard.State.INVESTIGATE])
	print("DONE")
	get_tree().quit()

func _place_in_front(player: Player, guard: Guard, dist: float) -> void:
	var fwd := -guard.global_basis.z
	fwd.y = 0.0
	player.global_position = guard.global_position + fwd.normalized() * dist + Vector3.UP * 0.1
	var to := guard.global_position - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

func _shot(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
