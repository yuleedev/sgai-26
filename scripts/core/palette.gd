extends Node
# Single source of truth for the game's neutral UI colors (text/panels/borders).
# Functional colors (Treat=green, Clear=red, etc.) stay defined where they're
# used -- those are semantic, not part of the neutral palette.

const TEXT_BONE := Color("f7edc5")  # matches the result screen's existing text color
const TEXT_BONE_MUTED := Color(0.533, 0.511, 0.425)  # TEXT_BONE darkened ~45%, precomputed
                                                       # so this const doesn't rely on a method call

const PANEL_BG := Color("1E2421")  # fully opaque -- alpha 1.0 by default on a 6-digit hex
const ACCENT_EDGE := Color("8A7B4A")  # the single accent-edge border color, replaces the old uniform border
const BOARD_FRAME_BG := Color("161A18")
const SEPARATOR_COLOR := Color("3A423C")

const BUTTON_TEXT := Color("F0EDC4")  # close to TEXT_BONE but its own distinct value, as specified
const BUTTON_DISABLED_BG := Color(0.11, 0.12, 0.1)
const BUTTON_DISABLED_BORDER := Color(0.18, 0.19, 0.16)
const BUTTON_DISABLED_TEXT := Color(0.42, 0.42, 0.38)

const ICON_TINT := Color("C8C4A0")
const ICON_TINT_LOCKED := Color("4A5450")  # dim but fully visible, not just a faded ICON_TINT

const VACCINE_TROUGH_BG := Color("12150F")
const VACCINE_TROUGH_BORDER := Color("3A423C")
const VACCINE_FILL := Color("A8BC7E")

const HIGHLIGHT_BONE := Color("F0EDC4")  # selection ring + at-risk outline both use this now
