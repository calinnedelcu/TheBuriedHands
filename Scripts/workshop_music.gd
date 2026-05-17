extends AudioStreamPlayer3D

@export var target_volume_db: float = -14.0
@export var occluded_volume_db: float = -40.0
@export var fade_duration: float = 5.0
@export var occlusion_smoothing: float = 3.0
@export var use_occlusion: bool = true

var _player: Node3D = null
var _occlusion_factor: float = 0.0
var _fade_done: bool = false

func _ready() -> void:
	if stream == null:
		return
	bus = &"Music"
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	volume_db = -48.0
	play()
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(self, "volume_db", target_volume_db, fade_duration)
	t.tween_callback(func(): _fade_done = true)

func _process(delta: float) -> void:
	if not _fade_done:
		return
	if not use_occlusion:
		volume_db = target_volume_db
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var blocked := _is_path_blocked()
	var target_occ := 1.0 if blocked else 0.0
	_occlusion_factor = lerpf(_occlusion_factor, target_occ, clampf(delta * occlusion_smoothing, 0.0, 1.0))
	var db := lerpf(target_volume_db, occluded_volume_db, _occlusion_factor)
	volume_db = db

func _is_path_blocked() -> bool:
	if _player == null:
		return false
	var from := global_position
	var to := _player.global_position + Vector3.UP * 0.8
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = []
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return false
	var hit_node: Node = hit.get("collider")
	var n := hit_node
	while n != null:
		if n == _player:
			return false
		n = n.get_parent()
	return true
