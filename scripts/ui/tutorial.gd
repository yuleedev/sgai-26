extends Control

const MAP_SCENE := "res://scenes/map_scene.tscn"
const UI_FONT := "res://assets/Play-Regular.ttf"

const TREAT_COLOR := Color(0.32, 0.52, 0.68)
const CLEAR_COLOR := Color(0.66, 0.38, 0.38)
const WAIT_COLOR := Color(0.40, 0.42, 0.48)
const FUNDING_COLOR := Color(0.98, 0.78, 0.24)
const DOSES_COLOR := Color(0.55, 0.8, 1.0)
const SKILL_COLOR := Color(0.44, 0.42, 0.58)
const HEALTHY_COLOR := Color(0.42, 0.7, 0.38)
const NEUTRAL_COLOR := Color(0.6, 0.62, 0.68)
const START_COLOR := Color(0.3, 0.68, 0.42)

var font: Font
var page_index := 0
var is_animating := false

var card: PanelContainer
var body: VBoxContainer
var back_button: Button
var next_button: Button
var dots_row: HBoxContainer
var dot_panels: Array[Panel] = []
var fade_overlay: ColorRect

var pages: Array = []

func _ready() -> void:
	font = load(UI_FONT)
	build_pages()
	build_background()
	build_card()
	build_fade_overlay()
	render_page(0)
	play_intro()

func build_pages() -> void:
	pages = [
		{
			"title": "Outbreak Response",
			"body": "A zombie virus has broken out in the city. You lead the response from the hospital at the center of the map.\n\nThe plan is simple to say and hard to do. Keep people alive until the vaccine is ready.",
		},
		{
			"title": "Read the Map",
			"body": "The city is a grid of neighborhoods around the central hospital.\n\nTile color shows the danger. Green means healthy, red means the neighborhood is overrun.\n\nClick a neighborhood to select it. Hover over one to see its healthy, infected, cured, and dead counts.",
			"chips": [
				{"icon": "res://assets/icons/hospital.png", "label": "Hospital", "color": SKILL_COLOR},
				{"icon": "res://assets/icons/neighborhood_SGAI.png", "label": "Neighborhood", "color": HEALTHY_COLOR},
			],
		},
		{
			"title": "Your Actions",
			"intro": "Select a neighborhood first, then choose an action. Every action moves the clock forward one day.",
			"rows": [
				{"icon": "res://assets/icons/upgrade_treatment.svg", "color": TREAT_COLOR, "name": "Treat", "desc": "Cure a share of the infected. Costs one dose."},
				{"icon": "res://assets/icons/upgrade_clear.svg", "color": CLEAR_COLOR, "name": "Clear", "desc": "Kill a share of the infected. Fast and final. The dead cannot be brought back."},
				{"icon": "", "color": WAIT_COLOR, "name": "Wait", "desc": "Pass the day and do nothing. The virus keeps spreading, so use it with care."},
			],
		},
		{
			"title": "Track Your Resources",
			"intro": "Three numbers decide how much you can do each day. Watch them closely.",
			"rows": [
				{"icon": "", "color": NEUTRAL_COLOR, "name": "Day", "desc": "Counts up to the vaccine day. Reach it and the vaccine ends the outbreak."},
				{"icon": "", "color": FUNDING_COLOR, "name": "Funding", "desc": "Cash from healthy neighborhoods each day. Spend it on upgrades."},
				{"icon": "", "color": DOSES_COLOR, "name": "Doses", "desc": "Limited Treat charges. Run out and you cannot Treat until you buy more."},
			],
		},
		{
			"title": "Spend on Upgrades",
			"body": "Open the Skill Tree to turn funding into an edge.\n\nStrengthen your treatment, stock extra doses, set up quarantine to slow the spread, or rush the vaccine to end the outbreak sooner.",
			"icon_row": [
				"res://assets/icons/upgrade_treatment.svg",
				"res://assets/icons/upgrade_doses.svg",
				"res://assets/icons/upgrade_clear.svg",
				"res://assets/icons/upgrade_quarantine.svg",
				"res://assets/icons/upgrade_vaccine.svg",
			],
		},
		{
			"title": "Win the Race",
			"body": "Every day the infection grows and spreads to new neighborhoods. Decide where to Treat and where to Clear, watch your doses and funding, and hold the line until the vaccine.\n\nSave at least half the city to win. Good luck.",
		},
	]

func build_background() -> void:
	var base := ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.06, 0.065, 0.08)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.15, 0.16, 0.19))
	gradient.set_color(1, Color(0.055, 0.06, 0.075))
	gradient.add_point(0.55, Color(0.10, 0.11, 0.13))

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.42)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 512
	tex.height = 512

	var vignette := TextureRect.new()
	vignette.texture = tex
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

func build_card() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(940, 660)
	card.add_theme_stylebox_override("panel", make_panel_style())
	center.add_child(card)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 18)
	card.add_child(main)

	var header := HBoxContainer.new()
	main.add_child(header)

	var heading := Label.new()
	heading.text = "How to Play"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_font(heading, 24, Color(0.55, 0.55, 0.6))
	header.add_child(heading)

	var skip_button := Button.new()
	skip_button.text = "Skip"
	skip_button.custom_minimum_size = Vector2(110, 40)
	apply_font(skip_button, 18)
	style_ghost_button(skip_button)
	skip_button.pressed.connect(start_game)
	header.add_child(skip_button)

	var divider := Panel.new()
	divider.custom_minimum_size = Vector2(0, 2)
	var line_style := StyleBoxFlat.new()
	line_style.bg_color = Color(0.24, 0.26, 0.30)
	divider.add_theme_stylebox_override("panel", line_style)
	main.add_child(divider)

	var body_wrap := MarginContainer.new()
	body_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_wrap.add_theme_constant_override("margin_top", 28)
	body_wrap.add_theme_constant_override("margin_bottom", 16)
	main.add_child(body_wrap)

	body = VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 20)
	body_wrap.add_child(body)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	main.add_child(nav)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(160, 56)
	apply_font(back_button, 26)
	style_action_button(back_button, WAIT_COLOR)
	back_button.pressed.connect(go_back)
	nav.add_child(back_button)

	dots_row = HBoxContainer.new()
	dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots_row.add_theme_constant_override("separation", 12)
	nav.add_child(dots_row)
	build_dots()

	next_button = Button.new()
	next_button.text = "Next"
	next_button.custom_minimum_size = Vector2(200, 56)
	apply_font(next_button, 26)
	style_action_button(next_button, TREAT_COLOR)
	next_button.pressed.connect(go_next)
	nav.add_child(next_button)

func build_dots() -> void:
	dot_panels.clear()
	for i in range(pages.size()):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dots_row.add_child(dot)
		dot_panels.append(dot)

func build_fade_overlay() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0.03, 0.035, 0.045)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.modulate.a = 1.0
	add_child(fade_overlay)

func render_page(index: int) -> void:
	page_index = index
	for child in body.get_children():
		child.queue_free()

	var page: Dictionary = pages[index]

	var title := Label.new()
	title.text = page.get("title", "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_font(title, 44, Color(0.92, 0.92, 0.94))
	body.add_child(title)

	if page.has("intro"):
		body.add_child(make_paragraph(page["intro"], 22, Color(0.62, 0.62, 0.67)))

	if page.has("body"):
		body.add_child(make_paragraph(page["body"], 25, Color(0.74, 0.74, 0.78)))

	if page.has("chips"):
		body.add_child(make_chip_row(page["chips"]))

	if page.has("icon_row"):
		body.add_child(make_icon_row(page["icon_row"]))

	if page.has("rows"):
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 16)
		rows.custom_minimum_size = Vector2(760, 0)
		rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for row_data in page["rows"]:
			rows.add_child(make_info_row(row_data))
		body.add_child(rows)

	update_dots()
	back_button.visible = index > 0
	var is_last := index == pages.size() - 1
	next_button.text = "Start Game" if is_last else "Next"
	style_action_button(next_button, START_COLOR if is_last else TREAT_COLOR)

func make_paragraph(text: String, size: int, color: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = "[center]%s[/center]" % text
	label.custom_minimum_size = Vector2(720, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if font != null:
		label.add_theme_font_override("normal_font", font)
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_color_override("default_color", color)
	label.add_theme_constant_override("line_separation", 6)
	return label

func make_chip_row(chips: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	for chip in chips:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 10)
		col.add_child(make_swatch(chip.get("icon", ""), chip["color"], 88, 52))
		var label := Label.new()
		label.text = chip["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		apply_font(label, 22, Color(0.8, 0.8, 0.84))
		col.add_child(label)
		row.add_child(col)
	return row

func make_icon_row(paths: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	for path in paths:
		row.add_child(make_swatch(path, SKILL_COLOR, 74, 44))
	return row

func make_info_row(data: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	row.add_child(make_swatch(data.get("icon", ""), data["color"], 66, 40))

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = data["name"]
	apply_font(name_label, 27, data["color"])
	text_col.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = data["desc"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(660, 0)
	apply_font(desc_label, 20, Color(0.7, 0.7, 0.74))
	text_col.add_child(desc_label)

	row.add_child(text_col)
	return row

func make_swatch(icon_path: String, accent: Color, box_size: float, icon_size: float) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(box_size, box_size)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.45)
	style.set_corner_radius_all(10)
	style.corner_detail = 8
	style.set_border_width_all(2)
	style.border_color = accent
	chip.add_theme_stylebox_override("panel", style)

	if icon_path != "":
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(icon)

	return chip

func update_dots() -> void:
	for i in range(dot_panels.size()):
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.corner_detail = 6
		if i == page_index:
			style.bg_color = Color(0.98, 0.78, 0.24)
		else:
			style.bg_color = Color(0.3, 0.31, 0.35)
		dot_panels[i].add_theme_stylebox_override("panel", style)

func go_next() -> void:
	if is_animating:
		return
	if page_index >= pages.size() - 1:
		start_game()
		return
	change_page(page_index + 1)

func go_back() -> void:
	if is_animating or page_index <= 0:
		return
	change_page(page_index - 1)

func change_page(new_index: int) -> void:
	is_animating = true
	var fade := create_tween()
	fade.tween_property(body, "modulate:a", 0.0, 0.12)
	await fade.finished
	render_page(new_index)
	body.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_property(body, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await reveal.finished
	is_animating = false

func play_intro() -> void:
	await get_tree().process_frame
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.97, 0.97)
	card.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.5)
	tween.tween_property(card, "modulate:a", 1.0, 0.45)
	tween.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func start_game() -> void:
	if is_animating:
		return
	is_animating = true
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.3)
	await tween.finished
	get_tree().change_scene_to_file(MAP_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		go_next()
	elif event.is_action_pressed("ui_cancel"):
		go_back()

func apply_font(control: Control, size: int, color: Color = Color(0.85, 0.85, 0.88)) -> void:
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)

func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16, 0.98)
	style.set_corner_radius_all(12)
	style.corner_detail = 8
	style.set_border_width_all(1)
	style.border_color = Color(0.24, 0.26, 0.30)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 18
	return style

func style_action_button(btn: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.45)
	normal.set_corner_radius_all(8)
	normal.corner_detail = 6
	normal.set_border_width_all(2)
	normal.border_color = accent
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 4
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.96))

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.25)
	hover.border_color = accent.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.6)
	btn.add_theme_stylebox_override("pressed", pressed)

func style_ghost_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.17)
	normal.set_corner_radius_all(6)
	normal.corner_detail = 6
	normal.set_border_width_all(1)
	normal.border_color = Color(0.26, 0.28, 0.32)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.74))

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.22, 0.26)
	hover.border_color = Color(0.34, 0.37, 0.42)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.09, 0.10, 0.12)
	btn.add_theme_stylebox_override("pressed", pressed)
