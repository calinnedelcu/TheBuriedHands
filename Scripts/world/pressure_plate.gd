class_name PressurePlate
extends Node3D
## A stone plate that sinks under weight and fires its linked crossbows.
## Anything heavy enough sets it off — a thrown shard wastes the shot from a
## safe distance. A wooden wedge jammed under it disables it for good.

const CLICK := preload("res://audio/sfx/impacts/impactPlate_light_000.ogg")
const JAM := preload("res://audio/sfx/impacts/impactPlank_medium_000.ogg")

@export var crossbow_paths: Array[NodePath] = []
@export var min_mass := 0.25
@export var fire_delay := 0.12

@onready var _plate: Node3D = $Plate
@onready var _area: Area3D = $Trigger
@onready var _wedge: Node3D = $Wedge
@onready var _usable: DelegateUsable = $Body/Usable

var jammed := false
var _rest_y := 0.0
var _pressed := false

func _ready() -> void:
	add_to_group(&"persistent")
	_rest_y = _plate.position.y
	_area.collision_layer = 0
	_area.collision_mask = 2 | 8
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_usable.hold_time = 1.4
	_wedge.visible = jammed

func _on_body_entered(body: Node3D) -> void:
	if jammed or _pressed:
		return
	if body is RigidBody3D and (body as RigidBody3D).mass < min_mass:
		return
	if not (body is Player or body is RigidBody3D):
		return
	_pressed = true
	var tween := create_tween()
	tween.tween_property(_plate, "position:y", _rest_y - 0.05, 0.08)
	Sfx.play_at(CLICK, global_position, -2.0, 0.05, &"Tomb", 20.0)
	await get_tree().create_timer(fire_delay, false).timeout
	for path in crossbow_paths:
		var cb := get_node_or_null(path)
		if cb != null and cb.has_method(&"fire"):
			cb.call(&"fire")

func _on_body_exited(_body: Node3D) -> void:
	if _area.get_overlapping_bodies().is_empty():
		_pressed = false
		create_tween().tween_property(_plate, "position:y", _rest_y, 0.3)

# --- Usable delegate: jam it --------------------------------------------------------

func usable_prompt(user: Node) -> String:
	var p := user as Player
	if jammed or p == null or not p.inventory.has_item(&"wedge"):
		return ""
	return tr("PROMPT_JAM_PLATE")

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	return not jammed and p != null and p.inventory.has_item(&"wedge")

func usable_hold_done(user: Node) -> void:
	var p := user as Player
	if p == null or not p.inventory.remove(&"wedge"):
		return
	jammed = true
	_wedge.visible = true
	Sfx.play_at(JAM, global_position, -2.0)
	p.viewmodel.call(&"play_use")

func persist_save() -> Dictionary:
	return {"jammed": jammed}

func persist_load(data: Dictionary) -> void:
	jammed = bool(data.get("jammed", false))
	_wedge.visible = jammed
