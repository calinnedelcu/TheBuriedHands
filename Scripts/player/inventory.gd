class_name Inventory
extends Node
## Four hand slots, key items carried in the satchel (cloth, register), and the
## oil lamp in the left hand. Handles the item-related input too.

signal changed
signal selection_changed(index: int)
signal lamp_changed(lamp: HeldLamp)
signal item_added(item: ItemData, count: int)
signal message(text_key: String)

const SLOTS := 4
const LAMP_SCENE := preload("res://scenes/player/held_lamp.tscn")
const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const THROWN_SCRIPT := preload("res://Scripts/items/thrown_item.gd")

@export var lamp_socket_path: NodePath
@export var throw_speed := 13.0

## Each slot is null or {"id": StringName, "count": int}.
var slots: Array = []
var key_items: Dictionary = {}
var selected := -1

var _lamp: HeldLamp = null
@onready var _player: Player = get_parent() as Player
@onready var _lamp_socket: Node3D = get_node_or_null(lamp_socket_path)

func _ready() -> void:
	slots.resize(SLOTS)
	add_to_group(&"persistent")

# --- Queries ------------------------------------------------------------------------

func lamp() -> HeldLamp:
	return _lamp

func has_item(id: StringName) -> bool:
	return count_of(id) > 0

## Whether `add(id, count)` would succeed.
func has_room_for(id: StringName, count := 1) -> bool:
	var item := ItemDB.get_item(id)
	if item == null:
		return false
	if item.key_item:
		return true
	for s in slots:
		if s == null or (s["id"] == id and int(s["count"]) + count <= item.max_stack):
			return true
	return false

func count_of(id: StringName) -> int:
	var total: int = key_items.get(id, 0)
	for s in slots:
		if s != null and s["id"] == id:
			total += int(s["count"])
	return total

func selected_item() -> ItemData:
	if selected < 0 or slots[selected] == null:
		return null
	return ItemDB.get_item(slots[selected]["id"])

func slot_item(index: int) -> ItemData:
	return ItemDB.get_item(slots[index]["id"]) if slots[index] != null else null

func slot_count(index: int) -> int:
	return int(slots[index]["count"]) if slots[index] != null else 0

# --- Mutations ----------------------------------------------------------------------

## Adds `count` of an item. Returns false (and says why) if there is no room.
func add(id: StringName, count := 1) -> bool:
	var item := ItemDB.get_item(id)
	if item == null:
		push_warning("Unknown item: %s" % id)
		return false
	if item.key_item:
		key_items[id] = int(key_items.get(id, 0)) + count
		_after_add(item, count)
		return true
	for i in SLOTS:
		var s = slots[i]
		if s != null and s["id"] == id and int(s["count"]) < item.max_stack:
			s["count"] = mini(item.max_stack, int(s["count"]) + count)
			_after_add(item, count)
			return true
	for i in SLOTS:
		if slots[i] == null:
			slots[i] = {"id": id, "count": count}
			_after_add(item, count)
			if selected < 0:
				select(i)
			return true
	message.emit("INVENTORY_FULL")
	return false

func remove(id: StringName, count := 1) -> bool:
	if key_items.has(id):
		key_items[id] = int(key_items[id]) - count
		if int(key_items[id]) <= 0:
			key_items.erase(id)
		changed.emit()
		return true
	for i in SLOTS:
		var s = slots[i]
		if s != null and s["id"] == id:
			s["count"] = int(s["count"]) - count
			if int(s["count"]) <= 0:
				slots[i] = null
				if selected == i:
					select(-1)
			changed.emit()
			return true
	return false

## Replaces an item in place (e.g. the empty jar becoming a full one).
func replace(old_id: StringName, new_id: StringName) -> bool:
	for i in SLOTS:
		if slots[i] != null and slots[i]["id"] == old_id:
			slots[i] = {"id": new_id, "count": slots[i]["count"]}
			changed.emit()
			if selected == i:
				selection_changed.emit(selected)
			return true
	return false

func select(index: int) -> void:
	if index >= 0 and (index >= SLOTS or slots[index] == null):
		return
	if index == selected:
		return
	selected = index
	selection_changed.emit(selected)
	changed.emit()

func cycle(direction: int) -> void:
	var options: Array[int] = [-1]
	for i in SLOTS:
		if slots[i] != null:
			options.append(i)
	var pos := options.find(selected)
	select(options[wrapi(pos + direction, 0, options.size())])

## Equips a lamp with the given oil (from a stand, a sconce, or a save).
func take_lamp(oil: float, lit := true) -> void:
	if _lamp == null:
		_lamp = LAMP_SCENE.instantiate() as HeldLamp
		_lamp_socket.add_child(_lamp)
		ViewmodelMaterial.apply(_lamp)
		_lamp.set_holder(_player)
	_lamp.set_state(oil, lit)
	lamp_changed.emit(_lamp)
	changed.emit()

## Removes the lamp from the hand and returns its state.
func give_lamp() -> Dictionary:
	if _lamp == null:
		return {}
	var state := _lamp.persist_state()
	_lamp.queue_free()
	_lamp = null
	lamp_changed.emit(null)
	changed.emit()
	return state

func drop_selected() -> void:
	var item := selected_item()
	if item == null or not item.droppable:
		return
	var origin := _player.global_position + (-_player.global_basis.z * 1.2) + Vector3.UP * 0.4
	var floor := _floor_below(origin)
	remove(item.id, 1)
	var pickup := PICKUP_SCENE.instantiate()
	pickup.set(&"item_id", item.id)
	_player.get_parent().add_child(pickup)
	pickup.global_position = floor
	pickup.rotation.y = randf() * TAU
	Stealth.make_noise(floor, 4.0, _player)

func throw_selected() -> void:
	var item := selected_item()
	if item == null or not item.throwable:
		return
	remove(item.id, 1)
	var body := RigidBody3D.new()
	body.set_script(THROWN_SCRIPT)
	body.set(&"item_id", item.id)
	_player.get_parent().add_child(body)
	var cam := _player.camera
	body.global_position = cam.global_position + (-cam.global_basis.z * 0.6) + Vector3.DOWN * 0.15
	body.linear_velocity = -cam.global_basis.z * throw_speed + Vector3.UP * 2.2 + _player.velocity * 0.5
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))

func _after_add(item: ItemData, count: int) -> void:
	changed.emit()
	item_added.emit(item, count)

func _floor_below(from: Vector3) -> Vector3:
	var params := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0, 1)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(params)
	return hit.position if not hit.is_empty() else from

# --- Input ----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _player.controls_locked():
		return
	for i in SLOTS:
		if event.is_action_pressed(StringName("slot_%d" % (i + 1))):
			select(i if selected != i else -1)
			return
	if event.is_action_pressed(&"holster"):
		select(-1)
	elif event.is_action_pressed(&"next_item"):
		cycle(1)
	elif event.is_action_pressed(&"prev_item"):
		cycle(-1)
	elif event.is_action_pressed(&"drop"):
		drop_selected()
	elif event.is_action_pressed(&"throw"):
		throw_selected()
	elif event.is_action_pressed(&"toggle_lamp") and _lamp != null:
		_lamp.toggle()
	elif event.is_action_pressed(&"raise_lamp") and _lamp != null:
		_lamp.is_raised = true
	elif event.is_action_released(&"raise_lamp") and _lamp != null:
		_lamp.is_raised = false

# --- Persistence ------------------------------------------------------------------------

func persist_save() -> Dictionary:
	var saved_slots := []
	for s in slots:
		saved_slots.append({"id": String(s["id"]), "count": s["count"]} if s != null else null)
	var keys := {}
	for k in key_items:
		keys[String(k)] = key_items[k]
	return {
		"slots": saved_slots,
		"keys": keys,
		"selected": selected,
		"lamp": _lamp.persist_state() if _lamp != null else null,
	}

func persist_load(data: Dictionary) -> void:
	slots.clear()
	slots.resize(SLOTS)
	var saved: Array = data.get("slots", [])
	for i in mini(saved.size(), SLOTS):
		if saved[i] != null:
			slots[i] = {"id": StringName(saved[i]["id"]), "count": int(saved[i]["count"])}
	key_items.clear()
	var keys: Dictionary = data.get("keys", {})
	for k in keys:
		key_items[StringName(k)] = int(keys[k])
	var lamp_state = data.get("lamp")
	if lamp_state is Dictionary:
		take_lamp(float(lamp_state.get("oil", 50.0)), bool(lamp_state.get("lit", true)))
	elif _lamp != null:
		give_lamp()
	selected = -1
	select(int(data.get("selected", -1)))
	changed.emit()
