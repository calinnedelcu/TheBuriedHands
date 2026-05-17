class_name SqueezeTunnelCollapse
extends Node3D

@export var taps_required: int = 8
@export var require_crawl: bool = true
@export var prompt_needs_crawl: String = "Trebuie să te târăști prin deschizătură"
@export var prompt_squeeze: String = "Împinge-te prin pasaj"
@export var prompt_open: String = "Treci mai departe"
@export var prompt_collapsed: String = "Tunelul este blocat"

@export_group("Camera")
@export var use_camera_focus: bool = true
@export var squeeze_focus_fov: float = 42.0
@export var collapse_focus_fov: float = 36.0
@export var focus_pan_duration: float = 0.45
@export var focus_hold_time: float = 0.5
@export var focus_return_duration: float = 0.4
@export_node_path("Marker3D") var squeeze_focus_path: NodePath = NodePath("SqueezeFocus")
@export_node_path("Marker3D") var collapse_focus_path: NodePath = NodePath("CollapseFocus")

@export_group("Timing")
@export var collapse_delay_after_exit: float = 0.25
@export var gravel_delay: float = 0.12
@export var stones_delay: float = 0.45
@export var rock_fall_duration: float = 0.9
@export var rock_spawn_height: float = 3.2
@export var collision_enable_delay: float = 0.35

@onready var _passage_gate: StaticBody3D = get_node_or_null("PassageGate")
@onready var _passage_gate_shape: CollisionShape3D = get_node_or_null("PassageGate/CollisionShape3D")
@onready var _passage_gate_visual: Node3D = get_node_or_null("PassageGate/GateVisual")
@onready var _exit_trigger: Area3D = get_node_or_null("ExitTrigger")
@onready var _collapse_blocker: StaticBody3D = get_node_or_null("CollapseBlocker")
@onready var _collapse_shape: CollisionShape3D = get_node_or_null("CollapseBlocker/RockReentryCollider")
@onready var _legacy_collapse_shape: CollisionShape3D = get_node_or_null("CollapseBlocker/CollisionShape3D")
@onready var _rocks_root: Node3D = get_node_or_null("CollapseBlocker/Rocks")
@onready var _squeeze_audio: AudioStreamPlayer3D = get_node_or_null("SqueezeAudio")
@onready var _gravel_audio: AudioStreamPlayer3D = get_node_or_null("GravelAudio")
@onready var _stones_audio: AudioStreamPlayer3D = get_node_or_null("StonesAudio")
@onready var _cinematic_audio: AudioStreamPlayer3D = get_node_or_null("CinematicAudio")

var _tap_count: int = 0
var _opened: bool = false
var _collapsed: bool = false
var _rock_final_positions: Dictionary = {}

func _ready() -> void:
	_set_passage_open(false)
	_set_collapse_enabled(false)
	_cache_rocks()
	if _exit_trigger != null and not _exit_trigger.body_entered.is_connected(_on_exit_body_entered):
		_exit_trigger.body_entered.connect(_on_exit_body_entered)

func get_squeeze_prompt(by: Node) -> String:
	if _collapsed:
		return prompt_collapsed
	if _opened:
		return prompt_open
	if require_crawl and not _is_player_crawling(by):
		return prompt_needs_crawl
	var remaining: int = max(0, taps_required - _tap_count)
	return "%s (%d)" % [prompt_squeeze, remaining]

func can_squeeze_interact(_by: Node) -> bool:
	return not _collapsed and not _opened

func squeeze_tap(by: Node) -> void:
	if _collapsed or _opened:
		return
	if require_crawl and not _is_player_crawling(by):
		return
	if _tap_count == 0:
		_focus_player(by, squeeze_focus_path, squeeze_focus_fov, focus_hold_time)
	_tap_count += 1
	_play_squeeze()
	if _tap_count >= max(1, taps_required):
		_opened = true
		_set_passage_open(true)
		_play_audio(_gravel_audio)

func _on_exit_body_entered(body: Node3D) -> void:
	if _collapsed or not _opened:
		return
	if not body.is_in_group("player"):
		return
	_collapse_after_exit(body)

func _collapse_after_exit(player: Node) -> void:
	_collapsed = true
	_focus_player(player, collapse_focus_path, collapse_focus_fov, 0.75)
	if collapse_delay_after_exit > 0.0:
		await get_tree().create_timer(collapse_delay_after_exit).timeout
	_set_collapse_enabled(true)
	_play_audio(_cinematic_audio)
	if gravel_delay > 0.0:
		await get_tree().create_timer(gravel_delay).timeout
	_play_audio(_gravel_audio)
	if stones_delay > 0.0:
		await get_tree().create_timer(stones_delay).timeout
	_play_audio(_stones_audio)
	_animate_rocks()
	if collision_enable_delay > 0.0:
		await get_tree().create_timer(collision_enable_delay).timeout
	if _collapse_shape != null:
		_collapse_shape.disabled = false

func _set_passage_open(open: bool) -> void:
	if _passage_gate_shape != null:
		_passage_gate_shape.disabled = open
	if _passage_gate_visual != null:
		_passage_gate_visual.visible = false

func _set_collapse_enabled(enabled: bool) -> void:
	if _collapse_blocker != null:
		_collapse_blocker.visible = true
	if _collapse_shape != null:
		_collapse_shape.disabled = true
	if _legacy_collapse_shape != null:
		_legacy_collapse_shape.disabled = true
	if _rocks_root != null:
		_rocks_root.visible = enabled
		_set_visible_recursive(_rocks_root, enabled)

func _cache_rocks() -> void:
	if _rocks_root == null:
		return
	for child in _rocks_root.get_children():
		if child is Node3D:
			var node := child as Node3D
			_rock_final_positions[node] = node.position
			node.position += Vector3(randf_range(-0.28, 0.28), rock_spawn_height + randf_range(0.0, 1.2), randf_range(-0.28, 0.28))

func _animate_rocks() -> void:
	if _rocks_root == null:
		return
	_set_visible_recursive(_rocks_root, true)
	var tween := create_tween()
	tween.set_parallel(true)
	for child in _rocks_root.get_children():
		if child is Node3D and _rock_final_positions.has(child):
			var node := child as Node3D
			var final_position: Vector3 = _rock_final_positions[child]
			tween.tween_property(node, "position", final_position, rock_fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(node, "rotation", node.rotation + Vector3(randf_range(-1.2, 1.2), randf_range(-1.8, 1.8), randf_range(-1.2, 1.2)), rock_fall_duration)

func _focus_player(player: Node, marker_path: NodePath, zoom_fov: float, hold_time: float) -> void:
	if not use_camera_focus or player == null or not player.has_method("play_cinematic_focus"):
		return
	var marker := get_node_or_null(marker_path) as Marker3D
	if marker == null:
		return
	player.call("play_cinematic_focus", marker.global_position, focus_pan_duration, hold_time, zoom_fov, focus_return_duration)

func _is_player_crawling(player: Node) -> bool:
	if player != null and player.has_method("is_crawling"):
		return bool(player.call("is_crawling"))
	return false

func _play_squeeze() -> void:
	if _squeeze_audio == null:
		return
	if _squeeze_audio.playing:
		_squeeze_audio.stop()
	_squeeze_audio.pitch_scale = randf_range(0.94, 1.05)
	_squeeze_audio.play()

func _play_audio(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.play()

func _set_visible_recursive(node: Node, visible: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = visible
	for child in node.get_children():
		_set_visible_recursive(child, visible)
