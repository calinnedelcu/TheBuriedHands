class_name HeldLamp
extends Node3D
## The oil lamp in the craftsman's left hand: light, oil, flicker.
## Oil burns faster when the holder runs or jumps (the oil sloshes and the
## wick flares) and slower when standing still, so careful movement saves light.

signal oil_changed(oil: float, max_oil: float)
signal lit_changed(lit: bool)

const IGNITE_SOUND := preload("res://audio/sfx/lamp/lamp_light_match.mp3")

@export var max_oil := 100.0
## Oil per second while lit and walking.
@export var base_drain := 0.2
@export var light_energy := 3.4
@export var light_range := 16.0
@export var spot_energy := 2.6
@export var spot_range := 24.0
@export var raised_range_boost := 1.35
@export var raised_energy_boost := 1.3
@export var raised_drain_boost := 1.4
@export var low_oil_fraction := 0.2
@export var relight_seconds := 0.9
## The lights live just in front of the camera, inside the player's capsule,
## instead of at the visual lamp: the visual can poke through a wall when you
## hug it, the light source must not.
@export var light_anchor_offset := Vector3(-0.22, -0.14, -0.2)
@export var raised_anchor_lift := 0.22

@onready var _light: OmniLight3D = $FlameSocket/Light
@onready var _spot: SpotLight3D = $Spot
@onready var _flame: MeshInstance3D = $FlameSocket/Flame
@onready var _hand_light: OmniLight3D = $FlameSocket/HandLight
@onready var _smoke: GPUParticles3D = $FlameSocket/Smoke
@onready var _audio: AudioStreamPlayer = $Audio

var oil := 100.0
var is_lit := true
var is_raised := false
var relighting := false

var _holder: Node = null
var _noise := FastNoiseLite.new()
var _t := 0.0
var _flame_scale := Vector3.ONE
var _raise_blend := 0.0
var _gust := 0.0
var _anchor: Node3D

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.6
	_flame_scale = _flame.scale
	# Co-op: the partner's lamp, seen in their hand, lights from where it is.
	var holder := _holder as Player
	var cam: Camera3D = null
	if holder == null:
		cam = get_viewport().get_camera_3d()
	elif holder.is_local:
		cam = holder.camera
	else:
		_hand_light.visible = false
	if cam != null:
		_anchor = Node3D.new()
		_anchor.name = "LampLightAnchor"
		cam.add_child(_anchor)
		_anchor.position = light_anchor_offset
		_light.reparent(_anchor, false)
		_light.position = Vector3.ZERO
		_spot.reparent(_anchor, false)
		_spot.position = Vector3(0.1, 0.05, 0.0)
	_refresh_visibility()

func _exit_tree() -> void:
	if is_instance_valid(_anchor):
		_anchor.queue_free()

func set_holder(holder: Node) -> void:
	_holder = holder

func fraction() -> float:
	return oil / max_oil if max_oil > 0.0 else 0.0

func is_full() -> bool:
	return oil >= max_oil - 0.01

## Lights the lamp (takes a moment: striking flint on the wick) or snuffs it.
func toggle() -> void:
	if relighting:
		return
	if is_lit:
		snuff()
	elif oil > 0.0:
		_relight()

func snuff() -> void:
	if not is_lit:
		return
	is_lit = false
	_refresh_visibility()
	lit_changed.emit(false)

## Adds oil, returns how much was actually accepted.
func refill(amount: float) -> float:
	var accepted := minf(amount, max_oil - oil)
	if accepted <= 0.0:
		return 0.0
	oil += accepted
	oil_changed.emit(oil, max_oil)
	return accepted

## A draught or a nearby impact makes the flame gutter for a moment.
func gust(strength := 0.6) -> void:
	_gust = maxf(_gust, strength)

func _relight() -> void:
	relighting = true
	_audio.stream = IGNITE_SOUND
	_audio.play()
	await get_tree().create_timer(relight_seconds, false).timeout
	relighting = false
	if oil <= 0.0:
		return
	is_lit = true
	_gust = 1.0
	_refresh_visibility()
	lit_changed.emit(true)

func _process(delta: float) -> void:
	_t += delta
	_raise_blend = move_toward(_raise_blend, 1.0 if is_raised else 0.0, delta * 4.0)
	_gust = maxf(0.0, _gust - delta * 1.5)
	if _anchor != null:
		_anchor.position = light_anchor_offset + Vector3.UP * raised_anchor_lift * _raise_blend
	if not is_lit:
		return
	# The partner's lamp burns on their machine; this copy only shows it.
	if not _is_own():
		_apply_flicker()
		return
	var drain := base_drain * _movement_multiplier() * lerpf(1.0, raised_drain_boost, _raise_blend)
	oil = maxf(0.0, oil - drain * delta)
	oil_changed.emit(oil, max_oil)
	if oil <= 0.0:
		snuff()
		return
	_apply_flicker()

func _is_own() -> bool:
	return not (_holder is Player) or (_holder as Player).is_local

func _movement_multiplier() -> float:
	if _holder == null or not (_holder is Player):
		return 1.0
	var p := _holder as Player
	if not p.is_on_floor() and not p.on_ladder():
		return 2.5
	if p.is_sprinting():
		return 3.2
	if not p.is_moving():
		return 0.35
	match p.stance:
		Player.Stance.CROUCH:
			return 0.7
		Player.Stance.CRAWL:
			return 0.6
	return 1.0

func _apply_flicker() -> void:
	var n := _noise.get_noise_1d(_t * 6.0)
	var low := clampf(fraction() / low_oil_fraction, 0.0, 1.0)  # 1 = healthy, 0 = nearly dry
	var instability := (1.0 - low) * 0.5 + _gust * 0.6
	var strength := lerpf(0.35, 1.0, low) * (1.0 + n * (0.12 + instability))
	var raise_e := lerpf(1.0, raised_energy_boost, _raise_blend)
	var raise_r := lerpf(1.0, raised_range_boost, _raise_blend)
	_light.light_energy = light_energy * strength * raise_e
	_light.omni_range = light_range * lerpf(0.6, 1.0, low) * raise_r * (0.96 + n * 0.04)
	_spot.light_energy = spot_energy * strength * raise_e
	_hand_light.light_energy = 0.32 * strength
	_spot.spot_range = spot_range * lerpf(0.55, 1.0, low) * raise_r
	var s := 1.0 + _noise.get_noise_1d(_t * 9.0 + 50.0) * (0.15 + instability * 0.4)
	_flame.scale = _flame_scale * Vector3(1.0, s, 1.0) * lerpf(0.5, 1.0, low)

func _refresh_visibility() -> void:
	_hand_light.visible = is_lit and _is_own()
	_light.visible = is_lit
	_spot.visible = is_lit
	_flame.visible = is_lit
	_smoke.emitting = is_lit

func set_state(new_oil: float, lit: bool) -> void:
	oil = clampf(new_oil, 0.0, max_oil)
	is_lit = lit and oil > 0.0
	if is_node_ready():
		_refresh_visibility()
	oil_changed.emit(oil, max_oil)
	lit_changed.emit(is_lit)

func persist_state() -> Dictionary:
	return {"oil": oil, "lit": is_lit}
