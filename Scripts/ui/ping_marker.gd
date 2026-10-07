class_name PingMarker
extends Node3D
## A mark one co-op player puts where they look, for the other: a seal glyph
## hanging over the spot (此, "here") or over a guard's head (兵, "soldier"),
## following him. It shows through walls, chimes once, and fades after a few
## seconds. Each player has one mark at a time.

const SEAL_FONT := preload("res://assets/fonts/MaShanZheng-Seal.ttf")
const CHIME := preload("res://audio/sfx/treasure/bell.wav")
const LIFETIME := 6.0
const GLYPH_SPOT := "此"
const GLYPH_GUARD := "兵"
## The partner's marks are vermilion, like a seal; your own pale, like paper.
const VERMILION := Color(0.9, 0.24, 0.14)
const PALE := Color(0.96, 0.86, 0.64)

var _target: Node3D
var _offset := Vector3.UP * 0.5
var _age := 0.0
var _label: Label3D
var _base: Color

static func place(parent: Node, position: Vector3, on: Node3D, own: bool) -> void:
	var group := &"ping_own" if own else &"ping_partner"
	for old in parent.get_tree().get_nodes_in_group(group):
		old.queue_free()
	var mark := PingMarker.new()
	mark.name = "Ping"
	mark.add_to_group(group)
	parent.add_child(mark)
	mark.global_position = position
	mark._setup(on, own)

func _setup(on: Node3D, own: bool) -> void:
	_target = on
	if on != null:
		_offset = Vector3.UP * 3.7
	_base = PALE if own else VERMILION
	_label = Label3D.new()
	_label.text = GLYPH_GUARD if on != null else GLYPH_SPOT
	_label.font = SEAL_FONT
	_label.font_size = 128
	_label.pixel_size = 0.001
	_label.fixed_size = true
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 10
	_label.outline_size = 18
	_label.outline_modulate = Color(0.08, 0.02, 0.01, 0.85)
	_label.modulate = _base
	_label.position = _offset
	_label.scale = Vector3.ONE * 1.8
	add_child(_label)
	Sfx.play_ui(CHIME, -16.0 if own else -9.0)
	create_tween().tween_property(_label, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position
	_label.position = _offset + Vector3.UP * sin(_age * 2.6) * 0.06
	var c := _base
	c.a = clampf(LIFETIME - _age, 0.0, 1.0) * (0.8 + 0.2 * sin(_age * 6.0))
	_label.modulate = c
