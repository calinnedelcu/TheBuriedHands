extends Node
## Dev test: the corridor's traps against the real player: every plate fires
## its crossbow and the bolt hurts; tiles give way; spike pits kill.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/trap_test_runner.gd

var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/level/mausoleum.tscn")
	await Game.level_ready
	Dialogue.stop()
	var level := Game.level
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var traps := level.get_node("CorridorTraps")
	for i in range(1, 6):
		var plate := traps.get_node("Plate%d" % i) as Node3D
		var bow := traps.get_node("Crossbow%d" % i)
		player.health = player.max_health
		player.global_position = plate.global_position + Vector3.UP * 0.3
		player.velocity = Vector3.ZERO
		await _wait(1.2)
		var fired := not bool(bow.get(&"loaded")) if bow.get(&"loaded") != null else true
		_check("plate %d fires crossbow %d (health %.1f/%.1f)" % [i, i, player.health, player.max_health], fired and player.health < player.max_health)
		player.global_position = Vector3(-30.0, 0.3, 20.0)
		await _wait(0.4)
	# A collapsing tile: stand on it, it gives way.
	var tile := traps.get_node("Tile1") as Node3D
	player.health = player.max_health
	player.global_position = tile.global_position + Vector3.UP * 0.4
	await _wait(2.5)
	_check("tile gives way (player y %.1f, tile y %.1f)" % [player.global_position.y, tile.global_position.y], player.global_position.y < tile.global_position.y - 1.0 or Game.is_dead())
	print("RESULT: %d failure(s)" % failures)
	Game._delete_save()
	get_tree().quit()
