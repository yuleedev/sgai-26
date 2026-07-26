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
		style.set_border_width_all(1)
		style.border_color = Palette.ACCENT_EDGE
	return style

static func make_ui_font() -> Font:
	return load("res://assets/Play-Regular.ttf")

static func style_button(btn: Button, fill_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill_color
	normal.set_corner_radius_all(0)
	normal.set_border_width_all(1)
	normal.border_color = Palette.ACCENT_EDGE
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", Palette.BUTTON_TEXT)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_hover_color", Palette.BUTTON_TEXT)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill_color.darkened(0.10)
	pressed.content_margin_top = 10  # shifts the label 2px down while the button's
	pressed.content_margin_bottom = 6  # overall size stays the same (10+6 == 8+8)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_pressed_color", Palette.BUTTON_TEXT)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Palette.BUTTON_DISABLED_BG
	disabled.border_color = Palette.BUTTON_DISABLED_BORDER
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Palette.BUTTON_DISABLED_TEXT)
