extends Node
## Dev test: music and ambience follow the zones, the sealing silences the
## workshop, the alert raises the heartbeat. Headless is fine (logic only).
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/music_test_runner.gd

var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _go(player: Player, at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.8).timeout

func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/level/mausoleum.tscn")
	await Game.level_ready
	var player := get_tree().get_first_node_in_group(&"player") as Player
	await get_tree().create_timer(0.8).timeout
	_check("workshop music at start (%s)" % Music.current(), Music.current() == &"workshop")
	_check("tomb ambience (%s)" % Music._ambience_id, Music._ambience_id == &"tomb")
	Game.set_flag(&"guards_hostile")
	await get_tree().create_timer(0.8).timeout
	_check("workshop silent after the sealing (%s)" % Music.current(), Music.current() == &"")
	await _go(player, Vector3(10.0, 0.2, -30.0))
	_check("archives music (%s)" % Music.current(), Music.current() == &"archives")
	await _go(player, Vector3(30.0, -3.0, -30.0))
	_check("tunnels silent (%s)" % Music.current(), Music.current() == &"")
	await _go(player, Vector3(-46.0, 7.9, 70.0))
	_check("mercury music (%s)" % Music.current(), Music.current() == &"mercury")
	_check("mercury ambience (%s)" % Music._ambience_id, Music._ambience_id == &"mercury")
	Stealth.alert_changed.emit(1.0)
	await get_tree().create_timer(1.5).timeout
	_check("heartbeat rises on alert (%.2f)" % Music._tension_level, Music._tension_level > 0.5 and Music._tension.playing)
	# Back to whatever the real guards feel (one may still be searching for us
	# after the walk through the archives).
	Stealth.alert_changed.emit(Stealth.alert_level)
	await get_tree().create_timer(5.0).timeout
	_check("heartbeat follows the guards (%.2f -> %.2f)" % [Music._tension_level, Music._tension_target], absf(Music._tension_level - Music._tension_target) < 0.15)
	print("RESULT: %d failure(s)" % failures)
	get_tree().quit()
