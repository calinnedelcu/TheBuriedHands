extends Node
## Fire-and-forget sound effects. 3D sounds come from a small pool of players
## parked under this autoload (they share the main World3D with the level).

const POOL_SIZE := 24

var _pool: Array[AudioStreamPlayer3D] = []
var _ui_player: AudioStreamPlayer
var _next := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.name = "Sfx3D_%d" % i
		p.attenuation_filter_cutoff_hz = 6000.0
		add_child(p)
		_pool.append(p)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = &"SFX"
	_ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_player)

## Plays `stream` at a world position. `pitch_jitter` randomises pitch +/- that amount.
func play_at(stream: AudioStream, position: Vector3, volume_db := 0.0, pitch_jitter := 0.06, bus := &"SFX", max_distance := 30.0, unit_size := 6.0) -> void:
	if stream == null:
		return
	var p := _take_player()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = unit_size
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.global_position = position
	p.play()

## Picks one stream from `streams` and plays it at `position`.
func play_random_at(streams: Array, position: Vector3, volume_db := 0.0, pitch_jitter := 0.06, bus := &"SFX", max_distance := 30.0) -> void:
	if streams.is_empty():
		return
	play_at(streams.pick_random(), position, volume_db, pitch_jitter, bus, max_distance)

func play_ui(stream: AudioStream, volume_db := -6.0) -> void:
	if stream == null:
		return
	_ui_player.stream = stream
	_ui_player.volume_db = volume_db
	_ui_player.play()

func _take_player() -> AudioStreamPlayer3D:
	# Prefer an idle player; otherwise steal the oldest one round-robin.
	for i in POOL_SIZE:
		var idx := (_next + i) % POOL_SIZE
		if not _pool[idx].playing:
			_next = (idx + 1) % POOL_SIZE
			return _pool[idx]
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stop()
	return p
