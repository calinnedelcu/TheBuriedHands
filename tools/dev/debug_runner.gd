extends Node
## Scratch runner for focused debugging (edit freely).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/dev/test_room.tscn")
	for i in 10:
		await get_tree().process_frame
	var p := get_tree().get_first_node_in_group(&"player") as Player
	await get_tree().create_timer(0.5).timeout
	p.global_position = Vector3(8.0, 0.1, -2.6)
	p.rotation.y = 0.0
	await get_tree().create_timer(0.3).timeout
	Input.action_press(&"move_forward")
	for i in 200:
		await get_tree().physics_frame
		if i % 6 == 0:
			print("t%03d pos=%s floor=%s wall=%s vel=%s" % [i, p.global_position.snapped(Vector3.ONE * 0.01), p.is_on_floor(), p.is_on_wall(), p.velocity.snapped(Vector3.ONE * 0.01)])
	Input.action_release(&"move_forward")
	get_tree().quit()
