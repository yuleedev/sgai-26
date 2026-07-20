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

const SKILLS := [
	{
		key = "better_cure_1",
		name = "Better Cure",
		desc = "Cure 20% → 35%",
		cost = 100000,
		letter = "C1",
		pos = Vector2(100, 140),
		prereqs = [],
	},
	{
		key = "better_cure_2",
		name = "Better Cure II",
		desc = "Cure 35% → 50%",
		cost = 200000,
		letter = "C2",
		pos = Vector2(100, 340),
		prereqs = ["better_cure_1"],
	},
	{
		key = "extra_doses_1",
		name = "Extra Doses",
		desc = "+5 doses",
		cost = 80000,
		letter = "D1",
		pos = Vector2(260, 140),
		prereqs = [],
	},
	{
		key = "extra_doses_2",
		name = "Extra Doses II",
		desc = "+5 more",
		cost = 120000,
		letter = "D2",
		pos = Vector2(260, 340),
		prereqs = ["extra_doses_1"],
	},
	{
		key = "rush_vaccine",
		name = "Rush Vaccine",
		desc = "Vaccine 3 days earlier",
		cost = 150000,
		letter = "V",
		pos = Vector2(420, 140),
		prereqs = [],
	},
	{
		key = "quarantine",
		name = "Quarantine",
		desc = "All spread chances halved",
		cost = 120000,
		letter = "Q",
		pos = Vector2(580, 140),
		prereqs = [],
	},
]

const CONNECTIONS := [
	["better_cure_1", "better_cure_2"],
	["extra_doses_1", "extra_doses_2"],
]

const NODE_SIZE := 56
const NODE_RADIUS := NODE_SIZE / 2

var upgrade_buttons: Dictionary = {}
var selected_key: String = ""

func _ready() -> void:
	build_visual_tree()
	visual_tree.draw.connect(_on_visual_tree_draw)
	close_button.pressed.connect(_on_close_pressed)
	earn_button.pressed.connect(_on_earn_pressed)
	detail_buy_button.pressed.connect(_on_detail_buy_pressed)
	hide_details()

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
	detail_icon.add_theme_font_size_override("font_size", 26)

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

		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(NODE_RADIUS)
		sb.corner_detail = 12
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_font_size_override("font_size", 24)
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
			color = Color(0.2, 0.8, 0.2, 0.8)
		elif gm.has_skill(conn[0]):
			color = Color(0.6, 0.8, 0.6, 0.5)
		else:
			color = Color(0.3, 0.3, 0.3, 0.6)

		visual_tree.draw_line(from_pos, to_pos, color, 2.0, true)

	if selected_key != "":
		var skill = _get_skill(selected_key)
		if skill != null:
			visual_tree.draw_circle(skill.pos, NODE_RADIUS + 5, Color(1.0, 0.85, 0.0, 0.8), false, 3.0)



func update_node_colors() -> void:
	var gm = get_parent()
	for skill in SKILLS:
		var btn = upgrade_buttons[skill.key]
		var color = _get_node_color(skill.key)

		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(NODE_RADIUS)
		sb.corner_detail = 12
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0

		if gm.has_skill(skill.key) or _can_buy(skill.key):
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.border_width_top = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(0.4, 1.0, 0.4)

		btn.add_theme_stylebox_override("normal", sb)

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

func _on_earn_pressed() -> void:
	var gm = get_parent()
	gm.earn_money(10000)
	update_ui()

func _on_close_pressed() -> void:
	queue_free()
