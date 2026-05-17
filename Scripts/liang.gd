class_name Liang
extends Node3D

@export var sitting_anim: StringName = &"NlaTrack.001_Armature"
@export var surprised_anim: StringName = &"NlaTrack.002_Armature"
@export var frustrated_anim: StringName = &"NlaTrack_Armature"
@export var y_offset: float = 0.0
@export var lock_vertical_motion: bool = true

var _animation_player: AnimationPlayer = null
var _base_position_y: float = 0.0
var _armature_node: Node3D = null
var _base_armature_y: float = 0.0
var _skeleton_node: Skeleton3D = null
var _base_skeleton_y: float = 0.0

func _ready() -> void:
	_base_position_y = position.y
	_armature_node = get_node_or_null("Armature") as Node3D
	if _armature_node != null:
		_base_armature_y = _armature_node.position.y
	_skeleton_node = _find_skeleton()
	if _skeleton_node != null:
		_base_skeleton_y = _skeleton_node.position.y
	_animation_player = _find_animation_player(self)
	if _animation_player == null:
		push_warning("[Liang] no AnimationPlayer found")
		return
	_lock_root_y()
	set_process(lock_vertical_motion)
	set_physics_process(lock_vertical_motion)
	play_sitting()

func _process(_delta: float) -> void:
	_restore_vertical_baseline()

func _physics_process(_delta: float) -> void:
	_restore_vertical_baseline()

func play_sitting() -> void:
	_play_anim(sitting_anim)

func play_surprised() -> void:
	_play_anim(surprised_anim)

func play_frustrated() -> void:
	_play_anim(frustrated_anim)

func get_animation_player() -> AnimationPlayer:
	return _animation_player

func _play_anim(name: StringName) -> void:
	if _animation_player == null:
		return
	if not _animation_player.has_animation(name):
		push_warning("[Liang] missing animation: " + String(name))
		return
	var anim := _animation_player.get_animation(name)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	_lock_root_y()
	_animation_player.play(name)
	_restore_vertical_baseline()

func _restore_vertical_baseline() -> void:
	if not lock_vertical_motion:
		return
	position.y = _base_position_y
	if _armature_node != null and is_instance_valid(_armature_node):
		_armature_node.position.y = _base_armature_y
	if _skeleton_node != null and is_instance_valid(_skeleton_node):
		_skeleton_node.position.y = _base_skeleton_y

func _lock_root_y() -> void:
	var skel := _skeleton_node if _skeleton_node != null and is_instance_valid(_skeleton_node) else _find_skeleton()
	if skel == null:
		return
	var root_bones := _find_root_bones(skel)
	if root_bones.is_empty():
		return
	for anim_name in _animation_player.get_animation_list():
		var anim := _animation_player.get_animation(anim_name)
		if anim == null:
			continue
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				var tp := str(anim.track_get_path(i))
				for bone_name in root_bones:
					if _track_targets_bone(tp, bone_name):
						var rest_y := skel.get_bone_rest(skel.find_bone(bone_name)).origin.y + y_offset
						for k in anim.track_get_key_count(i):
							var val := anim.track_get_key_value(i, k) as Vector3
							val.y = rest_y
							anim.track_set_key_value(i, k, val)
						break

func _find_root_bones(skel: Skeleton3D) -> Array[String]:
	var result: Array[String] = []
	for preferred in [&"Root", &"Hip", &"Hips", &"Pelvis", &"Waist"]:
		var idx := skel.find_bone(preferred)
		if idx >= 0:
			result.append(String(preferred))
	for i in skel.get_bone_count():
		var bone_name := skel.get_bone_name(i)
		var lower := bone_name.to_lower()
		if lower == "hip" or lower.contains("root") or lower.contains("hips") or lower.contains("pelvis"):
			if not result.has(bone_name):
				result.append(bone_name)
	return result

func _track_targets_bone(track_path: String, bone_name: String) -> bool:
	var lower_path := track_path.to_lower()
	var lower_bone := bone_name.to_lower()
	return lower_path.ends_with(":" + lower_bone) or lower_path.contains(":" + lower_bone + "/")

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_skeleton() -> Skeleton3D:
	for child in get_children():
		if child is Skeleton3D:
			return child
		for sub in child.get_children():
			if sub is Skeleton3D:
				return sub
	return null
