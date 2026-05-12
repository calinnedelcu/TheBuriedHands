extends Node3D

@export var animation_name: StringName = &""
@export var randomize_start_time: bool = true


func _ready() -> void:
	var animation_player := _find_animation_player(self)
	if animation_player == null:
		return

	var animations := animation_player.get_animation_list()
	if animations.is_empty():
		return

	var selected_animation := animation_name
	if selected_animation == &"" or not animation_player.has_animation(selected_animation):
		selected_animation = animations[0]

	var animation := animation_player.get_animation(selected_animation)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR

	animation_player.play(selected_animation)

	if randomize_start_time and animation != null and animation.length > 0.01:
		animation_player.seek(randf_range(0.0, animation.length), true)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found

	return null
