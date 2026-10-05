class_name TitleScreen
extends Node3D
## The main menu. Behind it, a slow walk down an aisle of the terracotta army
## between rammed-earth walls, lit by a few oil lamps. The aisle repeats every
## PERIOD metres, so the camera can walk forever by stepping back one period.
## Everything is built here from the game's own models and materials.

const SOLDIER := preload("res://TripoModels/statue1-idle.glb")
const FLAME_MESH := preload("res://scenes/items/flame_teardrop.obj")
const FLAME_SHADER := preload("res://scenes/items/oil_flame.gdshader")
const SURFACE_SHADER := preload("res://assets/shaders/surface_triplanar.gdshader")
const FLICKER := preload("res://Scripts/world/flicker_light.gd")
const CLICK := preload("res://audio/sfx/ui/click_001.ogg")
const HOVER := preload("res://audio/sfx/ui/click_003.ogg")
const CONFIRM := preload("res://audio/sfx/ui/confirmation_001.ogg")
const BACK := preload("res://audio/sfx/ui/back_001.ogg")

## The aisle repeats every PERIOD metres: four ranks, two lamps.
const PERIOD := 8.0
const RANK_SPACING := 2.0
const BUILD_AHEAD := 72.0
const COLUMNS := [-2.75, -1.85, 1.85, 2.75]
const TRENCH_HALF := 3.55
const WALL_WIDTH := 1.8
const WALL_HEIGHT := 3.6
const SOLDIER_HEIGHT := 1.95
const WALK_SPEED := 0.3
const EYE_HEIGHT := 1.72

var _camera: Camera3D
var _walk := 0.0
var _time := 0.0
var _ui: Control
var _menu: VBoxContainer
var _overlay: Control
var _options: OptionsMenu
var _credits: Control
var _confirm: Control
var _fade: ColorRect
var _busy := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_build_environment()
	_build_aisle()
	_build_camera()
	_build_ui()
	# Coming back from the credits the theme is already playing: let it run on.
	if Music.track() != &"menu":
		Music.silence(0.8)
	Music.set_ambience(&"", 0.8)
	Music.play(&"menu", 4.0)
	create_tween().tween_property(_fade, "color:a", 0.0, 2.8).set_trans(Tween.TRANS_SINE).set_delay(0.3)
	Settings.changed.connect(_on_setting)

func _process(delta: float) -> void:
	_time += delta
	_walk += delta * WALK_SPEED
	if _walk >= PERIOD:
		_walk -= PERIOD
	var bob := sin(_time * 1.7) * 0.025
	var sway := sin(_time * 0.23) * deg_to_rad(2.2)
	_camera.position = Vector3(sin(_time * 0.31) * 0.06, EYE_HEIGHT + bob, 3.0 - _walk)
	_camera.rotation = Vector3(deg_to_rad(-3.0) + sin(_time * 0.17) * 0.012, sway, 0.0)

# --- The aisle -----------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.03, 0.035, 0.05)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.2
	env.ssao_enabled = true
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.008, 0.01, 0.016)
	env.fog_density = 0.04
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.024
	env.volumetric_fog_albedo = Color(0.85, 0.8, 0.74)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 40.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.16
	env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _surface(set_name: String, colour: Color, scale: float, mean: float, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter(&"base_color", colour)
	m.set_shader_parameter(&"detail_albedo", load("res://assets/textures/surfaces/%s/albedo.jpg" % set_name))
	m.set_shader_parameter(&"detail_normal", load("res://assets/textures/surfaces/%s/normal.jpg" % set_name))
	m.set_shader_parameter(&"detail_roughness", load("res://assets/textures/surfaces/%s/roughness.jpg" % set_name))
	m.set_shader_parameter(&"albedo_mean", mean)
	m.set_shader_parameter(&"tex_scale", scale)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m

func _box(size: Vector3, mat: Material, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi

func _build_aisle() -> void:
	var root := Node3D.new()
	root.name = "Aisle"
	add_child(root)
	var earth := _surface("ground104", Color(0.42, 0.34, 0.26), 0.35, 0.432, {"detail_saturation": 0.35, "normal_strength": 1.1})
	var floor_mat := _surface("rock030", Color(0.3, 0.27, 0.24), 0.45, 0.301, {"normal_strength": 0.6})
	var wood := _surface("planks037a", Color(0.33, 0.24, 0.16), 0.6, 0.256, {"detail_saturation": 0.5})
	var length := BUILD_AHEAD + PERIOD * 2.0
	var mid_z := -length * 0.5 + PERIOD * 1.5
	_box(Vector3(TRENCH_HALF * 2.0 + WALL_WIDTH * 2.0, 0.2, length), floor_mat, Vector3(0, -0.1, mid_z), root)
	for side in [-1.0, 1.0]:
		var x: float = side * (TRENCH_HALF + WALL_WIDTH * 0.5)
		_box(Vector3(WALL_WIDTH, WALL_HEIGHT, length), earth, Vector3(x, WALL_HEIGHT * 0.5, mid_z), root)
	# Roof logs across the trench; two of every eight have fallen in.
	var z := PERIOD * 1.5
	var i := 0
	while z > -BUILD_AHEAD:
		if i % 8 != 2 and i % 8 != 5:
			var log := _box(Vector3(TRENCH_HALF * 2.0 + WALL_WIDTH * 2.0, 0.34, 0.34), wood, Vector3(0, WALL_HEIGHT + 0.17, z), root)
			log.rotation.z = deg_to_rad(((i * 37) % 7 - 3) * 0.4)
		z -= 1.0
		i += 1
	_build_soldiers(root)
	_build_lamps(root)
	_build_dust()

func _build_soldiers(parent: Node3D) -> void:
	var model := SOLDIER.instantiate() as Node3D
	var meshes: Array[MeshInstance3D] = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(n as MeshInstance3D)
	add_child(model)
	var height := 0.0
	for mi in meshes:
		height = maxf(height, (mi.global_transform * mi.get_aabb()).end.y)
	var scale := SOLDIER_HEIGHT / maxf(height, 0.01)
	var transforms: Array[Transform3D] = []
	var z := PERIOD * 1.5
	var rank := 0
	while z > -BUILD_AHEAD:
		for c in COLUMNS.size():
			# Variation repeats with the aisle (rank % 4) so the loop is seamless.
			var seed := (rank % 4) * 7 + c * 3
			var yaw := -PI * 0.5 + deg_to_rad(float((seed * 53) % 9 - 4) * 1.2)
			var s := scale * (1.0 + float((seed * 29) % 5 - 2) * 0.012)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
			transforms.append(Transform3D(basis, Vector3(COLUMNS[c], 0.0, z)))
		z -= RANK_SPACING
		rank += 1
	for mi in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = transforms.size()
		var local := mi.global_transform
		for k in transforms.size():
			mm.set_instance_transform(k, transforms[k] * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if mi.material_override != null:
			mmi.material_override = mi.material_override
		elif mi.mesh.get_surface_count() > 0 and mi.get_active_material(0) != null:
			mmi.material_override = mi.get_active_material(0)
		parent.add_child(mmi)
	model.queue_free()

func _build_lamps(parent: Node3D) -> void:
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.4, 0.3, 0.17)
	bronze.metallic = 0.7
	bronze.roughness = 0.45
	var flame := ShaderMaterial.new()
	flame.shader = FLAME_SHADER
	flame.set_shader_parameter(&"outer_color", Color(1, 0.3, 0.05, 0.8))
	flame.set_shader_parameter(&"core_color", Color(1, 0.8, 0.3, 0.95))
	flame.set_shader_parameter(&"tip_color", Color(1, 0.5, 0.1, 0.55))
	flame.set_shader_parameter(&"emission_strength", 4.5)
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.17
	bowl_mesh.bottom_radius = 0.06
	bowl_mesh.height = 0.1
	var z := PERIOD * 1.5 - 2.0
	var side := 1.0
	while z > -BUILD_AHEAD:
		var lamp := Node3D.new()
		lamp.position = Vector3(side * (TRENCH_HALF - 0.28), 2.35, z)
		parent.add_child(lamp)
		var bowl := MeshInstance3D.new()
		bowl.mesh = bowl_mesh
		bowl.material_override = bronze
		bowl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(bowl)
		var f := MeshInstance3D.new()
		f.mesh = FLAME_MESH
		f.material_override = flame
		f.scale = Vector3.ONE * 1.3
		f.position = Vector3(0, 0.07, 0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(f)
		var light := OmniLight3D.new()
		light.set_script(FLICKER)
		light.light_color = Color(1, 0.6, 0.28)
		light.light_energy = 3.0
		light.light_volumetric_fog_energy = 1.4
		light.omni_range = 9.5
		light.omni_attenuation = 1.3
		light.shadow_enabled = true
		light.shadow_bias = 0.06
		light.position = Vector3(-side * 0.35, 0.3, 0)
		lamp.add_child(light)
		z -= PERIOD * 0.5
		side = -side

func _build_dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 260
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.visibility_aabb = AABB(Vector3(-6, -1, -14), Vector3(12, 5, 18))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.6, 1.4, 6.0)
	pm.direction = Vector3(0.2, 0.3, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.05
	pm.gravity = Vector3(0, -0.004, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.014, 0.014)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.92, 0.8, 0.45)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = soft
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	mat.albedo_texture = dot
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	p.position = Vector3(0, 1.6, -4.0)
	p.name = "Dust"
	add_child(p)
	set_meta(&"dust", p)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.near = 0.05
	_camera.far = 90.0
	add_child(_camera)
	_camera.make_current()
	var dust := get_meta(&"dust") as Node3D
	dust.reparent(_camera, false)
	dust.position = Vector3(0, -0.1, -5.5)
	# A cold glow always far down the aisle: the ranks stand out against it.
	var far := OmniLight3D.new()
	far.light_color = Color(0.5, 0.64, 0.9)
	far.light_energy = 2.2
	far.light_volumetric_fog_energy = 2.0
	far.omni_range = 24.0
	far.omni_attenuation = 1.1
	far.shadow_enabled = true
	far.position = Vector3(0.0, 1.2, -30.0)
	_camera.add_child(far)

# --- Menu ----------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.theme = load("res://assets/ui/theme.tres")
	layer.add_child(_ui)

	# Darken the left third so the menu reads over the scene.
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.82))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	grad.add_point(0.38, Color(0, 0, 0, 0.45))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_to = Vector2(1, 0)
	shade.texture = gtex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	_ui.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 140)
	margin.add_theme_constant_override(&"margin_top", 120)
	margin.add_theme_constant_override(&"margin_bottom", 120)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	margin.add_child(column)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "GAME_TITLE"
	column.add_child(title)
	var tagline := Label.new()
	tagline.theme_type_variation = &"QuoteText"
	tagline.text = "MENU_TAGLINE"
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(560, 0)
	column.add_child(tagline)
	var rule := ColorRect.new()
	rule.color = Color(0.83, 0.66, 0.38, 0.45)
	rule.custom_minimum_size = Vector2(380, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var rule_box := MarginContainer.new()
	rule_box.add_theme_constant_override(&"margin_top", 22)
	rule_box.add_theme_constant_override(&"margin_bottom", 26)
	rule_box.add_child(rule)
	column.add_child(rule_box)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 4)
	column.add_child(_menu)
	if Game.has_save():
		_button("MENU_CONTINUE", _on_continue)
	_button("MENU_NEW_GAME", _on_new_game)
	_button("MENU_OPTIONS", _show_options)
	_button("MENU_CREDITS", _show_credits)
	_button("MENU_QUIT", func(): Game.quit_game())

	var footer := Label.new()
	footer.theme_type_variation = &"SmallLabel"
	footer.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.2")
	footer.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	footer.modulate.a = 0.55
	_ui.add_child(footer)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 140
	footer.offset_top = -86
	footer.offset_bottom = -50

	_ui.add_child(_language_switch())

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_ui.add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	_options = OptionsMenu.new()
	_options.visible = false
	_options.closed.connect(_close_overlay)
	center.add_child(_options)
	_credits = _build_credits()
	_credits.visible = false
	center.add_child(_credits)
	_confirm = _build_confirm()
	_confirm.visible = false
	center.add_child(_confirm)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_fade)
	(_menu.get_child(0) as Button).grab_focus.call_deferred()

func _button(key: String, action: Callable, parent: Control = null, small := false) -> Button:
	var b := Button.new()
	b.text = key
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if small:
		b.theme_type_variation = &"SmallButton"
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play_ui(HOVER, -22.0))
	b.pressed.connect(func():
		if _busy:
			return
		Sfx.play_ui(CLICK, -8.0)
		action.call())
	(parent if parent != null else _menu).add_child(b)
	return b

func _language_switch() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -120
	box.offset_bottom = -48
	for lang in ["ro", "en"]:
		var b := Button.new()
		b.theme_type_variation = &"SmallButton"
		b.text = lang.to_upper()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.toggle_mode = true
		b.button_pressed = Settings.resolved_language() == lang
		b.pressed.connect(func():
			Sfx.play_ui(CLICK, -8.0)
			Settings.set_value(&"language", lang))
		b.set_meta(&"lang", lang)
		box.add_child(b)
	box.name = "Language"
	return box

func _on_setting(key: StringName, _value: Variant) -> void:
	if key != &"language":
		return
	var box := _ui.get_node_or_null("Language")
	if box == null:
		return
	for b in box.get_children():
		(b as Button).set_pressed_no_signal(Settings.resolved_language() == String(b.get_meta(&"lang")))

func _panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"LacquerPanel"
	panel.custom_minimum_size = min_size
	return panel

func _build_credits() -> Control:
	var panel := _panel(Vector2(760, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "MENU_CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for entry in CreditsDB.ENTRIES:
		var head := Label.new()
		head.theme_type_variation = &"SmallLabel"
		head.text = entry[0]
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(head)
		if entry[1] != "":
			var body := Label.new()
			body.theme_type_variation = &"BodyText"
			body.text = entry[1]
			body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(body)
	var back_row := CenterContainer.new()
	box.add_child(back_row)
	var back := _button("MENU_BACK", _close_overlay, back_row, true)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel

func _build_confirm() -> Control:
	var panel := _panel(Vector2(640, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	panel.add_child(box)
	var text := Label.new()
	text.theme_type_variation = &"BodyText"
	text.text = "MENU_CONFIRM_NEW"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 40)
	box.add_child(row)
	_button("MENU_YES", _start_new_game, row, true)
	_button("MENU_NO", _close_overlay, row, true)
	return panel

func _open_overlay(which: Control) -> void:
	_overlay.visible = true
	for c in [_options, _credits, _confirm]:
		(c as Control).visible = c == which
	var first := which.find_children("*", "Button", true, false)
	if not first.is_empty():
		(first[0] as Button).grab_focus.call_deferred()

func _close_overlay() -> void:
	Sfx.play_ui(BACK, -10.0)
	_overlay.visible = false
	for c in [_options, _credits, _confirm]:
		(c as Control).visible = false
	(_menu.get_child(0) as Button).grab_focus.call_deferred()

func _show_options() -> void:
	_open_overlay(_options)

func _show_credits() -> void:
	_open_overlay(_credits)

func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")) and _overlay.visible:
		get_viewport().set_input_as_handled()
		_close_overlay()

func _on_new_game() -> void:
	if Game.has_save():
		_open_overlay(_confirm)
	else:
		_start_new_game()

func _on_continue() -> void:
	_leave(func(): Game.continue_game())

func _start_new_game() -> void:
	_leave(func(): Game.new_game())

func _leave(start: Callable) -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_ui(CONFIRM, -6.0)
	Music.stop(1.2)
	start.call()
