class_name Worker
extends Node3D
## An ambient craftsman at work. When the first gate slams shut he stops,
## and after a moment of confusion sinks into despair.

## Key -> clip name, for models whose clips have other names; keys not
## listed are clip names themselves (craftsman.glb: idle, walk, work_seated,
## sculpt, knead, kneel, collapse).
@export var anims: Dictionary = {}
@export var work_anim: StringName = &"work"
@export var after_sealing_anim: StringName = &"kneel"
## Freeze on the last frame of `after_sealing_anim` (e.g. a collapse).
@export var freeze_after := false
## Shows the modelling tool in his hand (craftsman.glb's "Tool") while he works.
@export var holds_tool := false
## One of those who didn't make it: plays `work_anim` once and stays on its
## last frame, deaf to the sealing.
@export var dead := false
## Crossbow bolts in his back.
@export var bolts := 0

## Clips that bring the body down: craftsman.glb keeps the hips at standing
## height in them (only the legs fold and the trunk tips), so the model is
## lowered until its lowest bone lies on the floor, or he kneels in the air.
const LOW_CLIPS := [&"kneel", &"collapse"]
## Bones run inside the limbs: the lowest one stays this far off the floor.
const GROUND_CLEARANCE := 0.07

var _anim: AnimationPlayer
var _working := false
var _last_pos := 0.0
var _model: Node3D
var _skeleton: Skeleton3D
var _model_rest := Vector3.ZERO

## Moments of the work clips (seconds into the loop) that make a sound:
## the tool scraping clay, the clay pressed down on the table.
const WORK_BEATS := {
	&"sculpt": [0.42, 1.42, 2.42, 3.42],
	&"knead": [0.42, 1.21],
}
const SCRAPE := [preload("res://audio/sfx/impacts/cloth1.ogg"), preload("res://audio/sfx/impacts/cloth3.ogg"), preload("res://audio/sfx/impacts/cloth4.ogg")]
const PRESS := [preload("res://audio/sfx/impacts/impactSoft_medium_000.ogg"), preload("res://audio/sfx/impacts/impactSoft_medium_001.ogg")]

func _ready() -> void:
	_anim = _first_anim_player()
	_model = get_node_or_null(^"Model") as Node3D
	if _model != null:
		_model_rest = _model.position
	var skeletons := find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if _anim != null:
		var last := StringName(anims.get(after_sealing_anim, after_sealing_anim))
		for clip in _anim.get_animation_list():
			_anim.get_animation(clip).loop_mode = Animation.LOOP_NONE if (freeze_after and clip == last) else Animation.LOOP_LINEAR
	_show_tool(holds_tool)
	if dead:
		_lie_dead()
		return
	_play(work_anim, true)
	_working = WORK_BEATS.has(StringName(anims.get(work_anim, work_anim)))
	Game.sealing_advanced.connect(_on_sealing)
	if Game.sealing_stage >= 1:
		_working = false
		_play(after_sealing_anim, false)

## The sound of the work, in step with the clip, close by only.
func _process(_delta: float) -> void:
	_ground_pose()
	if not _working or _anim == null or not _anim.is_playing():
		return
	var clip := _anim.current_animation
	var pos := _anim.current_animation_position
	var beats: Array = WORK_BEATS.get(StringName(clip), [])
	for beat in beats:
		var b: float = beat
		var crossed: bool = (_last_pos < b and pos >= b) or (pos < _last_pos and (b > _last_pos or b <= pos))
		if crossed:
			var sounds: Array = SCRAPE if clip == &"sculpt" else PRESS
			Sfx.play_at(sounds.pick_random(), global_position + Vector3.UP * 1.6, -14.0, 0.12, &"Tomb", 13.0, 2.5)
	_last_pos = pos

func _on_sealing(stage: int) -> void:
	if stage != 1:
		return
	await get_tree().create_timer(randf_range(0.3, 1.6), false).timeout
	_working = false
	_play(&"idle", false)
	_show_tool(false)
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

## In a low clip (or blending into one), lowers the model so the lowest bone
## rests on the floor; back up to where it stood in any other.
func _ground_pose() -> void:
	if _model == null or _skeleton == null or _anim == null:
		return
	var clip := StringName(_anim.current_animation if _anim.current_animation != "" else _anim.assigned_animation)
	var low_clip := false
	for k in LOW_CLIPS:
		low_clip = low_clip or clip == StringName(anims.get(k, k))
	if not low_clip:
		if _model.position != _model_rest:
			_model.position = _model_rest
		return
	var xf := _skeleton.global_transform
	var lowest := INF
	for b in _skeleton.get_bone_count():
		# Not the root: it stays on the floor whatever the body does.
		if _skeleton.get_bone_parent(b) >= 0:
			lowest = minf(lowest, (xf * _skeleton.get_bone_global_pose(b)).origin.y)
	var drop := lowest - (global_position.y + GROUND_CLEARANCE)
	if absf(drop) < 0.005:
		return
	var scale_y := maxf(global_basis.get_scale().y, 0.001)
	# Never above where he stands: only down, as far as the pose needs.
	_model.position.y = minf(_model_rest.y, _model.position.y - drop / scale_y)

func _lie_dead() -> void:
	# Bodies don't stand in the way (but what's on them can still be
	# looked at: a strip of bamboo at the belt, a Readable).
	for shape in find_children("*", "CollisionShape3D", true, false):
		if not (shape.get_parent() is Readable):
			(shape as CollisionShape3D).disabled = true
	if _anim != null:
		var n := StringName(anims.get(work_anim, work_anim))
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_NONE
			_anim.play(n)
			_anim.seek(_anim.get_animation(n).length, true)
			_anim.pause()
	var skeletons := find_children("*", "Skeleton3D", true, false)
	if bolts <= 0 or skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone := skeleton.find_bone("Spine02")
	if bone < 0:
		return
	var chest := BoneAttachment3D.new()
	chest.bone_name = "Spine02"
	skeleton.add_child(chest)
	var inv := 1.0 / maxf(skeleton.global_transform.basis.get_scale().x, 0.001)
	# His back, in the chest bone's space (the model faces +x).
	var rest := skeleton.get_bone_global_rest(bone).basis
	var back := (rest.inverse() * Vector3(-1.0, 0.0, 0.0)).normalized()
	var up := (rest.inverse() * Vector3.UP).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i in bolts:
		var dir := (back + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))).normalized()
		var bolt := _bolt()
		chest.add_child(bolt)
		bolt.transform = Transform3D(Basis.looking_at(-dir).scaled(Vector3.ONE * inv), back * 0.04 + up * rng.randf_range(-0.02, 0.05))

## A bronze-tipped bolt, its point buried; the shaft sticks out behind (+z).
func _bolt() -> Node3D:
	var n := Node3D.new()
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.025, 0.025, 0.5)
	shaft.mesh = box
	shaft.position.z = 0.22
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.12)
	shaft.material_override = wood
	n.add_child(shaft)
	var fletch := MeshInstance3D.new()
	var vanes := BoxMesh.new()
	vanes.size = Vector3(0.09, 0.005, 0.12)
	fletch.mesh = vanes
	fletch.position.z = 0.42
	var feather := StandardMaterial3D.new()
	feather.albedo_color = Color(0.55, 0.5, 0.42)
	fletch.material_override = feather
	n.add_child(fletch)
	return n

func _show_tool(on: bool) -> void:
	var tool := find_child("Tool", true, false) as Node3D
	if tool != null:
		tool.visible = on

func _first_anim_player() -> AnimationPlayer:
	var found := find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null
