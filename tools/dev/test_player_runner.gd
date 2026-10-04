extends Node
## Dev test runner (loaded by run.gd once autoloads exist): drives the
## player in the test room with simulated input, checks movement, stances and
## items, and saves screenshots from the player's camera.

var _out := ""
var _player: Player

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/dev/test_room.tscn")
	for i in 10:
		await get_tree().process_frame
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_check("player found", _player != null)
	await _frames(30)
	_check("on floor after settle", _player.is_on_floor())
	var start := _player.global_position

	# Walk forward one second.
	Input.action_press(&"move_forward")
	await _seconds(1.0)
	Input.action_release(&"move_forward")
	await _seconds(0.4)
	var walked := start.distance_to(_player.global_position)
	_check("walked ~3m in 1s (got %.2f)" % walked, walked > 2.0 and walked < 4.5)

	# Sprint.
	var p0 := _player.global_position
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _seconds(1.0)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	await _seconds(0.4)
	_check("sprint faster than walk (%.2f)" % p0.distance_to(_player.global_position), p0.distance_to(_player.global_position) > walked * 1.4)

	# Crouch toggles and stand up.
	_press_key(KEY_CTRL)
	await _seconds(0.6)
	_check("crouching", _player.stance == Player.Stance.CROUCH)
	_check("eye lowered (%.2f)" % _player.head.position.y, _player.head.position.y < 2.0)
	_press_key(KEY_CTRL)
	await _seconds(0.6)
	_check("standing again", _player.stance == Player.Stance.STAND)

	# Items and lamp.
	_player.inventory.take_lamp(80.0, true)
	_player.inventory.add(&"chisel")
	_player.inventory.add(&"ceramic", 3)
	await _seconds(0.8)
	_check("lamp in hand", _player.inventory.lamp() != null and _player.inventory.lamp().is_lit)
	_check("chisel selected", _player.inventory.selected_item() != null and _player.inventory.selected_item().id == &"chisel")
	_player.rotation.y = 0.0
	_player.global_position = Vector3(-6.0, 0.1, -4.0)
	await _seconds(0.8)
	await _shot("01_hands_lamp_chisel")
	_player.inventory.select(1)
	await _seconds(0.6)
	await _shot("02_hands_ceramic")
	_player.inventory.lamp().is_raised = true
	await _seconds(0.6)
	await _shot("03_lamp_raised")
	_player.inventory.lamp().is_raised = false

	# Look at the lamp stand: prompt should show.
	_player.global_position = Vector3(-5.2, 0.1, -5.5)
	_player.rotation.y = 0.0
	await _seconds(0.1)
	await _player.look_at_point(Vector3(-5.2, 2.0, -8.0), 0.01)
	await _seconds(0.5)
	_check("interactor targets lamp stand", _player.interactor.target != null)
	await _shot("04_prompt_lamp_stand")

	# Crawl under the low tunnel.
	_player.global_position = Vector3(-9.0, 0.1, 10.5)
	_player.rotation.y = 0.0
	await _seconds(0.3)
	_press_key(KEY_Z)
	await _seconds(0.8)
	_check("crawling", _player.stance == Player.Stance.CRAWL)
	Input.action_press(&"move_forward")
	await _seconds(4.0)
	Input.action_release(&"move_forward")
	_check("crawled under slab (z=%.2f)" % _player.global_position.z, _player.global_position.z < 7.0)
	_press_key(KEY_Z)
	await _seconds(0.5)
	_check("can't stand under slab", _player.stance == Player.Stance.CRAWL)
	await _shot("05_crawl_tunnel")

	# Stairs (stand up first: the crawl test leaves us crawling).
	_player.force_stand()
	_player.global_position = Vector3(8.0, 0.1, -1.5)
	_player.rotation.y = 0.0
	await _seconds(0.3)
	Input.action_press(&"move_forward")
	await _seconds(3.5)
	Input.action_release(&"move_forward")
	_check("climbed stairs (y=%.2f)" % _player.global_position.y, _player.global_position.y > 1.6)

	# Visibility: lamp lit vs snuffed in a dark corner.
	_player.global_position = Vector3(12.0, 0.1, 12.0)
	await _seconds(0.5)
	var lit_vis := Stealth.player_visibility
	_player.inventory.lamp().snuff()
	await _seconds(0.5)
	var dark_vis := Stealth.player_visibility
	_check("lamp raises visibility (%.2f -> %.2f)" % [lit_vis, dark_vis], lit_vis > dark_vis + 0.3)
	print("DONE")
	get_tree().quit()

func _press_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event.call_deferred(up)

func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _shot(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
