extends Node
# Single source of truth for the game's neutral UI colors (text/panels/borders).
# Functional colors (Treat=green, Clear=red, etc.) stay defined where they're
# used -- those are semantic, not part of the neutral palette.

const TEXT_BONE := Color("f7edc5")  # matches the result screen's existing text color
const TEXT_BONE_MUTED := Color(0.533, 0.511, 0.425)  # TEXT_BONE darkened ~45%, precomputed
                                                       # so this const doesn't rely on a method call

const PANEL_BG := Color("1E2421")  # fully opaque -- alpha 1.0 by default on a 6-digit hex
const ACCENT_EDGE := Color("9A9478")  # bone khaki -- was #8A7B4A ("gold trim"), replaced per feedback
const BOARD_FRAME_BG := Color("161A18")
const SEPARATOR_COLOR := Color("3A423C")

const BUTTON_TEXT := Color("F0EDC4")  # close to TEXT_BONE but its own distinct value, as specified
const BUTTON_DISABLED_BG := Color(0.11, 0.12, 0.1)
const BUTTON_DISABLED_BORDER := Color(0.18, 0.19, 0.16)
const BUTTON_DISABLED_TEXT := Color(0.42, 0.42, 0.38)

# button fill colors -- shared across every screen with buttons (main HUD,
# tutorial, skill tree modal), not just game_manager.gd
const TREAT_BUTTON_FILL := Color("5C7A3A")
const CLEAR_BUTTON_FILL := Color("8A4038")
const NEUTRAL_BUTTON_FILL := Color("3A423C")

const ICON_TINT := Color("C8C4A0")
const ICON_TINT_LOCKED := Color("6A7470")  # dim but fully visible, not just a faded ICON_TINT

const VACCINE_TROUGH_BG := Color("12150F")
const VACCINE_TROUGH_BORDER := Color("3A423C")
const VACCINE_FILL := Color("A8BC7E")

const HIGHLIGHT_BONE := Color("F0EDC4")  # selection ring -- neutral, crisp, "I clicked here"
const SPREAD_PREDICTION_COLOR := Color("E07A2E")  # bright orange, full opacity -- was a muddy dark brown

const TILE_GAP := Color("2A302C")  # the only line between tiles now -- inner border/top-edge removed
