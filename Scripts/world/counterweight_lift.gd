class_name CounterweightLift
extends Node3D
## The workers' lift in the shaft: a timber platform on ropes over a pulley,
## balanced by a basket of stones hanging on the other side. Release the brake
## and it goes the way the weight says: down when the platform (whoever stands
## on it, plus its ballast) outweighs the basket, up when it's lighter. The
## master alone is too light to go down; a stone or two in the ballast box,
## or his apprentice beside him, tips it. It creaks the whole way, and the
## guards below can hear it.
##
## A rope by each stop works the same brake from there, to call it up or send
## it down; it goes only if the weight says so.
##
## The origin is the top of the platform at its upper stop (level with the
## landing); the lower stop is `travel` below. Built in code: the platform,
## its railing, brake and ballast box, the basket, the ropes and the pulley,
## and the brake ropes at the stops.

const TIMBER := preload("res://assets/materials/level/timber.tres")
const ROCK := preload("res://assets/materials/level/tunnel_rock.tres")
const CREAKS := [preload("res://audio/sfx/impacts/creak1.ogg"), preload("res://audio/sfx/impacts/creak2.ogg"), preload("res://audio/sfx/impacts/creak3.ogg")]
const STONE_SOUNDS := [preload("res://audio/sfx/impacts/impactMining_000.ogg"), preload("res://audio/sfx/impacts/impactMining_001.ogg")]
const THUD := preload("res://audio/sfx/impacts/impactPlank_medium_002.ogg")
const BRAKE_SOUND := preload("res://audio/sfx/impacts/impactPlank_medium_000.ogg")

## Weights, in "men": the master is one, his apprentice a little over half.
const MASTER_WEIGHT := 1.0
const APPRENTICE_WEIGHT := 0.6
const STONE_WEIGHT := 0.5
const MAX_BALLAST := 3

@export var travel := 17.4
@export var counterweight := 1.2
@export var speed := 1.4
@export var platform_size := Vector2(4.6, 4.6)
## Side of the platform the basket hangs on (local x).
@export var basket_offset := 4.2
## How far guards hear it moving.
@export var noise_radius := 16.0
## Where the brake ropes hang, in the lift's space: by the upper stop (on the
## landing) and by the lower one (`travel` further down).
@export var call_top := Vector3(-2.9, 0.0, -3.0)
@export var call_bottom := Vector3(-1.6, 0.0, 3.6)

## 0 at the top stop, 1 at the bottom.
var level := 0.0
var ballast := 0
var brake := true
## +1 going down, -1 going up, 0 still.
var moving := 0

var _platform: AnimatableBody3D
var _riders: Area3D
var _basket: Node3D
var _ropes: Array[MeshInstance3D] = []
var _rope_tops: Array[Vector3] = []
var _stones: Array[Node3D] = []
var _brake_arm: Node3D
var _audio: AudioStreamPlayer3D
var _creak_timer := 0.0
var _brake_usable: DelegateUsable
var _ballast_usable: DelegateUsable

func _ready() -> void:
	add_to_group(&"persistent")
	_build()
	_apply()

# --- Weight and motion --------------------------------------------------------------

func load_weight() -> float:
	var w := ballast * STONE_WEIGHT
	for b in _riders.get_overlapping_bodies():
		if b is Player and not (b as Player).downed:
			w += APPRENTICE_WEIGHT if (b as Player).role == &"apprentice" else MASTER_WEIGHT
	return w

## Which way it would go with the brake off right now: +1, -1 or 0.
func pull() -> int:
	var w := load_weight()
	if w > counterweight + 0.05 and level < 1.0:
		return 1
	if w < counterweight - 0.05 and level > 0.0:
		return -1
	return 0

func _physics_process(delta: float) -> void:
	if moving == 0:
		return
	level = clampf(level + moving * speed * delta / travel, 0.0, 1.0)
	_apply()
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = randf_range(1.1, 1.7)
		_audio.stream = CREAKS.pick_random()
		_audio.pitch_scale = randf_range(0.85, 1.05)
		_audio.play()
		if not Net.is_client():
			# Heard from below, louder as it comes down: the guards come to the
			# foot of the shaft, not to a point in mid-air.
			Stealth.make_noise(global_position + Vector3.DOWN * travel, noise_radius * (0.5 + 0.5 * level), self)
	if (moving > 0 and level >= 1.0) or (moving < 0 and level <= 0.0):
		_arrive()

func _start(direction: int) -> void:
	moving = direction
	brake = direction == 0
	_creak_timer = 0.0
	_swing_brake(not brake)

func _arrive() -> void:
	moving = 0
	brake = true
	_swing_brake(false)
	Sfx.play_at(THUD, _platform.global_position, 2.0, 0.06, &"Tomb", 30.0)
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p != null and _riders.overlaps_body(p):
		p.add_shake(0.25)

## Co-op: the host decided where it goes; this machine follows.
func net_move(direction: int, from_level: float) -> void:
	level = from_level
	_start(direction)
	_apply()

func _apply() -> void:
	var y := -travel * level
	_platform.position = Vector3(0, y, 0)
	# The basket rides the other way: at the bottom when the platform is up.
	_basket.position = Vector3(basket_offset, -travel - y + 0.6, 0)
	_place_ropes()

# --- Usables: the brake and the ballast box --------------------------------------------

func brake_prompt(_user: Node) -> String:
	if moving != 0:
		return ""
	return tr("PROMPT_LIFT_RELEASE")

func brake_can_use(_user: Node) -> bool:
	return moving == 0

func brake_use(user: Node) -> void:
	Sfx.play_at(BRAKE_SOUND, _brake_arm.global_position, -2.0)
	# The host (or the only machine) weighs the load and sets it going.
	if Net.is_client():
		return
	var dir := pull()
	if dir == 0:
		_strain(user)
		Net.mirror(self, &"net_strain", [String(user.name) if user != null else ""])
		return
	Net.mirror(self, &"net_move", [dir, level])
	_start(dir)

## Nothing happens: it groans against the brake and stays. Whoever pulled,
## or is riding it, is told why.
func _strain(user: Node) -> void:
	_audio.stream = CREAKS[0]
	_audio.pitch_scale = 0.7
	_audio.play()
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p == null or not (p == user or _riders.overlaps_body(p)):
		return
	var hud := p.get_node_or_null("HUD")
	if hud != null and hud.has_method(&"toast"):
		hud.call(&"toast", tr("LIFT_TOO_LIGHT" if level < 1.0 else "LIFT_TOO_HEAVY"))

func net_strain(user_name: String) -> void:
	var user: Node = null
	for p in Net.players():
		if String(p.name) == user_name:
			user = p
	_strain(user)

## The ropes at the stops: the same brake, pulled from there.
func call_prompt(_user: Node) -> String:
	return "" if moving != 0 else tr("PROMPT_LIFT_CALL")

func call_can_use(user: Node) -> bool:
	return brake_can_use(user)

func call_use(user: Node) -> void:
	brake_use(user)

func ballast_prompt(_user: Node) -> String:
	if moving != 0:
		return ""
	var parts: Array[String] = []
	if ballast > 0:
		parts.append(tr("PROMPT_LIFT_REMOVE_STONE"))
	if ballast < MAX_BALLAST:
		parts.append("%s: %s" % [tr("HUD_HOLD"), tr("PROMPT_LIFT_ADD_STONE")])
	return "  ·  ".join(parts) + "  (%d/%d)" % [ballast, MAX_BALLAST]

func ballast_can_use(_user: Node) -> bool:
	return moving == 0

func ballast_tap(_user: Node) -> void:
	if ballast <= 0 or moving != 0:
		return
	ballast -= 1
	_show_stones()
	Sfx.play_random_at(STONE_SOUNDS, _platform.global_position, -4.0)

func ballast_hold_done(_user: Node) -> void:
	if ballast >= MAX_BALLAST or moving != 0:
		return
	ballast += 1
	_show_stones()
	Sfx.play_random_at(STONE_SOUNDS, _platform.global_position, 0.0)
	if not Net.is_client():
		Stealth.make_noise(_platform.global_position, 6.0, self)

func persist_save() -> Dictionary:
	return {"level": level, "ballast": ballast}

func persist_load(data: Dictionary) -> void:
	level = clampf(float(data.get("level", level)), 0.0, 1.0)
	# Back from a checkpoint it is always resting at a stop.
	level = 1.0 if level > 0.5 else 0.0
	ballast = clampi(int(data.get("ballast", ballast)), 0, MAX_BALLAST)
	moving = 0
	brake = true
	_show_stones()
	_apply()

# --- Building ---------------------------------------------------------------------------

func _build() -> void:
	var hx := platform_size.x * 0.5
	var hz := platform_size.y * 0.5
	_platform = AnimatableBody3D.new()
	_platform.name = "Platform"
	_platform.sync_to_physics = true
	add_child(_platform)
	_box(_platform, Vector3(platform_size.x, 0.3, platform_size.y), Vector3(0, -0.15, 0), TIMBER, true)
	# Two beams under the planks, posts at the corners, a rail on two sides
	# (the landing side and the side facing the pits stay open).
	for z in [-hz + 0.3, hz - 0.3]:
		_box(_platform, Vector3(platform_size.x, 0.25, 0.3), Vector3(0, -0.42, z), TIMBER, false)
	for c in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
		_box(_platform, Vector3(0.2, 1.6, 0.2), Vector3(c.x * 0.96, 0.8, c.y * 0.96), TIMBER, false)
	_box(_platform, Vector3(platform_size.x, 0.12, 0.12), Vector3(0, 1.2, -hz * 0.96), TIMBER, true)
	_box(_platform, Vector3(0.12, 0.12, platform_size.y), Vector3(hx * 0.96, 1.2, 0), TIMBER, true)
	# The brake: a lever at the north-east corner.
	_brake_arm = Node3D.new()
	_brake_arm.position = Vector3(hx - 0.6, 0.3, -hz + 0.5)
	_platform.add_child(_brake_arm)
	var arm := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.05
	rod.bottom_radius = 0.06
	rod.height = 1.4
	arm.mesh = rod
	arm.material_override = TIMBER
	arm.position = Vector3(0, 0.7, 0)
	_brake_arm.add_child(arm)
	_brake_usable = _usable_body(_platform, "BrakeBody", Vector3(0.6, 1.6, 0.6), _brake_arm.position + Vector3(0, 0.8, 0), &"brake", 0.0)
	# The ballast box: a low crate along the east rail.
	_box(_platform, Vector3(0.9, 0.5, 2.4), Vector3(hx - 0.6, 0.25, 0.6), TIMBER, true)
	_ballast_usable = _usable_body(_platform, "BallastBody", Vector3(1.0, 0.9, 2.5), Vector3(hx - 0.6, 0.45, 0.6), &"ballast", 1.4)
	_ballast_usable.tap_enabled = true
	for i in MAX_BALLAST:
		var s := _box(_platform, Vector3(0.55, 0.4, 0.55), Vector3(hx - 0.6, 0.62, -0.1 + i * 0.7), ROCK, false)
		s.visible = false
		_stones.append(s)
	# Who is standing on it.
	_riders = Area3D.new()
	_riders.name = "Riders"
	_riders.collision_layer = 0
	_riders.collision_mask = 2
	_riders.monitorable = false
	var area_shape := CollisionShape3D.new()
	var area_box := BoxShape3D.new()
	area_box.size = Vector3(platform_size.x, 2.4, platform_size.y)
	area_shape.shape = area_box
	area_shape.position = Vector3(0, 1.25, 0)
	_riders.add_child(area_shape)
	_platform.add_child(_riders)
	# The counterweight: a basket of stones on its own rope.
	_basket = Node3D.new()
	_basket.name = "Basket"
	add_child(_basket)
	_box(_basket, Vector3(1.6, 1.2, 1.6), Vector3(0, 0, 0), TIMBER, false)
	_box(_basket, Vector3(1.3, 0.5, 1.3), Vector3(0, 0.8, 0), ROCK, false)
	# The pulley beam over the top stop, and the ropes hanging from it.
	var beam_y := 6.0
	_box(self, Vector3(basket_offset + platform_size.x * 0.5 + 1.0, 0.45, 0.5), Vector3(basket_offset * 0.5, beam_y, 0), TIMBER, false)
	for x in [0.0, basket_offset]:
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.45
		cyl.height = 0.25
		wheel.mesh = cyl
		wheel.material_override = TIMBER
		wheel.rotation.x = PI * 0.5
		wheel.position = Vector3(x, beam_y - 0.5, 0.4)
		add_child(wheel)
	for c in [Vector3(-hx + 0.3, 0, -hz + 0.3), Vector3(hx - 0.3, 0, -hz + 0.3), Vector3(hx - 0.3, 0, hz - 0.3), Vector3(-hx + 0.3, 0, hz - 0.3)]:
		_rope(Vector3(c.x * 0.3, beam_y - 0.5, c.z * 0.3), c + Vector3(0, 1.2, 0), false)
	_rope(Vector3(basket_offset, beam_y - 0.5, 0), Vector3(0, 0.6, 0), true)
	_call_post("CallTop", call_top)
	_call_post("CallBottom", call_bottom + Vector3(0, -travel, 0))
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = &"Tomb"
	_audio.unit_size = 10.0
	_audio.max_distance = 50.0
	_platform.add_child(_audio)

## A post with a handle, the rope from it running up into the dark.
func _call_post(post_name: String, pos: Vector3) -> void:
	_box(self, Vector3(0.22, 1.5, 0.22), pos + Vector3(0, 0.75, 0), TIMBER, false)
	_box(self, Vector3(0.08, 0.08, 0.5), pos + Vector3(0, 1.3, 0.2), TIMBER, false)
	var rope := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 5.0
	cyl.radial_segments = 6
	rope.mesh = cyl
	rope.material_override = TIMBER
	rope.position = pos + Vector3(0, 1.3 + 2.5, 0.42)
	add_child(rope)
	_usable_body(self, post_name, Vector3(0.7, 1.8, 0.9), pos + Vector3(0, 0.9, 0.1), &"call", 0.0)

func _box(parent: Node3D, box_size: Vector3, pos: Vector3, mat: Material, solid: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if solid and parent is CollisionObject3D:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = box_size
		shape.shape = b
		shape.position = pos
		parent.add_child(shape)
	return mi

func _usable_body(parent: Node3D, body_name: String, box_size: Vector3, pos: Vector3, prefix: StringName, hold: float) -> DelegateUsable:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = box_size
	shape.shape = b
	body.add_child(shape)
	var proxy := LiftControl.new()
	proxy.name = "Control"
	proxy.lift = self
	proxy.prefix = prefix
	body.add_child(proxy)
	var usable := DelegateUsable.new()
	usable.name = "Usable"
	usable.delegate_path = ^"../Control"
	usable.hold_time = hold
	usable.highlight = false
	body.add_child(usable)
	return usable

## A rope from `top` (fixed, under the pulley) down to `bottom`, a point on
## the platform or on the basket (in their own space); stretched as they move.
func _rope(top: Vector3, bottom: Vector3, on_basket: bool) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 1.0
	cyl.radial_segments = 6
	mi.mesh = cyl
	mi.material_override = TIMBER
	mi.set_meta(&"bottom", bottom)
	mi.set_meta(&"basket", on_basket)
	add_child(mi)
	_ropes.append(mi)
	_rope_tops.append(top)

func _place_ropes() -> void:
	for i in _ropes.size():
		var mi := _ropes[i]
		var top := _rope_tops[i]
		var holder: Node3D = _basket if mi.get_meta(&"basket") else _platform
		var bottom: Vector3 = holder.position + (mi.get_meta(&"bottom") as Vector3)
		var span := top - bottom
		var length := maxf(span.length(), 0.05)
		mi.position = (top + bottom) * 0.5
		mi.basis = Basis(Quaternion(Vector3.UP, span / length)) * Basis.from_scale(Vector3(1, length, 1))

func _show_stones() -> void:
	for i in _stones.size():
		_stones[i].visible = i < ballast

func _swing_brake(released: bool) -> void:
	if _brake_arm == null:
		return
	create_tween().tween_property(_brake_arm, "rotation:z", -0.6 if released else 0.0, 0.25)
