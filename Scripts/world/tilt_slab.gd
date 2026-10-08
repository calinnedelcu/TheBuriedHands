@tool
class_name TiltSlab
extends Node3D
## One stone of a trapped floor laid over a pit, like its neighbours to the
## eye: only a pin through its axle would hold it, and the builders left the
## pin out. Weighed, it tips and drops whoever stood on it onto the spikes
## below, then swings back level to wait for the next. Pinned (the floor's
## lock) or held (its brake), it holds like any stone. A shard thrown on it
## tips it too, and falls in.
##
## The origin is the middle of the stone's top, over the middle of the pit;
## it tips on its -x edge.

const GRIND := preload("res://audio/sfx/tunnel/stones_falling.mp3")
const CLUNK := preload("res://audio/sfx/impacts/impactPlank_medium_000.ogg")

@export var size := 1.5:
	set(v):
		size = maxf(v, 0.5)
		if is_node_ready():
			_build()
@export var stone_seed := 0:
	set(v):
		stone_seed = v
		if is_node_ready():
			_build()
## The builders' pin is in: it holds for good.
@export var pinned := false

## The floor's brake keeps it level while someone holds it.
var held := false
var _tipping := false
var _pivot: Node3D
var _shape: CollisionShape3D

func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(&"persistent")
	var trigger := Area3D.new()
	trigger.name = "Trigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 2 | 8
	trigger.monitorable = false
	var ts := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size - 0.3, 0.8, size - 0.3)
	ts.shape = box
	ts.position.y = 0.4
	trigger.add_child(ts)
	add_child(trigger)
	trigger.body_entered.connect(_on_body_entered)

func _build() -> void:
	for c in get_children():
		if c.has_meta(&"generated"):
			c.free()
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.set_meta(&"generated", true)
	_pivot.position = Vector3(-size * 0.5, 0.0, 0.0)
	add_child(_pivot)
	# The stone: one of the workshop's flagstones, as the floor around it.
	var slabs := Masonry.stones("floor")
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var stone := MeshInstance3D.new()
	stone.name = "Stone"
	var thick := 0.24
	var dims := Vector3(size - 0.04, thick, size - 0.04)
	if slabs.is_empty():
		stone.mesh = Masonry.box()
		stone.scale = dims
	else:
		var pick: Array = slabs[rng.randi() % slabs.size()]
		stone.mesh = pick[0]
		stone.scale = dims / (pick[1] as Vector3)
	stone.material_override = TrapField.FLOOR_MATERIALS[rng.randi() % TrapField.FLOOR_MATERIALS.size()]
	stone.position = Vector3(size * 0.5, -thick * 0.5, 0.0)
	_pivot.add_child(stone)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size - 0.04, thick, size - 0.04)
	_shape.shape = box
	_shape.position = Vector3(size * 0.5, -thick * 0.5, 0.0)
	body.add_child(_shape)
	_pivot.add_child(body)

func holds() -> bool:
	return pinned or held

func _on_body_entered(body: Node3D) -> void:
	# Co-op: the host feels the weight; the other machine is told.
	if holds() or _tipping or Net.is_client():
		return
	if not (body is Player or body is RigidBody3D):
		return
	Net.mirror(self, &"net_tip")
	net_tip()

func net_tip() -> void:
	if _tipping:
		return
	_tipping = true
	_shape.set_deferred(&"disabled", true)
	Sfx.play_at(CLUNK, global_position, 2.0, 0.08, &"Tomb", 25.0)
	Sfx.play_at(GRIND, global_position, -2.0, 0.1, &"Tomb", 30.0)
	Stealth.make_noise(global_position, 14.0, self)
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:z", deg_to_rad(-78.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(2.6)
	tween.tween_property(_pivot, "rotation:z", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		_shape.disabled = false
		_tipping = false)

func pin() -> void:
	pinned = true

func persist_save() -> Dictionary:
	return {"pinned": pinned}

func persist_load(data: Dictionary) -> void:
	pinned = bool(data.get("pinned", pinned))
