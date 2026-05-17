extends Node3D

@export var flow_stream: AudioStream
@export var auto_stop_after: float = 8.0
@export var flow_volume_db: float = -8.0

@export_group("Jet Arc")
@export var jet_gravity: float = -5.5
@export var jet_initial_velocity_min: float = 2.2
@export var jet_initial_velocity_max: float = 3.4
## Unghi de lansare fata de orizontala (90 = drept in sus, 60-75 = fantana clasica).
@export var jet_angle_deg: float = 68.0
@export var jet_spread: float = 12.0
@export var jet_scale_min: float = 0.14
@export var jet_scale_max: float = 0.3

@onready var _audio: AudioStreamPlayer3D = $Audio
@onready var _particles: CPUParticles3D = $FlowParticles

var _anim: AnimationPlayer = null
var _flowing: bool = false
var _flow_timer: float = 0.0

func _ready() -> void:
	add_to_group("mercury_flow")
	if flow_stream != null:
		_audio.stream = flow_stream
	_audio.volume_db = flow_volume_db
	_audio.bus = &"Tomb"
	_anim = _find_anim_player()
	_configure_jet_arc()

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

func _configure_jet_arc() -> void:
	if _particles == null:
		return
	var angle_rad := deg_to_rad(jet_angle_deg)
	_particles.direction = Vector3(0.0, sin(angle_rad), -cos(angle_rad))
	_particles.gravity = Vector3(0.0, jet_gravity, 0.0)
	_particles.initial_velocity_min = jet_initial_velocity_min
	_particles.initial_velocity_max = jet_initial_velocity_max
	_particles.spread = jet_spread
	_particles.scale_amount_min = jet_scale_min
	_particles.scale_amount_max = jet_scale_max
