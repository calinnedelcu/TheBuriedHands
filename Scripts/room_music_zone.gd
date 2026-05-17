extends AudioStreamPlayer

## Reda muzica la volum uniform pe toata camera (non-3D, fara falloff).
## Cand player-ul intra in Area3D-ul `room_area`, volumul urca la `base_volume_db`.
## Cand iese, coboara la `muted_volume_db`. Tween smooth la ambele tranzitii.
## Forma camerei (BoxShape3D etc.) se editeaza pe nodul Area3D referit.

@export_node_path("Area3D") var room_area: NodePath
@export var base_volume_db: float = -6.0
@export var muted_volume_db: float = -80.0
@export var fade_in_duration: float = 1.6
@export var fade_out_duration: float = 2.2
@export var player_group: String = "player"

var _area: Area3D = null
var _player_inside: bool = false
var _tween: Tween = null

func _ready() -> void:
	_area = get_node_or_null(room_area) as Area3D
	volume_db = muted_volume_db
	if _area == null:
		push_warning("[room_music_zone] room_area not set on %s" % name)
		return
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	# verificare initiala in caz ca player-ul e deja in area la incarcare
	for body in _area.get_overlapping_bodies():
		if body.is_in_group(player_group):
			_player_inside = true
			_fade_to(base_volume_db, 0.4)
			return

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(player_group):
		return
	if _player_inside:
		return
	_player_inside = true
	_fade_to(base_volume_db, fade_in_duration)

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group(player_group):
		return
	# verifica daca alt body player (sau acelasi prin alt collider) ramane in area
	for other in _area.get_overlapping_bodies():
		if other != body and other.is_in_group(player_group):
			return
	_player_inside = false
	_fade_to(muted_volume_db, fade_out_duration)

func _fade_to(target_db: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", target_db, duration).set_trans(Tween.TRANS_SINE)
