class_name SealingDimmer
extends Node3D
## The workshop's working lights (its child lights): when the gate slams
## shut they gutter and go out one after another; after that they stay out.

func _ready() -> void:
	Game.sealing_advanced.connect(_on_sealing)
	if Game.sealing_stage >= 1:
		_set_all(0.0)

func _on_sealing(stage: int) -> void:
	if stage != 1:
		return
	for l in get_children():
		var light := l as Light3D
		if light == null:
			continue
		var start := light.light_energy
		var t := create_tween()
		t.tween_interval(randf_range(0.1, 1.2))
		# A few gusts, then out.
		for i in 3:
			t.tween_property(light, "light_energy", start * randf_range(0.15, 0.5), 0.07)
			t.tween_property(light, "light_energy", start * randf_range(0.6, 1.0), 0.09)
		t.tween_property(light, "light_energy", 0.0, randf_range(0.3, 0.8))
		t.tween_callback(func(): light.visible = false)

func _set_all(energy: float) -> void:
	for l in get_children():
		var light := l as Light3D
		if light != null:
			light.light_energy = energy
			light.visible = energy > 0.0
