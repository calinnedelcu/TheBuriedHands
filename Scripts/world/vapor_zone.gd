class_name VaporZone
extends Area3D
## Mercury fumes. Inside the area the player breathes a base intensity, rising
## toward the sources (Marker3D children named "Source*"). The player's breath
## holding and damp cloth are handled by the player.

@export_range(0.0, 1.0) var ambient := 0.25
@export var source_radius := 9.0
@export var source_peak := 1.0

var _player: Player
var _sources: Array[Node3D] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	for c in get_children():
		if c is Marker3D:
			_sources.append(c)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var intensity := ambient
	var p := _player.chest_position()
	for s in _sources:
		var d := s.global_position.distance_to(p)
		intensity = maxf(intensity, source_peak * pow(clampf(1.0 - d / source_radius, 0.0, 1.0), 1.6))
	_player.add_vapor(intensity)

## Lets scripted moments make the air worse (e.g. after the counterweight drops).
func set_ambient(value: float) -> void:
	ambient = value
