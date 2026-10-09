class_name TrapBattery
extends Node3D
## The crossbows set in a trapped floor's walls, high up behind bronze
## grilles, all wound by one winch. A trigger stone looses the ones nearest
## to it at whoever stands there, at the chest, the waist and the knee (no
## stance is safe from a battery). A volley is one hit: the bolts come within
## a breath of each other, inside the player's moment of grace, and one costs
## a third of a man's strength, so a wrong stone hurts and the third kills.
## The winch winds them again a few seconds later: a volley spent on a thrown
## shard buys only that long. Locked (the builders' pin), the battery never
## looses again; held slack (their brake), it can't.
##
## Its crossbows are the WallCrossbow children (out of reach: no cutting).

const WINCH := preload("res://audio/sfx/impacts/impactPlank_medium_002.ogg")
const AIM_HEIGHTS := [1.35, 0.85, 0.45, 1.1, 0.6]

## A third of the player's health (6, or 5 on the hardest setting): three
## volleys kill, two do not.
@export var bolt_damage := 2.0
@export var reload_time := 7.0
## Crossbows loosed per volley (the nearest to the stone).
@export var per_volley := 4

var armed := true
var locked := false
var slack := false
var _reload := 0.0

func _ready() -> void:
	add_to_group(&"persistent")
	for cb in crossbows():
		cb.reachable = false

func crossbows() -> Array[WallCrossbow]:
	var out: Array[WallCrossbow] = []
	for c in get_children():
		if c is WallCrossbow:
			out.append(c as WallCrossbow)
	return out

func can_loose() -> bool:
	return armed and not locked and not slack

## A volley at `at` (a man's feet, or a stone a shard landed on), led along
## `target`'s way if he is moving.
func loose_at(target: Node3D, at: Vector3) -> void:
	if not can_loose():
		return
	armed = false
	_reload = reload_time
	var aim := at
	if target is CharacterBody3D:
		aim += (target as CharacterBody3D).velocity * 0.12
	var list := crossbows()
	list.sort_custom(func(a: WallCrossbow, b: WallCrossbow) -> bool:
		return a.global_position.distance_squared_to(aim) < b.global_position.distance_squared_to(aim))
	for i in mini(per_volley, list.size()):
		# Wound, whatever a reloaded checkpoint says of each (the winch is one).
		if not list[i].armed:
			list[i].rearm()
		list[i].loose_at(aim + Vector3.UP * float(AIM_HEIGHTS[i % AIM_HEIGHTS.size()]), bolt_damage)
	Stealth.make_noise(aim, 24.0, self)

func _process(delta: float) -> void:
	if armed or locked:
		return
	_reload -= delta
	if _reload <= 0.0:
		armed = true
		for cb in crossbows():
			cb.rearm()
		Sfx.play_at(WINCH, global_position, -4.0, 0.1, &"Tomb", 30.0)

func lock() -> void:
	locked = true

func persist_save() -> Dictionary:
	return {"locked": locked}

func persist_load(data: Dictionary) -> void:
	locked = bool(data.get("locked", false))
