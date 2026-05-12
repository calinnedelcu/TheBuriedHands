extends Node

signal slot_changed(index: int, item_name: String)

class ItemDef:
	var item_name: String
	var color: Color
	var size: Vector3
	var offset: Vector3
	func _init(n: String, c: Color, s: Vector3, o: Vector3) -> void:
		item_name = n
		color = c
		size = s
		offset = o

@export var tool_socket_path: NodePath

var _socket: Node3D
var _current_index: int = 0
var _spawned: Node3D = null

# Slot 0 = empty/free hand
# Slot 1..4 = placeholder tools, easily replaced by real .glb meshes later
var _items: Array[ItemDef] = [
	ItemDef.new("Mâini libere", Color(0, 0, 0, 0), Vector3.ZERO, Vector3.ZERO),
	ItemDef.new("Daltă", Color(0.7, 0.65, 0.55), Vector3(0.025, 0.025, 0.18), Vector3(0.0, 0.0, -0.05)),
	ItemDef.new("Pană de lemn", Color(0.45, 0.3, 0.18), Vector3(0.04, 0.04, 0.12), Vector3(0.0, 0.0, -0.04)),
	ItemDef.new("Cioburi de ceramică", Color(0.7, 0.55, 0.4), Vector3(0.07, 0.05, 0.07), Vector3(0.0, 0.0, -0.03)),
	ItemDef.new("Tăbliță de ceară", Color(0.55, 0.45, 0.3), Vector3(0.14, 0.01, 0.09), Vector3(0.0, 0.0, -0.06)),
]

func _ready() -> void:
	if not tool_socket_path.is_empty():
		_socket = get_node(tool_socket_path)
	_apply_slot(_current_index)

func set_slot(index: int) -> void:
	if index < 0 or index >= _items.size() or index == _current_index:
		return
	_current_index = index
	_apply_slot(index)

func current_slot() -> int:
	return _current_index

func current_name() -> String:
	return _items[_current_index].item_name

func _apply_slot(index: int) -> void:
	if _spawned != null and is_instance_valid(_spawned):
		_spawned.queue_free()
		_spawned = null
	var def := _items[index]
	if _socket != null and def.size != Vector3.ZERO:
		_spawned = _build_placeholder(def)
		_socket.add_child(_spawned)
	slot_changed.emit(index, def.item_name)

func _build_placeholder(def: ItemDef) -> Node3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = def.size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.color
	mat.roughness = 0.85
	mat.no_depth_test = true
	mat.render_priority = 8
	mi.material_override = mat
	mi.position = def.offset
	mi.name = "PlaceholderItem"
	return mi
