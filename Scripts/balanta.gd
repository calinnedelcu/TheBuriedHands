extends Node3D

@export var animation_name: String = "Animation"
@export var blend_time: float = 0.08
@export var playback_duration: float = 8.0
@export var mechanism_stream: AudioStream
@export var mechanism_volume_db: float = 14.0
@export var mechanism_max_distance: float = 90.0
@export var mechanism_unit_size: float = 24.0
@export var create_complex_collision: bool = true
@export var disable_complex_collision_while_animating: bool = true
@export var rebuild_complex_collision_after_animation: bool = true
@export_flags_3d_physics var collision_layer: int = 1
@export_flags_3d_physics var collision_mask: int = 1

var _anim: AnimationPlayer = null
var _audio: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("mercury_flow")
	_anim = _find_anim_player()
	if _anim != null:
		_anim.animation_finished.connect(_on_animation_finished)
	_audio = _get_or_create_audio()
	if mechanism_stream != null:
		_audio.stream = mechanism_stream
	_audio.volume_db = mechanism_volume_db
	_audio.bus = &"Tomb"
	_audio.max_distance = mechanism_max_distance
	_audio.unit_size = mechanism_unit_size
	if create_complex_collision:
		_create_complex_collision()

func start_flow() -> void:
	if _anim == null:
		return
	var resolved_name: StringName = _resolve_animation_name()
	if resolved_name == &"":
		return
	_anim.stop()
	var speed: float = _playback_speed_for(resolved_name)
	if disable_complex_collision_while_animating:
		_set_complex_collision_enabled(false)
	_anim.play(resolved_name, blend_time, speed)
	if _audio != null and _audio.stream != null:
		_audio.stop()
		_audio.play()

func stop_flow() -> void:
	if _anim != null and _anim.is_playing():
		if rebuild_complex_collision_after_animation:
			_anim.seek(_anim.current_animation_length, true)
		_anim.stop()
	if _audio != null and _audio.playing:
		_audio.stop()
	if rebuild_complex_collision_after_animation:
		_rebuild_complex_collision()
	elif disable_complex_collision_while_animating:
		_set_complex_collision_enabled(true)

func _resolve_animation_name() -> StringName:
	if _anim.has_animation(animation_name):
		return StringName(animation_name)
	var anims: PackedStringArray = _anim.get_animation_list()
	if anims.is_empty():
		return &""
	return StringName(anims[0])

func _playback_speed_for(anim_name: StringName) -> float:
	if playback_duration <= 0.0:
		return 1.0
	var animation: Animation = _anim.get_animation(anim_name)
	if animation == null or animation.length <= 0.0:
		return 1.0
	return animation.length / playback_duration

func _on_animation_finished(_anim_name: StringName) -> void:
	if _anim != null:
		_anim.seek(_anim.current_animation_length, true)
	if _audio != null and _audio.playing:
		_audio.stop()
	if rebuild_complex_collision_after_animation:
		_rebuild_complex_collision()
	elif disable_complex_collision_while_animating:
		_set_complex_collision_enabled(true)

func _get_or_create_audio() -> AudioStreamPlayer3D:
	var existing: Node = get_node_or_null("MechanismAudio")
	if existing is AudioStreamPlayer3D:
		return existing as AudioStreamPlayer3D
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "MechanismAudio"
	add_child(player)
	return player

func _create_complex_collision() -> void:
	if has_node("ComplexCollision"):
		return
	var root_body: Node3D = Node3D.new()
	root_body.name = "ComplexCollision"
	add_child(root_body)

	for mesh_instance: MeshInstance3D in _find_mesh_instances(self):
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		var shape: Shape3D = mesh.create_trimesh_shape()
		if shape == null:
			continue

		var static_body: StaticBody3D = StaticBody3D.new()
		static_body.name = "%sCollision" % mesh_instance.name
		static_body.collision_layer = collision_layer
		static_body.collision_mask = collision_mask
		root_body.add_child(static_body)
		static_body.global_transform = mesh_instance.global_transform

		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.name = "Shape"
		collider.shape = shape
		static_body.add_child(collider)

func _rebuild_complex_collision() -> void:
	var existing: Node = get_node_or_null("ComplexCollision")
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	_finish_rebuild_complex_collision()

func _finish_rebuild_complex_collision() -> void:
	_create_complex_collision()
	_set_complex_collision_enabled(true)

func _set_complex_collision_enabled(enabled: bool) -> void:
	var root_body: Node = get_node_or_null("ComplexCollision")
	if root_body == null:
		return
	root_body.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	var pending: Array[Node] = [root_body]
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		if node is StaticBody3D:
			(node as StaticBody3D).collision_layer = collision_layer if enabled else 0
			(node as StaticBody3D).collision_mask = collision_mask if enabled else 0
		elif node is CollisionShape3D:
			(node as CollisionShape3D).disabled = not enabled
		for child: Node in node.get_children():
			pending.append(child)

func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		if node is MeshInstance3D:
			meshes.append(node as MeshInstance3D)
		for child: Node in node.get_children():
			pending.append(child)
	return meshes

func _find_anim_player() -> AnimationPlayer:
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		if node is AnimationPlayer:
			return node as AnimationPlayer
		for child: Node in node.get_children():
			pending.append(child)
	return null
