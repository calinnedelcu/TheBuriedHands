class_name DrainCrawl
extends Node3D
## The drainage channel out of the treasury. Too low to stand: crawl in and
## push through the tight bend (press the use key a few times). Once through,
## the channel collapses behind you — there is only forward.

const SQUEEZE := preload("res://audio/sfx/tunnel/squeeze_effort.mp3")
const GRAVEL := preload("res://audio/sfx/tunnel/gravel_slide.mp3")
const RUMBLE := preload("res://audio/sfx/tunnel/rock_cinematic.mp3")
const STONES := preload("res://audio/sfx/tunnel/stones_falling.mp3")

@export var pushes_needed := 6
@export var usable_path: NodePath = ^"EntryBody/Usable"
@export var gap_shape_path: NodePath = ^"PassageGate/CollisionShape3D"
@export var behind_path: NodePath = ^"ExitTrigger"
@export var rubble_path: NodePath = ^"CollapseBlocker/Rocks"
@export var rubble_shape_path: NodePath = ^"CollapseBlocker/RockReentryCollider"

@onready var _usable: DelegateUsable = get_node(usable_path)
@onready var _gap_blocker: CollisionShape3D = get_node(gap_shape_path)
@onready var _behind: Area3D = get_node(behind_path)
@onready var _rubble: Node3D = get_node(rubble_path)
@onready var _rubble_blocker: CollisionShape3D = get_node(rubble_shape_path)

var pushes := 0
var opened := false
var collapsed := false
## Co-op: who has made it past the bend (it holds until both have).
var _through: Array[StringName] = []

func _ready() -> void:
	add_to_group(&"persistent")
	_behind.collision_layer = 0
	_behind.collision_mask = 2
	_behind.body_entered.connect(_on_behind)
	_apply()

func usable_prompt(user: Node) -> String:
	if opened:
		return ""
	var p := user as Player
	# Co-op: the bend is too tight for the master's shoulders.
	if Net.active and p != null and p.role == &"master":
		return tr("PROMPT_DRAIN_TOO_TIGHT")
	if p != null and not p.is_crawling():
		return tr("PROMPT_MUST_CRAWL")
	return "%s  (%d)" % [tr("PROMPT_PUSH"), pushes_needed - pushes]

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	if Net.active and p != null and p.role == &"master":
		return false
	return not opened and p != null and p.is_crawling()

func usable_show_blocked(_user: Node) -> bool:
	return not opened

func usable_use(user: Node) -> void:
	var p := user as Player
	pushes += 1
	Sfx.play_at(SQUEEZE, p.global_position, -4.0, 0.08)
	p.add_shake(0.25)
	if pushes == 1:
		Story.fire(&"find_drain", &"drain_found")
	if pushes >= pushes_needed:
		opened = true
		_gap_blocker.set_deferred(&"disabled", true)
		Sfx.play_at(GRAVEL, global_position, 0.0)
		_try_collapse()

func _on_behind(body: Node3D) -> void:
	if collapsed or not (body is Player) or Net.is_client():
		return
	# Co-op: the channel holds until both of you are through. (Who got here
	# is remembered: the partner's news of the open bend can come after him.)
	if not _through.has(body.name):
		_through.append(body.name)
	_try_collapse()

func _try_collapse() -> void:
	if collapsed or not opened or Net.is_client():
		return
	for p in Net.players():
		if not _through.has(p.name):
			return
	Net.mirror(self, &"net_collapse")
	net_collapse()

func net_collapse() -> void:
	if collapsed:
		return
	collapsed = true
	Sfx.play_at(RUMBLE, global_position, 6.0, 0.0, &"Tomb", 60.0)
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p != null:
		p.add_shake(1.0)
	await get_tree().create_timer(0.35, false).timeout
	Sfx.play_at(STONES, global_position, 4.0)
	_rubble.visible = true
	_rubble_blocker.set_deferred(&"disabled", false)
	var fall := create_tween().set_parallel(true)
	for rock in _rubble.get_children():
		var r := rock as Node3D
		var final := r.position
		r.position += Vector3(0, 3.0, 0)
		fall.tween_property(r, "position", final, randf_range(0.5, 0.9)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await Dialogue.play(&"collapse")
	Quest.complete(&"crawl_out")

func _apply() -> void:
	_gap_blocker.disabled = opened
	_rubble.visible = collapsed
	_rubble_blocker.disabled = not collapsed

func persist_save() -> Dictionary:
	return {"pushes": pushes, "opened": opened, "collapsed": collapsed}

func persist_load(data: Dictionary) -> void:
	pushes = int(data.get("pushes", 0))
	opened = bool(data.get("opened", false))
	collapsed = bool(data.get("collapsed", false))
	_apply()
