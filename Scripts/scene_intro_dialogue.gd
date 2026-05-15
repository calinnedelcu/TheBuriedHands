extends Node

@export var play_on_ready: bool = true
@export var start_delay: float = 0.8
@export var dialogue_lines: PackedStringArray = []
@export var dialogue_line_duration: float = 6.5

func _ready() -> void:
	if play_on_ready:
		call_deferred("_play_intro")

func _play_intro() -> void:
	if dialogue_lines.is_empty():
		return
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	var events := get_node_or_null("/root/GameEvents")
	if events == null or not events.has_method("show_dialogue"):
		return
	for line in dialogue_lines:
		events.show_dialogue(str(line), dialogue_line_duration)
		if dialogue_line_duration > 0.0:
			await get_tree().create_timer(dialogue_line_duration).timeout
