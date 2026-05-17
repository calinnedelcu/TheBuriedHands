extends Node

const ToolVisualsLib = preload("res://Scripts/tool_visuals.gd")

## Generic 4-slot inventory. Any picked-up tool drops into the first free slot,
## regardless of type. A world lamp can also be stored here if a scene opts in.

signal slots_changed()
signal slot_selected(index: int)

const SLOT_COUNT := 4

## Static metadata for every item type the inventory knows about.
class ItemType:
	var id: String
	var display_name: String
	var color: Color
	var size: Vector3
	var offset: Vector3
	var stackable: bool
	var is_lamp: bool
	func _init(p_id: String, p_name: String, p_color: Color, p_size: Vector3, p_offset: Vector3, p_stackable: bool = false, p_is_lamp: bool = false) -> void:
		id = p_id
		display_name = p_name
		color = p_color
		size = p_size
		offset = p_offset
		stackable = p_stackable
		is_lamp = p_is_lamp

## One occupied slot. `node` is the live instance for items that carry state
## (the lamp); placeholder tools leave it null and are rebuilt on selection.
class SlotEntry:
	var id: String
	var stack: int = 1
	var node: Node3D = null

@export var tool_socket_path: NodePath
@export var lamp_socket_path: NodePath
@export var initial_lamp_path: NodePath
## Transformul cu care orice lampa ridicata se aseaza in LampSocket.
## Setat in editor pe nodul Inventory; daca initial_lamp_path este folosit,
## se preia automat din lampa initiala (cu prioritate).
@export var lamp_equipped_transform: Transform3D = Transform3D.IDENTITY
@export var pickup_scene: PackedScene

## Per-item override for the world prop spawned when an item is dropped.
## When set, replaces the generic pickup_scene for that item id.
const _DROP_SCENE_OVERRIDES: Dictionary = {
	"clay_bowl": preload("res://scenes/items/placed_clay_bowl.tscn"),
}

var _types: Dictionary = {}
var _slots: Array = []
var _current_index: int = -1
var _tool_socket: Node3D = null
var _lamp_socket: Node3D = null
var _storage: Node3D = null
var _spawned_placeholder: Node3D = null
var _lamp_equipped_transform: Transform3D = Transform3D.IDENTITY
var _lamp_transform_captured: bool = false
## Lampa traieste in slot offhand permanent — separat de cele SLOT_COUNT
## sloturi de unelte. Mereu echipata in LampSocket cat exista.
const LAMP_SLOT_INDEX: int = -2
## Selectia speciala Z pentru offhand: lampa ramane in mana stanga, dar refill
## si drop sunt permise doar cand _current_index == LAMP_SLOT_INDEX.
var _lamp_entry: SlotEntry = null

func _set_default_lamp_transform() -> void:
	# Daca exportul are alt transform decat IDENTITY, il folosim ca default
	# fara sa fie nevoie de o lampa initiala in scena.
	if lamp_equipped_transform != Transform3D.IDENTITY:
		_lamp_equipped_transform = lamp_equipped_transform
		_lamp_transform_captured = true

func _ready() -> void:
	_register_types()
	_slots.resize(SLOT_COUNT)
	if not tool_socket_path.is_empty():
		_tool_socket = get_node_or_null(tool_socket_path)
	if not lamp_socket_path.is_empty():
		_lamp_socket = get_node_or_null(lamp_socket_path)
	_storage = Node3D.new()
	_storage.name = "InventoryStorage"
	_storage.visible = false
	_storage.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_storage)
	_set_default_lamp_transform()
	if not initial_lamp_path.is_empty():
		call_deferred("_grab_initial_lamp")

func _register_types() -> void:
	_add_type(ItemType.new("chisel", "Daltă", Color(0.7, 0.65, 0.55), Vector3(0.025, 0.025, 0.18), Vector3(0.0, 0.0, -0.05)))
	_add_type(ItemType.new("wedge", "Pană de lemn", Color(0.45, 0.3, 0.18), Vector3(0.04, 0.04, 0.12), Vector3(0.0, 0.0, -0.04)))
	_add_type(ItemType.new("ceramic", "Cioburi de ceramică", Color(0.7, 0.55, 0.4), Vector3(0.07, 0.05, 0.07), Vector3(0.0, 0.0, -0.03), true))
	_add_type(ItemType.new("hammer", "Ciocan de lemn", Color(0.45, 0.28, 0.13), Vector3(0.14, 0.07, 0.22), Vector3(0.0, 0.0, -0.06)))
	_add_type(ItemType.new("wax_tablet", "Tăbliță de ceară", Color(0.55, 0.45, 0.3), Vector3(0.14, 0.01, 0.09), Vector3(0.0, 0.0, -0.06)))
	_add_type(ItemType.new("clay_bowl", "Vas de barbotină", Color(0.55, 0.32, 0.2), Vector3.ZERO, Vector3.ZERO))
	_add_type(ItemType.new("clay_slip", "Barbotină", Color(0.62, 0.5, 0.36), Vector3.ZERO, Vector3.ZERO))
	_add_type(ItemType.new("lamp", "Lampă cu ulei", Color(0, 0, 0, 0), Vector3.ZERO, Vector3.ZERO, false, true))

	_add_type(ItemType.new("mercury_vase", "Vaza cu mercur", Color(0.42, 0.45, 0.48), Vector3.ZERO, Vector3.ZERO))
	_add_type(ItemType.new("vapor_mask", "Masca de panza", Color(0.56, 0.48, 0.36), Vector3(0.12, 0.035, 0.09), Vector3(0.0, 0.0, -0.04)))

func _add_type(t: ItemType) -> void:
	_types[t.id] = t

func _grab_initial_lamp() -> void:
	var lamp := get_node_or_null(initial_lamp_path) as Node3D
	if lamp != null:
		_capture_lamp_transform(lamp)
		add_item("lamp", lamp)

## Records the lamp's hand transform once, so it can be restored on every
## re-equip even after it has been dropped into the world.
func _capture_lamp_transform(lamp: Node3D) -> void:
	if _lamp_transform_captured:
		return
	if _lamp_socket != null and lamp.get_parent() == _lamp_socket:
		_lamp_equipped_transform = lamp.transform
		_lamp_transform_captured = true

# --- Public API -------------------------------------------------------------

## Adds an item to the first free slot. `node` is the live instance to take
## ownership of (used for the lamp); leave null for placeholder tools.
## Returns the slot index, or -1 if the type is unknown or the bag is full.
func add_item(id: String, node: Node3D = null, stack: int = 1) -> int:
	if not _types.has(id):
		if node != null:
			node.queue_free()
		return -1
	var t: ItemType = _types[id]
	if t.is_lamp:
		return _set_lamp_offhand(node)
	if t.stackable:
		for i in SLOT_COUNT:
			var existing: SlotEntry = _slots[i]
			if existing != null and existing.id == id:
				existing.stack += max(1, stack)
				if node != null:
					node.queue_free()
				slots_changed.emit()
				return i
	else:
		for i in SLOT_COUNT:
			var existing: SlotEntry = _slots[i]
			if existing != null and existing.id == id:
				if node != null:
					node.queue_free()
				slots_changed.emit()
				return i
	var idx := _first_free_slot()
	if idx < 0:
		return -1
	var entry := SlotEntry.new()
	entry.id = id
	entry.stack = max(1, stack)
	entry.node = node
	_slots[idx] = entry
	if _current_index < 0:
		_select(idx)
	else:
		if node != null:
			_store_node(node)
		slots_changed.emit()
	return idx

## Pune o lampa in slotul offhand. Daca exista deja una, o ejecteaza la sol
## langa player (auto-swap a la Minecraft). Returneaza LAMP_SLOT_INDEX.
func _set_lamp_offhand(node: Node3D) -> int:
	if node == null:
		return -1
	if _lamp_entry != null and _lamp_entry.node != null and is_instance_valid(_lamp_entry.node) and _lamp_entry.node != node:
		var old_lamp: Node3D = _lamp_entry.node
		_drop_lamp_node_to_world(old_lamp, _find_player_node())
	_lamp_entry = SlotEntry.new()
	_lamp_entry.id = "lamp"
	_lamp_entry.node = node
	_capture_lamp_transform(node)
	_equip_lamp_node(node)
	slots_changed.emit()
	return LAMP_SLOT_INDEX

func _find_player_node() -> Node:
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null

func _drop_lamp_node_to_world(lamp: Node3D, player: Node) -> void:
	var world := _drop_world(player)
	if world == null:
		return
	var xform: Transform3D = _ask_drop_transform(player, true) if player != null else Transform3D.IDENTITY
	if lamp.get_parent() != null:
		lamp.reparent(world, false)
	else:
		world.add_child(lamp)
	if player != null:
		lamp.global_transform = xform
	lamp.visible = true
	if lamp.has_method("set_equipped"):
		lamp.set_equipped(false)

## Dropeaza lampa din slotul offhand. Returneaza true daca a aruncat ceva.
func drop_lamp(player: Node) -> bool:
	if _lamp_entry == null or _lamp_entry.node == null or not is_instance_valid(_lamp_entry.node):
		return false
	_drop_lamp_node_to_world(_lamp_entry.node, player)
	_lamp_entry = null
	if _current_index == LAMP_SLOT_INDEX:
		_current_index = -1
		slot_selected.emit(_current_index)
	slots_changed.emit()
	return true

## Selects a slot (0..3), or anything else for "free hands".
func set_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or _slots[index] == null:
		_select(-1)
		return
	_select(index)

func select_lamp() -> bool:
	if find_lamp() == null:
		if _current_index == LAMP_SLOT_INDEX:
			_select(-1)
		return false
	_select(LAMP_SLOT_INDEX)
	return true

## Drops current tool, or the offhand lamp only when selected with Z.
## Lampile NU mai sunt in _slots — sunt in _lamp_entry separat.
func drop_current(player: Node) -> bool:
	if _current_index == LAMP_SLOT_INDEX:
		return drop_lamp(player)
	if _current_index < 0:
		return false
	var entry: SlotEntry = _slots[_current_index]
	if entry == null:
		return false
	var dropped_id := entry.id
	var dropped_index := _current_index
	if _spawned_placeholder != null and is_instance_valid(_spawned_placeholder):
		_spawned_placeholder.queue_free()
	_spawned_placeholder = null
	var world := _drop_world(player)
	if world == null:
		return false
	_spawn_world_pickup(entry, world, _ask_drop_transform(player, false))
	_slots[dropped_index] = null
	_current_index = -1
	_cleanup_quest_carried(dropped_id)
	slots_changed.emit()
	slot_selected.emit(-1)
	_on_item_dropped(dropped_id)
	return true

## Removes lingering held-item visuals spawned by QuestStepInteractable when
## the matching inventory entry leaves player hands.
func _cleanup_quest_carried(item_id: String) -> void:
	if _tool_socket == null:
		return
	match item_id:
		"clay_bowl":
			var held := _tool_socket.get_node_or_null("HeldClayBowl")
			if held != null:
				held.queue_free()

## Quest-specific objective advancement on drop. Kept here so the inventory
## drop API stays single-source-of-truth for tutorial step progression.
func _on_item_dropped(item_id: String) -> void:
	if item_id != "clay_bowl":
		return
	# Advance objective FIRST. Daca tutorialul de lampa ruleaza dupa, va captura
	# "take_clay_slip" ca saved_id si nu va mai trimite jucatorul inapoi sa
	# repete drop_clay_bowl dupa refill.
	var objectives := get_node_or_null("/root/Objectives")
	if objectives != null and objectives.has_method("current_id"):
		if str(objectives.call("current_id")) == "drop_clay_bowl" and objectives.has_method("set_objective"):
			objectives.call("set_objective", "take_clay_slip", "Ia barbotina din bol.")
	var events := get_node_or_null("/root/GameEvents")
	if events != null and events.has_method("request_lamp_tutorial"):
		events.request_lamp_tutorial()

## Removes one unit from the active stackable slot (e.g. a thrown ceramic shard).
func consume_current_stack() -> bool:
	if _current_index < 0:
		return false
	var entry: SlotEntry = _slots[_current_index]
	if entry == null:
		return false
	var t: ItemType = _types[entry.id]
	if not t.stackable or entry.stack <= 0:
		return false
	entry.stack -= 1
	if entry.stack <= 0:
		_slots[_current_index] = null
		_select(-1)
	else:
		slots_changed.emit()
	return true

# --- Queries (used by HUD, interactables, player) ---------------------------

func slot_count() -> int:
	return SLOT_COUNT

func current_slot() -> int:
	return _current_index

func current_item_id() -> String:
	if _current_index == LAMP_SLOT_INDEX and find_lamp() != null:
		return "lamp"
	if _current_index < 0:
		return ""
	var entry: SlotEntry = _slots[_current_index]
	return entry.id if entry != null else ""

func current_name() -> String:
	var id := current_item_id()
	if id == "" or not _types.has(id):
		return "Mâini libere"
	return (_types[id] as ItemType).display_name

func slot_item_id(index: int) -> String:
	if index < 0 or index >= SLOT_COUNT or _slots[index] == null:
		return ""
	return _slots[index].id

func slot_display_name(index: int) -> String:
	var id := slot_item_id(index)
	if id == "" or not _types.has(id):
		return ""
	return (_types[id] as ItemType).display_name

func slot_stack(index: int) -> int:
	if index < 0 or index >= SLOT_COUNT or _slots[index] == null:
		return 0
	return _slots[index].stack

func has_item(id: String) -> bool:
	for i in SLOT_COUNT:
		if _slots[i] != null and _slots[i].id == id:
			return true
	return false

## Removes the first slot holding `id` (no world drop). Used by quest steps that
## consume the item silently (e.g. applying barbotină onto the soldier).
func remove_item(id: String) -> bool:
	for i in SLOT_COUNT:
		var entry: SlotEntry = _slots[i]
		if entry == null or entry.id != id:
			continue
		if _current_index == i:
			_clear_active_view()
			_current_index = -1
			slot_selected.emit(-1)
		if entry.node != null and is_instance_valid(entry.node):
			entry.node.queue_free()
		_slots[i] = null
		slots_changed.emit()
		return true
	return false

func release_node_item(node: Node3D) -> bool:
	if node == null:
		return false
	for i in SLOT_COUNT:
		var entry: SlotEntry = _slots[i]
		if entry == null or entry.node != node:
			continue
		_slots[i] = null
		if _current_index == i:
			_current_index = -1
			slot_selected.emit(-1)
		slots_changed.emit()
		return true
	return false

## Returns the lamp instance from the offhand slot, else null.
func find_lamp() -> Node:
	if _lamp_entry != null and _lamp_entry.node != null and is_instance_valid(_lamp_entry.node):
		return _lamp_entry.node
	return null

func is_lamp_selected() -> bool:
	return _current_index == LAMP_SLOT_INDEX and find_lamp() != null

## Returns the lamp instance only while the offhand lamp is selected with Z.
## `find_lamp()` is still available for HUD/state queries.
func active_lamp() -> Node:
	return find_lamp() if is_lamp_selected() else null

# --- Internals --------------------------------------------------------------

func _first_free_slot() -> int:
	for i in SLOT_COUNT:
		if _slots[i] == null:
			return i
	return -1

func _select(index: int) -> void:
	if index == _current_index:
		return
	_clear_active_view()
	_current_index = index
	_apply_active_view()
	slots_changed.emit()
	slot_selected.emit(_current_index)

func _clear_active_view() -> void:
	if _spawned_placeholder != null and is_instance_valid(_spawned_placeholder):
		_spawned_placeholder.queue_free()
	_spawned_placeholder = null
	if _current_index == LAMP_SLOT_INDEX and find_lamp() != null:
		var lamp_node := find_lamp()
		if lamp_node.has_method("set_selected"):
			lamp_node.set_selected(false)
		if lamp_node.has_method("set_raised"):
			lamp_node.set_raised(false)
	if _current_index >= 0 and _current_index < SLOT_COUNT:
		var entry: SlotEntry = _slots[_current_index]
		if entry != null and entry.node != null:
			_store_node(entry.node)

func _apply_active_view() -> void:
	if _current_index == LAMP_SLOT_INDEX:
		if find_lamp() != null:
			var lamp_node := find_lamp()
			if lamp_node.has_method("set_selected"):
				lamp_node.set_selected(true)
		return
	if _current_index < 0 or _current_index >= SLOT_COUNT:
		return
	var entry: SlotEntry = _slots[_current_index]
	if entry == null:
		_current_index = -1
		return
	var t: ItemType = _types[entry.id]
	# Lampile nu intra in _slots — sunt in _lamp_entry separat. Aici doar unelte.
	if entry.node != null and _tool_socket != null:
		if entry.node.has_method("set_equipped"):
			entry.node.set_equipped(true)
		if entry.node.get_parent() != _tool_socket:
			if entry.node.get_parent() != null:
				entry.node.reparent(_tool_socket, false)
			else:
				_tool_socket.add_child(entry.node)
		entry.node.visible = true
		return
	if t.size != Vector3.ZERO and _tool_socket != null:
		_spawned_placeholder = ToolVisualsLib.build_for_item_id(entry.id, true)
		if _spawned_placeholder == null:
			_spawned_placeholder = _build_placeholder(t)
		_tool_socket.add_child(_spawned_placeholder)

## Parks an item instance in the hidden storage node (process is disabled there).
func _store_node(node: Node3D) -> void:
	if node.get_parent() == _storage:
		return
	if node.get_parent() != null:
		node.reparent(_storage, false)
	else:
		_storage.add_child(node)
	if node.has_method("set_stored"):
		node.set_stored()

func _equip_lamp_node(lamp: Node3D) -> void:
	if _lamp_socket == null:
		return
	if lamp.get_parent() != _lamp_socket:
		if lamp.get_parent() != null:
			lamp.reparent(_lamp_socket, false)
		else:
			_lamp_socket.add_child(lamp)
	lamp.transform = _lamp_equipped_transform
	lamp.visible = true
	if lamp.has_method("set_equipped"):
		lamp.set_equipped(true)

func _build_placeholder(t: ItemType) -> Node3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = t.size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = t.color
	mat.roughness = 0.85
	mat.no_depth_test = true
	mat.render_priority = 8
	mi.material_override = mat
	mi.position = t.offset
	mi.name = "PlaceholderItem"
	return mi

func _drop_world(player: Node) -> Node:
	if player != null and player.is_inside_tree():
		var current := player.get_tree().current_scene
		if current != null:
			return current
	return get_tree().current_scene

func _ask_drop_transform(player: Node, scaled: bool) -> Transform3D:
	if player != null and player.has_method("get_drop_transform"):
		return player.get_drop_transform(scaled)
	return Transform3D.IDENTITY

func _spawn_world_pickup(entry: SlotEntry, world: Node, xform: Transform3D) -> void:
	if entry.node != null and is_instance_valid(entry.node):
		if entry.node.get_parent() != null:
			entry.node.reparent(world, false)
		else:
			world.add_child(entry.node)
		entry.node.global_transform = xform
		entry.node.visible = true
		if entry.node.has_method("set_equipped"):
			entry.node.call("set_equipped", false)
		return
	var override_scene: PackedScene = _DROP_SCENE_OVERRIDES.get(entry.id, null)
	if override_scene != null:
		var override_node := override_scene.instantiate()
		world.add_child(override_node)
		if override_node is Node3D:
			(override_node as Node3D).global_transform = xform
		return
	if pickup_scene == null:
		return
	var pickup := pickup_scene.instantiate()
	if "kind" in pickup:
		pickup.kind = 0
	if "item_id" in pickup:
		pickup.item_id = entry.id
	if "stack" in pickup:
		pickup.stack = entry.stack
	if "custom_prompt" in pickup:
		pickup.custom_prompt = ""
	world.add_child(pickup)
	if pickup is Node3D:
		(pickup as Node3D).global_transform = xform
