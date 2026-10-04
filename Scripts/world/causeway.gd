class_name Causeway
extends Node3D
## A stone causeway lying under the mercury of the balance pit. When the
## counterweight drops, it rises to the platforms — the way on to the
## treasury. Opened through the counterweight's gate list: open(animate).

const GRIND := preload("res://audio/sfx/mechanisms/ancient_mechanical_gears.mp3")
const SETTLE := preload("res://audio/sfx/tunnel/rock_cinematic.mp3")

## How far it rises, and how long that takes.
@export var rise := 5.8
@export var rise_seconds := 6.5

@onready var _slab: Node3D = $Slab

var raised := false
var _low := Vector3.ZERO

func _ready() -> void:
	add_to_group(&"persistent")
	_low = _slab.position
	_apply()

func open(animate := true) -> void:
	if raised:
		return
	raised = true
	if not animate:
		_apply()
		return
	Sfx.play_at(GRIND, global_position, 4.0, 0.0, &"Tomb", 60.0)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_slab, "position", _low + Vector3.UP * rise, rise_seconds)
	t.tween_callback(func():
		Sfx.play_at(SETTLE, global_position, -2.0, 0.1, &"Tomb", 50.0)
		var p := get_tree().get_first_node_in_group(&"player") as Player
		if p != null and p.global_position.distance_to(global_position) < 30.0:
			p.add_shake(0.35))

func _apply() -> void:
	_slab.position = _low + (Vector3.UP * rise if raised else Vector3.ZERO)

func persist_save() -> Dictionary:
	return {"raised": raised}

func persist_load(data: Dictionary) -> void:
	raised = bool(data.get("raised", false))
	_apply()
