class_name ClimbLadder
extends Node3D
## A climbable ladder between `Bottom` and `Top` markers. Use it to grab on;
## climbing past either end steps off onto the landing marker.

@onready var _bottom: Marker3D = $Bottom
@onready var _top: Marker3D = $Top
@onready var _usable: Usable = $Body/Usable

var _climber: Player

func _ready() -> void:
	_usable.prompt_key = "PROMPT_CLIMB"
	_usable.used.connect(_on_used)

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
