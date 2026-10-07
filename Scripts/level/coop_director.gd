class_name CoopDirector
extends Node
## What changes when two go down together (added to the level by Net in a
## session). The apprentice is no longer a figure at his bench but the second
## player: after the sealing he doesn't beg to be left a lamp, he comes along.
## And the tomb asks for both of them: the balance's causeway sinks back
## unless the master bears on a brake while the apprentice crosses and pins
## it (BrakeLever, CausewayPin, Causeway.needs_brake). The two-man jobs on
## single objects (the shaft stone, the drain's bend, the clay, the seal
## names) live in those objects' own scripts.

var _causeway: Causeway
var _hinted := false

func _ready() -> void:
	Quest.step_changed.connect(_on_step)
	Game.level_ready.connect(_on_level_ready, CONNECT_ONE_SHOT)
	_set_up_causeway()

func _process(_delta: float) -> void:
	# The first time the causeway starts sinking, say what it wants.
	if not _hinted and _causeway != null and _causeway.is_sinking():
		_hinted = true
		Net.show_notice(tr("COOP_HINT_BRAKE"), 7.0)

## Once the opening has played out: how to point things out to the partner.
func _on_level_ready(_level: Node) -> void:
	await get_tree().create_timer(16.0, false).timeout
	var me := Net.local_body()
	var hud: Node = me.get_node_or_null("HUD") if me != null else null
	if hud != null and hud.has_method(&"toast"):
		hud.call(&"toast", InputHint.format(tr("HINT_PING")))

func _on_step(step: StringName) -> void:
	if Net.is_client():
		return
	if step == &"answer_apprentice":
		_together()

func _together() -> void:
	await get_tree().create_timer(1.2, false).timeout
	if not Quest.is_at(&"answer_apprentice"):
		return
	await Dialogue.play(&"coop_together")
	Quest.complete(&"answer_apprentice")

## The brake on the counterweight's platform, over the pit, and the pin by
## the causeway's far end. Same names on both machines, so uses find them.
func _set_up_causeway() -> void:
	var level := get_parent() as Node3D
	_causeway = level.get_node_or_null("Mechanism/Causeway") as Causeway
	var counterweight := level.get_node_or_null("Mechanism/Counterweight") as Node3D
	if _causeway == null or counterweight == null:
		return
	_causeway.needs_brake = true
	var mechanism := _causeway.get_parent()
	var brake := BrakeLever.new()
	brake.name = "CoopBrake"
	brake.causeway = _causeway
	mechanism.add_child(brake)
	brake.global_position = _floor(level, counterweight.global_position + Vector3(-1.5, 0.0, 0.8))
	# The arm reaches back over the platform, toward whoever climbs up.
	brake.rotation.y = PI
	var pin := CausewayPin.new()
	pin.name = "CoopPin"
	pin.causeway = _causeway
	mechanism.add_child(pin)
	pin.global_position = _floor(level, _causeway.global_position + Vector3(2.1, 6.5, 8.6))

func _floor(level: Node3D, at: Vector3) -> Vector3:
	var space := level.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 4.0, 1)
	var hit := space.intersect_ray(q)
	return hit.position if not hit.is_empty() else at
