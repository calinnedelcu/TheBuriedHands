class_name HeldTorch
extends Node3D
## A torch carried in a hand bone (this node's parent). Flames burn upward,
## so it stays upright whatever the arm does, held a little away from the
## body, and leans back when the carrier moves.

## Where the fist is, in the parent bone's space.
@export var grip_offset := Vector3.ZERO
## Held this far out to the carrier's side (metres), clear of the arm.
@export var side_out := 0.16
## The world is built at ~1.75x human scale; so is the torch.
@export var size := 1.7

var _carrier: Node3D
var _last := Vector3.ZERO
var _lean := Vector2.ZERO

func _ready() -> void:
	_carrier = _find_carrier()
	_last = global_position

func _process(delta: float) -> void:
	var hand := (get_parent() as Node3D).global_transform * grip_offset
	if _carrier != null:
		hand += _carrier.global_basis.x.normalized() * side_out
	var v := (hand - _last) / maxf(delta, 0.001)
	_last = hand
	var target := Vector2(clampf(-v.z * 0.04, -0.3, 0.3), clampf(v.x * 0.04, -0.3, 0.3))
	_lean = _lean.lerp(target, 1.0 - exp(-delta * 5.0))
	global_transform = Transform3D(Basis.from_euler(Vector3(_lean.x, 0.0, _lean.y)).scaled(Vector3.ONE * size), hand)

func _find_carrier() -> Node3D:
	var n := get_parent()
	while n != null and not (n is CharacterBody3D):
		n = n.get_parent()
	return n as Node3D
