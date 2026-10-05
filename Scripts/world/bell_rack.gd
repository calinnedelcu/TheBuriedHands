class_name BellRack
extends Node3D
## A rack of bronze bells (bianzhong). Striking it rings the next note of an
## old pentatonic air, loud enough for any guard in the hall to hear.

const BELL := preload("res://audio/sfx/treasure/bell.wav")
## Pitches of the seven bells (relative to the recorded one), largest first.
const SCALE := [0.75, 0.84, 1.0, 1.125, 1.25, 1.5, 1.68]
## Which bell rings on each strike: a short tune that loops.
const TUNE := [2, 3, 4, 3, 2, 1, 2, 4, 5, 4, 2]

@export var noise_radius := 24.0

var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _rest := 0.0

func _ready() -> void:
	for i in 3:
		var p := AudioStreamPlayer3D.new()
		p.stream = BELL
		p.bus = &"SFX"
		p.unit_size = 8.0
		p.max_distance = 70.0
		p.position = Vector3(0.0, 1.6, 0.0)
		add_child(p)
		_players.append(p)

func _process(delta: float) -> void:
	_rest = maxf(0.0, _rest - delta)

func usable_prompt(_user: Node) -> String:
	return tr("PROMPT_STRIKE_BELLS")

func usable_can_use(_user: Node) -> bool:
	return _rest <= 0.0

func usable_use(user: Node) -> void:
	_rest = 0.35
	var bell: int = TUNE[_next % TUNE.size()]
	_next += 1
	var p := _players[_next % _players.size()]
	p.pitch_scale = SCALE[bell]
	p.volume_db = 2.0
	p.play()
	Stealth.make_noise(global_position, noise_radius, user)
