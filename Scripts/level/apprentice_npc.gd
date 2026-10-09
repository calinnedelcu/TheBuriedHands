class_name ApprenticeNpc
extends Npc
## The apprentice. Gives the opening task, and after the sealing asks for
## help: the player can leave him their lamp or keep it. Either way he hides
## in the mouth of the cold kiln once you look away; and while his master is
## with Liang, Wei's men find him there and take him down to the pen in the
## army pits (alone; together, the apprentice is the other player).

@export var lamp_prop_path: NodePath
@export var hide_spot_path: NodePath

@onready var _lamp_prop: Node3D = get_node_or_null(lamp_prop_path)

func _ready() -> void:
	super._ready()
	add_to_group(&"persistent")
	if _lamp_prop != null:
		_lamp_prop.visible = false
	Quest.step_changed.connect(_on_step_changed)

## Cowering keeps the hips where he stands: lowered onto the floor.
func _low_clips() -> Array[StringName]:
	return [&"cower"]

func _on_step_changed(step_id: StringName) -> void:
	if step_id == &"talk_liang" and not Net.active:
		Game.set_flag(&"apprentice_taken")
		_taken()

## Gone from the kiln, with the lamp if he had it (WorkersPen shows him).
func _taken() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	for body in find_children("*", "CollisionObject3D", true, false):
		(body as CollisionObject3D).collision_layer = 0
	_set_has_lamp(false)

func usable_can_use(_user: Node) -> bool:
	return not _talking and (Quest.is_at(&"talk_apprentice") or Quest.is_at(&"answer_apprentice"))

func talk(player: Player) -> void:
	if Quest.is_at(&"talk_apprentice"):
		dialogue = &"apprentice_task"
		completes_step = &"talk_apprentice"
		await super.talk(player)
	elif Quest.is_at(&"answer_apprentice"):
		await _plea(player)

func _plea(player: Player) -> void:
	_talking = true
	player.lock_controls(&"talk", false)
	_turn_toward(player.global_position)
	await Dialogue.play(&"apprentice_plea")
	var options := PackedStringArray(["CHOICE_KEEP_LAMP"])
	if player.inventory.lamp() != null:
		options = PackedStringArray(["CHOICE_GIVE_LAMP", "CHOICE_KEEP_LAMP"])
	var choice := await Dialogue.choose(options)
	if options[choice] == "CHOICE_GIVE_LAMP":
		player.inventory.give_lamp()
		Game.set_flag(&"gave_lamp")
		await Dialogue.play(&"apprentice_gave_lamp")
	else:
		await Dialogue.play(&"apprentice_kept_lamp")
	player.unlock_controls(&"talk")
	_talking = false
	_go_hide()
	Quest.complete(&"answer_apprentice")

func _set_has_lamp(value: bool) -> void:
	if _lamp_prop != null:
		_lamp_prop.visible = value

## He hides once the player has looked away (there is no path-finding for
## him, so nobody should watch him cross the floor), scared until then.
func _go_hide() -> void:
	play(&"scared")
	var spot := get_node_or_null(hide_spot_path) as Node3D
	if spot == null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	while player != null and is_inside_tree() and _seen_by(player):
		await get_tree().create_timer(0.5, false).timeout
	_snap_to_hide_spot()

func _snap_to_hide_spot() -> void:
	var spot := get_node_or_null(hide_spot_path) as Node3D
	if spot == null:
		return
	global_position = spot.global_position
	rotation.y = spot.global_rotation.y
	_base_yaw = rotation.y
	# Hidden in the kiln mouth, as far from the door as he can get: its vault
	# is 1.3 m under, too low for any sitting pose (his cower is 1.4 high
	# even set on the floor), so he crouches on hands and knees in it.
	play(&"crawl_idle")
	# The lamp you gave him burns beside him in the kiln mouth.
	_set_has_lamp(bool(Game.get_flag(&"gave_lamp")))

func _seen_by(player: Player) -> bool:
	var eye := global_position + Vector3.UP * 1.6
	if player.global_position.distance_to(global_position) > 28.0:
		return false
	return player.camera.is_position_in_frustum(eye)

func persist_save() -> Dictionary:
	return {"pos": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y, "lamp": Game.get_flag(&"gave_lamp")}

func persist_load(data: Dictionary) -> void:
	var p: Array = data.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	rotation.y = float(data.get("yaw", rotation.y))
	_set_has_lamp(bool(data.get("lamp", false)))
	if Quest.has_reached(&"find_liang"):
		_snap_to_hide_spot()
	if Quest.has_reached(&"talk_liang") and not Net.active:
		_taken()
