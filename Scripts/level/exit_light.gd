class_name ExitLight
extends Area3D
## A few steps before the drain's mouth: the walk out. The craftsman stops
## answering to the player, turns his face to the sun and walks on into the
## light while his eyes give up (the exposure climbs until all is white); the
## forest takes over from the tomb, and the ending screen tells the rest.

const ENDING_SCREEN := preload("res://scenes/ui/ending_screen.tscn")

@export var light_path: NodePath
## Walking pace out of the tunnel, m/s.
@export var walk_speed := 1.15

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
	var hud := p.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var day := get_tree().get_first_node_in_group(&"daylight_exit") as DaylightExit
	var light := get_node_or_null(light_path) as Node3D
	var sun := light.global_position if light != null else global_position + Vector3.FORWARD * 50.0
	if day != null:
		sun = day.sun_point(p.global_position)
		var end := day.threshold()
		p.walk_to(Vector3(end.x, p.global_position.y, end.z), walk_speed)
		day.hand_over_sound(7.0)
	p.look_at_point(sun, 4.5, 56.0)
	Dialogue.play(&"light")
	Music.stop(3.0)
	Music.set_ambience(&"forest", 7.0)
	var atmosphere := get_tree().get_first_node_in_group(&"atmosphere") as Atmosphere
	if atmosphere != null:
		atmosphere.flare_to(10.0, 7.5)
	var screen := ENDING_SCREEN.instantiate()
	get_tree().current_scene.add_child(screen)
	Quest.complete(&"escape")
	Game.finish()
