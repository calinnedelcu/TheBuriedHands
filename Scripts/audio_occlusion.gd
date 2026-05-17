extends AudioStreamPlayer3D

## Atenueaza volumul cand un perete sta intre emitter si camera player-ului.
## Foloseste un raycast periodic (check_interval) si tweens volumul intre
## valoarea de baza (cand vede player-ul) si valoarea atenuata (cand e blocat).

@export var occlusion_volume_drop_db: float = 18.0
@export var check_interval: float = 0.18
@export var fade_speed: float = 3.0
## Layer-ul de coliziune al peretilor (1 = layer 1, default Godot).
@export_flags_3d_physics var wall_mask: int = 1

var _base_volume: float
var _target_volume: float
var _timer: float = 0.0
var _camera: Camera3D = null
var _occluded: bool = false

func _ready() -> void:
	_base_volume = volume_db
	_target_volume = _base_volume

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = check_interval
	_update_occlusion()

func _process(delta: float) -> void:
	if is_equal_approx(volume_db, _target_volume):
		return
	var t: float = clampf(delta * fade_speed, 0.0, 1.0)
	volume_db = lerpf(volume_db, _target_volume, t)

func _ensure_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		return
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		var cam := p.get_node_or_null("CameraPivot/Camera3D") as Camera3D
		if cam != null:
			_camera = cam
			return

func _update_occlusion() -> void:
	_ensure_camera()
	if _camera == null:
		return
	var from: Vector3 = global_position
	var to: Vector3 = _camera.global_position
	if from.distance_squared_to(to) < 0.01:
		return
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, wall_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)
	var now_occluded: bool = not result.is_empty()
	if now_occluded == _occluded:
		return
	_occluded = now_occluded
	_target_volume = _base_volume - occlusion_volume_drop_db if _occluded else _base_volume
