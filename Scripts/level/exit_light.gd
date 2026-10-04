class_name ExitLight
extends Area3D
## The end of the drain: daylight. Walking into it ends the game.

const ENDING_SCREEN := preload("res://scenes/ui/ending_screen.tscn")

@export var light_path: NodePath

var _done := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _done or not (body is Player):
		return
	_done = true
	var p := body as Player
	p.lock_controls(&"ending")
	p.force_stand()
	var light := get_node_or_null(light_path) as Node3D
	if light != null:
		p.look_at_point(light.global_position, 2.0, 40.0)
	Dialogue.play(&"light")
	Music.stop(2.5)
	Music.set_ambience(&"forest", 5.0)
	var screen := ENDING_SCREEN.instantiate()
	get_tree().current_scene.add_child(screen)
	Quest.complete(&"escape")
	Game.finish()
