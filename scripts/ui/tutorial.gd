extends CanvasLayer

signal finished

const DIM_COLOR := Color(0, 0, 0, 0.74)
const HIGHLIGHT_COLOR := Color(0.79, 0.35, 0.36)  # spotlight-rect only, not panel/text chrome
const HIGHLIGHT_PAD := 12.0
const TOOLTIP_WIDTH := 400.0
const TOOLTIP_WIDTH_MEDIUM := 540.0
const TOOLTIP_WIDTH_WIDE := 660.0
const TOOLTIP_GAP := 26.0
const EDGE_MARGIN := 16.0

# keyword colors matched to the in-game buttons and stat labels they name
const KEYWORD_COLORS := {
	"TREAT": Color(0.5, 0.72, 0.88),
	"CLEAR": Color(0.86, 0.54, 0.54),
	"WAIT": Color(0.68, 0.7, 0.78),
	"DAY": Color(0.9, 0.9, 0.92),
	"FUNDING": Color(0.98, 0.78, 0.24),
	"DOSES": Color(0.55, 0.8, 1.0),
	"ORIGIN": Color(0.86, 0.42, 0.43),
	"Skill Tree": Color(0.72, 0.69, 0.9),
}

var steps: Array = []
var current := 0

var dimmer: Control
var tooltip: PanelContainer
var step_label: Label
var title_label: Label
var body_label: RichTextLabel
var next_button: Button
var skip_button: Button
var ui_font: Font

var has_highlight := false
var highlight_rect := Rect2()
var interactive_step := false
var is_animating := false
var spot_rect := Rect2()

class DimLayer extends Control:
	var owner_tutorial: Node = null

	func _has_point(point: Vector2) -> bool:
		if owner_tutorial == null:
			return true
		return owner_tutorial._dim_blocks_point(point)

func setup(step_list: Array) -> void:
	steps = step_list

func _ready() -> void:
	layer = 100
	ui_font = HudStyle.make_ui_font()
	_build_dimmer()
	_build_tooltip()
	if steps.is_empty():
		_finish()
		return
	_show_step(0, false)

func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _build_dimmer() -> void:
	var d := DimLayer.new()
	d.owner_tutorial = self
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	d.draw.connect(_on_dimmer_draw)
	add_child(d)
	dimmer = d

func _dim_blocks_point(point: Vector2) -> bool:
	if not interactive_step or not has_highlight:
		return true
	return not highlight_rect.has_point(point)

func _on_dimmer_draw() -> void:
	var screen := _screen_size()
	var hole := spot_rect
	if hole.size.x <= 1.0 or hole.size.y <= 1.0:
		dimmer.draw_rect(Rect2(Vector2.ZERO, screen), DIM_COLOR)
		return
	dimmer.draw_rect(Rect2(0, 0, screen.x, hole.position.y), DIM_COLOR)
	dimmer.draw_rect(Rect2(0, hole.end.y, screen.x, screen.y - hole.end.y), DIM_COLOR)
	dimmer.draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), DIM_COLOR)
	dimmer.draw_rect(Rect2(hole.end.x, hole.position.y, screen.x - hole.end.x, hole.size.y), DIM_COLOR)
	dimmer.draw_rect(hole, HIGHLIGHT_COLOR, false, 4.0)

func _build_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.add_theme_stylebox_override("panel", _tooltip_style())
	add_child(tooltip)

	tooltip.modulate.a = 0.0
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	tooltip.add_child(vbox)

	step_label = Label.new()
	if ui_font != null:
		step_label.add_theme_font_override("font", ui_font)
	step_label.add_theme_font_size_override("font_size", 18)
	step_label.add_theme_color_override("font_color", Palette.TEXT_BONE_MUTED)
	vbox.add_child(step_label)

	title_label = Label.new()
	if ui_font != null:
		title_label.add_theme_font_override("font", ui_font)
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Palette.TEXT_BONE)
	vbox.add_child(title_label)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = true
	body_label.scroll_active = false
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ui_font != null:
		body_label.add_theme_font_override("normal_font", ui_font)
		body_label.add_theme_font_override("bold_font", ui_font)
	body_label.add_theme_font_size_override("normal_font_size", 23)
	body_label.add_theme_color_override("default_color", Palette.TEXT_BONE)
	body_label.add_theme_constant_override("line_separation", 5)
	body_label.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	vbox.add_child(body_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(buttons)

	skip_button = Button.new()
	skip_button.text = "Skip"
	skip_button.custom_minimum_size = Vector2(100, 46)
	if ui_font != null:
		skip_button.add_theme_font_override("font", ui_font)
	skip_button.add_theme_font_size_override("font_size", 20)
	HudStyle.style_button(skip_button, Palette.NEUTRAL_BUTTON_FILL)
	skip_button.pressed.connect(_finish)
	buttons.add_child(skip_button)

	next_button = Button.new()
	next_button.text = "Next"
	next_button.custom_minimum_size = Vector2(132, 46)
	if ui_font != null:
		next_button.add_theme_font_override("font", ui_font)
	next_button.add_theme_font_size_override("font_size", 22)
	HudStyle.style_button(next_button, Palette.TREAT_BUTTON_FILL)
	next_button.pressed.connect(_on_next_pressed)
	buttons.add_child(next_button)

func _tooltip_style() -> StyleBoxFlat:
	return HudStyle.make_panel_style(HudStyle.AccentEdge.BORDERED)

func _show_step(index: int, animate := true) -> void:
	if animate:
		await _transition_to(index)
	else:
		await _intro_to(index)

func _apply_content(step: Dictionary, index: int) -> void:
	step_label.text = "STEP %d OF %d" % [index + 1, steps.size()]
	title_label.text = step.get("title", "")
	var raw_body: String = step.get("body", "")
	body_label.custom_minimum_size = Vector2(_body_width(raw_body), 0)
	body_label.text = _colorize(raw_body)
	next_button.text = "Got it" if index == steps.size() - 1 else "Next"

func _set_spot(r: Rect2) -> void:
	spot_rect = r
	dimmer.queue_redraw()

func _target_spot(info: Dictionary) -> Rect2:
	# a real highlight rect, or a zero-size rect (fully dimmed) for centered steps
	if info.has:
		return info.rect
	return Rect2(_screen_size() / 2.0, Vector2.ZERO)

func _intro_to(index: int) -> void:
	is_animating = true
	current = index
	var step: Dictionary = steps[index]
	var info := _resolve_rect(step)
	interactive_step = false
	has_highlight = info.has
	highlight_rect = info.rect
	_apply_content(step, index)
	await get_tree().process_frame
	tooltip.reset_size()
	tooltip.position = _tooltip_pos(tooltip.size)

	var target := _target_spot(info)
	var seed := Rect2(target.get_center(), Vector2.ZERO)
	spot_rect = seed
	dimmer.queue_redraw()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(tooltip, "modulate:a", 1.0, 0.3)
	tween.tween_method(_set_spot, seed, target, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	interactive_step = step.get("interactive", false)
	is_animating = false

func _transition_to(index: int) -> void:
	is_animating = true
	interactive_step = false

	# fade the current card out while the old spotlight is still showing
	var out := create_tween()
	out.tween_property(tooltip, "modulate:a", 0.0, 0.14)
	await out.finished

	# swap in the new content while the card is hidden
	current = index
	var step: Dictionary = steps[index]
	var info := _resolve_rect(step)
	_apply_content(step, index)
	await get_tree().process_frame
	tooltip.reset_size()

	# glide the spotlight from the old target to the new one
	var from_spot := spot_rect
	has_highlight = info.has
	highlight_rect = info.rect
	var to_spot := _target_spot(info)
	if not info.has:
		to_spot = Rect2(from_spot.get_center(), Vector2.ZERO)
	var move := create_tween()
	move.set_trans(Tween.TRANS_CUBIC)
	move.set_ease(Tween.EASE_IN_OUT)
	move.tween_method(_set_spot, from_spot, to_spot, 0.36)
	await move.finished

	# settle the card at its new spot with a small rise + fade in
	var final_pos := _tooltip_pos(tooltip.size)
	tooltip.position = final_pos + Vector2(0, 12)
	var reveal := create_tween()
	reveal.set_parallel(true)
	reveal.tween_property(tooltip, "modulate:a", 1.0, 0.2)
	reveal.tween_property(tooltip, "position", final_pos, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await reveal.finished

	interactive_step = step.get("interactive", false)
	is_animating = false

func _resolve_rect(step: Dictionary) -> Dictionary:
	if step.has("rect") and step["rect"] != null:
		return {"has": true, "rect": (step["rect"] as Rect2).grow(HIGHLIGHT_PAD)}
	var target = step.get("target")
	if target != null and is_instance_valid(target) and target is Control:
		var c := target as Control
		return {"has": true, "rect": Rect2(c.global_position, c.size).grow(HIGHLIGHT_PAD)}
	return {"has": false, "rect": Rect2()}

func _body_width(text: String) -> float:
	# wider cards for longer copy so it doesn't stack into a tall narrow wall
	if text.length() > 260:
		return TOOLTIP_WIDTH_WIDE
	if text.length() > 165:
		return TOOLTIP_WIDTH_MEDIUM
	return TOOLTIP_WIDTH

func _colorize(text: String) -> String:
	# tint keywords to match the buttons and stat labels they refer to
	var result := text
	for keyword in KEYWORD_COLORS:
		var hex: String = (KEYWORD_COLORS[keyword] as Color).to_html(false)
		result = result.replace(keyword, "[color=#%s]%s[/color]" % [hex, keyword])
	return result

func _tooltip_pos(size: Vector2) -> Vector2:
	var screen := _screen_size()
	var pos: Vector2

	if not has_highlight:
		pos = (screen - size) / 2.0
	else:
		var hole := highlight_rect
		if hole.end.x + TOOLTIP_GAP + size.x <= screen.x:
			pos.x = hole.end.x + TOOLTIP_GAP
			pos.y = hole.position.y + hole.size.y / 2.0 - size.y / 2.0
		elif hole.position.x - TOOLTIP_GAP - size.x >= 0:
			pos.x = hole.position.x - TOOLTIP_GAP - size.x
			pos.y = hole.position.y + hole.size.y / 2.0 - size.y / 2.0
		elif hole.end.y + TOOLTIP_GAP + size.y <= screen.y:
			pos.y = hole.end.y + TOOLTIP_GAP
			pos.x = hole.position.x + hole.size.x / 2.0 - size.x / 2.0
		else:
			pos.y = hole.position.y - TOOLTIP_GAP - size.y
			pos.x = hole.position.x + hole.size.x / 2.0 - size.x / 2.0

	pos.x = clampf(pos.x, EDGE_MARGIN, screen.x - size.x - EDGE_MARGIN)
	pos.y = clampf(pos.y, EDGE_MARGIN, screen.y - size.y - EDGE_MARGIN)
	return pos

func _on_next_pressed() -> void:
	if is_animating:
		return
	if current >= steps.size() - 1:
		_finish()
	else:
		_show_step(current + 1, true)

func _finish() -> void:
	if is_animating:
		return
	is_animating = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(tooltip, "modulate:a", 0.0, 0.22)
	tween.tween_property(dimmer, "modulate:a", 0.0, 0.28)
	await tween.finished
	finished.emit()
	queue_free()
