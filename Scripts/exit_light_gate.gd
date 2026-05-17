class_name ExitLightGate
extends Node3D

@export var player_group: String = "player"
@export_node_path("Area3D") var focus_trigger_path: NodePath = NodePath("FocusTrigger")
@export_node_path("Area3D") var finish_trigger_path: NodePath = NodePath("FinishTrigger")
@export_node_path("Marker3D") var focus_marker_path: NodePath = NodePath("FocusMarker")
@export_node_path("AudioStreamPlayer3D") var ambience_path: NodePath = NodePath("AmbienceAudio")
@export_node_path("OmniLight3D") var bloom_light_path: NodePath = NodePath("BloomLight")

@export_group("Camera")
@export var focus_fov: float = 24.0
@export var focus_pan_duration: float = 1.6
@export var focus_hold_time: float = 1.35
@export var focus_return_duration: float = 0.85

@export_group("Whiteout")
@export var fade_to_white_duration: float = 2.25
@export var white_hold_duration: float = 4.5
@export var ending_id: String = "escape_light"

@export_group("Audio")
@export var ambience_target_volume_db: float = -5.0
@export var ambience_focus_volume_db: float = -14.0
@export var ambience_silent_volume_db: float = -60.0
@export var ambience_fade_delay: float = 0.55
@export var ambience_focus_fade_duration: float = 2.5
@export var ambience_fade_duration: float = 4.0

@onready var _focus_trigger: Area3D = get_node_or_null(focus_trigger_path)
@onready var _finish_trigger: Area3D = get_node_or_null(finish_trigger_path)
@onready var _focus_marker: Marker3D = get_node_or_null(focus_marker_path)
@onready var _ambience: AudioStreamPlayer3D = get_node_or_null(ambience_path)
@onready var _bloom_light: OmniLight3D = get_node_or_null(bloom_light_path)

var _focused: bool = false
var _finished: bool = false
var _fade_layer: CanvasLayer = null
var _white_rect: ColorRect = null
var _audio_tween: Tween = null


func _ready() -> void:
	if _focus_trigger != null and not _focus_trigger.body_entered.is_connected(_on_focus_body_entered):
		_focus_trigger.body_entered.connect(_on_focus_body_entered)
	if _finish_trigger != null and not _finish_trigger.body_entered.is_connected(_on_finish_body_entered):
		_finish_trigger.body_entered.connect(_on_finish_body_entered)
	_prepare_audio()
	_prepare_whiteout_overlay()


func _on_focus_body_entered(body: Node3D) -> void:
	if _focused or not _is_player(body):
		return
	_focused = true
	_start_ambience_loop()
	_fade_ambience_to(ambience_focus_volume_db, ambience_focus_fade_duration)
	_focus_player(body)


func _on_finish_body_entered(body: Node3D) -> void:
	if _finished or not _is_player(body):
		return
	_finished = true
	_start_ambience_loop()
	_fade_ambience_to(ambience_focus_volume_db, 0.35)
	_lock_player_for_finish(body)
	_finish_sequence()


func _is_player(body: Node) -> bool:
	return body != null and (player_group == "" or body.is_in_group(player_group))


func _focus_player(player: Node) -> void:
	if player == null or _focus_marker == null or not player.has_method("start_cinematic_lock"):
		return
	player.call(
		"start_cinematic_lock",
		_focus_marker.global_position,
		focus_fov,
		focus_pan_duration
	)
	await get_tree().create_timer(focus_pan_duration + focus_hold_time).timeout
	if _finished:
		return
	if player != null and is_instance_valid(player) and player.has_method("end_cinematic_lock"):
		player.call("end_cinematic_lock", focus_return_duration)


func _lock_player_for_finish(player: Node) -> void:
	if player == null:
		return
	if "velocity" in player:
		player.set("velocity", Vector3.ZERO)
	if _focus_marker != null and player.has_method("is_cinematic_active") and bool(player.call("is_cinematic_active")):
		return
	if _focus_marker != null and player.has_method("start_cinematic_lock"):
		player.call(
			"start_cinematic_lock",
			_focus_marker.global_position,
			focus_fov,
			maxf(0.15, focus_pan_duration * 0.55)
		)


func _finish_sequence() -> void:
	if _white_rect == null:
		_prepare_whiteout_overlay()
	if _bloom_light != null:
		var light_tween := create_tween()
		light_tween.tween_property(_bloom_light, "light_energy", _bloom_light.light_energy * 1.8, fade_to_white_duration)
	var fade_tween := create_tween()
	_white_rect.visible = true
	_white_rect.modulate.a = 0.0
	fade_tween.tween_property(_white_rect, "modulate:a", 1.0, fade_to_white_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fade_in_ambience_after_delay()
	await fade_tween.finished
	if white_hold_duration > 0.0:
		await get_tree().create_timer(white_hold_duration).timeout
	var events := get_node_or_null("/root/GameEvents")
	if events != null and events.has_method("succeed"):
		events.call("succeed", ending_id)


func _fade_in_ambience_after_delay() -> void:
	if _ambience == null:
		return
	if ambience_fade_delay > 0.0:
		await get_tree().create_timer(ambience_fade_delay).timeout
	if _ambience == null:
		return
	_fade_ambience_to(ambience_target_volume_db, ambience_fade_duration)


func _fade_ambience_to(volume_db: float, duration: float) -> void:
	if _ambience == null:
		return
	if _audio_tween != null and _audio_tween.is_running():
		_audio_tween.kill()
	_audio_tween = create_tween()
	_audio_tween.tween_property(_ambience, "volume_db", volume_db, maxf(0.01, duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _prepare_audio() -> void:
	if _ambience == null:
		return
	_ambience.volume_db = ambience_silent_volume_db
	if _ambience.stream != null:
		var local_stream: AudioStream = _ambience.stream.duplicate()
		_ambience.stream = local_stream
		if "loop" in local_stream:
			local_stream.set("loop", true)


func _start_ambience_loop() -> void:
	if _ambience == null or _ambience.playing:
		return
	_ambience.play()


func _prepare_whiteout_overlay() -> void:
	if _fade_layer != null and is_instance_valid(_fade_layer):
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "ExitWhiteout"
	_fade_layer.layer = 120
	add_child(_fade_layer)

	_white_rect = ColorRect.new()
	_white_rect.name = "WhiteFade"
	_white_rect.visible = false
	_white_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white_rect.color = Color.WHITE
	_white_rect.modulate.a = 0.0
	_white_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_white_rect)
