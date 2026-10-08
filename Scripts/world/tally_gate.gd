@tool
class_name TallyGate
extends Node3D
## The inner wall's gate, at the top of the workers' stairs up from the army
## pits: two bronze leaves studded with nails, each with a tiger-shaped socket
## by the seam. It opens only to a whole tiger tally, as a Qin command did:
## Overseer Wei's half and the commander of the pits' half. Set each half in
## its socket (whoever carries it, in co-op either of you); with both in,
## the bolt draws back and the leaves swing away from you.
##
## The origin is on the floor in the middle of the doorway; the leaves stand
## across it (local z) and open toward -x. Built in code; nothing generated
## is saved.

const BRONZE := preload("res://assets/materials/props/bronze.tres")
const BLACK := preload("res://assets/materials/props/lacquer_black.tres")
const HALF_WEI := preload("res://assets/models/props/tally_left.glb")
const HALF_PIT := preload("res://assets/models/props/tally_right.glb")
const SET_SOUND := preload("res://audio/sfx/impacts/impactMetal_light_001.ogg")
const BOLT := preload("res://audio/sfx/impacts/impactPlate_light_000.ogg")
const SWING := preload("res://audio/sfx/mechanisms/ancient_mechanical_gears.mp3")

@export var width := 2.0
@export var height := 3.25
## How high the sockets are, for a hand to reach.
@export var socket_height := 1.45

var wei_set := false
var pit_set := false
var opened := false

var _leaves: Array[Node3D] = []
var _halves: Array[Node3D] = []
var _blocker: CollisionShape3D

func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(&"persistent")
	_apply(false)

# --- Usable: the sockets ---------------------------------------------------------------

func usable_prompt(user: Node) -> String:
	if opened:
		return ""
	return tr("PROMPT_TALLY_SET") if _settable(user as Player) else tr("PROMPT_TALLY_WANTS")

func usable_can_use(user: Node) -> bool:
	return not opened and _settable(user as Player)

func usable_show_blocked(_user: Node) -> bool:
	return not opened

func usable_use(user: Node) -> void:
	var p := user as Player
	if p == null or opened:
		return
	var set_one := false
	if not wei_set and p.inventory.has_item(&"tally_wei"):
		p.inventory.remove(&"tally_wei")
		wei_set = true
		set_one = true
	if not pit_set and p.inventory.has_item(&"tally_pit"):
		p.inventory.remove(&"tally_pit")
		pit_set = true
		set_one = true
	if not set_one:
		return
	Sfx.play_at(SET_SOUND, global_position + Vector3.UP * socket_height, 0.0, 0.05, &"Tomb", 18.0)
	if wei_set and pit_set:
		opened = true
		_apply(true)
		Story.fire(&"past_wall", &"tally_gate_open", &"inner_gate_open")
	else:
		_apply(false)
		Story.fire(&"", &"tally_gate_half")

func _settable(p: Player) -> bool:
	return p != null and ((not wei_set and p.inventory.has_item(&"tally_wei")) or (not pit_set and p.inventory.has_item(&"tally_pit")))

## Shows the halves set so far, and the leaves open or shut.
func _apply(animate: bool) -> void:
	_halves[0].visible = wei_set
	_halves[1].visible = pit_set
	if not opened:
		_blocker.disabled = false
		return
	if not animate:
		for i in _leaves.size():
			_leaves[i].rotation.y = _swing(i)
		_blocker.disabled = true
		return
	# The bolt draws back, then the leaves swing.
	Sfx.play_at(BOLT, global_position + Vector3.UP * socket_height, 4.0, 0.0, &"Tomb", 30.0)
	var t := create_tween()
	t.tween_interval(0.7)
	t.tween_callback(func() -> void: Sfx.play_at(SWING, global_position + Vector3.UP * 1.5, 0.0, 0.0, &"Tomb", 40.0))
	t.set_parallel(true)
	for i in _leaves.size():
		t.tween_property(_leaves[i], "rotation:y", _swing(i), 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_callback(func() -> void: _blocker.disabled = true)

## Each leaf turns on its hinge away from the stairs (toward -x).
func _swing(leaf: int) -> float:
	return PI * 0.5 if leaf == 0 else -PI * 0.5

# --- Build ----------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_leaves.clear()
	_halves.clear()
	var half_w := width * 0.5
	for i in 2:
		# Leaf 0 hangs from the +z jamb, leaf 1 from the -z one.
		var side := 1.0 if i == 0 else -1.0
		var hinge := Node3D.new()
		hinge.name = "Leaf%d" % i
		hinge.position = Vector3(0.0, 0.0, side * half_w)
		add_child(hinge)
		_leaves.append(hinge)
		var leaf := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = Vector3(0.12, height - 0.02, half_w - 0.01)
		leaf.mesh = slab
		leaf.material_override = BRONZE
		leaf.position = Vector3(0.0, height * 0.5, -side * half_w * 0.5)
		hinge.add_child(leaf)
		# Rows of nail heads on the face toward the stairs.
		var nail := SphereMesh.new()
		nail.radius = 0.045
		nail.height = 0.06
		for row in 6:
			for col in 3:
				var y := 0.45 + row * 0.5
				var along := 0.18 + col * 0.3
				if absf(y - socket_height) < 0.32 and col == 2:
					continue
				var n := MeshInstance3D.new()
				n.mesh = nail
				n.material_override = BRONZE
				n.position = Vector3(0.065, y, -side * along)
				hinge.add_child(n)
		# A ring handle hanging from a beast's mask, below the socket.
		var mask := MeshInstance3D.new()
		var mask_box := BoxMesh.new()
		mask_box.size = Vector3(0.05, 0.14, 0.14)
		mask.mesh = mask_box
		mask.material_override = BRONZE
		mask.position = Vector3(0.08, socket_height - 0.38, -side * (half_w - 0.2))
		hinge.add_child(mask)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.07
		torus.outer_radius = 0.095
		ring.mesh = torus
		ring.material_override = BRONZE
		ring.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.1, socket_height - 0.52, -side * (half_w - 0.2)))
		hinge.add_child(ring)
		# The socket by the seam, dark, and the half that goes in it: the
		# two tigers nose to nose across the seam.
		var socket := MeshInstance3D.new()
		var plate := BoxMesh.new()
		plate.size = Vector3(0.02, 0.12, 0.21)
		socket.mesh = plate
		socket.material_override = BLACK
		socket.position = Vector3(0.07, socket_height + 0.035, -side * (half_w - 0.16))
		hinge.add_child(socket)
		var model := (HALF_PIT if i == 0 else HALF_WEI).instantiate() as Node3D
		var holder := PropMaterials.new()
		holder.name = "Half%d" % i
		holder.add_child(model)
		# Flank out toward the stairs, head toward the seam.
		holder.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 if i == 0 else -PI * 0.5), Vector3(0.08, socket_height, -side * (half_w - 0.16)))
		hinge.add_child(holder)
		_halves.append(holder)
	# Wei's half is in leaf 1, the commander's in leaf 0.
	_halves.reverse()
	var body := StaticBody3D.new()
	body.name = "Blocker"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_blocker = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, height, width)
	_blocker.shape = box
	_blocker.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(_blocker)
	if Engine.is_editor_hint():
		return
	# What the use ray hits: the sockets by the seam.
	var sockets := StaticBody3D.new()
	sockets.name = "Sockets"
	sockets.collision_layer = 16
	sockets.collision_mask = 0
	add_child(sockets)
	var hit := CollisionShape3D.new()
	var hit_box := BoxShape3D.new()
	hit_box.size = Vector3(0.12, 0.5, 0.8)
	hit.shape = hit_box
	hit.position = Vector3(0.12, socket_height + 0.03, 0.0)
	sockets.add_child(hit)
	var usable := DelegateUsable.new()
	usable.name = "Usable"
	usable.prompt_key = "PROMPT_TALLY_SET"
	sockets.add_child(usable)

func persist_save() -> Dictionary:
	return {"wei": wei_set, "pit": pit_set, "open": opened}

func persist_load(data: Dictionary) -> void:
	wei_set = bool(data.get("wei", false))
	pit_set = bool(data.get("pit", false))
	opened = bool(data.get("open", false))
	_apply(false)
