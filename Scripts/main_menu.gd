extends Control

const GAME_SCENE := "res://scenes/tomb_layout.tscn"
const MUSIC_TARGET_VOLUME_DB := -16.0
const MUSIC_FADE_SECONDS := 3.0
const PLAY_START_DELAY_SECONDS := 0.42

@onready var music: AudioStreamPlayer = $Music
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var play_start_sound: AudioStreamPlayer = $PlayStartSound
@onready var background: TextureRect = $MenuArea/Content/Background
@onready var flicker: ColorRect = $MenuArea/Content/FlickerOverlay
@onready var dust: CPUParticles2D = $MenuArea/Content/Dust
@onready var embers: CPUParticles2D = $MenuArea/Content/Embers
@onready var drift: CPUParticles2D = $MenuArea/Content/Drift
@onready var content: Control = $MenuArea/Content

var _button_glows: Dictionary = {}
var _is_starting_game := false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_start_music()

	_button_glows = {
		$MenuArea/Content/PlayButton: $MenuArea/Content/PlayGlow,
		$MenuArea/Content/ContinueButton: $MenuArea/Content/ContinueGlow,
		$MenuArea/Content/OptionsButton: $MenuArea/Content/OptionsGlow,
		$MenuArea/Content/QuitButton: $MenuArea/Content/QuitGlow,
	}

	for btn in _button_glows.keys():
		var glow: Panel = _button_glows[btn]
		btn.mouse_entered.connect(_on_button_hover.bind(glow, true))
		btn.mouse_exited.connect(_on_button_hover.bind(glow, false))
		btn.pressed.connect(_on_button_pressed.bind(glow))
		btn.resized.connect(_sync_glow.bind(btn, glow))
		_sync_glow(btn, glow)

	$MenuArea/Content/PlayButton.pressed.connect(_on_play)
	$MenuArea/Content/ContinueButton.pressed.connect(_on_continue)
	$MenuArea/Content/OptionsButton.pressed.connect(_on_options)
	$MenuArea/Content/QuitButton.pressed.connect(_on_quit)

	content.resized.connect(_on_content_resized)
	_on_content_resized()

	_animate_background()
	_animate_flicker()

func _start_music() -> void:
	if not music or not music.stream:
		return

	if music.stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = music.stream
		mp3_stream.loop = true

	music.volume_db = -48.0
	if not music.playing:
		music.play()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(music, "volume_db", MUSIC_TARGET_VOLUME_DB, MUSIC_FADE_SECONDS)

func _sync_glow(btn: Button, glow: Panel) -> void:
	# Match the glow to the button's actual rect, ignoring its own anchors.
	glow.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	glow.global_position = btn.global_position
	glow.size = btn.size
	glow.pivot_offset = glow.size * 0.5

func _on_content_resized() -> void:
	if background:
		background.pivot_offset = background.size * 0.5
	var w := content.size.x
	var h := content.size.y
	if dust:
		dust.position = Vector2(w * 0.5, h + 10.0)
		dust.emission_rect_extents = Vector2(w * 0.5, 6)
	if embers:
		embers.position = Vector2(w * 0.5, h + 4.0)
		embers.emission_rect_extents = Vector2(w * 0.5, 8)
	if drift:
		drift.position = Vector2(w * 0.5, h * 0.45)
		drift.emission_rect_extents = Vector2(w * 0.55, h * 0.35)
	for btn in _button_glows.keys():
		_sync_glow(btn, _button_glows[btn])

func _animate_background() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(background, "scale", Vector2(1.022, 1.022), 16.0)
	tween.tween_property(background, "scale", Vector2(1.0, 1.0), 16.0)

func _animate_flicker() -> void:
	while is_inside_tree():
		var target_alpha: float = randf_range(0.02, 0.12)
		var duration: float = randf_range(0.18, 0.55)
		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE)
		t.tween_property(flicker, "color:a", target_alpha, duration)
		await t.finished
		await get_tree().create_timer(randf_range(0.05, 0.35)).timeout

func _on_button_hover(glow: Panel, entered: bool) -> void:
	var target: float = 0.85 if entered else 0.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(glow, "modulate:a", target, 0.22)

func _on_button_pressed(glow: Panel) -> void:
	_play_click_sound()
	glow.modulate.a = 1.0
	glow.pivot_offset = glow.size * 0.5
	var t := create_tween()
	t.tween_property(glow, "scale", Vector2(1.03, 1.03), 0.08)
	t.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.12)

func _play_click_sound() -> void:
	if click_sound:
		click_sound.stop()
		click_sound.play()

func _on_play() -> void:
	if _is_starting_game:
		return

	_is_starting_game = true
	_set_buttons_disabled(true)
	if play_start_sound:
		play_start_sound.play()

	var music_fade := create_tween()
	music_fade.set_trans(Tween.TRANS_SINE)
	music_fade.set_ease(Tween.EASE_OUT)
	music_fade.tween_property(music, "volume_db", -28.0, PLAY_START_DELAY_SECONDS)

	await get_tree().create_timer(PLAY_START_DELAY_SECONDS).timeout
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_continue() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _set_buttons_disabled(disabled: bool) -> void:
	for btn in _button_glows.keys():
		btn.disabled = disabled

func _on_options() -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = "Options — coming soon."
	dlg.title = "Options"
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)

func _on_quit() -> void:
	get_tree().quit()
