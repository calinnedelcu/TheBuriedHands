class_name Hud
extends CanvasLayer
## In-game HUD, built in code so it stays consistent with the theme.
## Everything is contextual: the objective appears when it changes and fades,
## health shows only after damage, toxicity only in the fumes, the item name
## only when switching. The oil phial and the visibility eye stay, small.

const SLOT_FRAMES := [
	preload("res://scenes/ui/Slots/slot_1.png"),
	preload("res://scenes/ui/Slots/slot_2.png"),
	preload("res://scenes/ui/Slots/slot_3.png"),
	preload("res://scenes/ui/Slots/slot_4.png"),
]
const PHIAL_BACK := preload("res://scenes/ui/OilPhial/Phial_Backing.png")
const PHIAL_OIL := preload("res://scenes/ui/OilPhial/Phial_Oil.png")
const PHIAL_FRAME := preload("res://scenes/ui/OilPhial/Phial_Frame.png")
const EFFECTS_SHADER := preload("res://assets/shaders/ui/screen_effects.gdshader")
const EYE_SHADER := preload("res://assets/shaders/ui/eye.gdshader")
const OIL_SHADER := preload("res://assets/shaders/ui/oil_fill.gdshader")
const UI_TICK := preload("res://audio/sfx/ui/click_002.ogg")
const OBJECTIVE_SOUND := preload("res://audio/sfx/ui/confirmation_001.ogg")

const OBJECTIVE_VISIBLE_SECONDS := 10.0
const TYPEWRITER_CPS := 55.0

var _player: Player
var _root: Control
var _effects_mat: ShaderMaterial
var _crosshair: Crosshair
var _prompt_box: HBoxContainer
var _prompt_key: Label
var _prompt_text: Label
var _subtitle_panel: PanelContainer
var _speaker_label: Label
var _subtitle_label: Label
var _objective_box: VBoxContainer
var _objective_header: Label
var _objective_label: Label
var _hint_label: Label
var _toast_box: VBoxContainer
var _oil_fill_mat: ShaderMaterial
var _oil_group: Control
var _eye_mat: ShaderMaterial
var _health_pips: HealthPips
var _tox_meter: ToxMeter
var _slot_rects: Array[TextureRect] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _item_name: Label
var _choice_box: VBoxContainer

var _objective_timer := 0.0
var _item_name_timer := 0.0
var _health_show_timer := 0.0
var _damage_flash := 0.0
var _subtitle_chars := 0.0
var _choice_options := PackedStringArray()
var _eye_open := 0.0
var _ready_done := false

func _ready() -> void:
	layer = 10
	_player = get_parent() as Player
	_build()
	if not _player.is_node_ready():
		await _player.ready
	_connect_signals()
	_on_objective_changed(Quest.objective_key(), Quest.hint_key())
	_ready_done = true

# --- Construction ---------------------------------------------------------------

func _build() -> void:
	var effects := ColorRect.new()
	effects.name = "ScreenEffects"
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects_mat = ShaderMaterial.new()
	_effects_mat.shader = EFFECTS_SHADER
	effects.material = _effects_mat
	add_child(effects)

	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.custom_minimum_size = Vector2(80, 80)
	_crosshair.offset_left = -40
	_crosshair.offset_top = -40
	_crosshair.offset_right = 40
	_crosshair.offset_bottom = 40
	_root.add_child(_crosshair)

	# Interaction prompt, just below the crosshair.
	_prompt_box = HBoxContainer.new()
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override("separation", 12)
	_prompt_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt_box.offset_left = -500
	_prompt_box.offset_right = 500
	_prompt_box.offset_top = 70
	_prompt_box.offset_bottom = 110
	var cap := PanelContainer.new()
	cap.theme_type_variation = &"KeyCap"
	_prompt_key = _label("KeyCapLabel", "E")
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(_prompt_key)
	_prompt_box.add_child(cap)
	_prompt_text = _label("PromptLabel", "")
	_prompt_box.add_child(_prompt_text)
	_prompt_box.modulate.a = 0.0
	_root.add_child(_prompt_box)

	# Subtitles.
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.theme_type_variation = &"SubtitleBand"
	_subtitle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle_panel.offset_top = -150
	_subtitle_panel.offset_bottom = -110
	_subtitle_panel.custom_minimum_size = Vector2(0, 0)
	var sub_v := VBoxContainer.new()
	sub_v.add_theme_constant_override("separation", 2)
	_speaker_label = _label("SpeakerLabel", "")
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label = _label("SubtitleLabel", "")
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.custom_minimum_size = Vector2(900, 0)
	_subtitle_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	sub_v.add_child(_speaker_label)
	sub_v.add_child(_subtitle_label)
	_subtitle_panel.add_child(sub_v)
	_subtitle_panel.modulate.a = 0.0
	_root.add_child(_subtitle_panel)

	# Objective, top-left.
	_objective_box = VBoxContainer.new()
	_objective_box.position = Vector2(56, 46)
	_objective_box.custom_minimum_size = Vector2(560, 0)
	_objective_box.add_theme_constant_override("separation", 4)
	_objective_header = _label("HeaderLabel", "")
	_objective_label = _label("ObjectiveLabel", "")
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(560, 0)
	_hint_label = _label("HintLabel", "")
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(560, 0)
	var rule := ColorRect.new()
	rule.color = Color(0.9, 0.7, 0.4, 0.55)
	rule.custom_minimum_size = Vector2(140, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_objective_box.add_child(_objective_header)
	_objective_box.add_child(rule)
	_objective_box.add_child(_objective_label)
	_objective_box.add_child(_hint_label)
	_objective_box.modulate.a = 0.0
	_root.add_child(_objective_box)

	# Toasts.
	_toast_box = VBoxContainer.new()
	_toast_box.position = Vector2(56, 300)
	_toast_box.add_theme_constant_override("separation", 6)
	_root.add_child(_toast_box)

	# Bottom-left cluster: oil phial, visibility eye, health and toxicity.
	_oil_group = Control.new()
	_oil_group.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_oil_group.offset_left = 48
	_oil_group.offset_top = -196
	_oil_group.offset_right = 140
	_oil_group.offset_bottom = -36
	_root.add_child(_oil_group)
	var phial_size := Vector2(78, 156)
	for tex in [PHIAL_BACK, PHIAL_OIL, PHIAL_FRAME]:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = phial_size
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if tex == PHIAL_OIL:
			_oil_fill_mat = ShaderMaterial.new()
			_oil_fill_mat.shader = OIL_SHADER
			r.material = _oil_fill_mat
		_oil_group.add_child(r)
	_oil_group.modulate.a = 0.0

	var eye := ColorRect.new()
	eye.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	eye.offset_left = 136
	eye.offset_top = -92
	eye.offset_right = 212
	eye.offset_bottom = -50
	_eye_mat = ShaderMaterial.new()
	_eye_mat.shader = EYE_SHADER
	eye.material = _eye_mat
	eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(eye)

	_health_pips = HealthPips.new()
	_health_pips.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_health_pips.offset_left = 140
	_health_pips.offset_top = -132
	_health_pips.offset_right = 300
	_health_pips.offset_bottom = -104
	_health_pips.modulate.a = 0.0
	_root.add_child(_health_pips)

	_tox_meter = ToxMeter.new()
	_tox_meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_tox_meter.offset_left = 228
	_tox_meter.offset_top = -190
	_tox_meter.offset_right = 248
	_tox_meter.offset_bottom = -48
	_tox_meter.modulate.a = 0.0
	_root.add_child(_tox_meter)

	# Slots, bottom-right.
	var slots := HBoxContainer.new()
	slots.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	slots.offset_left = -440
	slots.offset_top = -132
	slots.offset_right = -48
	slots.offset_bottom = -40
	slots.alignment = BoxContainer.ALIGNMENT_END
	slots.add_theme_constant_override("separation", 10)
	_root.add_child(slots)
	for i in Inventory.SLOTS:
		var frame := TextureRect.new()
		frame.texture = SLOT_FRAMES[i]
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.custom_minimum_size = Vector2(84, 89)
		frame.pivot_offset = Vector2(42, 89)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 14
		icon.offset_top = 14
		icon.offset_right = -10
		icon.offset_bottom = -12
		frame.add_child(icon)
		var count := _label("SmallLabel", "")
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count.offset_left = -40
		count.offset_top = -30
		count.offset_right = -8
		count.offset_bottom = -4
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_constant_override("outline_size", 6)
		frame.add_child(count)
		slots.add_child(frame)
		_slot_rects.append(frame)
		_slot_icons.append(icon)
		_slot_counts.append(count)
	_item_name = _label("ItemNameLabel", "")
	_item_name.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_item_name.offset_left = -640
	_item_name.offset_top = -176
	_item_name.offset_right = -52
	_item_name.offset_bottom = -144
	_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_item_name.modulate.a = 0.0
	_root.add_child(_item_name)

	# Dialogue choices.
	_choice_box = VBoxContainer.new()
	_choice_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_choice_box.offset_left = -560
	_choice_box.offset_right = 560
	_choice_box.offset_top = -330
	_choice_box.offset_bottom = -180
	_choice_box.alignment = BoxContainer.ALIGNMENT_END
	_choice_box.add_theme_constant_override("separation", 6)
	_choice_box.visible = false
	_root.add_child(_choice_box)

func _label(variation: StringName, text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l

func _connect_signals() -> void:
	Quest.objective_changed.connect(_on_objective_changed)
	Dialogue.line_started.connect(_on_line_started)
	Dialogue.line_ended.connect(_on_line_ended)
	Dialogue.choice_requested.connect(_on_choice_requested)
	Game.checkpoint_saved.connect(func(_id): toast(tr("CHECKPOINT_SAVED")))
	_player.interactor.prompt_changed.connect(_on_prompt_changed)
	Game.chapter_started.connect(_on_chapter_started)
	_player.interactor.hold_progress_changed.connect(func(p): _crosshair.hold_progress = p)
	_player.interactor.target_changed.connect(func(u): _crosshair.has_target = u != null)
	_player.health_changed.connect(_on_health_changed)
	_player.damaged.connect(func(_a, _s): _damage_flash = 1.0)
	var inv := _player.inventory
	inv.changed.connect(_refresh_slots)
	inv.selection_changed.connect(_on_selection_changed)
	inv.lamp_changed.connect(_on_lamp_changed)
	inv.message.connect(func(key): toast(tr(key)))
	inv.item_added.connect(func(item, _c): toast(item.display_name()))
	Settings.changed.connect(_on_setting_changed)
	_on_setting_changed(&"subtitle_scale", Settings.get_value(&"subtitle_scale"))
	_refresh_slots()

# --- Per-frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _ready_done:
		return
	_objective_timer -= delta
	if _objective_timer <= 0.0 and _objective_box.modulate.a > 0.0 and not Input.is_action_pressed(&"journal"):
		_objective_box.modulate.a = move_toward(_objective_box.modulate.a, 0.0, delta * 0.7)
	if Input.is_action_pressed(&"journal") and _objective_label.text != "":
		_objective_box.modulate.a = move_toward(_objective_box.modulate.a, 1.0, delta * 6.0)

	_item_name_timer -= delta
	if _item_name_timer <= 0.0:
		_item_name.modulate.a = move_toward(_item_name.modulate.a, 0.0, delta * 1.5)

	# Subtitle typewriter.
	if _subtitle_label.visible_characters >= 0:
		_subtitle_chars += delta * TYPEWRITER_CPS
		_subtitle_label.visible_characters = int(_subtitle_chars)
		if _subtitle_label.visible_characters >= _subtitle_label.get_total_character_count():
			_subtitle_label.visible_characters = -1

	# Status effects.
	_damage_flash = move_toward(_damage_flash, 0.0, delta * 1.6)
	var low := 1.0 - clampf(_player.health / (_player.max_health * 0.34), 0.0, 1.0)
	_effects_mat.set_shader_parameter(&"damage", _damage_flash)
	_effects_mat.set_shader_parameter(&"low_health", low)
	_effects_mat.set_shader_parameter(&"toxicity", _player.toxicity / 100.0)
	_effects_mat.set_shader_parameter(&"breath_hold", 1.0 - _player.breath / _player.breath_capacity if _player.holding_breath else 0.0)
	_health_show_timer -= delta
	var show_health := _health_show_timer > 0.0 or low > 0.0
	_health_pips.modulate.a = move_toward(_health_pips.modulate.a, 1.0 if show_health else 0.0, delta * 2.0)
	_tox_meter.value = _player.toxicity / 100.0
	_tox_meter.breath = _player.breath / _player.breath_capacity
	_tox_meter.modulate.a = move_toward(_tox_meter.modulate.a, 1.0 if _player.toxicity > 0.5 or _player.holding_breath else 0.0, delta * 2.0)

	# Visibility eye.
	_eye_open = lerpf(_eye_open, Stealth.player_exposure, clampf(delta * 6.0, 0.0, 1.0))
	_eye_mat.set_shader_parameter(&"open_amount", _eye_open)
	_eye_mat.set_shader_parameter(&"alert", Stealth.alert_level)

	var lamp := _player.inventory.lamp()
	if lamp != null:
		_oil_fill_mat.set_shader_parameter(&"level", lamp.fraction())
		_oil_fill_mat.set_shader_parameter(&"slosh", 1.0 if _player.is_moving() else 0.0)
		var tint := Color(1, 1, 1) if lamp.is_lit else Color(0.55, 0.5, 0.45)
		if lamp.fraction() < 0.2 and lamp.is_lit:
			tint = Color(1.0, 0.6 + 0.25 * sin(Time.get_ticks_msec() * 0.008), 0.4)
		_oil_fill_mat.set_shader_parameter(&"tint", tint)

# --- Signal handlers ------------------------------------------------------------------

func _on_objective_changed(text_key: String, hint_key: String) -> void:
	if text_key == "":
		_objective_timer = 0.0
		return
	_objective_header.text = tr("HUD_NEW_OBJECTIVE").to_upper()
	_objective_label.text = tr(text_key)
	var hint := ""
	if hint_key != "" and Settings.get_value(&"show_hints"):
		hint = InputHint.format(tr(hint_key))
	_hint_label.text = hint
	_hint_label.visible = hint != ""
	_objective_timer = OBJECTIVE_VISIBLE_SECONDS
	_objective_box.modulate.a = 0.0
	var tween := create_tween()
	_objective_box.position.x = 30
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_objective_box, "modulate:a", 1.0, 0.6)
	tween.tween_property(_objective_box, "position:x", 56.0, 0.8)
	tween.chain().tween_interval(3.0)
	tween.chain().tween_callback(func(): _objective_header.text = tr("HUD_OBJECTIVE").to_upper())
	Sfx.play_ui(OBJECTIVE_SOUND, -14.0)

func _on_line_started(_speaker_id: StringName, speaker: String, text: String, _duration: float, _extras: Dictionary) -> void:
	if not Settings.get_value(&"subtitles"):
		return
	_speaker_label.text = speaker.to_upper()
	_speaker_label.visible = speaker != ""
	_subtitle_label.text = text
	_subtitle_chars = 0.0
	_subtitle_label.visible_characters = 0
	create_tween().tween_property(_subtitle_panel, "modulate:a", 1.0, 0.18)

func _on_line_ended() -> void:
	create_tween().tween_property(_subtitle_panel, "modulate:a", 0.0, 0.25)

func _on_prompt_changed(text: String, action: StringName, is_hold: bool, blocked: bool) -> void:
	if text == "":
		create_tween().tween_property(_prompt_box, "modulate:a", 0.0, 0.12)
		return
	_prompt_key.text = Settings.binding_label(action)
	_prompt_key.get_parent().visible = not blocked
	_prompt_text.text = InputHint.format(text) + ("  ·  " + tr("HUD_HOLD").to_lower() if is_hold and not blocked else "")
	_prompt_text.modulate = Color(1, 1, 1, 0.55) if blocked else Color.WHITE
	create_tween().tween_property(_prompt_box, "modulate:a", 1.0, 0.1)

func _on_health_changed(current: float, maximum: float) -> void:
	_health_pips.current = current
	_health_pips.maximum = maximum
	_health_pips.queue_redraw()
	_health_show_timer = 4.0

func _refresh_slots() -> void:
	var inv := _player.inventory
	for i in Inventory.SLOTS:
		var item := inv.slot_item(i)
		_slot_icons[i].texture = item.icon if item != null else null
		var count := inv.slot_count(i)
		_slot_counts[i].text = str(count) if count > 1 else ""
		var selected := i == inv.selected
		_slot_rects[i].modulate = Color(1.25, 1.1, 0.85) if selected else (Color(1, 1, 1, 0.9) if item != null else Color(0.6, 0.6, 0.6, 0.55))
		_slot_rects[i].scale = Vector2.ONE * (1.08 if selected else 1.0)

func _on_selection_changed(_index: int) -> void:
	_refresh_slots()
	var item := _player.inventory.selected_item()
	_item_name.text = (item.display_name() if item != null else tr("HUD_HANDS_FREE")).to_upper()
	_item_name.modulate.a = 1.0
	_item_name_timer = 1.6
	Sfx.play_ui(UI_TICK, -18.0)

func _on_lamp_changed(lamp: HeldLamp) -> void:
	create_tween().tween_property(_oil_group, "modulate:a", 1.0 if lamp != null else 0.0, 0.4)

func _on_choice_requested(options: PackedStringArray) -> void:
	_choice_options = options
	for c in _choice_box.get_children():
		c.queue_free()
	for i in options.size():
		var b := Button.new()
		b.theme_type_variation = &"SmallButton"
		b.text = "[%s]  %s" % [Settings.binding_label(StringName("slot_%d" % (i + 1))), tr(options[i])]
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_pick_choice.bind(i))
		_choice_box.add_child(b)
	_choice_box.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _pick_choice(index: int) -> void:
	_choice_box.visible = false
	_choice_options = PackedStringArray()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play_ui(UI_TICK, -10.0)
	Dialogue.choose_option(index)

## Choices are picked with the slot keys (1, 2 by default, rebindable), so
## any device that can select a slot can answer.
func _unhandled_input(event: InputEvent) -> void:
	if not _ready_done or _choice_options.is_empty() or not event.is_pressed() or event.is_echo():
		return
	for i in mini(_choice_options.size(), 4):
		if event.is_action_pressed(StringName("slot_%d" % (i + 1))):
			get_viewport().set_input_as_handled()
			_pick_choice(i)
			return

func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"subtitle_scale":
		var s := float(value)
		_subtitle_label.add_theme_font_size_override("font_size", int(28 * s))
		_speaker_label.add_theme_font_size_override("font_size", int(18 * s))
	elif key == &"subtitles" and not value:
		_subtitle_panel.modulate.a = 0.0

## A short message that fades by itself.
## A chapter's title card: the numeral, the title, and (for the first) the
## place and year, faded in over the middle of the screen.
func _on_chapter_started(number: int) -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 10)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_top = 160
	box.offset_left = -600
	box.offset_right = 600
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# The chapter's numeral on a seal, as on a scroll.
	if number >= 1 and number <= 5:
		var seal := SealStamp.new()
		seal.text = "一二三四五"[number - 1]
		seal.side = 46.0
		seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		seal.modulate.a = 0.9
		box.add_child(seal)
	var numeral := _label("HeaderLabel", tr("CHAPTER_%d" % number))
	numeral.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(numeral)
	var title := _label("TitleLabel", tr("CHAPTER_TITLE_%d" % number))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(0.83, 0.66, 0.38, 0.5)
	rule.custom_minimum_size = Vector2(260, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	var place_key := "CHAPTER_PLACE_%d" % number
	if tr(place_key) != place_key:
		var place := _label("QuoteText", tr(place_key))
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(place)
	_root.add_child(box)
	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(3.2)
	tween.tween_property(box, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(box.queue_free)

func toast(text: String) -> void:
	var l := _label("ToastLabel", text)
	_toast_box.add_child(l)
	l.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(l, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.6)
	tween.tween_property(l, "modulate:a", 0.0, 0.8)
	tween.tween_callback(l.queue_free)

# --- Small custom-drawn widgets ---------------------------------------------------------

class Crosshair extends Control:
	var has_target := false:
		set(v):
			has_target = v
			queue_redraw()
	var hold_progress := 0.0:
		set(v):
			hold_progress = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var gold := Color(1.0, 0.82, 0.55)
		if has_target:
			draw_circle(c, 3.0, Color(gold, 0.95))
			draw_arc(c, 11.0, 0.0, TAU, 40, Color(gold, 0.35), 1.5, true)
		else:
			draw_circle(c, 2.2, Color(1, 1, 1, 0.45))
		if hold_progress > 0.0:
			draw_arc(c, 11.0, -PI * 0.5, -PI * 0.5 + TAU * hold_progress, 48, gold, 3.0, true)

class HealthPips extends Control:
	var current := 6.0
	var maximum := 6.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var count := int(maximum)
		for i in count:
			var center := Vector2(10 + i * 22, size.y * 0.5)
			var fill := clampf(current - i, 0.0, 1.0)
			var pts := PackedVector2Array([center + Vector2(0, -8), center + Vector2(7, 0), center + Vector2(0, 8), center + Vector2(-7, 0)])
			draw_colored_polygon(pts, Color(0.1, 0.06, 0.05, 0.7))
			if fill > 0.0:
				var inner := PackedVector2Array()
				for p in pts:
					inner.append(center + (p - center) * (0.45 + 0.4 * fill))
				draw_colored_polygon(inner, Color(0.75, 0.14, 0.1, 0.95).lerp(Color(0.95, 0.75, 0.5), 0.15))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.85, 0.66, 0.4, 0.8), 1.2, true)

class ToxMeter extends Control:
	var value := 0.0:
		set(v):
			if not is_equal_approx(v, value):
				value = v
				queue_redraw()
	var breath := 1.0:
		set(v):
			if not is_equal_approx(v, breath):
				breath = v
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(4, 0), Vector2(8, size.y))
		draw_rect(r, Color(0.05, 0.05, 0.06, 0.7))
		var h := r.size.y * value
		draw_rect(Rect2(r.position.x, r.end.y - h, r.size.x, h), Color(0.78, 0.84, 0.86, 0.95))
		draw_rect(r, Color(0.7, 0.75, 0.8, 0.6), false, 1.0)
		# Breath: a thin warm line beside the poison column.
		var bh := r.size.y * breath
		draw_rect(Rect2(r.end.x + 3, r.end.y - bh, 2, bh), Color(1.0, 0.85, 0.6, 0.8))
