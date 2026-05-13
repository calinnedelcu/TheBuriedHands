extends Node3D

@export_range(0.5, 10.0, 0.1) var seconds_per_animation: float = 3.0
@export var show_label: bool = false
@export var label_offset: Vector3 = Vector3(0.0, 0.92, 0.0)
@export var move_with_animation: bool = true
@export_range(0.0, 4.0, 0.05) var preview_move_speed: float = 0.8
@export_range(0.5, 20.0, 0.5) var preview_move_span: float = 6.0

var _animation_player: AnimationPlayer
var _animations := PackedStringArray()
var _current_index := 0
var _time_left := 0.0
var _label: Label3D
var _start_position := Vector3.ZERO
var _move_direction := Vector3.FORWARD


func _ready() -> void:
	_start_position = global_position
	_move_direction = -global_transform.basis.z.normalized()

	_animation_player = _find_animation_player(self)
	if _animation_player == null:
		push_warning("%s has no AnimationPlayer for preview." % name)
		return

	_animations = _animation_player.get_animation_list()
	if _animations.is_empty():
		push_warning("%s has no imported animations for preview." % name)
		return

	if show_label:
		_create_label()

	_play_current_animation()


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

	if _label != null:
		_label.text = "Ucenic: %s\n%d / %d" % [
			String(animation_name),
			_current_index + 1,
			_animations.size(),
		]

	print("Ucenic animation preview: %s (%d/%d)" % [
		String(animation_name),
		_current_index + 1,
		_animations.size(),
	])


func _create_label() -> void:
	_label = Label3D.new()
	_label.name = "AnimationPreviewLabel"
	_label.position = label_offset
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.font_size = 28
	_label.outline_size = 8
	_label.modulate = Color(0.98, 0.86, 0.58, 1.0)
	add_child(_label)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found

	return null
