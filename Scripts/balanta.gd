extends Node3D

@export var animation_name: String = "Balanta"

var _anim: AnimationPlayer = null

func _ready() -> void:
	add_to_group("mercury_flow")
	_anim = _find_anim_player()

func start_flow() -> void:
	if _anim == null:
		return
	if _anim.has_animation(animation_name):
		_anim.play(animation_name)
	else:
		var anims := _anim.get_animation_list()
		if not anims.is_empty():
			_anim.play(anims[0])

func stop_flow() -> void:
	if _anim != null and _anim.is_playing():
		_anim.stop()

func _find_anim_player() -> AnimationPlayer:
	for child in get_children():
		var ap := child.get_node_or_null("AnimationPlayer")
		if ap is AnimationPlayer:
			return ap as AnimationPlayer
	return get_node_or_null("AnimationPlayer")
