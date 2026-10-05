class_name DistantEchoes
extends Node
## After the sealing, now and then, from somewhere else in the dark: others
## pounding on stone, a tool ringing on a bronze gate, the mountain settling.
## Heard through rock (muffled, from far off), never close, never twice the
## same in a row; silent once the craftsman is out in the drain.

const SOUNDS := {
	&"pounding": ["res://audio/ambience/echoes/pounding_0.wav", "res://audio/ambience/echoes/pounding_1.wav",
			"res://audio/ambience/echoes/pounding_2.wav", "res://audio/ambience/echoes/pounding_3.wav"],
	&"gate": ["res://audio/ambience/echoes/gate_struck_0.wav", "res://audio/ambience/echoes/gate_struck_1.wav"],
	&"settling": ["res://audio/ambience/echoes/settling.wav"],
}
## kind -> [weight, volume dB]
const KINDS := {
	&"pounding": [0.6, -3.0],
	&"gate": [0.25, -5.0],
	&"settling": [0.15, -15.0],
}

@export var first_delay := 55.0
@export var min_gap := 30.0
@export var max_gap := 75.0
@export var distance := 30.0
## From this quest step on the tomb is behind him.
@export var silent_from: StringName = &"crawl_out"

var _timer := -1.0
var _last := ""
var _player: AudioStreamPlayer3D

func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.bus = &"Tomb"
	_player.unit_size = 14.0
	_player.max_distance = 70.0
	_player.attenuation_filter_cutoff_hz = 1500.0
	_player.attenuation_filter_db = -18.0
	add_child(_player)
	Game.sealing_advanced.connect(func(stage: int):
		if stage == 1:
			_timer = first_delay)
	Game.level_ready.connect(func(_l):
		if Game.sealing_stage >= 1:
			_timer = randf_range(min_gap, max_gap) * 0.5)

func _process(delta: float) -> void:
	if _timer < 0.0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if Game.is_over() or Quest.has_reached(silent_from):
		_timer = -1.0
		return
	if Dialogue.is_busy():
		_timer = 4.0
		return
	_timer = randf_range(min_gap, max_gap)
	_play_one()

func _play_one() -> void:
	var listener := get_viewport().get_camera_3d()
	if listener == null:
		return
	var kind := _pick_kind()
	var choices: Array = SOUNDS[kind].filter(func(p): return p != _last)
	if choices.is_empty():
		# The only sound of its kind just played: something else this time.
		kind = &"pounding"
		choices = SOUNDS[kind]
	var path: String = choices.pick_random()
	_last = path
	var angle := randf() * TAU
	_player.global_position = listener.global_position + Vector3(cos(angle), randf_range(-0.2, 0.15), sin(angle)) * distance
	_player.stream = load(path)
	_player.volume_db = float(KINDS[kind][1]) + randf_range(-2.0, 1.0)
	_player.pitch_scale = randf_range(0.9, 1.06)
	_player.play()

func _pick_kind() -> StringName:
	var r := randf()
	for kind in KINDS:
		r -= float(KINDS[kind][0])
		if r <= 0.0:
			return kind
	return &"pounding"
