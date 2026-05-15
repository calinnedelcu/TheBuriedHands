extends CanvasLayer

@export var player_path: NodePath
@export var lamp_path: NodePath
@export var interaction_path: NodePath
@export var inventory_path: NodePath
@export var debug_overlay_update_interval: float = 0.15

@onready var _oil_phial: Control = $Anchor/Bottom/OilPhial
@onready var _oil_halo: ColorRect = $Anchor/Bottom/OilPhial/WarmHalo
@onready var _oil_shadow: ColorRect = $Anchor/Bottom/OilPhial/BackShadow
@onready var _oil_fill: TextureRect = $Anchor/Bottom/OilPhial/OilClip/OilFill
@onready var _oil_surface: TextureRect = $Anchor/Bottom/OilPhial/OilClip/OilSurface
@onready var _left_hand_slot: TextureRect = $Anchor/Bottom/LeftHandSlot
@onready var _left_hand_icon: TextureRect = $Anchor/Bottom/LeftHandSlot/Icon
@onready var _interact_label: Label = $Anchor/Center/InteractLabel
@onready var _item_label: Label = $Anchor/Bottom/ItemLabel
@warning_ignore("unused_private_class_variable")
@onready var _dot: Panel = $Anchor/Center/CrosshairDot
@onready var _objective_card: TextureRect = $Anchor/TopRight/ObjectiveCard
@onready var _objective_label: Label = $Anchor/TopRight/ObjectiveCard/ObjectiveLabel
var _objective_visible_pos: Vector2 = Vector2.ZERO
var _objective_tween: Tween = null
const _OBJ_HIDDEN_OFFSET := Vector2(60.0, -16.0)
@onready var _slot_panels: Array[TextureRect] = [
	$Anchor/Bottom/SlotBar/Slot1,
	$Anchor/Bottom/SlotBar/Slot2,
	$Anchor/Bottom/SlotBar/Slot3,
	$Anchor/Bottom/SlotBar/Slot4,
]
@onready var _slot_icons: Array[TextureRect] = [
	$Anchor/Bottom/SlotBar/Slot1/Icon,
	$Anchor/Bottom/SlotBar/Slot2/Icon,
	$Anchor/Bottom/SlotBar/Slot3/Icon,
	$Anchor/Bottom/SlotBar/Slot4/Icon,
]
@onready var _oil_dust: Array[Control] = [
	$Anchor/Bottom/OilPhial/DustLayer/Dust1,
	$Anchor/Bottom/OilPhial/DustLayer/Dust2,
	$Anchor/Bottom/OilPhial/DustLayer/Dust3,
	$Anchor/Bottom/OilPhial/DustLayer/Dust4,
]

## Modulate state pentru sloturile noi cu textura proprie:
## empty = dim, owned = neutral, active = warm bright
const _SLOT_MOD_EMPTY: Color = Color(0.62, 0.62, 0.62, 0.88)
const _SLOT_MOD_OWNED: Color = Color(1.0, 1.0, 1.0, 1.0)
const _SLOT_MOD_ACTIVE: Color = Color(1.25, 1.08, 0.78, 1.0)
const _ITEM_ICON_TEXTURES: Dictionary = {
	"chisel": preload("res://scenes/ui/Slots/Icons/icon_chisel.png"),
	"wedge": preload("res://scenes/ui/Slots/Icons/icon_wedge.png"),
	"ceramic": preload("res://scenes/ui/Slots/Icons/icon_ceramic.png"),
	"hammer": preload("res://scenes/ui/Slots/Icons/icon_hammer.png"),
	"wax_tablet": preload("res://scenes/ui/Slots/Icons/icon_wax_tablet.png"),
	"clay_bowl": preload("res://scenes/ui/Slots/Icons/icon_clay_bowl.png"),
	"clay_slip": preload("res://scenes/ui/Slots/Icons/icon_clay_slip.png"),
	"lamp": preload("res://scenes/ui/Slots/Icons/icon_lamp.png"),
	"rope": preload("res://scenes/ui/Slots/Icons/icon_rope.png"),
	"wet_cloth": preload("res://scenes/ui/Slots/Icons/icon_wet_cloth.png"),
	"qin_seal": preload("res://scenes/ui/Slots/Icons/icon_qin_seal.png"),
}
var _slot_count_labels: Array[Label] = []
var _inventory: Node = null
var _active_lamp_node: Node = null
var _oil_dust_base_positions: Array[Vector2] = []
var _oil_effect_lit: bool = true
var _oil_effect_intensity: float = 1.0
var _debug_panel: PanelContainer = null
var _debug_label: Label = null
var _debug_overlay_visible: bool = false
var _debug_overlay_timer: float = 0.0
var _left_hand_selected: bool = false
var _dialogue_panel: PanelContainer = null
var _dialogue_label: Label = null
var _dialogue_hide_timer: float = 0.0

const _OIL_DRAIN_AMOUNT: float = 152.0
const _OIL_BOB_AMPLITUDE: float = 0.4
const _OIL_BOB_SPEED: float = 2.0
const _OIL_PHIAL_LIT_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const _OIL_PHIAL_UNLIT_TINT: Color = Color(0.9, 0.86, 0.78, 0.78)
const _OIL_FILL_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const _OIL_FILL_LOW_TINT: Color = Color(1.35, 0.56, 0.18, 1.0)
const _OIL_SURFACE_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const _OIL_SURFACE_LOW_TINT: Color = Color(1.45, 0.72, 0.28, 1.0)
const _OIL_HALO_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const _OIL_HALO_LOW_TINT: Color = Color(1.35, 0.62, 0.25, 1.0)
const _OIL_LOW_WARNING_THRESHOLD: float = 0.14
const _OIL_HALO_ALPHA: float = 0.22
const _OIL_SHADOW_ALPHA: float = 0.76
const _OIL_DUST_ALPHA: float = 0.26
var _oil_fill_base_y: float = 0.0
var _oil_surface_base_y: float = 0.0
var _oil_target_drain: float = 0.0
var _oil_smooth_drain: float = 0.0
var _oil_bob_time: float = 0.0
var _oil_pct: float = 1.0

func _ready() -> void:
	_setup_debug_overlay_input()
	_build_debug_overlay()
	_build_dialogue_panel()
	_interact_label.text = ""
	_oil_fill_base_y = _oil_fill.position.y
	_oil_surface_base_y = _oil_surface.position.y
	for dust in _oil_dust:
		_oil_dust_base_positions.append(dust.position)
	_apply_oil_phial_tone(true)
	# OilPhial este ascuns implicit. Devine vizibil doar cand exista
	# o lampa in offhand (vezi _attach_lamp / _detach_lamp).
	_oil_phial.visible = false
	_set_left_hand_slot(false)
	_objective_label.text = ""
	_objective_visible_pos = _objective_card.position
	_objective_card.position = _objective_visible_pos + _OBJ_HIDDEN_OFFSET
	_objective_card.modulate.a = 0.0
	_objective_label.modulate.a = 0.0
	_prepare_slot_count_labels()

	if has_node("/root/Objectives"):
		var obj := get_node("/root/Objectives")
		obj.objective_changed.connect(_on_objective_changed)
		var current_text: String = obj.current_text()
		if current_text != "":
			_objective_label.text = current_text
			_animate_objective_in()

	if has_node("/root/GameEvents"):
		var events := get_node("/root/GameEvents")
		if events.has_signal("dialogue_changed"):
			events.dialogue_changed.connect(_on_dialogue_changed)

	if not interaction_path.is_empty():
		var inter := get_node_or_null(interaction_path)
		if inter != null:
			inter.prompt_changed.connect(_on_prompt_changed)
	if not inventory_path.is_empty():
		var inv := get_node_or_null(inventory_path)
		if inv != null:
			_inventory = inv
			if inv.has_signal("slots_changed"):
				inv.connect("slots_changed", Callable(self, "_on_inventory_slots_changed"))
			if inv.has_signal("slot_selected"):
				inv.connect("slot_selected", Callable(self, "_on_inventory_slot_selected"))
			if inv.has_method("current_name"):
				_item_label.text = inv.current_name()
			_refresh_slots()
	# Fallback legacy: daca nu e inventory dar e lamp_path, conectam direct.
	# Daca inventory exista, HUD-ul citeste find_lamp(), nu active_lamp();
	# active_lamp() e rezervat pentru refill/drop cand lampa e selectata cu Z.
	if _inventory == null and not lamp_path.is_empty():
		var lamp := get_node_or_null(lamp_path)
		if lamp != null:
			_attach_lamp(lamp)
	# Sincronizam o data dupa frame ca initial_lamp_path (deferred) sa apuce
	# sa fie procesat de inventory.
	call_deferred("_sync_active_lamp")

func _prepare_slot_count_labels() -> void:
	_slot_count_labels.clear()
	for i in _slot_panels.size():
		var panel := _slot_panels[i]
		var count_label := panel.get_node_or_null("Count") as Label
		if count_label == null:
			count_label = Label.new()
			count_label.name = "Count"
			panel.add_child(count_label)
			count_label.anchor_left = 1.0
			count_label.anchor_top = 1.0
			count_label.anchor_right = 1.0
			count_label.anchor_bottom = 1.0
			count_label.offset_left = -18.0
			count_label.offset_top = -16.0
			count_label.offset_right = -2.0
			count_label.offset_bottom = -2.0
			count_label.grow_horizontal = 0
			count_label.grow_vertical = 0
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			count_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6, 1))
			count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			count_label.add_theme_constant_override("outline_size", 4)
			count_label.add_theme_font_size_override("font_size", 11)
		count_label.text = ""
		_slot_count_labels.append(count_label)

func _refresh_slots() -> void:
	if _inventory == null:
		return
	var current_slot: int = _inventory.current_slot() if _inventory.has_method("current_slot") else -1
	var lamp_lit := true
	if _active_lamp_node != null:
		var lit_value = _active_lamp_node.get("is_lit")
		lamp_lit = bool(lit_value) if lit_value != null else true
	_set_left_hand_slot(_active_lamp_node != null, lamp_lit)
	for i in _slot_panels.size():
		var slot_index: int = i
		var panel: TextureRect = _slot_panels[i]
		var item_id := ""
		var acquired := false
		var stack := 0
		if _inventory.has_method("slot_item_id"):
			item_id = _inventory.slot_item_id(slot_index)
			acquired = item_id != ""
			stack = _inventory.slot_stack(slot_index) if _inventory.has_method("slot_stack") else 0
		var active: bool = slot_index == current_slot
		if active:
			panel.modulate = _SLOT_MOD_ACTIVE
		elif acquired:
			panel.modulate = _SLOT_MOD_OWNED
		else:
			panel.modulate = _SLOT_MOD_EMPTY
		if i < _slot_icons.size():
			var icon := _slot_icons[i]
			var tex: Texture2D = _ITEM_ICON_TEXTURES.get(item_id, null)
			icon.texture = tex
			icon.visible = tex != null
		if i < _slot_count_labels.size():
			_slot_count_labels[i].text = ("×%d" % stack) if stack > 1 else ""

func _on_oil_changed(level: float, max_level: float) -> void:
	var pct: float = clamp(level / max(1.0, max_level), 0.0, 1.0)
	_oil_pct = pct
	_oil_target_drain = (1.0 - pct) * _OIL_DRAIN_AMOUNT

func _on_lit_changed(lit: bool) -> void:
	_apply_oil_phial_tone(lit)
	_set_left_hand_slot(_active_lamp_node != null, lit)

func _apply_oil_phial_tone(lit: bool) -> void:
	_oil_effect_lit = lit
	_oil_phial.modulate = _OIL_PHIAL_LIT_TINT if lit else _OIL_PHIAL_UNLIT_TINT

func _process(delta: float) -> void:
	_oil_bob_time += delta
	_update_dialogue_timer(delta)
	var t: float = clamp(delta * 4.0, 0.0, 1.0)
	_oil_smooth_drain = lerp(_oil_smooth_drain, _oil_target_drain, t)
	# Bob = sloshing-ul intregii mase de ulei; aplicat identic la fill si surface
	# ca sa ramana lipite vizual fara delay.
	var bob: float = sin(_oil_bob_time * _OIL_BOB_SPEED) * _OIL_BOB_AMPLITUDE
	_oil_fill.position.y = _oil_fill_base_y + _oil_smooth_drain + bob
	_oil_surface.position.y = _oil_surface_base_y + _oil_smooth_drain + bob
	_update_oil_effects(delta)
	_update_left_hand_selection_effect()
	_update_debug_overlay(delta)

func _update_oil_effects(delta: float) -> void:
	var target_intensity: float = 1.0 if _oil_effect_lit else 0.18
	_oil_effect_intensity = lerp(_oil_effect_intensity, target_intensity, clamp(delta * 3.0, 0.0, 1.0))
	var warm_flicker: float = 0.92 + sin(_oil_bob_time * 1.55) * 0.055 + sin(_oil_bob_time * 3.7 + 0.8) * 0.025
	var low_warning: float = 1.0 - clamp(_oil_pct / _OIL_LOW_WARNING_THRESHOLD, 0.0, 1.0)
	var low_pulse: float = 0.68 + sin(_oil_bob_time * 5.2) * 0.32
	var low_t: float = clamp(low_warning * low_pulse, 0.0, 1.0)
	_oil_fill.modulate = _OIL_FILL_TINT.lerp(_OIL_FILL_LOW_TINT, low_t)
	_oil_surface.modulate = _OIL_SURFACE_TINT.lerp(_OIL_SURFACE_LOW_TINT, low_t)
	_oil_halo.modulate = _OIL_HALO_TINT.lerp(_OIL_HALO_LOW_TINT, low_t)
	_oil_halo.modulate.a = _OIL_HALO_ALPHA * _oil_effect_intensity * warm_flicker
	_oil_shadow.modulate.a = _OIL_SHADOW_ALPHA * lerp(0.78, 1.0, _oil_effect_intensity)
	for i in _oil_dust.size():
		var dust := _oil_dust[i]
		var base_pos := _oil_dust_base_positions[i]
		var phase := float(i) * 1.83
		dust.position = base_pos + Vector2(
			sin(_oil_bob_time * 0.42 + phase) * 1.4,
			sin(_oil_bob_time * 0.31 + phase * 1.7) * 3.0
		)
		var dust_alpha: float = _OIL_DUST_ALPHA * _oil_effect_intensity * (0.55 + sin(_oil_bob_time * 0.74 + phase) * 0.25)
		dust.modulate.a = max(0.0, dust_alpha)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		_debug_overlay_visible = not _debug_overlay_visible
		if _debug_panel != null:
			_debug_panel.visible = _debug_overlay_visible
		_debug_overlay_timer = 0.0
		_update_debug_overlay(debug_overlay_update_interval)
		get_viewport().set_input_as_handled()

func _setup_debug_overlay_input() -> void:
	if not InputMap.has_action("debug_overlay"):
		InputMap.add_action("debug_overlay")
	var already_mapped := false
	for ev in InputMap.action_get_events("debug_overlay"):
		if ev is InputEventKey and (ev as InputEventKey).keycode == KEY_F3:
			already_mapped = true
			break
	if not already_mapped:
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_F3
		InputMap.action_add_event("debug_overlay", key_event)

func _build_debug_overlay() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugOverlay"
	_debug_panel.visible = false
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Anchor.add_child(_debug_panel)
	_debug_panel.anchor_left = 0.0
	_debug_panel.anchor_top = 0.0
	_debug_panel.anchor_right = 0.0
	_debug_panel.anchor_bottom = 0.0
	_debug_panel.offset_left = 12.0
	_debug_panel.offset_top = 48.0
	_debug_panel.offset_right = 322.0
	_debug_panel.offset_bottom = 272.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.016, 0.012, 0.78)
	style.border_color = Color(0.78, 0.52, 0.25, 0.65)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_content_margin(SIDE_LEFT, 10.0)
	style.set_content_margin(SIDE_TOP, 8.0)
	style.set_content_margin(SIDE_RIGHT, 10.0)
	style.set_content_margin(SIDE_BOTTOM, 8.0)
	_debug_panel.add_theme_stylebox_override("panel", style)

	_debug_label = Label.new()
	_debug_label.name = "DebugText"
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.68, 0.96))
	_debug_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_debug_label.add_theme_constant_override("outline_size", 3)
	_debug_label.add_theme_font_size_override("font_size", 12)
	_debug_panel.add_child(_debug_label)

func _build_dialogue_panel() -> void:
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.name = "DialoguePanel"
	_dialogue_panel.visible = false
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Anchor.add_child(_dialogue_panel)
	_dialogue_panel.anchor_left = 0.5
	_dialogue_panel.anchor_top = 1.0
	_dialogue_panel.anchor_right = 0.5
	_dialogue_panel.anchor_bottom = 1.0
	_dialogue_panel.offset_left = -390.0
	_dialogue_panel.offset_top = -205.0
	_dialogue_panel.offset_right = 390.0
	_dialogue_panel.offset_bottom = -132.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.023, 0.014, 0.78)
	style.border_color = Color(0.72, 0.46, 0.2, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.set_content_margin(SIDE_LEFT, 18.0)
	style.set_content_margin(SIDE_TOP, 12.0)
	style.set_content_margin(SIDE_RIGHT, 18.0)
	style.set_content_margin(SIDE_BOTTOM, 12.0)
	_dialogue_panel.add_theme_stylebox_override("panel", style)

	_dialogue_label = Label.new()
	_dialogue_label.name = "DialogueText"
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72, 1.0))
	_dialogue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.86))
	_dialogue_label.add_theme_constant_override("outline_size", 5)
	_dialogue_label.add_theme_font_size_override("font_size", 18)
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_panel.add_child(_dialogue_label)

func _update_dialogue_timer(delta: float) -> void:
	if _dialogue_hide_timer <= 0.0:
		return
	_dialogue_hide_timer -= delta
	if _dialogue_hide_timer <= 0.0 and _dialogue_panel != null:
		_dialogue_panel.visible = false

func _update_debug_overlay(delta: float) -> void:
	if not _debug_overlay_visible or _debug_label == null:
		return
	_debug_overlay_timer -= delta
	if _debug_overlay_timer > 0.0:
		return
	_debug_overlay_timer = debug_overlay_update_interval

	var player := get_node_or_null(player_path) as CharacterBody3D
	var interaction := get_node_or_null(interaction_path)
	var lamp_node := _active_lamp_node
	if lamp_node == null and _inventory != null and _inventory.has_method("find_lamp"):
		lamp_node = _inventory.call("find_lamp")

	var lines: Array[String] = ["DEBUG F3"]
	if player != null:
		var hv := player.velocity
		hv.y = 0.0
		var speed: float = float(player.call("horizontal_speed")) if player.has_method("horizontal_speed") else hv.length()
		var target_speed: float = float(player.call("current_target_speed")) if player.has_method("current_target_speed") else 0.0
		var stance: String = str(player.call("current_stance_text")) if player.has_method("current_stance_text") else "-"
		var surface: String = str(player.call("current_surface_key")) if player.has_method("current_surface_key") else "-"
		var step_noise: float = float(player.call("current_step_noise")) if player.has_method("current_step_noise") else 0.0
		var accel_mult: float = float(player.call("current_acceleration_multiplier")) if player.has_method("current_acceleration_multiplier") else 1.0
		var decel_mult: float = float(player.call("current_deceleration_multiplier")) if player.has_method("current_deceleration_multiplier") else 1.0
		var bob_mult: float = float(player.call("current_head_bob_multiplier")) if player.has_method("current_head_bob_multiplier") else 1.0
		lines.append("stance: %s  floor: %s" % [stance, str(player.is_on_floor())])
		lines.append("speed: %.2f / %.2f m/s" % [speed, target_speed])
		lines.append("feel: accel %.2f  decel %.2f  bob %.2f" % [accel_mult, decel_mult, bob_mult])
		lines.append("noise: %.2f  surface: %s" % [step_noise, surface])
	else:
		lines.append("player: -")

	if lamp_node != null:
		var oil: float = float(lamp_node.get("oil_level"))
		var oil_max_value: float = maxf(1.0, float(lamp_node.get("oil_max")))
		var drain_mult: float = float(lamp_node.call("current_oil_drain_multiplier")) if lamp_node.has_method("current_oil_drain_multiplier") else 1.0
		var oil_sec: float = float(lamp_node.call("current_oil_drain_per_second")) if lamp_node.has_method("current_oil_drain_per_second") else 0.0
		var movement_mult: float = float(lamp_node.call("current_movement_oil_multiplier")) if lamp_node.has_method("current_movement_oil_multiplier") else drain_mult
		var light_strength: float = float(lamp_node.call("current_oil_light_strength")) if lamp_node.has_method("current_oil_light_strength") else 1.0
		lines.append("oil: %.1f / %.1f (%.0f%%)" % [oil, oil_max_value, oil / oil_max_value * 100.0])
		lines.append("drain: %.2f/sec  mult: %.2f" % [oil_sec, drain_mult])
		lines.append("move oil mult: %.2f  light %.2f  lit: %s" % [movement_mult, light_strength, str(lamp_node.get("is_lit"))])
	else:
		lines.append("lamp: -")

	if _inventory != null:
		var item_name: String = str(_inventory.call("current_name")) if _inventory.has_method("current_name") else "-"
		var item_id: String = str(_inventory.call("current_item_id")) if _inventory.has_method("current_item_id") else "-"
		lines.append("slot: %s [%s]" % [item_name, item_id])
	if interaction != null and interaction.has_method("current_debug_text"):
		lines.append("interact: %s" % str(interaction.call("current_debug_text")))

	_debug_label.text = "\n".join(lines)

func _on_prompt_changed(text: String, key: String = "E") -> void:
	if text.is_empty():
		_interact_label.text = ""
	else:
		var k: String = key if key != "" else "E"
		_interact_label.text = "[" + k + "]  " + text

func _on_inventory_slots_changed() -> void:
	if _inventory != null and _inventory.has_method("current_name"):
		_item_label.text = _inventory.current_name()
	_refresh_slots()
	_sync_active_lamp()

func _on_inventory_slot_selected(_index: int) -> void:
	if _inventory != null and _inventory.has_method("current_name"):
		_item_label.text = _inventory.current_name()
	_refresh_slots()
	_sync_active_lamp()

## Citeste lampa offhand din inventar si reataseaza HUD-ul la ea.
## Daca nu exista lampa, ascunde OilPhial.
func _sync_active_lamp() -> void:
	if _inventory == null:
		return
	var lamp_node: Node = null
	if _inventory.has_method("find_lamp"):
		lamp_node = _inventory.call("find_lamp")
	if lamp_node != null:
		_attach_lamp(lamp_node)
	else:
		_detach_lamp()

func _set_left_hand_slot(has_lamp: bool, lit: bool = true) -> void:
	_left_hand_icon.visible = has_lamp
	_left_hand_selected = has_lamp and _inventory != null and _inventory.has_method("is_lamp_selected") and bool(_inventory.call("is_lamp_selected"))
	if not has_lamp:
		_left_hand_slot.modulate = _SLOT_MOD_EMPTY
		_left_hand_icon.modulate = Color(1, 1, 1, 0.0)
	elif _left_hand_selected:
		_left_hand_slot.modulate = _SLOT_MOD_ACTIVE
		_left_hand_icon.modulate = Color(1.2, 1.06, 0.78, 1.0)
	elif lit:
		_left_hand_slot.modulate = _SLOT_MOD_OWNED
		_left_hand_icon.modulate = Color(1, 1, 1, 0.88)
	else:
		_left_hand_slot.modulate = _SLOT_MOD_OWNED
		_left_hand_icon.modulate = Color(0.78, 0.76, 0.68, 0.72)

func _update_left_hand_selection_effect() -> void:
	if not _left_hand_selected or _active_lamp_node == null:
		return
	var pulse: float = 1.0 + sin(_oil_bob_time * 5.0) * 0.045
	_left_hand_slot.modulate = Color(
		_SLOT_MOD_ACTIVE.r * pulse,
		_SLOT_MOD_ACTIVE.g * pulse,
		_SLOT_MOD_ACTIVE.b * pulse,
		_SLOT_MOD_ACTIVE.a
	)
	_left_hand_icon.modulate = Color(1.22 * pulse, 1.06 * pulse, 0.78 * pulse, 1.0)

func _attach_lamp(lamp_node: Node) -> void:
	if lamp_node == _active_lamp_node:
		# deja conectati — doar asiguram vizibilitatea
		_oil_phial.visible = true
		var current_lit = lamp_node.get("is_lit")
		_set_left_hand_slot(true, bool(current_lit) if current_lit != null else true)
		return
	_detach_lamp()
	_active_lamp_node = lamp_node
	if lamp_node.has_signal("oil_changed") and not lamp_node.oil_changed.is_connected(_on_oil_changed):
		lamp_node.oil_changed.connect(_on_oil_changed)
	if lamp_node.has_signal("lit_changed") and not lamp_node.lit_changed.is_connected(_on_lit_changed):
		lamp_node.lit_changed.connect(_on_lit_changed)
	# citim starea curenta a noii lampi (fiecare are oil_level propriu)
	var lvl = lamp_node.get("oil_level")
	var mx = lamp_node.get("oil_max")
	if lvl != null and mx != null:
		_on_oil_changed(float(lvl), float(mx))
	var lit = lamp_node.get("is_lit")
	if lit != null:
		_on_lit_changed(bool(lit))
	else:
		_set_left_hand_slot(true)
	_oil_phial.visible = true

func _detach_lamp() -> void:
	if _active_lamp_node != null and is_instance_valid(_active_lamp_node):
		if _active_lamp_node.has_signal("oil_changed") and _active_lamp_node.oil_changed.is_connected(_on_oil_changed):
			_active_lamp_node.oil_changed.disconnect(_on_oil_changed)
		if _active_lamp_node.has_signal("lit_changed") and _active_lamp_node.lit_changed.is_connected(_on_lit_changed):
			_active_lamp_node.lit_changed.disconnect(_on_lit_changed)
	_active_lamp_node = null
	_oil_phial.visible = false
	_set_left_hand_slot(false)

func _on_objective_changed(_id: String, text: String) -> void:
	if text == "":
		_animate_objective_out()
		return
	var was_empty: bool = _objective_label.text == "" or _objective_card.modulate.a < 0.05
	_objective_label.text = text
	if was_empty:
		_animate_objective_in()
	else:
		_animate_objective_replace()

func _kill_objective_tween() -> void:
	if _objective_tween != null and _objective_tween.is_running():
		_objective_tween.kill()
	_objective_tween = null

func _animate_objective_in() -> void:
	_kill_objective_tween()
	_objective_card.position = _objective_visible_pos + _OBJ_HIDDEN_OFFSET
	_objective_card.modulate.a = 0.0
	_objective_label.modulate.a = 0.0
	_objective_tween = create_tween().set_parallel(true)
	_objective_tween.tween_property(_objective_card, "position", _objective_visible_pos, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_objective_tween.tween_property(_objective_card, "modulate:a", 1.0, 0.45)
	_objective_tween.tween_property(_objective_label, "modulate:a", 1.0, 0.4).set_delay(0.18)

func _animate_objective_replace() -> void:
	_kill_objective_tween()
	_objective_tween = create_tween().set_parallel(true)
	_objective_tween.tween_property(_objective_label, "modulate:a", 0.0, 0.12)
	_objective_tween.chain().tween_property(_objective_label, "modulate:a", 1.0, 0.25)
	var pulse_tween := create_tween()
	pulse_tween.tween_property(_objective_card, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(_objective_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _animate_objective_out() -> void:
	_kill_objective_tween()
	_objective_tween = create_tween().set_parallel(true)
	_objective_tween.tween_property(_objective_label, "modulate:a", 0.0, 0.2)
	_objective_tween.tween_property(_objective_card, "modulate:a", 0.0, 0.32).set_delay(0.05)
	_objective_tween.tween_property(_objective_card, "position", _objective_visible_pos + _OBJ_HIDDEN_OFFSET, 0.4).set_delay(0.05).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)

func _on_dialogue_changed(text: String, duration: float) -> void:
	if _dialogue_panel == null or _dialogue_label == null:
		return
	if text.strip_edges() == "":
		_dialogue_label.text = ""
		_dialogue_panel.visible = false
		_dialogue_hide_timer = 0.0
		return
	_dialogue_label.text = text
	_dialogue_panel.visible = true
	_dialogue_hide_timer = max(0.0, duration)
