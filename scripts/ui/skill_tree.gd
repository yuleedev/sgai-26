extends CanvasLayer

@onready var money_label: Label = %MoneyLabel
@onready var close_button: Button = %CloseButton
@onready var earn_button: Button = %EarnButton
@onready var visual_tree: Control = %VisualTree
@onready var detail_panel: VBoxContainer = %DetailPanel
@onready var detail_hint: Label = %DetailHint
@onready var detail_content: VBoxContainer = %DetailContent
@onready var detail_icon: Label = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_desc: Label = %DetailDesc
@onready var detail_cost: Label = %DetailCost
@onready var detail_buy_button: Button = %DetailBuyButton
@onready var detail_purchased: Label = %DetailPurchased
@onready var bg_overlay: ColorRect = $Background
@onready var panel: PanelContainer = $Panel

var _bangers: FontFile

const SKILLS := [
	{
		key = "better_treatment_1",
		name = "Better Treatment I",
		desc = "Treat 20% → 35%",
		cost = 50000,
		letter = "T1",
		pos = Vector2(40, 140),
		prereqs = [],
	},
	{
		key = "better_treatment_2",
		name = "Better Treatment II",
		desc = "Treat 35% → 50%",
		cost = 100000,
		letter = "T2",
		pos = Vector2(40, 340),
		prereqs = ["better_treatment_1"],
	},
	{
		key = "extra_doses_1",
		name = "Extra Doses I",
		desc = "+5 doses",
		cost = 40000,
		letter = "D1",
		pos = Vector2(170, 140),
		prereqs = [],
	},
	{
		key = "extra_doses_2",
		name = "Extra Doses II",
		desc = "+5 more",
		cost = 70000,
		letter = "D2",
		pos = Vector2(170, 340),
		prereqs = ["extra_doses_1"],
	},
	{
		key = "reinforced_clear",
		name = "Reinforced Clear",
		desc = "Unlock paid Clear (55% kill for $8K)",
		cost = 50000,
		letter = "RC",
		pos = Vector2(300, 140),
		prereqs = [],
	},
	{
		key = "rush_vaccine",
		name = "Rush Vaccine",
		desc = "Vaccine unlocked at day 27",
		cost = 80000,
		letter = "RV",
		pos = Vector2(430, 140),
		prereqs = [],
	},
	{
		key = "quarantine",
		name = "Quarantine",
		desc = "All spread chances halved",
		cost = 110000,
		letter = "Q",
		pos = Vector2(560, 140),
		prereqs = [],
	},
]

const CONNECTIONS := [
	["better_treatment_1", "better_treatment_2"],
	["extra_doses_1", "extra_doses_2"],
]

const NODE_SIZE := 56
const NODE_RADIUS := NODE_SIZE / 2

var upgrade_buttons: Dictionary = {}
var selected_key: String = ""

func _ready() -> void:
	_bangers = load("res://assets/Bangers-Regular.ttf")
	_apply_theme()
	build_visual_tree()
	visual_tree.draw.connect(_on_visual_tree_draw)
	close_button.pressed.connect(_on_close_pressed)
	earn_button.pressed.connect(_on_earn_pressed)
	detail_buy_button.pressed.connect(_on_detail_buy_pressed)
	hide_details()

func _apply_theme() -> void:
	bg_overlay.color = Color(0.06, 0.02, 0.02, 0.85)

	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.09, 0.09, 0.10)
	panel_bg.set_corner_radius_all(8)
	panel_bg.corner_detail = 8
	panel_bg.border_width_left = 2
	panel_bg.border_width_right = 2
	panel_bg.border_width_top = 2
	panel_bg.border_width_bottom = 2
	panel_bg.border_color = Color(0.25, 0.05, 0.05)
	panel_bg.content_margin_left = 12
	panel_bg.content_margin_right = 12
	panel_bg.content_margin_top = 8
	panel_bg.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_bg)

	panel.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))

	var title := $Panel/MainVBox/Header/Title as Label
	if title != null and _bangers != null:
		title.add_theme_font_override("font", _bangers)
		title.add_theme_font_size_override("font_size", 32)
		title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	money_label.add_theme_font_override("font", _bangers)
	money_label.add_theme_font_size_override("font_size", 20)
	money_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))

	detail_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	detail_hint.add_theme_font_size_override("font_size", 16)

	detail_name.add_theme_font_override("font", _bangers)
	detail_name.add_theme_font_size_override("font_size", 22)
	detail_name.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	detail_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_desc.add_theme_font_size_override("font_size", 14)

	detail_cost.add_theme_font_override("font", _bangers)
	detail_cost.add_theme_font_size_override("font_size", 18)
	detail_cost.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))

	detail_purchased.add_theme_font_override("font", _bangers)
	detail_purchased.add_theme_font_size_override("font_size", 20)
	detail_purchased.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))

	detail_buy_button.add_theme_font_override("font", _bangers)
	detail_buy_button.add_theme_font_size_override("font_size", 18)

	close_button.add_theme_font_override("font", _bangers)
	close_button.add_theme_font_size_override("font_size", 18)

	earn_button.add_theme_font_override("font", _bangers)
	earn_button.add_theme_font_size_override("font_size", 14)
	earn_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	_style_dark_button(detail_buy_button)
	_style_dark_button(close_button)

	var earn_sb := StyleBoxFlat.new()
	earn_sb.bg_color = Color(0.12, 0.12, 0.12)
	earn_sb.set_corner_radius_all(4)
	earn_sb.corner_detail = 6
	earn_sb.border_width_left = 1
	earn_sb.border_width_right = 1
	earn_sb.border_width_top = 1
	earn_sb.border_width_bottom = 1
	earn_sb.border_color = Color(0.2, 0.2, 0.2)
	earn_button.add_theme_stylebox_override("normal", earn_sb)

func _style_dark_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.17)
	normal.set_corner_radius_all(4)
	normal.corner_detail = 6
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.35, 0.08, 0.08)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.1, 0.1)
	hover.set_corner_radius_all(4)
	hover.corner_detail = 6
	hover.border_width_left = 1
	hover.border_width_right = 1
	hover.border_width_top = 1
	hover.border_width_bottom = 1
	hover.border_color = Color(0.5, 0.12, 0.12)
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.1, 0.05, 0.05)
	pressed.set_corner_radius_all(4)
	pressed.corner_detail = 6
	pressed.border_width_left = 1
	pressed.border_width_right = 1
	pressed.border_width_top = 1
	pressed.border_width_bottom = 1
	pressed.border_color = Color(0.3, 0.05, 0.05)
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	pressed.content_margin_top = 4
	pressed.content_margin_bottom = 4
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.08, 0.08, 0.08)
	disabled.set_corner_radius_all(4)
	disabled.corner_detail = 6
	disabled.border_width_left = 1
	disabled.border_width_right = 1
	disabled.border_width_top = 1
	disabled.border_width_bottom = 1
	disabled.border_color = Color(0.12, 0.12, 0.12)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))

func hide_details() -> void:
	detail_hint.visible = true
	detail_content.visible = false
	selected_key = ""

func show_details(key: String) -> void:
	selected_key = key
	var skill = _get_skill(key)
	if skill == null:
		return

	detail_hint.visible = false
	detail_content.visible = true

	detail_icon.text = skill.letter
	detail_name.text = skill.name
	detail_desc.text = skill.desc

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(NODE_RADIUS)
	sb.corner_detail = 12
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.bg_color = _get_node_color(key)
	detail_icon.add_theme_stylebox_override("normal", sb)
	detail_icon.add_theme_font_override("font", _bangers)
	detail_icon.add_theme_font_size_override("font_size", 24)

	var gm = get_parent()
	if gm.has_skill(key):
		detail_cost.text = ""
		detail_buy_button.visible = false
		detail_purchased.visible = true
	else:
		detail_cost.text = "Cost: " + _format_money(skill.cost)
		detail_buy_button.visible = true
		detail_purchased.visible = false
		detail_buy_button.text = "Buy"
		detail_buy_button.disabled = not _can_buy(key)

	visual_tree.queue_redraw()

func _get_skill(key: String):
	for s in SKILLS:
		if s.key == key:
			return s
	return null

func _prereqs_met(key: String) -> bool:
	var skill = _get_skill(key)
	if skill == null:
		return false
	var gm = get_parent()
	for p in skill.prereqs:
		if not gm.has_skill(p):
			return false
	return true

func _can_buy(key: String) -> bool:
	var gm = get_parent()
	var skill = _get_skill(key)
	if skill == null:
		return false
	if gm.has_skill(key):
		return false
	if not _prereqs_met(key):
		return false
	if gm.money < skill.cost:
		return false
	return true

func _format_money(amount: int) -> String:
	if amount == 0:
		return "$0"
	return "$" + str(amount / 1000) + "K"

func _get_node_color(key: String) -> Color:
	var gm = get_parent()
	if gm.has_skill(key):
		return Color(0.2, 0.7, 0.2)
	elif _can_buy(key) or _prereqs_met(key):
		return Color(0.35, 0.35, 0.4)
	else:
		return Color(0.15, 0.15, 0.18)

func build_visual_tree() -> void:
	for skill in SKILLS:
		var btn := Button.new()
		btn.text = skill.letter
		btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		btn.size = Vector2(NODE_SIZE, NODE_SIZE)
		btn.position = skill.pos - Vector2(NODE_RADIUS, NODE_RADIUS)
		btn.pressed.connect(_on_node_pressed.bind(skill.key))

		var sb_base := StyleBoxFlat.new()
		sb_base.set_corner_radius_all(NODE_RADIUS)
		sb_base.corner_detail = 12
		sb_base.content_margin_left = 0
		sb_base.content_margin_right = 0
		sb_base.content_margin_top = 0
		sb_base.content_margin_bottom = 0
		btn.add_theme_stylebox_override("normal", sb_base)

		var sb_hover := StyleBoxFlat.new()
		sb_hover.set_corner_radius_all(NODE_RADIUS)
		sb_hover.corner_detail = 12
		sb_hover.content_margin_left = 0
		sb_hover.content_margin_right = 0
		sb_hover.content_margin_top = 0
		sb_hover.content_margin_bottom = 0
		sb_hover.bg_color = Color(0.4, 0.4, 0.45)
		btn.add_theme_stylebox_override("hover", sb_hover)

		var sb_pressed := StyleBoxFlat.new()
		sb_pressed.set_corner_radius_all(NODE_RADIUS)
		sb_pressed.corner_detail = 12
		sb_pressed.content_margin_left = 0
		sb_pressed.content_margin_right = 0
		sb_pressed.content_margin_top = 0
		sb_pressed.content_margin_bottom = 0
		sb_pressed.bg_color = Color(0.2, 0.2, 0.25)
		btn.add_theme_stylebox_override("pressed", sb_pressed)

		var sb_disabled := StyleBoxFlat.new()
		sb_disabled.set_corner_radius_all(NODE_RADIUS)
		sb_disabled.corner_detail = 12
		sb_disabled.content_margin_left = 0
		sb_disabled.content_margin_right = 0
		sb_disabled.content_margin_top = 0
		sb_disabled.content_margin_bottom = 0
		btn.add_theme_stylebox_override("disabled", sb_disabled)

		btn.add_theme_font_override("font", _bangers)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color.WHITE)

		upgrade_buttons[skill.key] = btn
		visual_tree.add_child(btn)

	update_node_colors()

func _on_node_pressed(key: String) -> void:
	show_details(key)

func _on_visual_tree_draw() -> void:
	var gm = get_parent()

	for conn in CONNECTIONS:
		var from_skill = _get_skill(conn[0])
		var to_skill = _get_skill(conn[1])
		if from_skill == null or to_skill == null:
			continue

		var from_pos = from_skill.pos
		var to_pos = to_skill.pos

		var color: Color
		if gm.has_skill(conn[0]) and gm.has_skill(conn[1]):
			color = Color(0.25, 0.9, 0.25, 0.9)
		elif gm.has_skill(conn[0]):
			color = Color(0.5, 0.85, 0.5, 0.5)
		else:
			color = Color(0.3, 0.2, 0.2, 0.5)

		visual_tree.draw_line(from_pos, to_pos, color, 2.5, true)

	if selected_key != "":
		var skill = _get_skill(selected_key)
		if skill != null:
			visual_tree.draw_circle(skill.pos, NODE_RADIUS + 5, Color(1.0, 0.7, 0.0, 0.9), false, 3.0)



func update_node_colors() -> void:
	var gm = get_parent()
	for skill in SKILLS:
		var btn = upgrade_buttons[skill.key]
		var color = _get_node_color(skill.key)
		var has_border: bool = gm.has_skill(skill.key) or _can_buy(skill.key)

		for state in ["normal", "hover", "pressed", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = color
			sb.set_corner_radius_all(NODE_RADIUS)
			sb.corner_detail = 12
			sb.content_margin_left = 0
			sb.content_margin_right = 0
			sb.content_margin_top = 0
			sb.content_margin_bottom = 0

			if has_border:
				sb.border_width_left = 2
				sb.border_width_right = 2
				sb.border_width_top = 2
				sb.border_width_bottom = 2
				sb.border_color = Color(0.4, 1.0, 0.4)

			if state == "hover":
				sb.bg_color = Color(
					min(color.r + 0.15, 1.0),
					min(color.g + 0.15, 1.0),
					min(color.b + 0.15, 1.0),
				)

			btn.add_theme_stylebox_override(state, sb)

	visual_tree.queue_redraw()

func update_ui() -> void:
	var gm = get_parent()
	money_label.text = "Money: " + _format_money(gm.money)

	update_node_colors()

	if selected_key != "":
		show_details(selected_key)

func _on_detail_buy_pressed() -> void:
	if selected_key == "":
		return
	var gm = get_parent()
	var skill = _get_skill(selected_key)
	if skill != null and gm.buy_skill(selected_key, skill.cost):
		update_ui()
		if gm.has_method("refresh_status"):
			gm.refresh_status()

func _on_earn_pressed() -> void:
	var gm = get_parent()
	gm.earn_money(10000)
	update_ui()

func _on_close_pressed() -> void:
	var gm = get_parent()
	if gm.has_method("refresh_status"):
		gm.refresh_status()
	queue_free()
