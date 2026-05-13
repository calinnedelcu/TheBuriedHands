extends Node3D

@export var speed: float = 18.0
@export var lifetime: float = 1.5

var _t: float = 0.0

func _process(delta: float) -> void:
	translate(Vector3(0, 0, -speed * delta))
	_t += delta
	if _t >= lifetime:
		queue_free()
