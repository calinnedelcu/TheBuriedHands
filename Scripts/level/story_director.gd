class_name StoryDirector
extends Node
## Story beats that don't belong to a single object: the craftsman's opening
## thoughts on a new game, and the second gate slamming shut somewhere behind
## him once the counterweight drops.

const BOOM := preload("res://audio/sfx/tunnel/rock_cinematic.mp3")

func _ready() -> void:
	Game.level_ready.connect(_on_level_ready, CONNECT_ONE_SHOT)
	Game.sealing_advanced.connect(_on_sealing)

func _on_level_ready(_level: Node) -> void:
	if not Quest.is_at(&"talk_apprentice") or Game.get_flag(&"intro_done"):
		return
	Game.set_flag(&"intro_done")
	await get_tree().create_timer(1.6, false).timeout
	Dialogue.play(&"intro", Dialogue.Priority.HINT)

func _on_sealing(stage: int) -> void:
	if stage != 2:
		return
	# Let "It's moving!" land before the ground answers.
	while Dialogue.is_busy():
		await Dialogue.sequence_finished
	await get_tree().create_timer(2.2, false).timeout
	Sfx.play_ui(BOOM, 1.0)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.add_shake(0.8)
	for lamp in get_tree().get_nodes_in_group(&"wall_lamps"):
		lamp.call(&"gust")
	await get_tree().create_timer(1.4, false).timeout
	Dialogue.play(&"sealing_second")
