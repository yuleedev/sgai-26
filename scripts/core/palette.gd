extends Node
# Single source of truth for the game's neutral UI colors (text/panels/borders).
# Functional colors (Treat=green, Clear=red, etc.) stay defined where they're
# used -- those are semantic, not part of the neutral palette.

const TEXT_BONE := Color("f7edc5")  # matches the result screen's existing text color
const TEXT_BONE_MUTED := Color(0.533, 0.511, 0.425)  # TEXT_BONE darkened ~45%, precomputed
                                                       # so this const doesn't rely on a method call

const PANEL_BG := Color(0.08, 0.095, 0.075, 0.95)   # dark green-black, not neutral grey
const PANEL_BORDER := Color(0.22, 0.24, 0.19)        # muted olive-grey, low contrast on purpose

const BUTTON_TEXT := TEXT_BONE
const BUTTON_DISABLED_BG := Color(0.11, 0.12, 0.1)
const BUTTON_DISABLED_BORDER := Color(0.18, 0.19, 0.16)
const BUTTON_DISABLED_TEXT := Color(0.42, 0.42, 0.38)
