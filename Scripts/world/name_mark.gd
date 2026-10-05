class_name NameMark
extends Node3D
## A maker's name pressed into a figure's clay. Reading it remembers the name
## (the epilogue counts them). Placed by the level patch on statues, facing
## out of the clay (local -z points into it).

const READ_SOUND := preload("res://audio/sfx/impacts/cloth2.ogg")
const FONT := preload("res://assets/fonts/MaShanZheng-Seal.ttf")

@export var name_id: StringName = &""

var read := false
var _label: Label3D

func _ready() -> void:
	add_to_group(&"persistent")
	var entry := NamesDB.find(name_id)
	_label = Label3D.new()
	_label.text = "\n".join(String(entry.get("han", "")).split(""))
	_label.font = FONT
	_label.font_size = 64
	_label.pixel_size = 0.002
	_label.modulate = Color(0.16, 0.1, 0.07, 0.85)
	_label.outline_size = 0
	_label.double_sided = false
	_label.shaded = true
	# Held a little proud of the clay, so its curve doesn't swallow the
	# characters.
	_label.position = Vector3(0, 0, 0.05)
	add_child(_label)
	var body := StaticBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.35, 0.6, 0.12)
	shape.shape = box
	shape.position = Vector3(0, 0, 0.05)
	body.add_child(shape)
	var usable := DelegateUsable.new()
	usable.name = "Usable"
	usable.prompt_key = "PROMPT_READ_NAME"
	usable.highlight = false
	usable.delegate_path = ^"../.."
	body.add_child(usable)
	_refresh()

func usable_prompt(_user: Node) -> String:
	return tr("PROMPT_READ_NAME")

func usable_can_use(_user: Node) -> bool:
	return not read

func usable_use(user: Node) -> void:
	read = true
	Game.set_flag(NamesDB.flag(name_id))
	Sfx.play_at(READ_SOUND, global_position, -8.0)
	var entry := NamesDB.find(name_id)
	var hud := (user as Node).get_node_or_null("HUD")
	if hud != null and hud.has_method(&"toast"):
		hud.call(&"toast", tr("NAME_READ") % tr(String(entry.get("key", ""))))
		hud.call(&"toast", tr("NAMES_COUNT") % [NamesDB.found().size(), NamesDB.NAMES.size()])
	_refresh()

func _refresh() -> void:
	# Once read, the name stands out a little: you know it now.
	if _label != null:
		_label.modulate = Color(0.3, 0.17, 0.08, 0.95) if read else Color(0.16, 0.1, 0.07, 0.85)

func persist_save() -> Dictionary:
	return {"read": read}

func persist_load(data: Dictionary) -> void:
	read = bool(data.get("read", false))
	_refresh()
