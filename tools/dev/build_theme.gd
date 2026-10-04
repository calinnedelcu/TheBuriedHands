extends SceneTree
## Builds the UI theme and font variations (res://assets/ui/theme.tres).
## Palette: lacquer black, aged bronze, lamplight gold, parchment cream.
## Re-run after edits: godot --headless --path . -s res://tools/dev/build_theme.gd

const CREAM := Color(0.94, 0.88, 0.76)
const CREAM_DIM := Color(0.78, 0.71, 0.6)
const GOLD := Color(0.9, 0.7, 0.4)
const GOLD_DIM := Color(0.66, 0.52, 0.33)
const INK := Color(0.07, 0.05, 0.04)
const LACQUER := Color(0.06, 0.04, 0.035, 0.86)
const BRONZE := Color(0.55, 0.42, 0.26)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/fonts"))
	var body := _variation("res://assets/fonts/EBGaramond[wght].ttf", 460, 0, "body")
	var body_bold := _variation("res://assets/fonts/EBGaramond[wght].ttf", 640, 0, "body_bold")
	var italic := _variation("res://assets/fonts/EBGaramond-Italic[wght].ttf", 460, 0, "body_italic")
	var title := _variation("res://assets/fonts/Cinzel[wght].ttf", 520, 0, "title")
	var title_spaced := _variation("res://assets/fonts/Cinzel[wght].ttf", 600, 3, "title_spaced")
	var title_bold := _variation("res://assets/fonts/Cinzel[wght].ttf", 760, 1, "title_bold")

	var t := Theme.new()
	t.default_font = body
	t.default_font_size = 24

	# Base label look.
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.75))
	t.set_constant("outline_size", "Label", 0)

	_label(t, "TitleLabel", title, 76, GOLD, 0)
	_label(t, "SubtitleTitle", title_spaced, 20, GOLD_DIM, 0)
	_label(t, "HeaderLabel", title_spaced, 17, GOLD, 4)
	_label(t, "ObjectiveLabel", body, 25, CREAM, 6)
	_label(t, "HintLabel", italic, 20, CREAM_DIM, 5)
	_label(t, "SubtitleLabel", body, 28, CREAM, 8)
	_label(t, "SpeakerLabel", title_spaced, 18, GOLD, 6)
	_label(t, "PromptLabel", body_bold, 24, CREAM, 7)
	_label(t, "KeyCapLabel", title_bold, 18, INK, 0)
	_label(t, "LoadingLabel", title_spaced, 22, GOLD, 0)
	_label(t, "ToastLabel", italic, 21, CREAM, 6)
	_label(t, "ItemNameLabel", title_spaced, 18, GOLD, 6)
	_label(t, "BodyText", body, 26, CREAM, 0)
	_label(t, "QuoteText", italic, 24, CREAM_DIM, 0)
	_label(t, "SmallLabel", body, 18, CREAM_DIM, 0)

	# Panels.
	var lacquer := StyleBoxFlat.new()
	lacquer.bg_color = LACQUER
	lacquer.border_color = Color(BRONZE, 0.7)
	lacquer.set_border_width_all(1)
	lacquer.set_corner_radius_all(3)
	lacquer.set_content_margin_all(18)
	lacquer.shadow_color = Color(0, 0, 0, 0.45)
	lacquer.shadow_size = 12
	t.set_stylebox("panel", "PanelContainer", lacquer)
	t.set_type_variation("LacquerPanel", "PanelContainer")
	t.set_stylebox("panel", "LacquerPanel", lacquer)

	var keycap := StyleBoxFlat.new()
	keycap.bg_color = GOLD
	keycap.border_color = Color(1, 0.9, 0.7)
	keycap.set_border_width_all(1)
	keycap.set_corner_radius_all(4)
	keycap.content_margin_left = 9
	keycap.content_margin_right = 9
	keycap.content_margin_top = 2
	keycap.content_margin_bottom = 3
	t.set_type_variation("KeyCap", "PanelContainer")
	t.set_stylebox("panel", "KeyCap", keycap)

	var subtitle_band := StyleBoxFlat.new()
	subtitle_band.bg_color = Color(0.02, 0.015, 0.01, 0.62)
	subtitle_band.set_corner_radius_all(4)
	subtitle_band.content_margin_left = 26
	subtitle_band.content_margin_right = 26
	subtitle_band.content_margin_top = 12
	subtitle_band.content_margin_bottom = 14
	t.set_type_variation("SubtitleBand", "PanelContainer")
	t.set_stylebox("panel", "SubtitleBand", subtitle_band)

	# Buttons: text-only, gold on hover, with a thin underline.
	var empty := StyleBoxEmpty.new()
	empty.content_margin_top = 6
	empty.content_margin_bottom = 6
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(GOLD, 0.06)
	hover.border_color = Color(GOLD, 0.8)
	hover.border_width_bottom = 1
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	t.set_font("font", "Button", title)
	t.set_font_size("font_size", "Button", 30)
	t.set_color("font_color", "Button", CREAM_DIM)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color(1, 0.85, 0.6))
	t.set_color("font_disabled_color", "Button", Color(CREAM_DIM, 0.35))
	t.set_stylebox("normal", "Button", empty)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("disabled", "Button", empty)
	t.set_type_variation("SmallButton", "Button")
	t.set_font_size("font_size", "SmallButton", 22)

	# Option controls.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.15, 0.1, 0.9)
	track.set_corner_radius_all(2)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(GOLD, 0.85)
	fill.set_corner_radius_all(2)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	if ResourceLoader.exists("res://scenes/ui/slider_grabber_bronze.svg"):
		t.set_icon("grabber", "HSlider", load("res://scenes/ui/slider_grabber_bronze.svg"))
		t.set_icon("grabber_highlight", "HSlider", load("res://scenes/ui/slider_grabber_bronze_hover.svg"))
	t.set_font("font", "CheckButton", body)
	t.set_font_size("font_size", "CheckButton", 24)
	t.set_color("font_color", "CheckButton", CREAM)
	t.set_font("font", "OptionButton", body)
	t.set_font_size("font_size", "OptionButton", 24)
	var option_box := StyleBoxFlat.new()
	option_box.bg_color = Color(0.12, 0.09, 0.07, 0.9)
	option_box.border_color = Color(BRONZE, 0.7)
	option_box.set_border_width_all(1)
	option_box.set_corner_radius_all(3)
	option_box.set_content_margin_all(8)
	for state in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(state, "OptionButton", option_box)
	t.set_font("font", "PopupMenu", body)
	t.set_font_size("font_size", "PopupMenu", 22)
	t.set_stylebox("panel", "PopupMenu", lacquer)
	t.set_font("font", "TabBar", title)
	t.set_font_size("font_size", "TabBar", 22)
	t.set_color("font_selected_color", "TabBar", GOLD)
	t.set_color("font_unselected_color", "TabBar", CREAM_DIM)
	t.set_color("font_hovered_color", "TabBar", CREAM)
	var tab_selected := StyleBoxFlat.new()
	tab_selected.bg_color = Color(0, 0, 0, 0)
	tab_selected.border_color = GOLD
	tab_selected.border_width_bottom = 2
	tab_selected.content_margin_left = 18
	tab_selected.content_margin_right = 18
	tab_selected.content_margin_bottom = 8
	var tab_idle := tab_selected.duplicate()
	tab_idle.border_color = Color(0, 0, 0, 0)
	t.set_stylebox("tab_selected", "TabBar", tab_selected)
	t.set_stylebox("tab_unselected", "TabBar", tab_idle)
	t.set_stylebox("tab_hovered", "TabBar", tab_idle)
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	t.set_font("font", "TabContainer", title)
	t.set_font_size("font_size", "TabContainer", 22)
	t.set_color("font_selected_color", "TabContainer", GOLD)
	t.set_color("font_unselected_color", "TabContainer", CREAM_DIM)
	t.set_color("font_hovered_color", "TabContainer", CREAM)
	t.set_stylebox("tab_selected", "TabContainer", tab_selected)
	t.set_stylebox("tab_unselected", "TabContainer", tab_idle)
	t.set_stylebox("tab_hovered", "TabContainer", tab_idle)
	t.set_font("normal_font", "RichTextLabel", body)
	t.set_font("italics_font", "RichTextLabel", italic)
	t.set_font("bold_font", "RichTextLabel", body_bold)
	t.set_font_size("normal_font_size", "RichTextLabel", 26)
	t.set_font_size("italics_font_size", "RichTextLabel", 26)
	t.set_font_size("bold_font_size", "RichTextLabel", 26)
	t.set_color("default_color", "RichTextLabel", CREAM)

	print("theme err=", ResourceSaver.save(t, "res://assets/ui/theme.tres"))
	quit()

func _variation(path: String, weight: int, spacing: int, name: String) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = load(path)
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	v.spacing_glyph = spacing
	var out := "res://assets/ui/fonts/%s.tres" % name
	ResourceSaver.save(v, out)
	return load(out)

func _label(t: Theme, variation: String, font: Font, size: int, color: Color, outline: int) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font("font", variation, font)
	t.set_font_size("font_size", variation, size)
	t.set_color("font_color", variation, color)
	t.set_constant("outline_size", variation, outline)
	t.set_color("font_outline_color", variation, Color(0, 0, 0, 0.8))
