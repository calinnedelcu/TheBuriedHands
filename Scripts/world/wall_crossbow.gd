@tool
class_name WallCrossbow
extends Node3D
## A bronze crossbow set in a wall niche, fired by linked pressure plates.
## One shot. The bolt flies level at the crossbow's height, so crouching or
## crawling lets it pass overhead; it glances off stone armour. Cut its
## string with a chisel to disarm it.

const FIRE_SOUND := preload("res://audio/sfx/trap/crossbow_shot.mp3")
const CUT_SOUND := preload("res://audio/sfx/impacts/drawKnife1.ogg")
const MODEL := preload("res://assets/models/props/crossbow.glb")
const BRONZE := preload("res://assets/materials/props/bronze.tres")

@export var damage := 3.0
@export var bolt_speed := 42.0
@export var max_range := 40.0
## Within a hand's reach of the floor, to cut its string. A battery's (high
## in the wall behind a grille) is not.
@export var reachable := true

var armed := true
## Shot (rather than disarmed): its bolt is gone from the groove.
var fired := false
var _bolt: Node3D
var _string: MeshInstance3D

func _ready() -> void:
	_build_visual()
	if Engine.is_editor_hint():
		return
	add_to_group(&"persistent")
	var usable := $Body/Usable as DelegateUsable
	usable.hold_time = 2.0

# --- Firing --------------------------------------------------------------------------

func fire() -> void:
	if not armed:
		return
	armed = false
	fired = true
	_string.visible = false
	_bolt.visible = false
	Sfx.play_at(FIRE_SOUND, global_position, 4.0, 0.05, &"Tomb", 50.0)
	Stealth.make_noise(global_position, 20.0, self)
	Bolt.launch(get_tree().current_scene, global_position + (-global_basis.z) * 0.5, -global_basis.z, bolt_speed, damage, max_range, self)

## A battery's winch: the string drawn back, a new bolt in the groove.
func rearm() -> void:
	armed = true
	fired = false
	_string.visible = true
	_bolt.visible = true

## Looses its bolt at `target` (a battery's, at the stone pressed).
func loose_at(target: Vector3, bolt_damage: float) -> void:
	if not armed:
		return
	armed = false
	fired = true
	_string.visible = false
	_bolt.visible = false
	Sfx.play_at(FIRE_SOUND, global_position, 4.0, 0.08, &"Tomb", 50.0)
	var from := global_position + (-global_basis.z) * 0.5
	Bolt.launch(get_tree().current_scene, from, (target - from).normalized(), bolt_speed, bolt_damage, max_range, self)

# --- Usable delegate: cut the string --------------------------------------------------------

func usable_prompt(user: Node) -> String:
	if not armed or not reachable:
		return ""
	var p := user as Player
	return tr("PROMPT_DISARM") if p != null and p.inventory.has_item(&"chisel") else tr("PROMPT_NEED_CHISEL_DISARM")

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	return armed and reachable and p != null and p.inventory.has_item(&"chisel")

func usable_show_blocked(_user: Node) -> bool:
	return armed and reachable

func usable_hold_done(user: Node) -> void:
	armed = false
	_string.visible = false
	Sfx.play_at(CUT_SOUND, global_position, -2.0)
	var p := user as Player
	if p != null:
		p.viewmodel.call(&"play_use")

func persist_save() -> Dictionary:
	return {"armed": armed, "fired": fired}

func persist_load(data: Dictionary) -> void:
	armed = bool(data.get("armed", true))
	fired = bool(data.get("fired", false))
	if _string != null:
		_string.visible = armed
		_bolt.visible = not fired

# --- Visuals (built in code so the scene stays tiny) ----------------------------------------

func _build_visual() -> void:
	var root := get_node_or_null("Visual")
	if root != null:
		root.free()
	# A Qin crossbow (tools/blender/build_crossbow.py): its string and the
	# bolt in the groove come and go with the trap's state.
	root = MODEL.instantiate() as Node3D
	root.name = "Visual"
	# The tomb is built at about 1.6 times life size; so are its traps.
	root.scale = Vector3.ONE * 1.5
	add_child(root)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "Bronze":
				mi.set_surface_override_material(i, BRONZE)
	_string = root.find_child("String", true, false) as MeshInstance3D
	_bolt = root.find_child("Bolt", true, false) as Node3D
	_string.visible = armed
	_bolt.visible = not fired
