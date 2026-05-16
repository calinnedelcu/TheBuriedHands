extends Node3D

@export var flow_stream: AudioStream
@export var auto_stop_after: float = 8.0

@onready var _audio: AudioStreamPlayer3D = $Audio
@onready var _particles: CPUParticles3D = $FlowParticles

var _anim: AnimationPlayer = null
var _flowing: bool = false
var _flow_timer: float = 0.0

func _ready() -> void:
	add_to_group("mercury_flow")
	if flow_stream != null:
		_audio.stream = flow_stream
	_anim = _find_anim_player()

func _process(delta: float) -> void:
	if not _flowing:
		return
	_flow_timer -= delta
	if _flow_timer <= 0.0:
		stop_flow()

func start_flow() -> void:
	_flowing = true
	_flow_timer = auto_stop_after
	if _particles != null:
		_particles.emitting = true
	if _anim != null:
		var anims := _anim.get_animation_list()
		if not anims.is_empty():
			_anim.play(anims[0])
	if _audio.stream != null and not _audio.playing:
		_audio.play()

func stop_flow() -> void:
	_flowing = false
	if _particles != null:
		_particles.emitting = false
	if _anim != null and _anim.is_playing():
		_anim.stop()
	if _audio.playing:
		_audio.stop()

func _find_anim_player() -> AnimationPlayer:
	for child in get_children():
		var ap := child.get_node_or_null("AnimationPlayer")
		if ap is AnimationPlayer:
			return ap as AnimationPlayer
	return get_node_or_null("AnimationPlayer")
