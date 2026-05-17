extends Node3D

@export var player_group: String = "player"
@export var ending_id: String = "exit_found"
@export var ambient_stream: AudioStream
@export var ending_background: Texture2D
@export var bloom_environment: Environment
## Daca true: trigger-ul Area3D NU declanseaza ending-ul. Se cheama doar prin
## trigger_sequence() din afara (ex. squeeze_tunnel_collapse epilogue).
@export var auto_trigger_only: bool = true

@export_group("Cinematic")
@export var focus_zoom_fov: float = 28.0
@export var focus_pan_duration: float = 1.6
@export var focus_hold_time: float = 1.4

@export_group("White Screen")
@export var white_fade_duration: float = 2.6
@export var white_hold_before_audio: float = 1.0
@export var white_hold_before_ui: float = 4.5

@export_group("Audio")
@export var ambient_fade_in_duration: float = 4.0
@export var ambient_volume_target_db: float = -6.0

@export_group("Ending UI")
@export var ui_fade_in_duration: float = 1.8
@export var main_menu_scene: String = "res://scenes/main_menu.tscn"
## Native size of the ending_background card (Untitled_19.png is 1024x682)
@export var card_native_size: Vector2 = Vector2(1024, 682)
## Max width of the card on screen — actual scale is min(this, viewport_h*ratio)
@export var card_max_screen_width: float = 1024.0
## Hit-rect for "Meniu principal" in the card's local pixel coords (relative to card_native_size)
@export var main_menu_hit_rect: Rect2 = Rect2(295, 405, 435, 40)
## Hit-rect for "Ieși" in the card's local pixel coords
@export var leave_hit_rect: Rect2 = Rect2(295, 467, 435, 40)

@export_node_path("Marker3D") var light_marker_path: NodePath = NodePath("LightMarker")
@export_node_path("Area3D") var trigger_path: NodePath = NodePath("Trigger")

@onready var _light_marker: Marker3D = get_node_or_null(light_marker_path)
@onready var _trigger: Area3D = get_node_or_null(trigger_path)
@onready var _ambient_audio: AudioStreamPlayer = get_node_or_null("AmbientAudio")

var _triggered: bool = false
var _player_camera: Camera3D = null
var _saved_camera_env: Environment = null

func _ready() -> void:
	add_to_group("exit_light_gate")
	if _ambient_audio != null and ambient_stream != null and _ambient_audio.stream == null:
		_ambient_audio.stream = ambient_stream
	if auto_trigger_only:
		print("[exit_light_gate] ready at %s, auto-trigger only (body_entered NOT connected)" % global_position)
		return
	if _trigger == null:
		push_warning("[exit_light_gate] Trigger node not found at %s" % trigger_path)
		return
	if not _trigger.body_entered.is_connected(_on_body_entered):
		_trigger.body_entered.connect(_on_body_entered)
	print("[exit_light_gate] ready at %s, trigger=%s mask=%d monitoring=%s" % [global_position, _trigger.name, _trigger.collision_mask, _trigger.monitoring])

func _on_body_entered(body: Node3D) -> void:
	if _triggered:
		return
	if player_group != "" and not body.is_in_group(player_group):
		return
	trigger_sequence(body)

## API public — declanseaza secventa ending fara sa depinda de body_entered.
## Player-ul e cel pe care se aplica freeze + cinematic focus.
func trigger_sequence(player: Node) -> void:
	if _triggered:
		return
	_triggered = true
	print("[exit_light_gate] TRIGGERED via API — starting sequence")
	_run_sequence(player)

func _run_sequence(player: Node) -> void:
	_apply_bloom(player)

	if _light_marker != null and player.has_method("play_cinematic_focus"):
		player.call("play_cinematic_focus", _light_marker.global_position, focus_pan_duration, focus_hold_time, focus_zoom_fov, white_fade_duration * 0.5)

	await get_tree().create_timer(focus_pan_duration * 0.55).timeout

	var overlay := _create_white_overlay()
	_fade_white_in(overlay, white_fade_duration)

	await get_tree().create_timer(white_fade_duration).timeout

	_freeze_player(player)

	await get_tree().create_timer(white_hold_before_audio).timeout

	_start_ambient_fade()

	var events := get_node_or_null("/root/GameEvents")
	if events != null and events.has_method("succeed"):
		events.call("succeed", ending_id)

	await get_tree().create_timer(white_hold_before_ui).timeout

	_show_ending_ui(overlay)

func _apply_bloom(player: Node) -> void:
	var cam := player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if cam == null:
		return
	_player_camera = cam
	var env: Environment = cam.environment
	if env == null:
		var world_env := _find_world_environment()
		if world_env != null:
			env = world_env.environment
	if env == null and bloom_environment != null:
		cam.environment = bloom_environment
		return
	if env == null:
		return
	env.glow_enabled = true
	env.glow_intensity = max(env.glow_intensity, 2.4)
	env.glow_strength = max(env.glow_strength, 1.6)
	env.glow_bloom = max(env.glow_bloom, 0.9)
	env.glow_hdr_threshold = min(env.glow_hdr_threshold, 0.5)
	env.glow_hdr_scale = max(env.glow_hdr_scale, 5.0)
	for i in range(1, 8):
		env.set("glow_levels/" + str(i), 1.0)

func _find_world_environment() -> WorldEnvironment:
	var root := get_tree().current_scene
	if root == null:
		return null
	return _find_world_env_recursive(root)

func _find_world_env_recursive(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node as WorldEnvironment
	for child in node.get_children():
		var found := _find_world_env_recursive(child)
		if found != null:
			return found
	return null

func _freeze_player(player: Node) -> void:
	if player == null:
		return
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)

func _start_ambient_fade() -> void:
	if _ambient_audio == null:
		return
	_ambient_audio.volume_db = -80.0
	if not _ambient_audio.playing:
		_ambient_audio.play()
	var tween := create_tween()
	tween.tween_property(_ambient_audio, "volume_db", ambient_volume_target_db, ambient_fade_in_duration).set_trans(Tween.TRANS_SINE)

func _create_white_overlay() -> CanvasLayer:
	var canvas := CanvasLayer.new()
	canvas.name = "ExitWhiteOverlay"
	canvas.layer = 128
	var color := ColorRect.new()
	color.name = "WhiteScreen"
	color.color = Color(1.0, 1.0, 1.0, 1.0)
	color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color.modulate.a = 0.0
	canvas.add_child(color)
	get_tree().current_scene.add_child(canvas)
	return canvas

func _fade_white_in(overlay: CanvasLayer, duration: float) -> void:
	var color_rect := overlay.get_child(0) as ColorRect
	if color_rect == null:
		return
	var tween := create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)

func _show_ending_ui(white_overlay: CanvasLayer) -> void:
	var ui := CanvasLayer.new()
	ui.name = "ExitEndingUI"
	ui.layer = 129
	ui.process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var centerer := CenterContainer.new()
	centerer.name = "Centerer"
	centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centerer.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(centerer)

	var window_size: Vector2 = Vector2(get_window().size)
	var scale_x: float = min(card_max_screen_width, window_size.x * 0.85) / card_native_size.x
	var scale_y: float = (window_size.y * 0.85) / card_native_size.y
	var card_scale: float = min(scale_x, scale_y)
	var card_size: Vector2 = card_native_size * card_scale

	var card := Control.new()
	card.name = "Card"
	card.custom_minimum_size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	centerer.add_child(card)

	var bg := TextureRect.new()
	bg.name = "CardImage"
	bg.texture = ending_background
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)

	var main_menu_btn := _make_invisible_button(main_menu_hit_rect, card_scale)
	main_menu_btn.name = "MainMenuHit"
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	card.add_child(main_menu_btn)

	var leave_btn := _make_invisible_button(leave_hit_rect, card_scale)
	leave_btn.name = "LeaveHit"
	leave_btn.pressed.connect(_on_leave_pressed)
	card.add_child(leave_btn)

	root.modulate.a = 0.0
	get_tree().current_scene.add_child(ui)

	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, ui_fade_in_duration).set_trans(Tween.TRANS_SINE)

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _make_invisible_button(hit_rect: Rect2, card_scale: float) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.text = ""
	btn.focus_mode = Control.FOCUS_ALL
	btn.position = hit_rect.position * card_scale
	btn.size = hit_rect.size * card_scale
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)
	transparent.border_width_left = 0
	transparent.border_width_right = 0
	transparent.border_width_top = 0
	transparent.border_width_bottom = 0
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.92, 0.74, 0.10)
	hover.border_color = Color(1.0, 0.92, 0.74, 0.55)
	hover.border_width_left = 1
	hover.border_width_right = 1
	hover.border_width_top = 1
	hover.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", transparent)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", transparent)
	return btn

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)

func _on_leave_pressed() -> void:
	get_tree().quit()
