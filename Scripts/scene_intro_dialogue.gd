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
		await get_tree().create_timer(start_delay).timeout
	var events := get_node_or_null("/root/GameEvents")
	if events == null or not events.has_method("show_dialogue"):
		return
	for line in lines:
		events.show_dialogue(str(line), dialogue_line_duration)
		if dialogue_line_duration > 0.0:
			await get_tree().create_timer(dialogue_line_duration).timeout
	if events.has_method("notify_intro_finished"):
		events.call("notify_intro_finished")
