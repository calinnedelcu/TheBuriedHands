extends Node3D

@export var flow_stream: AudioStream
@export var auto_stop_after: float = 8.0
@export var flow_volume_db: float = -8.0

@export_group("Particle Shape")
@export var force_faucet_arc_settings: bool = true
@export var faucet_direction: Vector3 = Vector3(0.0, -0.32, -1.0)
@export var faucet_spread: float = 10.0
@export var faucet_gravity: Vector3 = Vector3(0.0, -4.8, 0.0)
@export var faucet_lifetime: float = 1.25
@export var faucet_velocity_min: float = 0.95
@export var faucet_velocity_max: float = 1.85
@export var faucet_angular_velocity_min: float = -35.0
@export var faucet_angular_velocity_max: float = 35.0
@export var faucet_scale_min: float = 0.17
@export var faucet_scale_max: float = 0.33

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
	_apply_faucet_particle_settings()
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
		_apply_faucet_particle_settings()
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

func _apply_faucet_particle_settings() -> void:
	if not force_faucet_arc_settings or _particles == null:
		return
	_particles.lifetime = faucet_lifetime
	_particles.direction = faucet_direction
	_particles.spread = faucet_spread
	_particles.gravity = faucet_gravity
	_particles.initial_velocity_min = faucet_velocity_min
	_particles.initial_velocity_max = faucet_velocity_max
	_particles.angular_velocity_min = faucet_angular_velocity_min
	_particles.angular_velocity_max = faucet_angular_velocity_max
	_particles.scale_amount_min = faucet_scale_min
	_particles.scale_amount_max = faucet_scale_max
