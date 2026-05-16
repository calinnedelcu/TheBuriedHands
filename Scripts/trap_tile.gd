class_name TrapTile
extends StaticBody3D

@export var crack_delay: float = 0.2
@export var player_group: String = "player"
@export var shake_intensity: float = 0.025
@export var crack_stream: AudioStream
@export var break_stream: AudioStream
@export var settle_stream: AudioStream

@onready var _tile_collision: CollisionShape3D = $TileCollision
@onready var _tile_visual: Node3D = $TileMesh
@onready var _center_area: Area3D = $CenterArea
@onready var _break_particles: GPUParticles3D = $BreakParticles
@onready var _audio: AudioStreamPlayer3D = $Audio

var _triggered: bool = false
var _origin_pos: Vector3

func _ready() -> void:
	_origin_pos = position
	_center_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group(player_group):
		return
	_triggered = true
	_start_cracking()

func _start_cracking() -> void:
	if crack_stream != null:
		_audio.stream = crack_stream
		_audio.play()

	var tween := create_tween()
	var steps := 8
	for i in steps:
		var offset := Vector3(
			randf_range(-shake_intensity, shake_intensity),
			0.0,
			randf_range(-shake_intensity, shake_intensity)
		)
		tween.tween_property(self, "position", _origin_pos + offset, crack_delay / steps)
	tween.tween_property(self, "position", _origin_pos, 0.02)
	tween.tween_callback(_break_tile)

func _break_tile() -> void:
	_tile_collision.set_deferred("disabled", true)
	_tile_visual.hide()

	if break_stream != null:
		_audio.stream = break_stream
		_audio.play()

	_break_particles.emitting = true

	if settle_stream != null:
		_play_settle_delayed()

func _play_settle_delayed() -> void:
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self):
		return
	_audio.stream = settle_stream
	_audio.play()
