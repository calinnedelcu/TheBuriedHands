extends Node
## Dev test: a checkpoint keeps the story, flags, taken pickups, the lamp and
## the player's place; dying and retrying restores them; "Continue" from the
## menu restores them from the save file too.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/checkpoint_test_runner.gd

var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player

func _run() -> void:
	Game.new_game()
	await Game.level_ready
	await _wait(0.5)
	Dialogue.stop()
	var player := _player()
	# Somewhere in Act II: past the sealing, register in the satchel, a lamp.
	Quest.start_at(&"find_liang")
	Game.set_flag(&"guards_hostile")
	Game.advance_sealing(1)
	var register := Game.level.get_node("Register") as Pickup
	# Beside the register (on Wei's desk): let him come down to the floor.
	player.global_position = register.global_position + Vector3(1.0, 0.0, 1.0)
	await _wait(0.3)
	var t := 0.0
	while not player.is_on_floor() and t < 3.0:
		await _wait(0.1)
		t += 0.1
	await _wait(0.3)
	register.get_node("Usable").call(&"use", player)
	player.inventory.take_lamp(42.0, true)
	var spot := player.global_position
	Game.request_checkpoint(&"find_liang")
	await Game.checkpoint_saved
	_check("save file written", Game.has_save())

	# Change things after the checkpoint, then die.
	Quest.start_at(&"talk_liang")
	player.global_position += Vector3(5, 0, 0)
	player.kill("DEATH_GUARD")
	await _wait(0.5)
	_check("death reported", Game.is_dead())
	get_tree().paused = false
	Game.retry_from_checkpoint()
	await Game.level_ready
	await _wait(0.5)
	_verify(spot, "retry")

	# Back to the menu and Continue.
	Game.return_to_menu()
	await _wait(2.5)
	_check("menu shown (%s)" % get_tree().current_scene.name, get_tree().current_scene.name == "Title")
	Game.continue_game()
	await Game.level_ready
	await _wait(0.5)
	_verify(spot, "continue")
	print("RESULT: %d failure(s)" % failures)
	# Don't leave a test save behind for the real game's Continue button.
	Game._delete_save()
	get_tree().quit()

func _verify(spot: Vector3, how: String) -> void:
	var player := _player()
	_check("%s: quest back at find_liang (%s)" % [how, Quest.current()], Quest.is_at(&"find_liang"))
	_check("%s: evidence flag kept" % how, Game.get_flag(&"has_evidence"))
	_check("%s: guards still hostile" % how, Game.get_flag(&"guards_hostile"))
	_check("%s: register in satchel" % how, player.inventory.has_item(&"register"))
	var register := Game.level.get_node("Register") as Pickup
	_check("%s: register gone from the shelf" % how, register.taken and not register.visible)
	var lamp := player.inventory.lamp()
	_check("%s: lamp with its oil (%s)" % [how, "none" if lamp == null else "%.0f" % lamp.oil], lamp != null and absf(lamp.oil - 42.0) < 3.0)
	_check("%s: player where the checkpoint was (%.1f m off)" % [how, player.global_position.distance_to(spot)], player.global_position.distance_to(spot) < 1.0)
	_check("%s: alive" % how, not Game.is_dead() and player.health > 0.0)
