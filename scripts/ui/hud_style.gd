class_name HudStyle
extends RefCounted
# Shared HUD look, used by both game_manager.gd and skill_tree.gd so the two
# screens can't quietly drift into two different-looking dark panel styles.

enum AccentEdge { NONE, BORDERED }

static func make_panel_style(accent_edge: AccentEdge = AccentEdge.BORDERED) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL_BG
	style.set_corner_radius_all(0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	if accent_edge == AccentEdge.BORDERED:
		style.set_border_width_all(2)
		style.border_color = Palette.ACCENT_EDGE
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
	btn.add_theme_color_override("font_color", Palette.BUTTON_TEXT)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.25)
	hover.border_color = accent.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_hover_color", Palette.TEXT_BONE)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.6)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Palette.BUTTON_DISABLED_BG
	disabled.border_color = Palette.BUTTON_DISABLED_BORDER
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Palette.BUTTON_DISABLED_TEXT)
