extends Node3D

@export_range(0.5, 10.0, 0.1) var seconds_per_animation: float = 3.0
@export var show_label: bool = false
@export var label_prefix: String = ""
@export var label_offset: Vector3 = Vector3(0.0, 0.92, 0.0)
@export var move_with_animation: bool = true
@export_range(0.0, 4.0, 0.05) var preview_move_speed: float = 0.8
@export_range(0.5, 20.0, 0.5) var preview_move_span: float = 6.0
@export var animation_name: String = ""
@export var lock_y_position: bool = true
@export var y_offset: float = 0.0

var _animation_player: AnimationPlayer
var _animations := PackedStringArray()
var _current_index := 0
var _time_left := 0.0
var _label: Label3D
var _start_position := Vector3.ZERO
var _locked_y: float
var _move_direction := Vector3.FORWARD


func _ready() -> void:
	_start_position = global_position
	_locked_y = global_position.y
	_move_direction = -global_transform.basis.z.normalized()

	_animation_player = _find_animation_player(self)
	if _animation_player == null:
		push_warning("%s has no AnimationPlayer for preview." % name)
		return

	_animations = _animation_player.get_animation_list()
	if _animations.is_empty():
		push_warning("%s has no imported animations for preview." % name)
		return

	if animation_name != "" and _animations.has(animation_name):
		_animations = PackedStringArray([animation_name])

	if lock_y_position:
		_lock_root_y()

	if show_label:
		_create_label()

	_play_current_animation()

func _lock_root_y() -> void:
	var skel := _find_root_skeleton()
	if not (skel is Skeleton3D):
		return
	var bone_name := "Root"
	var bone_idx := (skel as Skeleton3D).find_bone(bone_name)
	if bone_idx < 0:
		bone_name = "Hips"
		bone_idx = (skel as Skeleton3D).find_bone(bone_name)
	if bone_idx < 0:
		return
	var rest_y := (skel as Skeleton3D).get_bone_rest(bone_idx).origin.y + y_offset
	for anim_name in _animations:
		var anim := _animation_player.get_animation(anim_name)
		if anim == null:
			continue
		var track_count := anim.get_track_count()
		for i in track_count:
			if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				var tp := str(anim.track_get_path(i))
				if tp.ends_with(":" + bone_name):
					for k in anim.track_get_key_count(i):
						var val := anim.track_get_key_value(i, k) as Vector3
						val.y = rest_y
						anim.track_set_key_value(i, k, val)
					print("%s: locked %s Y to %.2f" % [name, bone_name, rest_y])
					return


func _process(delta: float) -> void:
	_update_preview_motion(delta)

	if _animations.size() <= 1:
		return

	_time_left -= delta
	if _time_left <= 0.0:
		_current_index = (_current_index + 1) % _animations.size()
		_play_current_animation()


func _update_preview_motion(delta: float) -> void:
	if not move_with_animation or preview_move_speed <= 0.0:
		return

	global_position += _move_direction * preview_move_speed * delta

	var offset := global_position - _start_position
	if offset.length() >= preview_move_span:
		global_position = _start_position + _move_direction * preview_move_span
		_move_direction = -_move_direction
		look_at(global_position + _move_direction, Vector3.UP)


func _play_current_animation() -> void:
	var animation_name := StringName(_animations[_current_index])
	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR

	_animation_player.play(animation_name)
	_animation_player.seek(0.0, true)
	_time_left = seconds_per_animation

	var display_prefix: String = label_prefix if label_prefix != "" else String(name)
	if _label != null:
		_label.text = "%s: %s\n%d / %d" % [
			display_prefix,
			String(animation_name),
			_current_index + 1,
			_animations.size(),
		]

	print("%s: %s" % [display_prefix, String(animation_name)])


func _create_label() -> void:
	_label = Label3D.new()
	_label.name = "AnimationPreviewLabel"
	_label.position = label_offset
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.font_size = 14
	_label.outline_size = 4
	_label.modulate = Color(0.98, 0.86, 0.58, 1.0)
	_label.pixel_size = 0.005
	add_child(_label)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found

	return null

func _find_root_skeleton() -> Node:
	for child in get_children():
		if child is Skeleton3D:
			return child
		for sub in child.get_children():
			if sub is Skeleton3D:
				return sub
	return null
