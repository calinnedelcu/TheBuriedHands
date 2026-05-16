class_name Liang
extends Node3D

@export var sitting_anim: StringName = &"NlaTrack.001_Armature"
@export var surprised_anim: StringName = &"NlaTrack.002_Armature"
@export var frustrated_anim: StringName = &"NlaTrack_Armature"
@export var y_offset: float = 0.0

var _animation_player: AnimationPlayer = null

func _ready() -> void:
	_animation_player = _find_animation_player(self)
	if _animation_player == null:
		push_warning("[Liang] no AnimationPlayer found")
		return
	_lock_root_y()
	play_sitting()

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
	_animation_player.play(name)

func _lock_root_y() -> void:
	var skel := _find_skeleton()
	if skel == null:
		return
	var bone_name := "Root"
	var bone_idx := skel.find_bone(bone_name)
	if bone_idx < 0:
		bone_name = "Hips"
		bone_idx = skel.find_bone(bone_name)
	if bone_idx < 0:
		return
	var rest_y := skel.get_bone_rest(bone_idx).origin.y + y_offset
	for anim_name in _animation_player.get_animation_list():
		var anim := _animation_player.get_animation(anim_name)
		if anim == null:
			continue
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				var tp := str(anim.track_get_path(i))
				if tp.ends_with(":" + bone_name):
					for k in anim.track_get_key_count(i):
						var val := anim.track_get_key_value(i, k) as Vector3
						val.y = rest_y
						anim.track_set_key_value(i, k, val)
					return

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
