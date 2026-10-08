@tool
class_name ClimbLadder
extends Node3D
## A climbable ladder from this node's origin (the bottom) up to `top`. Use
## it to grab on; climbing past either end steps off — onto `landing` at the
## top. The grab volume is sized from these, so placing a ladder in a level
## means setting the three values on the instance (instanced scenes don't
## save edits to their inner nodes).

const TIMBER := preload("res://assets/materials/level/timber.tres")

## Top of the climb, in the ladder's own space.
@export var top := Vector3(0.0, 4.0, 0.0):
	set(value):
		top = value
		_layout()
## Where the climber is put after reaching the top, in the ladder's space.
@export var landing := Vector3(0.0, 4.2, -0.9):
	set(value):
		landing = value
		_layout()
## Builds its own timber rails and rungs up to `top` (the jam's ladders
## carry a model of their own instead).
@export var rungs := false:
	set(value):
		rungs = value
		_layout()

@onready var _bottom: Marker3D = $Bottom
@onready var _top: Marker3D = $Top
@onready var _usable: Usable = $Body/Usable

var _climber: Player

func _ready() -> void:
	_layout()
	# The jam ladder's pale flat colour glared white in the lamp a hand's
	# breadth away: the same dark timber as the tunnel props.
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = TIMBER
	if Engine.is_editor_hint():
		return
	_usable.prompt_key = "PROMPT_CLIMB"
	_usable.used.connect(_on_used)

func _layout() -> void:
	if not is_inside_tree() or not has_node("Top"):
		return
	($Top as Node3D).position = top
	($TopLanding as Node3D).position = landing
	var shape := $Body/Shape as CollisionShape3D
	# The grab volume runs from the foot to waist height above the top, so it
	# can be aimed at from the landing as well as from below.
	var h := maxf(top.y, 0.5) + 1.3
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, h, 0.35)
	shape.shape = box
	# Stood a little proud of the rungs, on the climber's side (+Z), so the
	# wall behind the ladder doesn't catch the aim first.
	shape.position = Vector3(top.x * 0.5, h * 0.5, top.z * 0.5 + 0.3)
	_build_rungs()

func _build_rungs() -> void:
	var old := get_node_or_null("Rungs")
	if old != null:
		remove_child(old)
		old.queue_free()
	if not rungs:
		return
	var holder := Node3D.new()
	holder.name = "Rungs"
	add_child(holder)
	var rail := BoxMesh.new()
	rail.size = Vector3(0.09, top.y, 0.09)
	for sx in [-0.3, 0.3]:
		var mi := MeshInstance3D.new()
		mi.mesh = rail
		mi.material_override = TIMBER
		mi.position = Vector3(sx, top.y * 0.5, -0.05)
		holder.add_child(mi)
	var rung := BoxMesh.new()
	rung.size = Vector3(0.62, 0.055, 0.065)
	var y := 0.35
	while y < top.y - 0.1:
		var mi := MeshInstance3D.new()
		mi.mesh = rung
		mi.material_override = TIMBER
		mi.position = Vector3(0.0, y, -0.05)
		holder.add_child(mi)
		y += 0.38

func _on_used(user: Node) -> void:
	var p := user as Player
	if p == null or p.on_ladder():
		return
	_climber = p
	# Snap onto the ladder line at the nearest height, facing the rungs.
	var y := clampf(p.global_position.y, _bottom.global_position.y, _top.global_position.y - 2.5)
	var start_at_top := p.global_position.y > _top.global_position.y - 1.0
	var anchor := _bottom.global_position
	p.global_position = Vector3(anchor.x, (_top.global_position.y - 2.6) if start_at_top else y, anchor.z) + global_basis.z * 0.55
	p.rotation.y = global_rotation.y
	p.enter_ladder(self)

func climber_moved(p: Player) -> void:
	if p.global_position.y >= _top.global_position.y - 0.4:
		p.exit_ladder()
		p.global_position = $TopLanding.global_position
	elif p.global_position.y <= _bottom.global_position.y + 0.05 and Input.is_action_pressed(&"move_backward"):
		p.exit_ladder()
		p.global_position = _bottom.global_position + global_basis.z * 0.9
