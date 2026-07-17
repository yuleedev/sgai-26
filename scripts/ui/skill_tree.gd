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
		key = "hazard_resistance",
		name = "Hazard Resistance",
		desc = "Reduce damage from hazards",
		cost = 100,
		letter = "H",
		pos = Vector2(240, 80),
	},
	{
		key = "zombie_killing",
		name = "Zombie Killing",
		desc = "Take down zombies faster",
		cost = 150,
		letter = "Z",
		pos = Vector2(140, 210),
	},
	{
		key = "cure_efficacy",
		name = "Cure Efficacy",
		desc = "Each cure heals more infected",
		cost = 200,
		letter = "C",
		pos = Vector2(340, 210),
	},
	{
		key = "cargo_capacity",
		name = "Cargo Capacity",
		desc = "Carry more cure supplies per trip",
		cost = 300,
		letter = "G",
		pos = Vector2(240, 340),
	},
]

const CONNECTIONS := [
	["hazard_resistance", "zombie_killing"],
	["hazard_resistance", "cure_efficacy"],
	["cure_efficacy", "cargo_capacity"],
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
		detail_cost.text = "Cost: " + str(skill.cost) + "g"
		detail_buy_button.visible = true
		detail_purchased.visible = false
		if gm.can_buy_skill(key):
			detail_buy_button.disabled = false
			detail_buy_button.text = "Buy"
		else:
			detail_buy_button.disabled = true
			detail_buy_button.text = "Locked"

	visual_tree.queue_redraw()

func _get_skill(key: String):
	for s in SKILLS:
		if s.key == key:
			return s
	return null

func _get_node_color(key: String) -> Color:
	var gm = get_parent()
	if gm.has_skill(key):
		return Color(0.2, 0.7, 0.2)
	elif gm.can_buy_skill(key):
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

		if gm.has_skill(skill.key):
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.border_width_top = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(0.4, 1.0, 0.4)

		btn.add_theme_stylebox_override("normal", sb)

	visual_tree.queue_redraw()

func update_ui() -> void:
	var gm = get_parent()
	money_label.text = "Money: " + str(gm.money) + "g"

	update_node_colors()

	if selected_key != "":
		show_details(selected_key)

func _on_detail_buy_pressed() -> void:
	if selected_key == "":
		return
	var gm = get_parent()
	if gm.buy_skill(selected_key):
		update_ui()

func _on_earn_pressed() -> void:
	var gm = get_parent()
	gm.earn_money(50)
	update_ui()

func _on_close_pressed() -> void:
	queue_free()
