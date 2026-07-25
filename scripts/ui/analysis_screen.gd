extends Control

const DISPLAY_FONT: FontFile = preload("res://assets/Bangers-Regular.ttf")
const UI_FONT: FontFile = preload("res://assets/Play-Regular.ttf")
const STRATEGY_SCALE = preload("res://scripts/ui/strategy_scale.gd")
const CREAM := Color("f7edc5")
const MUTED := Color("aaa9ad")
const PANEL := Color(0.09, 0.095, 0.11, 0.94)
const TITLE_MUSIC := preload("res://assets/audio/hauntsync-stealth-breacher-tense-title-screen-218087.mp3")

const SCALE_DEFINITIONS := [
	{"key": "cure_clear", "title": "INTERVENTION", "left": "CURE", "right": "CLEAR"},
	{"key": "contain_hotspot", "title": "OUTBREAK CONTROL", "left": "CONTAIN SPREAD", "right": "SUPPRESS HOTSPOTS"},
	{"key": "focused_broad", "title": "TARGET COVERAGE", "left": "FOCUSED RESPONSE", "right": "BROAD COVERAGE"},
	{"key": "conserve_invest", "title": "RESOURCE USE", "left": "CONSERVE", "right": "INVEST"},
	{"key": "early_late", "title": "UPGRADE TIMING", "left": "EARLY", "right": "LATE"},
	{"key": "consistent_switching", "title": "ACTION PATTERN", "left": "CONSISTENT", "right": "SWITCHING"},
]

const UPGRADE_NAMES := {
	"better_treatment_1": "Treatment I",
	"better_treatment_2": "Treatment II",
	"extra_doses_1": "Extra Doses I",
	"extra_doses_2": "Extra Doses II",
	"reinforced_clear": "Reinforced Clear",
	"rush_vaccine": "Rush Vaccine",
	"quarantine": "Quarantine",
}

@onready var close_game_button: Button = $CloseGameButton
@onready var main_menu_button: Button = $MainMenuButton
@onready var scrim: ColorRect = $Scrim

var results: Array[Dictionary] = []
var scale_scores: Dictionary = {}

func _ready() -> void:
	for result in GameResults.playthrough_results:
		results.append(result)
	Music.play_track(TITLE_MUSIC, -10.0)
	_style_accent_button(close_game_button, 34)
	_style_accent_button(main_menu_button, 34)
	close_game_button.pressed.connect(_on_close_game_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	scrim.modulate.a = 1.0
	self.modulate.a = 0.0
	close_game_button.disabled = true
	main_menu_button.disabled = true
	_build_report()
	close_game_button.move_to_front()
	main_menu_button.move_to_front()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_property(scrim, "modulate:a", 0.84, 0.5)
	await tween.finished
	close_game_button.disabled = false
	main_menu_button.disabled = false

func _build_report() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 48
	margin.offset_top = 30
	margin.offset_right = -48
	margin.offset_bottom = -145
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)

	var title := _make_label("STRATEGY ANALYSIS", 54, CREAM, DISPLAY_FONT)
	page.add_child(title)

	var stats_panel := _make_panel()
	page.add_child(stats_panel)
	_build_stats_table(stats_panel)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(content)

	var scales_panel := _make_panel()
	scales_panel.custom_minimum_size = Vector2(1130, 0)
	scales_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scales_panel)
	_build_scales(scales_panel)

	var details_panel := _make_panel()
	details_panel.custom_minimum_size = Vector2(570, 0)
	content.add_child(details_panel)
	_build_details(details_panel)

func _build_stats_table(panel: PanelContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 7)
	panel.add_child(grid)
	for heading in ["OUTCOMES", "P1", "P2", "P3", "TOTAL"]:
		var header := _make_label(heading, 20, CREAM, UI_FONT)
		header.custom_minimum_size.x = 285 if heading == "OUTCOMES" else 205
		grid.add_child(header)

	_add_stat_row(grid, "ZOMBIES KILLED BY DISEASE", "disease_deaths")
	_add_stat_row(grid, "ZOMBIES KILLED BY PLAYER", "player_kills")
	_add_stat_row(grid, "ZOMBIES CURED", "zombies_cured")
	_add_stat_row(grid, "HEALTHY REMAINING", "survivors")

func _add_stat_row(grid: GridContainer, label_text: String, key: String) -> void:
	grid.add_child(_make_label(label_text, 20, MUTED, UI_FONT))
	var total_value := 0
	var total_population := 0
	for i in range(3):
		if i >= results.size():
			grid.add_child(_make_label("-", 22, MUTED, UI_FONT))
			continue
		var result := results[i]
		var value: int = result.get(key, 0)
		total_value += value
		total_population += int(result.get("original_population", 0))
		var text := "%d / %d" % [value, result.get("original_population", 0)] if key == "survivors" else str(value)
		grid.add_child(_make_label(text, 22, MUTED, UI_FONT))
	var total_text := "%d / %d" % [total_value, total_population] if key == "survivors" else str(total_value)
	grid.add_child(_make_label(total_text, 22, CREAM, UI_FONT))

func _build_scales(panel: PanelContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	panel.add_child(section)
	section.add_child(_make_label("STRATEGY SCALES", 30, CREAM, DISPLAY_FONT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)

	for definition in SCALE_DEFINITIONS:
		var values: Array[float] = []
		for result in results:
			values.append(_score_result(result, definition.key))
		var overall := _average(values)
		scale_scores[definition.key] = overall
		var row = STRATEGY_SCALE.new()
		row.setup(definition.title, definition.left, definition.right, overall, values)
		rows.add_child(row)

func _build_details(panel: PanelContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 16)
	scroll.add_child(details)

	details.add_child(_make_label("STRATEGY PROFILE", 30, CREAM, DISPLAY_FONT))
	_build_strategy_tags(details)
	details.add_child(HSeparator.new())
	details.add_child(_make_label("ACTIONS", 27, CREAM, DISPLAY_FONT))
	_build_action_bars(details)
	details.add_child(HSeparator.new())
	details.add_child(_make_label("UPGRADES", 27, CREAM, DISPLAY_FONT))
	_build_upgrade_matrix(details)

func _build_strategy_tags(parent: VBoxContainer) -> void:
	var candidates: Array[Dictionary] = []
	for definition in SCALE_DEFINITIONS:
		var value: float = scale_scores.get(definition.key, 0.0)
		candidates.append({"value": value, "strength": absf(value), "definition": definition})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.strength > b.strength)
	for i in range(mini(3, candidates.size())):
		var candidate := candidates[i]
		var definition: Dictionary = candidate.definition
		var tag_text: String = "MIXED " + definition.title
		if candidate.strength >= 0.15:
			tag_text = definition.left if candidate.value < 0.0 else definition.right
		var tag := _make_label(tag_text.to_upper(), 22, Color("2b2620"), UI_FONT)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_stylebox_override("normal", _make_tag_style())
		tag.custom_minimum_size.y = 42
		parent.add_child(tag)

func _build_action_bars(parent: VBoxContainer) -> void:
	parent.add_child(_make_label("TREAT   CLEAR   WAIT", 17, MUTED, UI_FONT))
	for i in range(results.size()):
		var actions: Array = results[i].get("action_history", [])
		var treat := actions.count("TREAT")
		var clear := actions.count("CLEAR")
		var wait := actions.count("WAIT")
		parent.add_child(_make_label("P%d    T %d    C %d    W %d" % [i + 1, treat, clear, wait], 18, CREAM, UI_FONT))
		var bar := HBoxContainer.new()
		bar.custom_minimum_size.y = 16
		bar.add_theme_constant_override("separation", 2)
		_add_bar_segment(bar, treat, Color("65c9d4"))
		_add_bar_segment(bar, clear, Color("cf6d67"))
		_add_bar_segment(bar, wait, Color("85858d"))
		parent.add_child(bar)

func _add_bar_segment(bar: HBoxContainer, amount: int, color: Color) -> void:
	if amount <= 0:
		return
	var segment := ColorRect.new()
	segment.color = color
	segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	segment.size_flags_stretch_ratio = float(amount)
	bar.add_child(segment)

func _build_infection_peaks(parent: VBoxContainer) -> void:
	for i in range(results.size()):
		var high_cells: Array = results[i].get("high_infected_cells_timeline", [])
		var peak := _max_int(high_cells)
		var spread: int = results[i].get("newly_infected_cells", 0)
		parent.add_child(_make_label("P%d   %d high-infection cells   %d new cells" % [i + 1, peak, spread], 18, CREAM, UI_FONT))
		var bar := ProgressBar.new()
		bar.max_value = 24
		bar.value = peak
		bar.show_percentage = false
		bar.custom_minimum_size.y = 16
		_style_progress_bar(bar)
		parent.add_child(bar)

func _build_upgrade_matrix(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	parent.add_child(grid)
	for heading in ["UPGRADE", "P1", "P2", "P3"]:
		var label := _make_label(heading, 17, MUTED, UI_FONT)
		label.custom_minimum_size.x = 240 if heading == "UPGRADE" else 62
		grid.add_child(label)
	for key in UPGRADE_NAMES:
		grid.add_child(_make_label(UPGRADE_NAMES[key], 17, CREAM, UI_FONT))
		for i in range(3):
			var purchase_day := _upgrade_day(results[i], key) if i < results.size() else 0
			grid.add_child(_make_label("D%d" % purchase_day if purchase_day > 0 else "-", 17, CREAM, UI_FONT))

func _score_result(result: Dictionary, key: String) -> float:
	var actions: Array = result.get("action_history", [])
	var targets: Array = result.get("action_targets", [])
	var purchases: Array = result.get("upgrade_purchases", [])
	match key:
		"cure_clear":
			var treat := actions.count("TREAT")
			var clear := actions.count("CLEAR")
			var intervention_score := float(clear - treat) / float(maxi(1, clear + treat))
			var treatment_upgrades := 0
			for upgrade_key in ["better_treatment_1", "better_treatment_2", "extra_doses_1", "extra_doses_2"]:
				if _upgrade_day(result, upgrade_key) > 0:
					treatment_upgrades += 1
			var upgrade_score := float(int(_upgrade_day(result, "reinforced_clear") > 0)) - float(treatment_upgrades) / 4.0
			return clampf(intervention_score * 0.75 + upgrade_score * 0.25, -1.0, 1.0)
		"contain_hotspot":
			var hotspot_targets := 0
			for target in targets:
				if int(target.get("infected_before", 0)) >= 25:
					hotspot_targets += 1
			var hotspot_share := float(hotspot_targets) / float(maxi(1, targets.size()))
			var containment := 1.0 if _upgrade_day(result, "quarantine") > 0 else 0.0
			return clampf(hotspot_share - containment, -1.0, 1.0)
		"focused_broad":
			if targets.size() < 2:
				return 0.0
			var unique_cells := {}
			for target in targets:
				unique_cells[target.get("cell", Vector2i(-1, -1))] = true
			var coverage := float(unique_cells.size() - 1) / float(maxi(1, mini(targets.size(), 24) - 1))
			return coverage * 2.0 - 1.0
		"conserve_invest":
			var income: int = result.get("total_income", 0)
			if income <= 0:
				return 0.0
			var spending: int = result.get("upgrade_spending", 0) + result.get("clear_spending", 0)
			return clampf(float(spending) / float(income) * 2.0 - 1.0, -1.0, 1.0)
		"early_late":
			if purchases.is_empty():
				return 0.0
			var timing_total := 0.0
			var final_day: int = maxi(2, result.get("days_played", 2))
			for purchase in purchases:
				timing_total += float(int(purchase.get("day", 1)) - 1) / float(final_day - 1)
			return clampf(timing_total / purchases.size() * 2.0 - 1.0, -1.0, 1.0)
		"consistent_switching":
			if actions.size() < 2:
				return 0.0
			var switches := 0
			for i in range(1, actions.size()):
				if actions[i] != actions[i - 1]:
					switches += 1
			return float(switches) / float(actions.size() - 1) * 2.0 - 1.0
		"origin_perimeter":
			if targets.is_empty():
				return 0.0
			var origin: Vector2i = result.get("outbreak_origin", Vector2i.ZERO)
			var max_distance := maxi(origin.x + origin.y, (4 - origin.x) + (4 - origin.y))
			max_distance = maxi(max_distance, origin.x + (4 - origin.y))
			max_distance = maxi(max_distance, (4 - origin.x) + origin.y)
			var distance_total := 0.0
			for target in targets:
				var cell: Vector2i = target.get("cell", origin)
				distance_total += abs(cell.x - origin.x) + abs(cell.y - origin.y)
			return clampf(distance_total / targets.size() / maxi(1, max_distance) * 2.0 - 1.0, -1.0, 1.0)
	return 0.0

func _upgrade_day(result: Dictionary, key: String) -> int:
	for purchase in result.get("upgrade_purchases", []):
		if purchase.get("key", "") == key:
			return purchase.get("day", 0)
	return 0

func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()

func _max_int(values: Array) -> int:
	var highest := 0
	for value in values:
		highest = maxi(highest, int(value))
	return highest

func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color("383a42")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _style_progress_bar(bar: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.16, 0.19)
	bg.border_color = Color("383a42")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CREAM
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)

func _make_tag_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _make_label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _style_accent_button(button: Button, font_size: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = CREAM
	normal.border_color = Color("2b2620")
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("fff7d9")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("e0d3a0")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("2b2620"))
	button.add_theme_color_override("font_hover_color", Color("2b2620"))
	button.add_theme_color_override("font_pressed_color", Color("2b2620"))

func _on_main_menu_pressed() -> void:
	GameResults.reset()
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")

func _on_close_game_pressed() -> void:
	get_tree().quit()
