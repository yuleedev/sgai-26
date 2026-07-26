extends CanvasLayer

@onready var money_label: Label = %MoneyLabel
@onready var close_button: Button = %CloseButton

@onready var visual_tree: Control = %VisualTree
@onready var detail_box: PanelContainer = %DetailBox
@onready var detail_panel: VBoxContainer = %DetailPanel
@onready var detail_hint: Label = %DetailHint
@onready var detail_content: VBoxContainer = %DetailContent
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_desc: Label = %DetailDesc
@onready var detail_cost: Label = %DetailCost
@onready var detail_buy_button: Button = %DetailBuyButton
@onready var detail_purchased: Label = %DetailPurchased
@onready var bg_overlay: ColorRect = $Background
@onready var panel: PanelContainer = $Panel

var _ui_font: Font

const SKILLS := [
		{
			key = "better_treatment_1",
			name = "Better Treatment I",
			desc = "Treat 20% → 35%",
			cost = 90,
			icon_path = "res://assets/icons/upgrade_treatment.svg",
			pos = Vector2(86, 135),
			prereqs = [],
		},
		{
			key = "better_treatment_2",
			name = "Better Treatment II",
			desc = "Treat 35% → 50%",
			cost = 160,
			icon_path = "res://assets/icons/upgrade_treatment.svg",
			pos = Vector2(86, 405),
			prereqs = ["better_treatment_1"],
		},
		{
			key = "extra_doses_1",
			name = "Extra Doses I",
			desc = "+5 doses",
			cost = 70,
			icon_path = "res://assets/icons/upgrade_doses.svg",
			pos = Vector2(306, 135),
			prereqs = [],
		},
		{
			key = "extra_doses_2",
			name = "Extra Doses II",
			desc = "+5 more",
			cost = 120,
			icon_path = "res://assets/icons/upgrade_doses.svg",
			pos = Vector2(306, 405),
			prereqs = ["extra_doses_1"],
		},
		{
			key = "reinforced_clear",
			name = "Reinforced Clear",
			desc = "Unlock paid Clear (55% kill for $8K)",
			cost = 50,
			icon_path = "res://assets/icons/upgrade_clear.svg",
			pos = Vector2(526, 135),
			prereqs = [],
		},
		{
			key = "rush_vaccine",
			name = "Rush Vaccine",
			desc = "Vaccine unlocked at day 22",
			cost = 140,
			icon_path = "res://assets/icons/upgrade_vaccine.svg",
			pos = Vector2(746, 135),
			prereqs = [],
		},
		{
			key = "quarantine",
			name = "Quarantine",
			desc = "All spread chances halved",
			cost = 220,
			icon_path = "res://assets/icons/upgrade_quarantine.svg",
			pos = Vector2(746, 405),
			prereqs = [],
		},
	]

const CONNECTIONS := [
	["better_treatment_1", "better_treatment_2"],
	["extra_doses_1", "extra_doses_2"],
]

const NODE_SIZE := 92
const NODE_RADIUS := NODE_SIZE / 2

var upgrade_buttons: Dictionary = {}
var selected_key: String = ""

const PURCHASE_SOUND: AudioStream = preload("res://assets/audio/purchase.mp3")
@onready var purchase_sound_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	_ui_font = _make_ui_font()
	_apply_theme()
	build_visual_tree()
	visual_tree.draw.connect(_on_visual_tree_draw)
	close_button.pressed.connect(_on_close_pressed)
	detail_buy_button.pressed.connect(_on_detail_buy_pressed)
	hide_details()

	purchase_sound_player.stream = PURCHASE_SOUND
	purchase_sound_player.volume_db = -18.0
	add_child(purchase_sound_player)

func _make_ui_font() -> Font:
	return HudStyle.make_ui_font()

func _apply_theme() -> void:
	bg_overlay.color = Color(0.03, 0.035, 0.045, 0.82)

	var panel_bg := HudStyle.make_panel_style(HudStyle.AccentEdge.BORDERED)
	panel_bg.content_margin_left = 32
	panel_bg.content_margin_right = 32
	panel_bg.content_margin_top = 26
	panel_bg.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", panel_bg)

	panel.add_theme_color_override("font_color", Palette.TEXT_BONE)

	var title := $Panel/MainVBox/Header/Title as Label
	if title != null and _ui_font != null:
		title.add_theme_font_override("font", _ui_font)
		title.add_theme_font_size_override("font_size", 32)
		title.add_theme_color_override("font_color", Palette.TEXT_BONE)

	money_label.add_theme_font_override("font", _ui_font)
	money_label.add_theme_font_size_override("font_size", 32)
	money_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))

	detail_hint.add_theme_color_override("font_color", Palette.TEXT_BONE_MUTED)
	detail_hint.add_theme_font_size_override("font_size", 16)

	detail_name.add_theme_font_override("font", _ui_font)
	detail_name.add_theme_font_size_override("font_size", 22)
	detail_name.add_theme_color_override("font_color", Palette.TEXT_BONE)

	detail_desc.add_theme_color_override("font_color", Palette.TEXT_BONE_MUTED)
	detail_desc.add_theme_font_size_override("font_size", 14)

	detail_cost.add_theme_font_override("font", _ui_font)
	detail_cost.add_theme_font_size_override("font_size", 18)
	detail_cost.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))

	detail_purchased.add_theme_font_override("font", _ui_font)
	detail_purchased.add_theme_font_size_override("font_size", 20)
	detail_purchased.add_theme_color_override("font_color", Palette.VACCINE_FILL)  # same "owned/complete" green as the vaccine bar fill

	detail_buy_button.add_theme_font_override("font", _ui_font)
	detail_buy_button.add_theme_font_size_override("font_size", 18)

	close_button.add_theme_font_override("font", _ui_font)
	close_button.add_theme_font_size_override("font_size", 18)

	HudStyle.style_button(detail_buy_button, Palette.TREAT_BUTTON_FILL)
	HudStyle.style_button(close_button, Palette.NEUTRAL_BUTTON_FILL)

	detail_content.add_theme_constant_override("separation", 12)
	detail_panel.add_theme_constant_override("separation", 12)
	var main_vbox := $Panel/MainVBox as VBoxContainer
	if main_vbox != null:
		main_vbox.add_theme_constant_override("separation", 18)
	detail_buy_button.custom_minimum_size = Vector2(0, 44)
	close_button.custom_minimum_size = Vector2(120, 44)

	var detail_card := HudStyle.make_panel_style(HudStyle.AccentEdge.BORDERED)
	detail_card.bg_color = Palette.BOARD_FRAME_BG  # a shade darker than the main panel, so it still reads as "nested inside" it
	detail_card.content_margin_left = 20
	detail_card.content_margin_right = 20
	detail_card.content_margin_top = 20
	detail_card.content_margin_bottom = 20
	detail_box.add_theme_stylebox_override("panel", detail_card)

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

	detail_icon.texture = load(skill.icon_path)
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
		return "$0k"
	return "$" + str(amount) + "k"

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
		btn.icon = load(skill.icon_path)
		btn.expand_icon = true
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

		upgrade_buttons[skill.key] = btn
		visual_tree.add_child(btn)

		var name_label := Label.new()
		name_label.text = skill.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.position = skill.pos + Vector2(-75, NODE_RADIUS + 8)
		if _ui_font != null:
			name_label.add_theme_font_override("font", _ui_font)
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", Palette.TEXT_BONE_MUTED)
		visual_tree.add_child(name_label)

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
			color = Color(0.28, 0.30, 0.34, 0.5)

		visual_tree.draw_line(from_pos, to_pos, color, 4.0, true)

	if selected_key != "":
		var skill = _get_skill(selected_key)
		if skill != null:
			visual_tree.draw_circle(skill.pos, NODE_RADIUS + 6, Color(1.0, 0.7, 0.0, 0.9), false, 4.0)



func update_node_colors() -> void:
	var gm = get_parent()
	for skill in SKILLS:
		var btn = upgrade_buttons[skill.key]
		var color = _get_node_color(skill.key)
		var is_locked = not (gm.has_skill(skill.key) or _can_buy(skill.key) or _prereqs_met(skill.key))
		btn.modulate = Color(0.5, 0.5, 0.5, 0.6) if is_locked else Color.WHITE
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
		purchase_sound_player.play()
		update_ui()
		if gm.has_method("refresh_status"):
			gm.refresh_status()

func _on_close_pressed() -> void:
	var gm = get_parent()
	if gm != null:
		gm.skill_tree_ref = null
		if gm.has_method("refresh_status"):
			gm.refresh_status()
	queue_free()
