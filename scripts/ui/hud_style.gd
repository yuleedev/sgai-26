class_name HudStyle
extends RefCounted
# Shared HUD look, used by both game_manager.gd and skill_tree.gd so the two
# screens can't quietly drift into two different-looking dark panel styles.

static func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16, 0.95)
	style.set_corner_radius_all(10)
	style.corner_detail = 8
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.24, 0.26, 0.30)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	return style

static func style_button(btn: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.45)
	normal.set_corner_radius_all(8)
	normal.corner_detail = 6
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
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

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.14, 0.14, 0.15)
	disabled.border_color = Color(0.22, 0.22, 0.24)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.42))
