class_name CollapsingTile
extends Node3D
## A floor slab over a spike pit, marked with a faint Qin seal. It cracks a
## moment after you step on it, then drops away. Heavy thrown objects set it
## off too, which is how a careful player finds them.

const CRACK := preload("res://audio/sfx/trap/spinopel-ceramic-tile-411505.mp3")
const BREAK := preload("res://audio/sfx/trap/spinopel-break-the-ceramic-tiles-411504.mp3")

@export var crack_delay := 0.45

@onready var _slab: Node3D = $Slab
@onready var _collision: CollisionShape3D = $Slab/Collision
@onready var _area: Area3D = $Trigger

var broken := false
var _triggered := false

func _ready() -> void:
	add_to_group(&"persistent")
	_area.collision_layer = 0
	_area.collision_mask = 2 | 8
	_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if broken or _triggered:
		return
	if body is RigidBody3D and (body as RigidBody3D).mass < 1.0:
		return
	_triggered = true
	Sfx.play_at(CRACK, global_position, 0.0, 0.05, &"Tomb", 25.0)
	var tween := create_tween()
	for i in 6:
		tween.tween_property(_slab, "position", Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03)), crack_delay / 6.0)
	tween.tween_callback(_break)

func _break() -> void:
	broken = true
	Sfx.play_at(BREAK, global_position, 2.0, 0.05, &"Tomb", 35.0)
	Stealth.make_noise(global_position, 16.0, self)
	_collision.set_deferred(&"disabled", true)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(_slab, "position:y", -9.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(_slab, "rotation", Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), 0.7)

func persist_save() -> Dictionary:
	return {"broken": broken}

func persist_load(data: Dictionary) -> void:
	broken = bool(data.get("broken", false))
	if broken:
		_triggered = true
		_slab.visible = false
		_collision.disabled = true
