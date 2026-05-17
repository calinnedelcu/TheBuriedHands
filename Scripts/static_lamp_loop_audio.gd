extends AudioStreamPlayer3D

@export var light_path: NodePath
@export var active_volume_db: float = -27.0
@export var muted_volume_db: float = -80.0
@export var fade_speed: float = 8.0

var _light: Light3D = null

func _ready() -> void:
	_light = get_node_or_null(light_path) as Light3D
	if stream != null and "loop" in stream:
		stream.loop = true
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)
	volume_db = active_volume_db if _is_active() else muted_volume_db
	if _is_active() and stream != null:
		play()

func _process(delta: float) -> void:
	var target_volume := active_volume_db if _is_active() else muted_volume_db
	volume_db = lerpf(volume_db, target_volume, clampf(delta * fade_speed, 0.0, 1.0))
	if _is_active():
		if stream != null and not playing:
			play()
	elif playing and volume_db <= muted_volume_db + 1.0:
		stop()

func _on_finished() -> void:
	if _is_active() and stream != null:
		play()

func _is_active() -> bool:
	return _light == null or _light.visible
