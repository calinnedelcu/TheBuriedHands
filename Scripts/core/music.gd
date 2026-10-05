extends Node
## Music and ambience. Two players crossfade between music tracks; the level's
## atmosphere zones pick the track and the ambience bed. A tension layer (a
## heartbeat) rises with the guards' alert, a stinger hits when a guard spots
## the player, and music ducks under dialogue.

## id -> [path, gain dB]. Gains bring the tracks to roughly the same loudness.
const TRACKS := {
	&"menu": ["res://audio/music/mainmenu.mp3", -2.0],
	&"workshop": ["res://audio/music/jamegam.mp3", -6.0],
	&"archives": ["res://audio/music/Sneaking-Administrativa+Arbalete.mp3", -8.5],
	&"mercury": ["res://audio/music/treasure_room.mp3", -1.0],
}
const AMBIENCE := {
	&"tomb": ["res://audio/ambience/tomb_bed.wav", -4.0],
	&"mercury": ["res://audio/ambience/mercury_hum.wav", -2.0],
	&"forest": ["res://audio/music/exit_ambient_woods.mp3", 12.0],
}
const TENSION := preload("res://audio/ambience/tension_heartbeat.wav")
const SPOTTED := preload("res://audio/sfx/stingers/spotted.wav")
const SILENT_DB := -60.0
const DUCK_DB := -7.0

var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _track: StringName = &""
var _music_gain := 0.0
var _duck := 0.0
var _ambience: AudioStreamPlayer
var _ambience_id: StringName = &""
var _tension: AudioStreamPlayer
var _tension_level := 0.0
var _tension_target := 0.0
var _last_alert := 0.0
var _stinger_cooldown := 0.0
var _tweens := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = SILENT_DB
		add_child(p)
		_music.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"SFX"
	_ambience.volume_db = SILENT_DB
	add_child(_ambience)
	_tension = AudioStreamPlayer.new()
	_tension.bus = &"Music"
	_tension.stream = TENSION
	_tension.volume_db = SILENT_DB
	add_child(_tension)
	Stealth.alert_changed.connect(_on_alert)
	Dialogue.sequence_started.connect(func(_id: StringName): _duck_to(DUCK_DB))
	Dialogue.sequence_finished.connect(func(_id: StringName): _duck_to(0.0))

## Crossfades to a track (see TRACKS), or to silence with &"".
func play(track: StringName, fade := 3.0) -> void:
	if track == _track:
		return
	_track = track
	var old := _music[_active]
	_fade(old, SILENT_DB, fade, true)
	if track == &"" or not TRACKS.has(track):
		return
	_active = 1 - _active
	var p := _music[_active]
	var stream := load(TRACKS[track][0]) as AudioStream
	_set_loop(stream)
	p.stream = stream
	_music_gain = float(TRACKS[track][1])
	p.volume_db = SILENT_DB
	p.play()
	_fade(p, _music_gain + _duck, fade)

## The track playing (or fading in), &"" for none.
func track() -> StringName:
	return _track

func stop(fade := 2.0) -> void:
	play(&"", fade)

func current() -> StringName:
	return _track

## Switches the ambience bed (see AMBIENCE), or silences it with &"".
func set_ambience(id: StringName, fade := 3.0) -> void:
	if id == _ambience_id:
		return
	_ambience_id = id
	if id == &"" or not AMBIENCE.has(id):
		_fade(_ambience, SILENT_DB, fade, true)
		return
	var stream := load(AMBIENCE[id][0]) as AudioStream
	_set_loop(stream)
	if _ambience.playing:
		# Dip out and back in with the new bed.
		var t := _new_tween(_ambience)
		t.tween_property(_ambience, "volume_db", SILENT_DB, fade * 0.5)
		t.tween_callback(func():
			_ambience.stream = stream
			_ambience.play())
		t.tween_property(_ambience, "volume_db", float(AMBIENCE[id][1]), fade * 0.5)
	else:
		_ambience.stream = stream
		_ambience.volume_db = SILENT_DB
		_ambience.play()
		_fade(_ambience, float(AMBIENCE[id][1]), fade)

## Everything off (leaving a level, the ending).
func silence(fade := 1.5) -> void:
	stop(fade)
	set_ambience(&"", fade)
	_tension_target = 0.0

func _process(delta: float) -> void:
	_stinger_cooldown = maxf(0.0, _stinger_cooldown - delta)
	# The heartbeat follows the alert, rising faster than it settles.
	var rate := 0.8 if _tension_target > _tension_level else 0.25
	_tension_level = move_toward(_tension_level, _tension_target, delta * rate)
	if _tension_level > 0.01:
		if not _tension.playing:
			_tension.play()
		_tension.volume_db = lerpf(-34.0, -4.0, _tension_level)
	elif _tension.playing:
		_tension.stop()

func _on_alert(level: float) -> void:
	_tension_target = clampf((level - 0.15) / 0.85, 0.0, 1.0)
	if level >= 0.999 and _last_alert < 0.999 and _stinger_cooldown <= 0.0:
		Sfx.play_ui(SPOTTED, -3.0)
		_stinger_cooldown = 12.0
	_last_alert = level

func _duck_to(db: float) -> void:
	_duck = db
	var p := _music[_active]
	if p.playing and _track != &"":
		_fade(p, _music_gain + _duck, 0.6)

func _fade(p: AudioStreamPlayer, db: float, seconds: float, stop_after := false) -> void:
	var t := _new_tween(p)
	t.tween_property(p, "volume_db", db, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE)
	if stop_after:
		t.tween_callback(p.stop)

func _new_tween(p: Node) -> Tween:
	var old: Tween = _tweens.get(p)
	if old != null and old.is_valid():
		old.kill()
	var t := create_tween()
	_tweens[p] = t
	return t

func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
