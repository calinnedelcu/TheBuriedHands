class_name WallLamp
extends Node3D
## A wall sconce burning from its own oil reservoir. Tap the use key to snuff
## it (darkness hides you) or relight it from your own flame; hold the key to
## pour its oil into your lamp. Lit sconces make the player visible to guards.

const SNUFF_SOUND := preload("res://audio/sfx/impacts/cloth3.ogg")
const POUR_SOUND := preload("res://audio/sfx/mercury/fill.mp3")

@export var oil := 60.0
@export var max_oil := 100.0
@export var start_lit := true
## Oil per second poured into the player's lamp while holding the key.
@export var pour_rate := 22.0
@export var light_energy := 2.6
@export var light_range := 11.0
@export var flicker := 0.14
## The lamp's own bronze bracket. Off where the lamp sits in a sconce that is
## part of the level's model.
@export var show_fixture := true

@onready var _light: OmniLight3D = $Light
@onready var _flame: MeshInstance3D = $Flame
@onready var _usable: DelegateUsable = $Body/Usable
@onready var _audio: AudioStreamPlayer3D = $Audio

var lit := true
var _gust := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _last_progress := 0.0

func _ready() -> void:
	add_to_group(&"persistent")
	add_to_group(&"wall_lamps")
	_noise.seed = randi()
	_noise.frequency = 0.7
	_t = randf() * 100.0
	_usable.hold_time = 3.5
	_usable.tap_enabled = true
	($Model as Node3D).visible = show_fixture
	_set_lit(start_lit and oil > 0.0, false)

func _exit_tree() -> void:
	Stealth.unregister_light(_light)

func _process(delta: float) -> void:
	if not lit:
		return
	_t += delta
	_gust = maxf(0.0, _gust - delta * 0.8)
	var n := _noise.get_noise_1d(_t * 5.0)
	var strength := clampf(oil / 12.0, 0.25, 1.0) * (1.0 - _gust * 0.6 * absf(_noise.get_noise_1d(_t * 23.0)))
	_light.light_energy = light_energy * strength * (1.0 + n * flicker)
	_light.omni_range = light_range * lerpf(0.6, 1.0, strength) * (1.0 + n * 0.03)
	_flame.scale = Vector3.ONE * lerpf(0.55, 1.0, strength) * (1.0 + _noise.get_noise_1d(_t * 8.0 + 30.0) * 0.12)

## A draught (doors, the gates slamming) makes the flame gutter.
func gust(strength := 1.0) -> void:
	_gust = maxf(_gust, strength)

func _set_lit(value: bool, with_sound := true) -> void:
	lit = value
	_light.visible = value
	_flame.visible = value
	if value:
		Stealth.register_light(_light)
	else:
		Stealth.unregister_light(_light)
	if with_sound:
		Sfx.play_at(SNUFF_SOUND, global_position, -8.0)

# --- Usable delegate -----------------------------------------------------------------

func usable_prompt(user: Node) -> String:
	var lamp := _player_lamp(user)
	var parts: Array[String] = []
	if lit:
		parts.append(tr("PROMPT_SNUFF"))
	elif lamp != null and lamp.is_lit and oil > 0.0:
		parts.append(tr("PROMPT_LIGHT"))
	if oil <= 0.0:
		parts.append(tr("PROMPT_RESERVOIR_EMPTY"))
	elif lamp != null and not lamp.is_full():
		parts.append("%s: %s" % [tr("HUD_HOLD"), tr("PROMPT_REFILL")])
	return "  ·  ".join(parts)

func usable_can_use(user: Node) -> bool:
	var lamp := _player_lamp(user)
	return lit or (lamp != null and lamp.is_lit and oil > 0.0) or (lamp != null and not lamp.is_full() and oil > 0.0)

func usable_tap(user: Node) -> void:
	var lamp := _player_lamp(user)
	if lit:
		_set_lit(false)
		Stealth.make_noise(global_position, 2.5, user)
	elif lamp != null and lamp.is_lit and oil > 0.0:
		_set_lit(true)

func usable_hold_tick(user: Node, progress: float) -> void:
	var lamp := _player_lamp(user)
	if lamp == null or oil <= 0.0:
		return
	var dt := maxf(0.0, (progress - _last_progress) * _usable.hold_time)
	_last_progress = progress
	var poured := lamp.refill(minf(pour_rate * dt, oil))
	oil -= poured
	if not _audio.playing and poured > 0.0:
		_audio.stream = POUR_SOUND
		_audio.play()
	if oil <= 0.0:
		oil = 0.0
		_set_lit(false)

func usable_hold_cancelled(_user: Node) -> void:
	_last_progress = 0.0
	_audio.stop()

func usable_hold_done(_user: Node) -> void:
	_last_progress = 0.0
	_audio.stop()

func _player_lamp(user: Node) -> HeldLamp:
	var p := user as Player
	return p.inventory.lamp() if p != null else null

# --- Persistence ------------------------------------------------------------------------

func persist_save() -> Dictionary:
	return {"oil": oil, "lit": lit}

func persist_load(data: Dictionary) -> void:
	oil = float(data.get("oil", oil))
	_set_lit(bool(data.get("lit", lit)) and oil > 0.0, false)
