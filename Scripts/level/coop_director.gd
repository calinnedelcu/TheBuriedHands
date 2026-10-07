class_name CoopDirector
extends Node
## Story beats that change when two go down together (added to the level by
## Net in a session). The apprentice is no longer a figure at his bench but
## the second player: after the sealing he doesn't beg to be left a lamp, he
## comes along, and the two of them say so.

func _ready() -> void:
	Quest.step_changed.connect(_on_step)
	Game.level_ready.connect(_on_level_ready, CONNECT_ONE_SHOT)

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
