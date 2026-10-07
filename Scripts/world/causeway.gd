class_name Causeway
extends Node3D
## A stone causeway lying under the mercury of the balance pit. When the
## counterweight drops, it rises to the platforms — the way on to the
## treasury. Opened through the counterweight's gate list: open(animate).
##
## Co-op (`needs_brake`): the balance alone won't hold it up. Once risen it
## sinks back into the mercury unless someone bears on the brake by the
## counterweight (BrakeLever) — until the far end is pinned (CausewayPin).
## So one holds while the other crosses and drops the pin.

const GRIND := preload("res://audio/sfx/mechanisms/ancient_mechanical_gears.mp3")
const SETTLE := preload("res://audio/sfx/tunnel/rock_cinematic.mp3")

## How far it rises, and how long that takes.
@export var rise := 5.8
@export var rise_seconds := 6.5
## Co-op: how long it takes to sink back when nobody holds the brake.
@export var sink_seconds := 9.0

@onready var _slab: Node3D = $Slab

var raised := false
## Co-op: set by the CoopDirector; the brake and the pin decide the rest.
var needs_brake := false
var held := false
var pinned := false
## 0 = down in the mercury, 1 = up at the platforms (co-op only).
var _level := 0.0
var _rising := false
var _moving := false
var _low := Vector3.ZERO
var _audio: AudioStreamPlayer3D

func _ready() -> void:
	add_to_group(&"persistent")
	_low = _slab.position
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = &"Tomb"
	_audio.stream = GRIND
	_audio.unit_size = 12.0
	_audio.max_distance = 60.0
	add_child(_audio)
	_apply()

func open(animate := true) -> void:
	if raised:
		return
	raised = true
	if needs_brake:
		# The pour lifts it once; holding it there is the brake's work.
		_rising = animate
		if not animate:
			_level = 1.0 if pinned else 0.0
			_apply()
		return
	if not animate:
		_apply()
		return
	Sfx.play_at(GRIND, global_position, 4.0, 0.0, &"Tomb", 60.0)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_slab, "position", _low + Vector3.UP * rise, rise_seconds)
	t.tween_callback(_settled)

## Co-op: an open the host made (the dev bots skip the pour this way).
func net_open() -> void:
	open(true)

## Co-op: risen once, and now going back down for want of the brake.
func is_sinking() -> bool:
	return needs_brake and raised and not pinned and not held and not _rising and _level < 0.999

## Fully up and still: the pin can go in.
func is_up() -> bool:
	return raised and (not needs_brake or _level >= 0.999)

func pin() -> void:
	if pinned:
		return
	pinned = true
	_level = 1.0
	_apply()

func _process(delta: float) -> void:
	if not needs_brake or not raised:
		return
	var up := pinned or held or _rising
	var target := 1.0 if up else 0.0
	var rate := 1.0 / (rise_seconds if up else sink_seconds)
	var was := _level
	_level = move_toward(_level, target, rate * delta)
	if _rising and _level >= 1.0:
		_rising = false
	var moving := not is_equal_approx(was, _level)
	if moving and not _moving:
		_audio.volume_db = 2.0
		_audio.play()
	elif not moving and _moving:
		_audio.stop()
		_settled()
	_moving = moving
	_apply()

func _settled() -> void:
	Sfx.play_at(SETTLE, global_position, -2.0, 0.1, &"Tomb", 50.0)
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p != null and p.global_position.distance_to(global_position) < 30.0:
		p.add_shake(0.35)

func _apply() -> void:
	var up := _level if needs_brake else (1.0 if raised else 0.0)
	_slab.position = _low + Vector3.UP * rise * ease(up, -1.6)

func persist_save() -> Dictionary:
	return {"raised": raised, "pinned": pinned}

func persist_load(data: Dictionary) -> void:
	raised = bool(data.get("raised", false))
	pinned = bool(data.get("pinned", false))
	_rising = false
	# Co-op: back from a checkpoint, an unpinned causeway lies sunk again.
	_level = 1.0 if raised and pinned else 0.0
	_apply()
