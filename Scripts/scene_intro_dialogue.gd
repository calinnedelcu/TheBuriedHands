extends Node

@export var play_on_ready: bool = true
@export var start_delay: float = 0.8
@export var dialogue_lines: PackedStringArray = []
@export var dialogue_line_duration: float = 6.5

## Fallback played when `dialogue_lines` is left empty in the scene. Keeps the
## opening monologue alive even if a Godot editor save strips the .tscn array.
const DEFAULT_LINES := [
	"Meșteșugar: Împăratul Qin Shi Huang a murit deja de câteva săptămâni, iar noi încă muncim la armata lui de teracotă...",
	"Meșteșugar: E aproape gata. Doar câteva statui și terminăm.",
]

func _ready() -> void:
	if play_on_ready:
		call_deferred("_play_intro")

func _play_intro() -> void:
	var lines: PackedStringArray = dialogue_lines
	if lines.is_empty():
		lines = PackedStringArray(DEFAULT_LINES)
	if lines.is_empty():
		return
	if start_delay > 0.0:
		await _dialogue_wait(start_delay)
	var events := get_node_or_null("/root/GameEvents")
	if events == null or not events.has_method("show_dialogue"):
		return
	for line in lines:
		events.show_dialogue(str(line), dialogue_line_duration)
		if dialogue_line_duration > 0.0:
			await _dialogue_wait(dialogue_line_duration)
	if events.has_method("notify_intro_finished"):
		events.call("notify_intro_finished")

func _dialogue_wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var t0 := Time.get_ticks_msec()
	var dur_ms := seconds * 1000.0
	while Time.get_ticks_msec() - t0 < dur_ms:
		var events_node := get_node_or_null("/root/GameEvents")
		if events_node != null and events_node.has_method("is_dialogue_skip_pending") and events_node.call("is_dialogue_skip_pending"):
			if events_node.has_method("consume_dialogue_skip"):
				events_node.call("consume_dialogue_skip")
			return
		await get_tree().process_frame
