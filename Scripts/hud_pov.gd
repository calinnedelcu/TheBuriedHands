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

func _ready() -> void:
	_interact_label.text = ""
	_oil_bar.max_value = 100.0
	_oil_bar.value = 100.0

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
			inv.slot_changed.connect(_on_slot_changed)
			if inv.has_method("current_name"):
				_item_label.text = inv.current_name()
	if not player_path.is_empty():
		var p := get_node_or_null(player_path)
		if p != null and p.has_signal("stance_changed"):
			p.stance_changed.connect(_on_stance_changed)

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

func _on_stance_changed(stance: String) -> void:
	_stance_label.text = stance
