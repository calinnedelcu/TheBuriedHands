class_name Npc
extends Node3D
## A character you can talk to. Plays its idle animation, turns toward the
## player while speaking, and follows per-line animation hints from the
## dialogue ({"anim": &"talk"}). Talking can advance the quest.
##
## Animations are given as logical names in `anims` (e.g. {"idle": "NlaTrack_004_Armature"}).

signal talked

@export var speaker_id: StringName = &"apprentice"
@export var anims: Dictionary = {}
@export var idle_anim: StringName = &"idle"
@export var face_player := true
## Which way the model looks at yaw 0, in degrees from -Z (Tripo models face +X: -90).
@export var model_forward_deg := -90.0

@export_group("Talk")
@export var dialogue: StringName = &""
## Talking is available only while the quest is at this step (empty = never).
@export var talk_step: StringName = &""
@export var completes_step: StringName = &""
@export var sets_flag: StringName = &""
@export var prompt_key := "PROMPT_TALK"

@onready var _usable: DelegateUsable = get_node_or_null("TalkBody/Usable")

var _anim: AnimationPlayer
var _current: StringName = &""
var _base_yaw := 0.0
var _talking := false
var _turn_tween: Tween

func _ready() -> void:
	_anim = _first_anim_player()
	for key in anims:
		var n := StringName(anims[key])
		if _anim != null and _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_base_yaw = rotation.y
	play(idle_anim)
	if _usable != null:
		_usable.prompt_key = prompt_key
	Dialogue.line_started.connect(_on_line_started)
	Dialogue.sequence_finished.connect(_on_sequence_finished)

func play(key: StringName, blend := 0.3) -> void:
	if _anim == null:
		return
	var n := StringName(anims.get(key, key))
	if n == _current or not _anim.has_animation(n):
		return
	_current = n
	_anim.play(n, blend)
	# Desynchronise identical idles between characters.
	if key == idle_anim:
		_anim.seek(randf() * _anim.current_animation_length, true)

func usable_prompt(_user: Node) -> String:
	return tr(prompt_key)

func usable_can_use(_user: Node) -> bool:
	return talk_step != &"" and Quest.is_at(talk_step) and not _talking and dialogue != &""

func usable_use(user: Node) -> void:
	talk(user as Player)

## Plays this character's dialogue with the player.
func talk(player: Player) -> void:
	if _talking:
		return
	_talking = true
	if face_player and player != null:
		_turn_toward(player.global_position)
	if player != null:
		player.lock_controls(&"talk", false)
		player.look_at_point(global_position + Vector3.UP * 2.4, 0.5)
	await Dialogue.play(dialogue)
	if player != null:
		player.unlock_controls(&"talk")
	_talking = false
	_turn_back()
	play(idle_anim)
	talked.emit()
	Story.fire(completes_step, &"", sets_flag)

func _on_line_started(speaker: StringName, _name: String, _text: String, _duration: float, extras: Dictionary) -> void:
	if speaker != speaker_id:
		return
	play(StringName(extras.get("anim", &"talk")))

func _on_sequence_finished(_id: StringName) -> void:
	if not _talking:
		play(idle_anim)

func _turn_toward(point: Vector3) -> void:
	var to := point - global_position
	var yaw := atan2(-to.x, -to.z) - deg_to_rad(model_forward_deg)
	_turn(rotation.y + wrapf(yaw - rotation.y, -PI, PI))

func _turn_back() -> void:
	_turn(_base_yaw)

func _turn(target_yaw: float) -> void:
	if _turn_tween != null:
		_turn_tween.kill()
	_turn_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn_tween.tween_property(self, "rotation:y", target_yaw, 0.5)

func _first_anim_player() -> AnimationPlayer:
	var found := find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null
