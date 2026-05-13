extends CanvasLayer

@export var player_path: NodePath
@export var lamp_path: NodePath
@export var interaction_path: NodePath
@export var inventory_path: NodePath

@onready var _oil_bar: ProgressBar = $Anchor/Bottom/OilBar
@onready var _interact_label: Label = $Anchor/Center/InteractLabel
@onready var _item_label: Label = $Anchor/Bottom/ItemLabel
@onready var _stance_label: Label = $Anchor/TopLeft/StanceLabel
@onready var _dot: Panel = $Anchor/Center/CrosshairDot
@onready var _objective_label: Label = $Anchor/TopRight/ObjectiveLabel
@onready var _slot_panels: Array[Panel] = [
	$Anchor/Bottom/SlotBar/Slot1,
	$Anchor/Bottom/SlotBar/Slot2,
	$Anchor/Bottom/SlotBar/Slot3,
	$Anchor/Bottom/SlotBar/Slot4,
]
@onready var _ceramic_count_label: Label = $Anchor/Bottom/SlotBar/Slot3/Count

var _slot_empty_style: StyleBox
var _slot_owned_style: StyleBox
var _slot_active_style: StyleBox
var _inventory: Node = null

func _ready() -> void:
	_interact_label.text = ""
	_oil_bar.max_value = 100.0
	_oil_bar.value = 100.0
	_objective_label.text = ""
	_ceramic_count_label.text = ""
	_slot_empty_style = _slot_panels[0].get_theme_stylebox("panel")
	_slot_owned_style = _make_style(Color(0.18, 0.13, 0.07, 0.85), Color(0.85, 0.6, 0.28, 0.85), 1)
	_slot_active_style = _make_style(Color(0.45, 0.28, 0.12, 0.95), Color(1, 0.85, 0.45, 1), 2)

	if has_node("/root/Objectives"):
		var obj := get_node("/root/Objectives")
		obj.objective_changed.connect(_on_objective_changed)
		var current_text: String = obj.current_text()
		if current_text != "":
			_objective_label.text = current_text

	if not lamp_path.is_empty():
		var lamp := get_node_or_null(lamp_path)
		if lamp != null:
			lamp.oil_changed.connect(_on_oil_changed)
			lamp.lit_changed.connect(_on_lit_changed)
	if not interaction_path.is_empty():
		var inter := get_node_or_null(interaction_path)
		if inter != null:
			inter.prompt_changed.connect(_on_prompt_changed)
	if not inventory_path.is_empty():
		var inv := get_node_or_null(inventory_path)
		if inv != null:
			_inventory = inv
			inv.slot_changed.connect(_on_slot_changed)
			if inv.has_signal("slot_acquired"):
				inv.slot_acquired.connect(_on_slot_acquired)
			if inv.has_signal("ceramic_changed"):
				inv.ceramic_changed.connect(_on_ceramic_changed)
			if inv.has_method("current_name"):
				_item_label.text = inv.current_name()
			_refresh_slots()
	if not player_path.is_empty():
		var p := get_node_or_null(player_path)
		if p != null and p.has_signal("stance_changed"):
			p.stance_changed.connect(_on_stance_changed)

func _make_style(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_top = border_w
	s.border_width_right = border_w
	s.border_width_bottom = border_w
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_right = 4
	s.corner_radius_bottom_left = 4
	return s

func _refresh_slots() -> void:
	if _inventory == null:
		return
	var current_slot: int = _inventory.current_slot() if _inventory.has_method("current_slot") else 0
	for i in _slot_panels.size():
		var slot_index: int = i + 1
		var panel: Panel = _slot_panels[i]
		var label: Label = panel.get_node("Label") as Label
		var acquired: bool = _inventory.has_method("is_acquired") and _inventory.is_acquired(slot_index)
		var active: bool = slot_index == current_slot
		var style: StyleBox = _slot_empty_style
		var label_alpha: float = 0.4
		if active:
			style = _slot_active_style
			label_alpha = 1.0
		elif acquired:
			style = _slot_owned_style
			label_alpha = 0.9
		panel.add_theme_stylebox_override("panel", style)
		var c: Color = label.get_theme_color("font_color")
		c.a = label_alpha
		label.add_theme_color_override("font_color", c)
	if _inventory.has_method("ceramic_count"):
		var n: int = _inventory.ceramic_count()
		_ceramic_count_label.text = ("×%d" % n) if n > 0 else ""

func _on_oil_changed(level: float, max_level: float) -> void:
	_oil_bar.max_value = max_level
	_oil_bar.value = level

func _on_lit_changed(lit: bool) -> void:
	_oil_bar.modulate.a = 1.0 if lit else 0.45

func _on_prompt_changed(text: String) -> void:
	if text.is_empty():
		_interact_label.text = ""
	else:
		_interact_label.text = "[F]  " + text

func _on_slot_changed(_index: int, item_name: String) -> void:
	_item_label.text = item_name
	_refresh_slots()

func _on_slot_acquired(_index: int, _item_name: String) -> void:
	_refresh_slots()

func _on_ceramic_changed(_count: int) -> void:
	_refresh_slots()

func _on_stance_changed(stance: String) -> void:
	_stance_label.text = stance

func _on_objective_changed(_id: String, text: String) -> void:
	_objective_label.text = text
