extends Node2D

signal money_changed(new_amount: int)

const GRID_SIZE := 5
const STARTING_ZOMBIES := 20
const ZOMBIE_LEVELS := 4
const INFECTED_LEVEL_THRESHOLDS: Array[int] = [1, 25, 50]
const MIN_POPULATION := 50
const MAX_POPULATION := 150
const BASE_CELL := Vector2i(2, 2)

const WIN_SURVIVAL_THRESHOLD := 0.5
const INFECT_CONVERT_RATE := 0.30
const INFECT_DEATH_RATE := 0.05
const SPREAD_CHANCE_PER_INFECTED := 0.015
const SPREAD_CHANCE_CAP := 0.60
const SPREAD_INFECT_AMOUNT := 4
const INCOME_PER_DAY := 10
const INCOME_PER_HEALTHY := 100
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]

var treat_cure_rate: float = 0.20
var clear_kill_rate: float = 0.40
var max_doses: int = 10
const TILE_PX := 200
const TILE_SOURCE_ID := 0
const COLOR_TILES: Array[Vector2i] =[
	Vector2i(0,0),
	Vector2i(1,0),
	Vector2i(2,0),
	Vector2i(3,0),
	Vector2i(4,0),
]

const HUD_MARGIN := 24.0  # shared left/right screen margin so the board sits centered between the two side panels
const RIGHT_HUD_WIDTH := 240.0  # wider of the old skill-panel (200) and action-panel (240) content widths
const RIGHT_HUD_BLOCK_GAP := 269.0  # matches the previous gap between the (top-anchored) skill panel
									 # and the (independently center-anchored) action panel at 1920x1080
const TREAT_COLOR := Color(0.49, 0.84, 0.34)       # green (cure) -- was blue, now matches the "+cured" text color
const CLEAR_COLOR := Color(0.66, 0.38, 0.38)
const CLEAR_PLUS_ACCENT := Color(0.72, 0.46, 0.30)
const WAIT_ACCENT := Color(0.40, 0.42, 0.48)
const KILL_TEXT_COLOR := Color(1.0, 0.36, 0.36)

const SkillTreeScript := preload("res://scripts/ui/skill_tree.gd")  # lets us read SKILLS without instantiating the tree

signal game_ended_signal(ending: String, people_lost: int, zombies_killed: int, zombies_cured: int, total_population: int)

@onready var grid: TileMapLayer = $Grid
var money := 0
var day := 1
var skills: Dictionary = {}
var doses: int
var spread_multiplier: float = 1.0
var reinforced_clear_fee: int = 0
var vaccine_unlock_day: int = 25
var selected_cell := Vector2i(-1, -1)
var original_population := 0  # sum of all 24 neighborhoods' starting population
var total_zombies_cured := 0  # people actually treated by the player — NOT everyone who survived
var total_zombies_killed := 0  # people killed by CLEAR — NOT natural deaths
var game_ended := false
var ending_result := ""
var last_action_type := "WAIT"
var last_action_cell := Vector2i(-1, -1)
var game_id := ""
var run_id := 1
var log_path := ""
var summary_path := ""
var prev_total_dead := 0
var prev_total_cured := 0
var action_label: Label
var day_value: Label
var funding_value: Label
var doses_value: Label
var population_value: Label
var selection_header: Label
var selection_no_cell_label: Label
var selection_stats_box: VBoxContainer
var selection_healthy_value: Label
var selection_infected_value: Label
var selection_cured_value: Label
var selection_dead_value: Label
var treat_preview_label: Label
var clear_preview_label: Label
var outbreak_totals_value: Label
var vaccine_progress: ProgressBar
var vaccine_days_label: Label
var hud_font: Font
var treat_button: Button
var clear_button: Button
var selection_highlight: Line2D
var origin_marker: Label
var zombie_cell := Vector2i.ZERO
var cell_data: Dictionary[Vector2i, Dictionary] = {}
var hover_popup: PanelContainer
var hover_popup_shown := false
var hover_fade_tween: Tween
var hover_label: RichTextLabel
var hovered_cell := Vector2i(-1, -1)
var skill_tree_ref: CanvasLayer
var status_panel: PanelContainer
var action_panel: PanelContainer
var skill_button_panel: PanelContainer
var skill_preview_icons: Dictionary = {}  # icon_path -> {"node": TextureRect, "keys": Array[String]}
var tutorial_ref: CanvasLayer
const TUTORIAL_FLAG_PATH := "user://tutorial_seen"
var risk_highlight_nodes: Array[Line2D] = []
var risk_highlight_tweens: Array[Tween] = []

const REINFORCED_CLEAR_RATE := 0.55
var clear_plus_button: Button
var reduced_growth_cells: Dictionary[Vector2i, bool] = {}  # treated cells get halved growth for exactly 1 day

@export_file("*.tscn")
var end_screen_path := "res://scenes/end_screen.tscn"

@onready var map_music: AudioStreamPlayer = $MapMusic
@onready var treat_sound: AudioStreamPlayer = $TreatSound
@onready var clear_sound: AudioStreamPlayer = $ClearSound

func _ready() -> void:
	game_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	run_id = _compute_run_id()
	# wipe old CSVs after a full 3-run session so data doesn't overlap
	if run_id > 3:
		_clear_all_csvs()
		run_id = 1
	log_path = "user://log_run%d.csv" % run_id
	summary_path = "user://summary_run%d.csv" % run_id
	ensure_log_headers()
	_set_background_aspect_ratio()
	doses = max_doses
	initialize_grid()
	create_grid_frame()
	zombie_cell = random_outer_cell()
	seed_infection(zombie_cell, STARTING_ZOMBIES)
	update_all_cells()
	update_risk_highlights()
	set_player_cell()
	add_cell_icons()
	create_grid_lines()
	create_hover_popup()
	create_day_controls()
	create_origin_marker()
	refresh_status()
	maybe_start_tutorial.call_deferred()
	fade_in()
	map_music.finished.connect(map_music.play)
	map_music.play()

func _set_background_aspect_ratio() -> void:
	# keeps the vignette a true circle in physical screen space rather than
	# whatever aspect the raw UV happens to be, if the viewport size ever changes
	var bg_rect := get_node_or_null("BackgroundLayer/Background") as ColorRect
	if bg_rect == null or bg_rect.material == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0:
		return
	(bg_rect.material as ShaderMaterial).set_shader_parameter("aspect_ratio", viewport_size.x / viewport_size.y)
func _compute_run_id() -> int:
	var highest := 0
	for n in range(1, 100):
		var path := "user://log_run%d.csv" % n
		if FileAccess.file_exists(path):
			highest = n
	return highest + 1

func _clear_all_csvs() -> void:
	for n in range(1, 100):
		var log_f := "user://log_run%d.csv" % n
		var sum_f := "user://summary_run%d.csv" % n
		if FileAccess.file_exists(log_f):
			DirAccess.remove_absolute(log_f)
		if FileAccess.file_exists(sum_f):
			DirAccess.remove_absolute(sum_f)
		elif not FileAccess.file_exists(log_f):
			break

func fade_in() -> void:
	# black overlay on top that fades out so the map eases in instead of popping
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)

func ensure_log_headers() -> void:
	if not FileAccess.file_exists(log_path):
		var f := FileAccess.open(log_path, FileAccess.WRITE)
		f.store_line("run_id,game_id,player_type,day,action,cell_x,cell_y,doses_left,money,total_healthy,total_infected,total_cured,total_dead,daily_deaths,daily_cured")
		f.close()
	if not FileAccess.file_exists(summary_path):
		var f := FileAccess.open(summary_path, FileAccess.WRITE)
		f.store_line("run_id,game_id,player_type,ending,days_played,people_lost,zombies_killed,zombies_cured")
		f.close()

func add_cell_icons() -> void:
	var hospital_icon: Texture2D = load("res://assets/icons/hospital.png")
	var neighborhood_icon: Texture2D = load("res://assets/icons/neighborhood_SGAI.png")
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var icon := Sprite2D.new()
			icon.texture = hospital_icon if cell == BASE_CELL else neighborhood_icon
			var target := 110.0 / icon.texture.get_width()
			icon.scale = Vector2(target, target)
			icon.position = grid.position + Vector2(x * TILE_PX + TILE_PX / 2.0, y * TILE_PX + TILE_PX / 2.0)
			icon.modulate.a = 0.85
			icon.z_index = 3
			add_child(icon)

func create_grid_frame() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -5
	add_child(layer)

	var pad := 26.0
	var grid_px := float(GRID_SIZE * TILE_PX)
	var frame := Panel.new()
	frame.position = grid.position - Vector2(pad, pad)
	frame.size = Vector2(grid_px + pad * 2.0, grid_px + pad * 2.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.BOARD_FRAME_BG
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(2)
	sb.border_color = Palette.ACCENT_EDGE
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 26
	frame.add_theme_stylebox_override("panel", sb)
	layer.add_child(frame)

func create_grid_lines() -> void:
	var grid_px := float(GRID_SIZE * TILE_PX)
	for i in range(GRID_SIZE + 1):
		var offset := float(i * TILE_PX)
		_add_grid_line(
			grid.position + Vector2(offset, 0),
			grid.position + Vector2(offset, grid_px))
		_add_grid_line(
			grid.position + Vector2(0, offset),
			grid.position + Vector2(grid_px, offset))

func _add_grid_line(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = Color(0.03, 0.02, 0.03, 0.55)
	line.z_index = 2
	add_child(line)

func initialize_grid() -> void:
	cell_data.clear()
	original_population = 0
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var population := 0 if cell == BASE_CELL else randi_range(MIN_POPULATION, MAX_POPULATION)
			original_population += population
			cell_data[cell] = {
				"healthy": population,
				"infected": 0,
				"cured": 0,
				"dead": 0,
			}
			grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[0])
	center_grid()

func seed_infection(cell: Vector2i, amount: int) -> void:
	var data := cell_data[cell]
	var converted: int = min(amount, data["healthy"])
	data["healthy"] -= converted
	data["infected"] += converted

func center_grid() -> void:
	var grid_size_pixels := Vector2(GRID_SIZE * TILE_PX, GRID_SIZE * TILE_PX)
	var window_size := get_viewport_rect().size
	grid.position = (window_size - grid_size_pixels) / 2.0

func random_outer_cell() -> Vector2i:
	var outer_cells: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x,y)
			var is_outer_cell := (
				x == 0
				or x == GRID_SIZE - 1
				or y == 0
				or y == GRID_SIZE - 1
			)
			if is_outer_cell:
				outer_cells.append(cell)
	return outer_cells.pick_random()

func get_infected(cell: Vector2i) -> int:
	return cell_data.get(cell, {}).get("infected", 0)

func get_zombie_level(cell: Vector2i) -> int:
	var data: Dictionary = cell_data.get(cell, {})
	var infected: int = data.get("infected", 0)
	var level := 0
	for threshold in INFECTED_LEVEL_THRESHOLDS:
		if infected >= threshold:
			level += 1
	return clampi(level, 0, ZOMBIE_LEVELS - 1)

func update_all_cells() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			update_individual_cell(Vector2i(x,y))

func update_individual_cell(cell: Vector2i) -> void:
	if cell == BASE_CELL:
		grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[4])
		return
	grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[get_zombie_level(cell)])

func _compute_at_risk_cells() -> Array[Vector2i]:
	# a clean cell next door to an infected one is "at risk" -- same neighbor
	# check spread_infection() uses, just asked before the dice roll instead of after
	var at_risk: Array[Vector2i] = []
	for cell in cell_data:
		if cell == BASE_CELL or cell_data[cell]["infected"] > 0:
			continue
		for offset in NEIGHBOR_OFFSETS:
			var neighbor := cell + offset
			if cell_data.has(neighbor) and neighbor != BASE_CELL and cell_data[neighbor]["infected"] > 0:
				at_risk.append(cell)
				break
	return at_risk

func update_risk_highlights() -> void:
	for t in risk_highlight_tweens:
		if t != null:
			t.kill()
	risk_highlight_tweens.clear()
	for node in risk_highlight_nodes:
		if is_instance_valid(node):
			node.queue_free()
	risk_highlight_nodes.clear()

	for cell in _compute_at_risk_cells():
		var corner := grid.position + Vector2(cell.x * TILE_PX, cell.y * TILE_PX)
		var outline := Line2D.new()
		outline.width = 5.0
		outline.default_color = Color(1.0, 0.55, 0.15)
		outline.z_index = 6
		outline.closed = true  # lets the engine miter-join the corner properly, instead of
		outline.points = PackedVector2Array([  # manually repeating the first point, which leaves a seam
			corner + Vector2(8, 8),
			corner + Vector2(TILE_PX - 8, 8),
			corner + Vector2(TILE_PX - 8, TILE_PX - 8),
			corner + Vector2(8, TILE_PX - 8),
		])
		add_child(outline)
		risk_highlight_nodes.append(outline)

		var pulse := create_tween()
		pulse.set_loops()
		pulse.tween_property(outline, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(outline, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		risk_highlight_tweens.append(pulse)

func set_player_cell() -> void:
	grid.set_cell(BASE_CELL, TILE_SOURCE_ID, COLOR_TILES[4])

func earn_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)
	_update_skill_tree()

var is_transitioning := false
var tooltip_suppressed := false  # true only during the day-card flip (phase 4); tooltip stays available otherwise

func _build_calendar_card(initial_day: int) -> Control:
	# a small calendar-page-styled card instead of a plain full-screen label,
	# so the day-change reads as "a page turning" rather than a static title card
	const CARD_SIZE := Vector2(240, 280)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.19, 0.98)
	style.set_corner_radius_all(14)
	style.border_width_bottom = 3
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.32, 0.32, 0.38)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	var header := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.62, 0.18, 0.2)
	header_style.corner_radius_top_left = 14
	header_style.corner_radius_top_right = 14
	header.add_theme_stylebox_override("panel", header_style)
	header.custom_minimum_size = Vector2(0, 46)
	vbox.add_child(header)

	var header_label := Label.new()
	header_label.text = "DAY"
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if hud_font != null:
		header_label.add_theme_font_override("font", hud_font)
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", Palette.TEXT_BONE)
	header.add_child(header_label)

	var number_wrap := CenterContainer.new()
	number_wrap.custom_minimum_size = Vector2(0, CARD_SIZE.y - 46)
	vbox.add_child(number_wrap)

	var number_label := Label.new()
	number_label.text = "%d" % initial_day
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.add_theme_font_override("font", _make_display_font())  # same "important moment" font as the DAY value
	number_label.add_theme_font_size_override("font_size", 96)
	number_label.add_theme_color_override("font_color", Palette.TEXT_BONE)
	number_wrap.add_child(number_label)

	card.set_meta("day_label", number_label)
	card.set_meta("card_size", CARD_SIZE)
	return card

func play_day_transition() -> void:
	# calendar-flip beat: shows today's number, "flips" the page, reveals tomorrow's.
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.02, 0.03, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)

	var card := _build_calendar_card(day)
	var card_size: Vector2 = card.get_meta("card_size")
	var viewport_size := get_viewport().get_visible_rect().size
	# left side, lower third -- the left HUD panel grew tall enough (4 sections)
	# that vertical-center now overlaps it, so this sits below it instead
	card.position = Vector2(40.0, viewport_size.y - card_size.y - 40.0)
	card.pivot_offset = card_size / 2.0
	card.modulate.a = 0.0
	layer.add_child(card)

	var day_number_label: Label = card.get_meta("day_label")

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.55, 0.15)
	tween.tween_property(card, "modulate:a", 1.0, 0.15)
	tween.chain().tween_interval(0.15)
	# the flip: collapse vertically to a sliver, swap the number, expand back out
	tween.tween_property(card, "scale:y", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): day_number_label.text = "%d" % (day + 1))
	tween.tween_property(card, "scale:y", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.2)
	tween.set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.0, 0.18)
	tween.tween_property(card, "modulate:a", 0.0, 0.18)
	await tween.finished
	layer.queue_free()

func run_day_cycle(cell: Vector2i, icon_path: String, tint: Color, floater_text: String, floater_color: Color, add_impact_flash: bool, doses_before: int, funding_before: int, population_before: int) -> void:
	# Phase 1: action resolves -- floater and counter-tick start immediately (fire-and-forget,
	# they're allowed to keep animating past this phase's gate); play_action_scan is what
	# actually gates how long phase 1 lasts, so it's the one thing we await here.
	show_floating_text(cell, floater_text, floater_color)
	_tick_stat_label(doses_value, doses_before, doses, func(v): return "%d" % v)
	if funding_before != money:
		_tick_stat_label(funding_value, funding_before, money, func(v): return "$%dk" % v)
	if population_before != living_population():
		_tick_stat_label(population_value, population_before, living_population(), func(v): return "%d / %d" % [v, original_population])
	await play_action_scan(cell, icon_path, tint, add_impact_flash)
	# Phase 2: beat -- nothing, lets the eye settle before the simulation ticks.
	await get_tree().create_timer(0.15).timeout
	# Phase 3: simulation ticks -- growth/spread apply.
	# (fresh snapshot here, not the original pre-action values above, so this tick
	# animates from where phase 1 left off instead of jumping backward first)
	var sim_funding_before := money
	var sim_population_before := living_population()
	_run_simulation_phase(sim_funding_before, sim_population_before)
	await get_tree().create_timer(0.5).timeout
	# Phase 4: day card -- day number flips, tooltip suppressed.
	tooltip_suppressed = true
	await play_day_transition()
	day += 1
	check_ending()
	refresh_status()
	tooltip_suppressed = false
	is_transitioning = false

func run_wait_cycle() -> void:
	await get_tree().create_timer(0.15).timeout
	_run_simulation_phase(money, living_population())
	await get_tree().create_timer(0.5).timeout
	tooltip_suppressed = true
	await play_day_transition()
	day += 1
	check_ending()
	refresh_status()
	tooltip_suppressed = false
	is_transitioning = false

func log_day_row() -> void:
	var total_healthy := 0
	var total_infected := 0
	var total_cured := 0
	var total_dead := 0
	for cell in cell_data:
		if cell == BASE_CELL:
			continue
		var d: Dictionary = cell_data[cell]
		total_healthy += d["healthy"]
		total_infected += d["infected"]
		total_cured += d["cured"]
		total_dead += d["dead"]

	var daily_deaths := total_dead - prev_total_dead
	var daily_cured := total_cured - prev_total_cured
	prev_total_dead = total_dead
	prev_total_cured = total_cured

	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line("%d,%s,human,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
		run_id, game_id, day, last_action_type, last_action_cell.x, last_action_cell.y,
		doses, money, total_healthy, total_infected, total_cured, total_dead,
		daily_deaths, daily_cured,
	])
	f.close()

func check_ending() -> void:
	var all_overrun := true
	for cell in cell_data:
		if cell == BASE_CELL:
			continue
		var d: Dictionary = cell_data[cell]
		if d["healthy"] > 0 or d["cured"] > 0:
			all_overrun = false
			break

	if all_overrun:
		ending_result = "LOSS"
		finish_game(compute_people_lost())
		return

	if day >= vaccine_unlock_day:
		# captured before the vaccine conversion below zeroes out infected/healthy,
		# so this matches exactly what compute_people_lost() would have reported
		# at this instant -- same source as the live HUD line and the LOSS branch above
		var people_lost := compute_people_lost()
		for cell in cell_data:
			if cell == BASE_CELL:
				continue
			var d: Dictionary = cell_data[cell]
			d["cured"] += d["healthy"]  # vaccine protects everyone still healthy
			d["healthy"] = 0
			d["infected"] = 0
		update_all_cells()

		var alive := 0
		for cell in cell_data:
			if cell == BASE_CELL:
				continue
			alive += cell_data[cell]["cured"]
		var survival_rate := float(alive) / float(original_population) if original_population > 0 else 0.0
		ending_result = "WIN" if survival_rate >= WIN_SURVIVAL_THRESHOLD else "PYRRHIC"
		finish_game(people_lost)

func finish_game(people_lost: int) -> void:
	game_ended = true
	var f := FileAccess.open(summary_path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line("%d,%s,human,%s,%d,%d,%d,%d" % [
		run_id, game_id, ending_result, day, people_lost, total_zombies_killed, total_zombies_cured,
	])
	f.close()
	refresh_status()
	game_ended_signal.emit(ending_result, people_lost, total_zombies_killed, total_zombies_cured, original_population)
	GameResults.people_lost = people_lost
	GameResults.zombies_killed = total_zombies_killed
	GameResults.zombies_cured = total_zombies_cured

	GameResults.run_id = run_id
	var music_fade := create_tween()
	music_fade.tween_property(map_music, "volume_db", -40.0, 0.6)
	await music_fade.finished
	get_tree().change_scene_to_file(end_screen_path)

func grow_infection() -> void:
	for cell in cell_data:
		if cell == BASE_CELL:
			continue
		var data := cell_data[cell]
		var infected: int = data["infected"]
		if infected <= 0:
			continue
		# at least 1/day once infected > 0 — otherwise floor() truncation freezes
		# small counts forever (e.g. floor(2 * 0.30) == 0), which silently kills
		# spread: a freshly-seeded neighbor cell could never grow past its seed.
		var convert_rate := INFECT_CONVERT_RATE
		if reduced_growth_cells.has(cell):
			convert_rate *= 0.5
			reduced_growth_cells.erase(cell)
		var growth: int = max(1, int(floor(infected * convert_rate)))
		var converted: int = min(growth, data["healthy"])
		var died: int = min(int(floor(infected * INFECT_DEATH_RATE)), infected)
		data["healthy"] -= converted
		data["infected"] += converted - died
		data["dead"] += died

func spread_infection() -> void:
	var source_infected: Dictionary[Vector2i, int] = {}
	for cell in cell_data:
		source_infected[cell] = cell_data[cell]["infected"]
	for cell in cell_data:
		var infected: int = source_infected[cell]
		if infected <= 0:
			continue
		for offset in NEIGHBOR_OFFSETS:
			var target := cell + offset
			if not cell_data.has(target) or target == BASE_CELL:
				continue
			var target_data := cell_data[target]
			var target_population: int = target_data["healthy"] + target_data["infected"] + target_data["cured"]
			var chance: float = min(
				infected * SPREAD_CHANCE_PER_INFECTED * (target_population / 100.0),
				SPREAD_CHANCE_CAP,
			) * spread_multiplier
			if randf() < chance:
				var appear: int = min(SPREAD_INFECT_AMOUNT, target_data["healthy"])
				target_data["healthy"] -= appear
				target_data["infected"] += appear

func collect_income() -> void:
	var total_healthy := 0
	for cell in cell_data:
		total_healthy += cell_data[cell]["healthy"]
	earn_money(INCOME_PER_DAY + total_healthy / INCOME_PER_HEALTHY)

func _run_simulation_phase(funding_before: int, population_before: int) -> void:
	grow_infection()
	spread_infection()
	collect_income()
	log_day_row()
	update_all_cells()
	update_risk_highlights()
	_tick_stat_label(funding_value, funding_before, money, func(v): return "$%dk" % v)
	_tick_stat_label(population_value, population_before, living_population(), func(v): return "%d / %d" % [v, original_population])

func play_action_scan(cell: Vector2i, icon_path: String, tint: Color, add_impact_flash: bool = false) -> void:
	# icon pops in with a bounce (instead of a flat fade), a soft radial ring pulses
	# outward from the tile center, and a full-tile color wash wipes across left-to-right
	var tile_origin := grid.position + Vector2(cell.x * TILE_PX, cell.y * TILE_PX)
	var tile_center := tile_origin + Vector2(TILE_PX / 2.0, TILE_PX / 2.0)

	if add_impact_flash:
		# Clear-only: a quick dark flash under the wash gives the kill a bit of extra
		# weight, distinguishing it from Treat's softer reveal. Runs on its own tween
		# so it can't shift the timing of the main sequence below.
		var flash := ColorRect.new()
		flash.color = Color(0, 0, 0, 0.0)
		flash.position = tile_origin
		flash.size = Vector2(TILE_PX, TILE_PX)
		flash.z_index = 8
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var flash_tween := create_tween()
		flash_tween.tween_property(flash, "color:a", 0.35, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash_tween.tween_property(flash, "color:a", 0.0, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		flash_tween.tween_callback(flash.queue_free)

	var wash := ColorRect.new()
	wash.color = Color(tint.r, tint.g, tint.b, 0.32)
	wash.position = tile_origin
	wash.size = Vector2(0.0, TILE_PX)
	wash.z_index = 9
	add_child(wash)

	# radial gradient (transparent -> bright -> transparent) makes a soft pulsing ring
	var ring_gradient := Gradient.new()
	ring_gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ring_gradient.colors = PackedColorArray([
		Color(tint.r, tint.g, tint.b, 0.0),
		Color(tint.r, tint.g, tint.b, 0.55),
		Color(tint.r, tint.g, tint.b, 0.0),
	])
	var ring_tex := GradientTexture2D.new()
	ring_tex.gradient = ring_gradient
	ring_tex.fill = GradientTexture2D.FILL_RADIAL
	ring_tex.fill_from = Vector2(0.5, 0.5)
	ring_tex.fill_to = Vector2(1.0, 0.5)
	ring_tex.width = 128
	ring_tex.height = 128

	var ring := TextureRect.new()
	ring.texture = ring_tex
	ring.size = Vector2(TILE_PX, TILE_PX)
	ring.position = tile_origin
	ring.pivot_offset = Vector2(TILE_PX / 2.0, TILE_PX / 2.0)
	ring.scale = Vector2(0.3, 0.3)
	ring.modulate.a = 0.0
	ring.z_index = 11
	add_child(ring)

	var icon := Sprite2D.new()
	icon.texture = load(icon_path)
	var tex_width: float = icon.texture.get_width()
	var target_scale := Vector2.ONE * (140.0 / tex_width)
	icon.scale = target_scale * 0.3
	icon.position = tile_center
	icon.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	icon.z_index = 12
	add_child(icon)

	# retimed to fit inside the ~0.4s "action resolves" phase budget (was ~1.27s total)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(wash, "size:x", float(TILE_PX), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "modulate:a", 1.0, 0.1)
	tween.tween_property(icon, "scale", target_scale * 1.15, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.6, 0.05)
	tween.tween_property(ring, "scale", Vector2.ONE * 1.6, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(icon, "scale", target_scale, 0.06).set_trans(Tween.TRANS_SINE)
	tween.set_parallel(true)
	tween.tween_property(ring, "modulate:a", 0.0, 0.12)
	tween.chain().tween_interval(0.05)
	tween.set_parallel(true)
	tween.tween_property(wash, "modulate:a", 0.0, 0.12)
	tween.tween_property(icon, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(wash.queue_free)
	tween.tween_callback(ring.queue_free)
	tween.tween_callback(icon.queue_free)
	await tween.finished

func show_floating_text(cell: Vector2i, text: String, color: Color) -> void:
	# separate from the scan animation on purpose: this is the plain, readable
	# "what actually changed" number, so a result never has to be inferred
	# from the tile just looking the same as it did yesterday.
	var label := Label.new()
	label.text = text
	if hud_font != null:
		label.add_theme_font_override("font", hud_font)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.size = Vector2(160, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = grid.position + Vector2(cell.x * TILE_PX + TILE_PX / 2.0 - 80, cell.y * TILE_PX + TILE_PX / 2.0 - 16)
	label.z_index = 15
	label.modulate.a = 0.0
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.15)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(label.queue_free)

func has_valid_selection() -> bool:
	return cell_data.has(selected_cell) and selected_cell != BASE_CELL

func _on_treat_pressed() -> void:
	if game_ended or is_transitioning:
		return
	if not has_valid_selection():
		set_last_action("Select a neighborhood first")
		return
	if doses <= 0:
		set_last_action("No doses left")
		return
	is_transitioning = true
	var doses_before := doses
	var funding_before := money
	var population_before := living_population()
	var data := cell_data[selected_cell]
	var cured: int = compute_action_amount(data["infected"], treat_cure_rate)
	data["infected"] -= cured
	data["cured"] += cured
	total_zombies_cured += cured
	doses -= 1
	reduced_growth_cells[selected_cell] = true
	last_action_type = "TREAT"
	last_action_cell = selected_cell
	treat_sound.play()
	set_last_action("Treated (%d, %d): -%d infected, +%d cured" % [selected_cell.x, selected_cell.y, cured, cured])
	await run_day_cycle(selected_cell, "res://assets/icons/upgrade_treatment.svg", TREAT_COLOR, "+%d cured" % cured, TREAT_COLOR, false, doses_before, funding_before, population_before)

func _on_clear_pressed() -> void:
	if game_ended or is_transitioning:
		return
	if not has_valid_selection():
		set_last_action("Select a neighborhood first")
		return
	is_transitioning = true
	var doses_before := doses
	var funding_before := money
	var population_before := living_population()
	var data := cell_data[selected_cell]
	var killed: int = compute_action_amount(data["infected"], clear_kill_rate)
	data["infected"] -= killed
	data["dead"] += killed
	total_zombies_killed += killed
	last_action_type = "CLEAR"
	last_action_cell = selected_cell
	clear_sound.play()
	set_last_action("Cleared (%d, %d): -%d infected, +%d dead" % [selected_cell.x, selected_cell.y, killed, killed])
	await run_day_cycle(selected_cell, "res://assets/icons/upgrade_clear.svg", CLEAR_COLOR, "+%d killed" % killed, KILL_TEXT_COLOR, true, doses_before, funding_before, population_before)

func _on_clear_plus_pressed() -> void:
	if game_ended or is_transitioning:
		return
	if not has_valid_selection():
		set_last_action("Select a neighborhood first")
		return
	if money < reinforced_clear_fee:
		set_last_action("Not enough funding for Reinforced Clear")
		return
	is_transitioning = true
	var doses_before := doses
	var funding_before := money
	var population_before := living_population()
	money -= reinforced_clear_fee
	money_changed.emit(money)
	_update_skill_tree()
	var data := cell_data[selected_cell]
	var killed: int = compute_action_amount(data["infected"], REINFORCED_CLEAR_RATE)
	data["infected"] -= killed
	data["dead"] += killed
	total_zombies_killed += killed
	last_action_type = "CLEAR"
	last_action_cell = selected_cell
	clear_sound.play()
	set_last_action("Reinforced Clear (%d, %d): -%d infected, +%d dead ($%dK)" % [selected_cell.x, selected_cell.y, killed, killed, reinforced_clear_fee])
	await run_day_cycle(selected_cell, "res://assets/icons/upgrade_clear.svg", CLEAR_COLOR, "+%d killed" % killed, KILL_TEXT_COLOR, true, doses_before, funding_before, population_before)

func _on_wait_pressed() -> void:
	if game_ended or is_transitioning:
		return
	is_transitioning = true
	last_action_type = "WAIT"
	last_action_cell = Vector2i(-1, -1)
	set_last_action("Waited")
	await run_wait_cycle()

func set_last_action(text: String) -> void:
	if action_label != null:
		action_label.text = text

func has_skill(skill: String) -> bool:
	return skills.get(skill, false)

func buy_skill(skill: String, cost: int) -> bool:
	if has_skill(skill):
		return false
	if money < cost:
		return false
	money -= cost
	money_changed.emit(money)
	_update_skill_tree()
	skills[skill] = true
	match skill:
		"better_treatment_1":
			treat_cure_rate = 0.35
		"better_treatment_2":
			treat_cure_rate = 0.50
		"extra_doses_1":
			max_doses += 5
			doses += 5
		"extra_doses_2":
			max_doses += 5
			doses += 5
		"reinforced_clear":
			reinforced_clear_fee = 8
			if clear_plus_button != null:
				clear_plus_button.visible = true
				clear_plus_button.text = "Clear+ ($%dK)" % reinforced_clear_fee
		"rush_vaccine":
			vaccine_unlock_day = 22
			# buying this can retroactively put the game already past its own new
			# deadline (e.g. bought on day 22+); re-check right away instead of
			# waiting for the next day-transition to notice
			if day >= vaccine_unlock_day:
				check_ending()
		"quarantine":
			spread_multiplier = 0.5
	var skill_names := {
		"better_treatment_1": "Better Treatment I",
		"better_treatment_2": "Better Treatment II",
		"extra_doses_1": "Extra Doses I",
		"extra_doses_2": "Extra Doses II",
		"reinforced_clear": "Reinforced Clear",
		"rush_vaccine": "Rush Vaccine",
		"quarantine": "Quarantine",
	}
	set_last_action("Purchased " + skill_names.get(skill, skill))

	log_skill_purchase(skill)
	_refresh_skill_preview()

	return true

func log_skill_purchase(skill: String) -> void:
	var total_healthy := 0
	var total_infected := 0
	var total_cured := 0
	var total_dead := 0
	for cell in cell_data:
		if cell == BASE_CELL:
			continue
		var d: Dictionary = cell_data[cell]
		total_healthy += d["healthy"]
		total_infected += d["infected"]
		total_cured += d["cured"]
		total_dead += d["dead"]
	var daily_deaths := total_dead - prev_total_dead
	var daily_cured := total_cured - prev_total_cured
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line("%d,%s,human,%d,SKILL:%s,-1,-1,%d,%d,%d,%d,%d,%d,%d,%d" % [
		run_id, game_id, day, skill,
		doses, money, total_healthy, total_infected, total_cured, total_dead,
		daily_deaths, daily_cured,
	])
	f.close()

func _on_skills_pressed() -> void:
	var tree := preload("res://scenes/skill_tree.tscn").instantiate()
	skill_tree_ref = tree
	add_child(tree)
	tree.update_ui()

func _update_skill_tree() -> void:
	if skill_tree_ref != null and is_instance_valid(skill_tree_ref):
		skill_tree_ref.update_ui()

func create_day_controls() -> void:
	hud_font = _make_ui_font()
	_build_status_panel()
	_build_right_hud()
	selection_highlight = Line2D.new()
	selection_highlight.width = 4.0
	selection_highlight.default_color = Color(1.0, 0.85, 0.2, 0.85)
	selection_highlight.visible = false
	selection_highlight.z_index = 5
	selection_highlight.closed = true
	add_child(selection_highlight)
	# same pulse cadence as the risk outlines, so the two don't look like two
	# different visual languages next to each other
	var selection_pulse := create_tween()
	selection_pulse.set_loops()
	selection_pulse.tween_property(selection_highlight, "modulate:a", 0.6, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	selection_pulse.tween_property(selection_highlight, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _make_ui_font() -> Font:
	# condensed fonts read cramped at zero tracking -- FontVariation's glyph
	# spacing adds real letter-spacing without needing a different typeface
	var variation := FontVariation.new()
	variation.base_font = load("res://assets/Coolvetica Rg.otf")
	variation.spacing_glyph = 3
	return variation

func _make_display_font() -> Font:
	# reserved for the few "important" moments (day count, vaccine countdown) --
	# everywhere else uses the condensed font from _make_ui_font() for legibility
	return load("res://assets/Bangers-Regular.ttf")

func _build_status_panel() -> void:
	# one panel, one border/background -- four sections stacked in a single
	# VBoxContainer and divided by thin HSeparators, not separate bordered panels
	var panel := PanelContainer.new()
	panel.position = Vector2(HUD_MARGIN, 24)
	panel.add_theme_stylebox_override("panel", _make_hud_panel_style(HudStyle.AccentEdge.BORDERED))
	$UI.add_child(panel)
	status_panel = panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(340, 0)
	panel.add_child(vbox)

	# Section 1: Status
	day_value = _add_stat_row(vbox, "DAY", Palette.TEXT_BONE)
	day_value.add_theme_font_override("font", _make_display_font())  # the one "important" value in this section
	day_value.add_theme_font_size_override("font_size", 30)
	funding_value = _add_stat_row(vbox, "FUNDING", Color(0.98, 0.78, 0.24))
	doses_value = _add_stat_row(vbox, "DOSES", Color(0.55, 0.8, 1.0))
	population_value = _add_stat_row(vbox, "POPULATION", Color(0.6, 0.88, 0.62))

	vbox.add_child(_make_hud_separator())

	# Section 2: Selected neighborhood
	selection_header = Label.new()
	if hud_font != null:
		selection_header.add_theme_font_override("font", hud_font)
	selection_header.add_theme_font_size_override("font_size", 22)
	selection_header.add_theme_color_override("font_color", Palette.TEXT_BONE)
	vbox.add_child(selection_header)

	selection_no_cell_label = Label.new()
	selection_no_cell_label.text = "No neighborhood selected"
	selection_no_cell_label.add_theme_font_override("font", _make_ui_font())
	selection_no_cell_label.add_theme_font_size_override("font_size", 18)
	selection_no_cell_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.54))
	vbox.add_child(selection_no_cell_label)

	selection_stats_box = VBoxContainer.new()
	selection_stats_box.add_theme_constant_override("separation", 6)
	vbox.add_child(selection_stats_box)

	selection_healthy_value = _add_stat_row(selection_stats_box, "HEALTHY", Color(0.49, 0.84, 0.34))
	selection_infected_value = _add_stat_row(selection_stats_box, "INFECTED", Color(1.0, 0.36, 0.36))
	selection_cured_value = _add_stat_row(selection_stats_box, "CURED", Color(0.36, 0.61, 1.0))
	selection_dead_value = _add_stat_row(selection_stats_box, "DEAD", Color(0.69, 0.69, 0.69))

	treat_preview_label = Label.new()
	treat_preview_label.add_theme_font_override("font", _make_ui_font())
	treat_preview_label.add_theme_font_size_override("font_size", 18)
	selection_stats_box.add_child(treat_preview_label)

	clear_preview_label = Label.new()
	clear_preview_label.add_theme_font_override("font", _make_ui_font())
	clear_preview_label.add_theme_font_size_override("font_size", 18)
	selection_stats_box.add_child(clear_preview_label)

	vbox.add_child(_make_hud_separator())

	# Section 3: Outbreak totals
	outbreak_totals_value = Label.new()
	if hud_font != null:
		outbreak_totals_value.add_theme_font_override("font", hud_font)
	outbreak_totals_value.add_theme_font_size_override("font_size", 18)
	outbreak_totals_value.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	vbox.add_child(outbreak_totals_value)

	vbox.add_child(_make_hud_separator())

	# Section 4: Vaccine -- the other "important" moment, gets the same display font
	var vaccine_label := Label.new()
	vaccine_label.text = "VACCINE"
	vaccine_label.add_theme_font_override("font", _make_display_font())
	vaccine_label.add_theme_font_size_override("font_size", 24)
	vaccine_label.add_theme_color_override("font_color", Palette.TEXT_BONE)
	vbox.add_child(vaccine_label)

	vaccine_progress = ProgressBar.new()
	vaccine_progress.min_value = 0.0
	vaccine_progress.max_value = 1.0
	vaccine_progress.step = 0.001
	vaccine_progress.show_percentage = false
	vaccine_progress.custom_minimum_size = Vector2(0, 18)
	var vaccine_fill_style := StyleBoxFlat.new()
	vaccine_fill_style.bg_color = Color(0.42, 0.68, 0.35)  # green -- rescue arriving, not pressure
	vaccine_fill_style.set_corner_radius_all(4)
	vaccine_progress.add_theme_stylebox_override("fill", vaccine_fill_style)
	var vaccine_bg_style := StyleBoxFlat.new()
	vaccine_bg_style.bg_color = Color(0.1, 0.11, 0.13)
	vaccine_bg_style.set_corner_radius_all(4)
	vaccine_progress.add_theme_stylebox_override("background", vaccine_bg_style)
	vbox.add_child(vaccine_progress)

	vaccine_days_label = Label.new()
	vaccine_days_label.add_theme_font_override("font", _make_ui_font())  # caption text -- condensed font, not the display one
	vaccine_days_label.add_theme_font_size_override("font_size", 16)
	vaccine_days_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(vaccine_days_label)

func _add_stat_row(parent: Node, label_text: String, value_color: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(150, 0)
	if hud_font != null:
		name_label.add_theme_font_override("font", hud_font)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Palette.TEXT_BONE_MUTED)
	row.add_child(name_label)

	var value_label := Label.new()
	if hud_font != null:
		value_label.add_theme_font_override("font", hud_font)
	value_label.add_theme_font_size_override("font_size", 26)
	value_label.add_theme_color_override("font_color", value_color)
	row.add_child(value_label)
	return value_label

func _make_hud_separator() -> HSeparator:
	var sep := HSeparator.new()
	var line_style := StyleBoxLine.new()
	line_style.color = Palette.SEPARATOR_COLOR
	line_style.thickness = 1
	sep.add_theme_stylebox_override("separator", line_style)
	sep.add_theme_constant_override("separation", 17)  # 1px line + 8px margin above and below
	return sep

func _make_hud_panel_style(accent_edge: HudStyle.AccentEdge = HudStyle.AccentEdge.NONE) -> StyleBoxFlat:
	return HudStyle.make_panel_style(accent_edge)

func _build_right_hud() -> void:
	# one VBoxContainer owns both blocks now, so width and right-margin are set
	# once here instead of independently on each panel (which is what let them
	# drift out of alignment with each other before).
	var vbox := VBoxContainer.new()
	vbox.anchor_left = 1.0
	vbox.anchor_right = 1.0
	vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vbox.offset_top = 24.0
	vbox.offset_right = -HUD_MARGIN
	vbox.custom_minimum_size = Vector2(RIGHT_HUD_WIDTH, 0)
	vbox.add_theme_constant_override("separation", RIGHT_HUD_BLOCK_GAP)
	$UI.add_child(vbox)

	vbox.add_child(_build_skill_panel_block())
	vbox.add_child(_build_action_panel_block())

func _build_skill_panel_block() -> PanelContainer:
	# one panel holding both the button and the read-only unlock-progress icons
	# below it, instead of two separate panels that had to be kept in sync --
	# this guarantees identical width by construction, and is more compact
	# overall since there's only one set of borders/margins/shadow, not two.
	# Sizing/positioning is owned by the parent right-hud VBoxContainer, not here.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.add_theme_stylebox_override("panel", _make_hud_panel_style(HudStyle.AccentEdge.BORDERED))
	skill_button_panel = panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var button := Button.new()
	button.text = "Skill Tree"
	button.custom_minimum_size = Vector2(200, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if hud_font != null:
		button.add_theme_font_override("font", hud_font)
	button.add_theme_font_size_override("font_size", 22)
	_style_hud_button(button, Color(0.44, 0.42, 0.58))
	button.pressed.connect(_on_skills_pressed)
	vbox.add_child(button)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var grouped: Dictionary = {}
	for entry in SkillTreeScript.SKILLS:
		if not grouped.has(entry.icon_path):
			grouped[entry.icon_path] = []
		grouped[entry.icon_path].append(entry.key)

	for icon_path in grouped:
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(icon_path)
		tex_rect.custom_minimum_size = Vector2(20, 20)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(tex_rect)
		skill_preview_icons[icon_path] = {"node": tex_rect, "keys": grouped[icon_path]}

	_refresh_skill_preview()
	return panel

func _refresh_skill_preview() -> void:
	for icon_path in skill_preview_icons:
		var entry: Dictionary = skill_preview_icons[icon_path]
		var unlocked := false
		for key in entry["keys"]:
			if has_skill(key):
				unlocked = true
				break
		var node: TextureRect = entry["node"]
		node.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.45, 0.45, 0.48, 0.55)

func _build_action_panel_block() -> PanelContainer:
	# sizing/positioning is owned by the parent right-hud VBoxContainer, not here
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.add_theme_stylebox_override("panel", _make_hud_panel_style(HudStyle.AccentEdge.BORDERED))
	action_panel = panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "ACTIONS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if hud_font != null:
		header.add_theme_font_override("font", hud_font)
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(header)

	treat_button = add_action_button(vbox, "Treat", _on_treat_pressed, TREAT_COLOR)
	clear_button = add_action_button(vbox, "Clear", _on_clear_pressed, CLEAR_COLOR)
	clear_plus_button = add_action_button(vbox, "Clear+", _on_clear_plus_pressed, CLEAR_PLUS_ACCENT)
	clear_plus_button.visible = has_skill("reinforced_clear")
	add_action_button(vbox, "Wait", _on_wait_pressed, WAIT_ACCENT)
	return panel

func add_action_button(parent: Node, label: String, handler: Callable, accent: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 64)
	button.add_theme_font_override("font", _make_ui_font())
	button.add_theme_font_size_override("font_size", 30)
	_style_hud_button(button, accent)
	button.pressed.connect(handler)
	parent.add_child(button)
	return button

func _style_hud_button(btn: Button, accent: Color) -> void:
	HudStyle.style_button(btn, accent)

func _unhandled_input(event: InputEvent) -> void:
	if game_ended:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := grid.local_to_map(grid.to_local(get_global_mouse_position()))
		if cell_data.has(cell) and cell != BASE_CELL:
			selected_cell = cell
			update_selection_highlight()
			refresh_status()

func update_selection_highlight() -> void:
	update_selection_panel()
	if selection_highlight == null or not has_valid_selection():
		if selection_highlight != null:
			selection_highlight.visible = false
		return
	var corner := grid.position + Vector2(selected_cell.x * TILE_PX, selected_cell.y * TILE_PX)
	# inset to match the risk-highlight outline's inset -- otherwise, when a selected
	# cell sits next to an at-risk cell, the two outlines crowd/overlap at the shared edge
	selection_highlight.points = PackedVector2Array([
		corner + Vector2(8, 8),
		corner + Vector2(TILE_PX - 8, 8),
		corner + Vector2(TILE_PX - 8, TILE_PX - 8),
		corner + Vector2(8, TILE_PX - 8),
	])
	selection_highlight.visible = true

func update_selection_panel() -> void:
	if selection_header == null:
		return
	if not has_valid_selection():
		selection_header.visible = false
		selection_stats_box.visible = false
		selection_no_cell_label.visible = true
		return
	selection_header.visible = true
	selection_stats_box.visible = true
	selection_no_cell_label.visible = false

	selection_header.text = "(%d, %d)" % [selected_cell.x, selected_cell.y]
	var data: Dictionary = cell_data[selected_cell]
	var infected: int = data["infected"]
	selection_healthy_value.text = "%d" % data["healthy"]
	selection_infected_value.text = "%d" % infected
	selection_cured_value.text = "%d" % data["cured"]
	selection_dead_value.text = "%d" % data["dead"]

	var cure_amount := compute_action_amount(infected, treat_cure_rate)
	var kill_amount := compute_action_amount(infected, clear_kill_rate)
	var treat_available := doses > 0 and infected > 0
	var clear_available := infected > 0

	treat_preview_label.text = "Treat → %d cured" % cure_amount
	treat_preview_label.add_theme_color_override("font_color", Color(0.49, 0.84, 0.34) if treat_available else Color(0.5, 0.5, 0.54))

	clear_preview_label.text = "Clear → %d killed" % kill_amount
	clear_preview_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45) if clear_available else Color(0.5, 0.5, 0.54))

func create_origin_marker() -> void:
	origin_marker = Label.new()
	origin_marker.text = "ORIGIN"
	origin_marker.add_theme_font_size_override("font_size", 30)
	origin_marker.add_theme_color_override("font_color", Color.WHITE)
	origin_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	origin_marker.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	origin_marker.size = Vector2(TILE_PX, TILE_PX)
	origin_marker.position = grid.position + Vector2(zombie_cell.x * TILE_PX, zombie_cell.y * TILE_PX + 14)
	origin_marker.z_index = 4
	add_child(origin_marker)

func living_population() -> int:
	var alive := 0
	for cell in cell_data:
		var d: Dictionary = cell_data[cell]
		alive += d["healthy"] + d["infected"] + d["cured"]
	return alive

func compute_action_amount(infected: int, rate: float) -> int:
	# single source of truth for "how many people does this action affect" --
	# used by the real action handlers AND the selected-cell preview lines,
	# so the preview can never drift out of sync with what actually happens
	return min(int(floor(infected * rate)), infected)

func compute_people_lost() -> int:
	# same formula used at game-end (check_ending()) and live in the HUD's
	# outbreak-totals line, so both always agree with each other
	var lost := 0
	for cell in cell_data:
		if cell == BASE_CELL:
			continue
		lost += cell_data[cell]["infected"] + cell_data[cell]["dead"]
	return lost

func refresh_status() -> void:
	if day_value == null:
		return
	day_value.text = "%d / %d" % [day, vaccine_unlock_day]
	funding_value.text = "$%dk" % money
	doses_value.text = "%d" % doses
	population_value.text = "%d / %d" % [living_population(), original_population]
	if treat_button != null:
		treat_button.disabled = doses <= 0
	_update_outbreak_totals()
	_update_vaccine_section()
	update_selection_panel()

func _update_outbreak_totals() -> void:
	if outbreak_totals_value == null:
		return
	outbreak_totals_value.text = "Lost %d · Killed %d · Cured %d" % [compute_people_lost(), total_zombies_killed, total_zombies_cured]

func _update_vaccine_section() -> void:
	if vaccine_progress == null:
		return
	var progress := float(day) / float(vaccine_unlock_day) if vaccine_unlock_day > 0 else 0.0
	vaccine_progress.value = clamp(progress, 0.0, 1.0)
	var days_remaining: int = max(vaccine_unlock_day - day, 0)
	vaccine_days_label.text = "%d days remaining" % days_remaining

func _tick_stat_label(label: Label, from_value: int, to_value: int, formatter: Callable, duration: float = 0.4) -> void:
	if from_value == to_value:
		label.text = formatter.call(to_value)
		return
	var t := create_tween()
	t.tween_method(func(v: float): label.text = formatter.call(int(round(v))), float(from_value), float(to_value), duration)

func create_hover_popup() -> void:
	hover_popup = PanelContainer.new()
	hover_popup.visible = false
	hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_popup.z_index = 50  # always render above the HUD panels regardless of add order
	var opaque_style := _make_hud_panel_style()
	opaque_style.bg_color.a = 1.0  # fully opaque -- this box's content changes every frame
	hover_popup.add_theme_stylebox_override("panel", opaque_style)  # it can't afford any bleed-through
	hover_label = RichTextLabel.new()
	hover_label.bbcode_enabled = true
	hover_label.fit_content = true
	hover_label.scroll_active = false
	hover_label.custom_minimum_size = Vector2(210, 0)
	hover_label.add_theme_font_size_override("normal_font_size", 18)
	hover_label.add_theme_font_size_override("bold_font_size", 20)
	hover_label.add_theme_constant_override("line_separation", 4)
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_popup.add_child(hover_label)
	$UI.add_child(hover_popup)

func _process(_delta: float) -> void:
	if hover_popup == null:
		return
	if tooltip_suppressed:
		_fade_hover_popup(false)
		return
	var cell := grid.local_to_map(grid.to_local(get_global_mouse_position()))
	if not cell_data.has(cell):
		_fade_hover_popup(false)
		hovered_cell = Vector2i(-1, -1)
		return
	if cell != hovered_cell:
		hovered_cell = cell
		hover_label.text = build_hover_text(cell)
	hover_popup.position = get_viewport().get_mouse_position() + Vector2(18, 18)
	_fade_hover_popup(true)

func _fade_hover_popup(should_show: bool) -> void:
	# same quick fade language as the selection/risk outlines, instead of an instant pop
	if should_show == hover_popup_shown:
		return
	hover_popup_shown = should_show
	if hover_fade_tween != null:
		hover_fade_tween.kill()  # rapid mouse movement across cell edges could otherwise
	if should_show:                # stack overlapping fades fighting over modulate:a
		hover_popup.visible = true
		hover_fade_tween = create_tween()
		hover_fade_tween.tween_property(hover_popup, "modulate:a", 1.0, 0.15)
	else:
		hover_fade_tween = create_tween()
		hover_fade_tween.tween_property(hover_popup, "modulate:a", 0.0, 0.15)
		hover_fade_tween.tween_callback(func(): hover_popup.visible = false)

func build_hover_text(cell: Vector2i) -> String:
	if cell == BASE_CELL:
		return "[b]Base (Hospital)[/b]\n[color=#b0b0b0]No residents. Runs your response.[/color]"
	var data := cell_data[cell]
	return "[b]Neighborhood (%d, %d)[/b]\n" % [cell.x, cell.y] \
		+ "[color=#7ed957]Healthy[/color]: %d\n" % data["healthy"] \
		+ "[color=#ff5b5b]Infected[/color]: %d\n" % data["infected"] \
		+ "[color=#5b9bff]Cured[/color]: %d\n" % data["cured"] \
		+ "[color=#b0b0b0]Dead[/color]: %d" % data["dead"]

func maybe_start_tutorial() -> void:
	if not _should_show_tutorial():
		return
	start_tutorial()

func start_tutorial() -> void:
	if tutorial_ref != null and is_instance_valid(tutorial_ref):
		return
	var grid_px := float(GRID_SIZE * TILE_PX)
	var grid_rect := Rect2(grid.position, Vector2(grid_px, grid_px))
	var tutorial: CanvasLayer = preload("res://scripts/ui/tutorial.gd").new()
	tutorial.setup([
		{
			"title": "Welcome, Doctor",
			"body": "A zombie virus has broken out in the city, and you lead the response from the hospital at its center. Each tile is a neighborhood with its own population. The outbreak began at the ORIGIN tile and spreads to neighboring tiles every day. Your job is to keep people alive until the vaccine is ready.",
			"rect": grid_rect,
		},
		{
			"title": "Read the map",
			"body": "Tile color shows the danger at a glance: green means healthy, red means the neighborhood is overrun. Click any tile to select it, and hover over one to see its healthy, infected, cured, and dead counts. Go ahead and select a tile to continue.",
			"rect": grid_rect,
			"interactive": true,
		},
		{
			"title": "Track your resources",
			"body": "Four numbers track the state of the city. DAY counts up to the vaccine deadline, FUNDING is the cash healthy neighborhoods bring in to spend on upgrades, DOSES are your limited charges for treating the infected, and POPULATION shows how many people are still living out of the city's starting total.",
			"target": status_panel,
		},
		{
			"title": "Take action",
			"body": "Select a tile first, then choose a move. Every action advances the day. TREAT spends a dose to cure a share of the infected, CLEAR kills a share fast but the dead cannot be brought back, and WAIT passes the day while the virus keeps spreading. The infection is fatal on its own: every day a neighborhood stays infected, about 5% of its infected die. Leaving a tile alone still costs lives.",
			"target": action_panel,
		},
		{
			"title": "Spend on upgrades",
			"body": "Open the Skill Tree to turn funding into an edge. Strengthen your treatment, stock extra doses, set up quarantine to slow the spread, or rush the vaccine to end the outbreak sooner.",
			"target": skill_button_panel,
		},
		{
			"title": "Win the race",
			"body": "Every day the infection grows and reaches new neighborhoods. Decide where to treat and where to clear, watch your doses and funding, and hold the line until the vaccine. Save at least half the city to win. Good luck.",
		},
	])
	tutorial.finished.connect(_on_tutorial_finished)
	add_child(tutorial)
	tutorial_ref = tutorial

func _should_show_tutorial() -> bool:
	return not FileAccess.file_exists(TUTORIAL_FLAG_PATH)

func _on_tutorial_finished() -> void:
	tutorial_ref = null
	var f := FileAccess.open(TUTORIAL_FLAG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line("1")
		f.close()
