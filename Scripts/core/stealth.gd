extends Node
## Shared stealth state: noise events for guards to hear, how visible the
## player currently is, and how alarmed the guards are overall (drives music
## and the HUD eye).

## `radius` is how far (in metres) the sound carries for a guard in the open.
signal noise_made(position: Vector3, radius: float, source: Node)
signal alert_changed(level: float)

## 0 = invisible in darkness, 1 = standing in full light. Written by the
## (local) player; in co-op each body also keeps its own `exposure`.
var player_visibility := 0.0
## How exposed the player is overall, for the HUD (visibility * movement/stance).
var player_exposure := 0.0
## 0 = all guards calm, 1 = a guard is chasing. Max over all guards.
var alert_level := 0.0

var _guards: Array[Node] = []
var _lights: Array[Light3D] = []

func make_noise(position: Vector3, radius: float, source: Node = null) -> void:
	if radius <= 0.0:
		return
	# Co-op: the guards live on the host, so the apprentice's own sounds go there.
	if source is Player and (source as Player).is_local and Net.is_client():
		Net.forward_noise(position, radius)
	noise_made.emit(position, radius, source)

func register_guard(guard: Node) -> void:
	if not _guards.has(guard):
		_guards.append(guard)

func unregister_guard(guard: Node) -> void:
	_guards.erase(guard)

func guards() -> Array[Node]:
	return _guards

## Static lights (sconces, braziers) that make the player visible.
func register_light(light: Light3D) -> void:
	if not _lights.has(light):
		_lights.append(light)

func unregister_light(light: Light3D) -> void:
	_lights.erase(light)

func lights() -> Array[Light3D]:
	return _lights

func _physics_process(_delta: float) -> void:
	var level := 0.0
	for guard in _guards:
		if is_instance_valid(guard) and guard.has_method("awareness_level"):
			level = maxf(level, float(guard.call("awareness_level")))
	if not is_equal_approx(level, alert_level):
		alert_level = level
		alert_changed.emit(level)
