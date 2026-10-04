class_name Worker
extends Node3D
## An ambient craftsman at work. When the first gate slams shut he stops,
## and after a moment of confusion sinks into despair.

@export var anims: Dictionary = {}
@export var work_anim: StringName = &"work"
@export var after_sealing_anim: StringName = &"kneel"
## Freeze on the last frame of `after_sealing_anim` (e.g. a collapse).
@export var freeze_after := false

var _anim: AnimationPlayer

func _ready() -> void:
	_anim = _first_anim_player()
	for key in anims:
		var n := StringName(anims[key])
		if _anim != null and _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_NONE if (freeze_after and key == after_sealing_anim) else Animation.LOOP_LINEAR
	_play(work_anim, true)
	Game.sealing_advanced.connect(_on_sealing)
	if Game.sealing_stage >= 1:
		_play(after_sealing_anim, false)

func _on_sealing(stage: int) -> void:
	if stage != 1:
		return
	await get_tree().create_timer(randf_range(0.3, 1.6), false).timeout
	_play(&"idle", false)
	await get_tree().create_timer(randf_range(2.0, 4.0), false).timeout
	_play(after_sealing_anim, false)

func _play(key: StringName, random_start: bool) -> void:
	if _anim == null:
		return
	var n := StringName(anims.get(key, key))
	if not _anim.has_animation(n):
		return
	_anim.play(n, 0.4)
	if random_start:
		_anim.seek(randf() * _anim.get_animation(n).length, true)

func _first_anim_player() -> AnimationPlayer:
	var found := find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null
