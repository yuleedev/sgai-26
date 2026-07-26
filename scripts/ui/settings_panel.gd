extends CanvasLayer

signal closed

const CONTENT_WIDTH := 460.0
const SLIDER_HEIGHT := 24.0
const DIM_COLOR := Color(0.03, 0.035, 0.045, 0.82)

var dim: ColorRect
var panel: PanelContainer
var music_slider: HSlider
var sfx_slider: HSlider
var music_value: Label
var sfx_value: Label
var ui_font: Font
var is_closing := false

func _ready() -> void:
	layer = 90
	ui_font = HudStyle.make_ui_font()
	_build()
	_animate_in()

func _build() -> void:
	dim = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = PanelContainer.new()
	var style := HudStyle.make_panel_style(HudStyle.AccentEdge.BORDERED)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 26
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	_add_panel_grain(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	if ui_font != null:
		title.add_theme_font_override("font", ui_font)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Palette.TEXT_BONE)
	vbox.add_child(title)

	vbox.add_child(_make_separator())

	music_slider = _add_slider_row(vbox, "MUSIC", AudioSettings.music_volume)
	music_value = music_slider.get_meta("value_label")
	music_slider.value_changed.connect(_on_music_changed)

	sfx_slider = _add_slider_row(vbox, "SFX", AudioSettings.sfx_volume)
	sfx_value = sfx_slider.get_meta("value_label")
	sfx_slider.value_changed.connect(_on_sfx_changed)

	vbox.add_child(_make_separator())

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 44)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	if ui_font != null:
		close_button.add_theme_font_override("font", ui_font)
	close_button.add_theme_font_size_override("font_size", 18)
	HudStyle.style_button(close_button, Palette.NEUTRAL_BUTTON_FILL)
	close_button.pressed.connect(close)
	vbox.add_child(close_button)

func _add_panel_grain(target: PanelContainer) -> void:
	var grain := ColorRect.new()
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/panel_grain.gdshader")
	grain.material = material
	target.add_child(grain)

func _add_slider_row(parent: Node, label_text: String, value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(120, 0)
	if ui_font != null:
		name_label.add_theme_font_override("font", ui_font)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Palette.TEXT_BONE_MUTED)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = _format_percent(value)
	value_label.custom_minimum_size = Vector2(70, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if ui_font != null:
		value_label.add_theme_font_override("font", ui_font)
	value_label.add_theme_font_size_override("font_size", 22)
	value_label.add_theme_color_override("font_color", Palette.TEXT_BONE)
	row.add_child(value_label)

	slider.set_meta("value_label", value_label)
	return slider

func _style_slider(slider: HSlider) -> void:
	var trough := StyleBoxFlat.new()
	trough.bg_color = Palette.VACCINE_TROUGH_BG
	trough.set_corner_radius_all(0)
	trough.set_border_width_all(1)
	trough.border_color = Palette.VACCINE_TROUGH_BORDER
	trough.content_margin_top = 7
	trough.content_margin_bottom = 7
	slider.add_theme_stylebox_override("slider", trough)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.VACCINE_FILL
	fill.set_corner_radius_all(0)
	slider.add_theme_stylebox_override("grabber_area", fill)

	var fill_highlight := fill.duplicate() as StyleBoxFlat
	fill_highlight.bg_color = Palette.VACCINE_FILL.lightened(0.12)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_highlight)

	var grabber := _make_grabber(Palette.HIGHLIGHT_BONE)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_disabled", grabber)
	slider.add_theme_icon_override("grabber_highlight", _make_grabber(Color.WHITE))

func _make_grabber(color: Color) -> ImageTexture:
	var image := Image.create(10, 24, false, Image.FORMAT_RGBA8)
	image.fill(color)
	for y in range(image.get_height()):
		image.set_pixel(0, y, Palette.PANEL_BG)
		image.set_pixel(image.get_width() - 1, y, Palette.PANEL_BG)
	return ImageTexture.create_from_image(image)

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var line_style := StyleBoxLine.new()
	line_style.color = Palette.SEPARATOR_COLOR
	line_style.thickness = 1
	sep.add_theme_stylebox_override("separator", line_style)
	sep.add_theme_constant_override("separation", 17)
	return sep

func _format_percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

func _on_music_changed(value: float) -> void:
	music_value.text = _format_percent(value)
	AudioSettings.set_music_volume(value)

func _on_sfx_changed(value: float) -> void:
	sfx_value.text = _format_percent(value)
	AudioSettings.set_sfx_volume(value)

func _animate_in() -> void:
	dim.modulate.a = 0.0
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if is_closing:
		return
	is_closing = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.16)
	tween.tween_property(dim, "modulate:a", 0.0, 0.2)
	await tween.finished
	closed.emit()
	queue_free()
