extends Node2D

## Map scene controller — owns grid visuals, player state, and day-loop orchestration.
##
## Rulebook: res://docs/GAME_DESIGN.md
##   §1 — Board setup (grid, cell_data, heatmap)
##   §2 — Day loop orchestration (simulation lives in OutbreakSimulation)
##   §3 — Player actions (not yet implemented; End Day button simulates WAIT)
##   §4 — Money display
##   §5 — Upgrade hooks (spread multiplier; more added with upgrade wiring)
##   §6 — Ending checks (loss implemented; vaccine win stubbed for later)
##
## Simulation math: res://scripts/core/outbreak_simulation.gd

# ---------------------------------------------------------------------------
# §1 — Board constants
# Rulebook: res://docs/GAME_DESIGN.md — §1
# ---------------------------------------------------------------------------

const GRID_SIZE := 5
const STARTING_ZOMBIES := 20
const MIN_POPULATION := 50
const MAX_POPULATION := 150
const BASE_CELL := Vector2i(2, 2)

const TILE_SOURCE_ID := 0
const COLOR_TILES: Array[Vector2i] = [
	Vector2i(0, 0),  # no infection
	Vector2i(1, 0),  # low
	Vector2i(2, 0),  # medium
	Vector2i(3, 0),  # high
	Vector2i(4, 0),  # player base (always shown on BASE_CELL)
]

# ---------------------------------------------------------------------------
# §2 / §3 — Turn state
# Rulebook: res://docs/GAME_DESIGN.md — §2 step 1, §3
# ---------------------------------------------------------------------------

enum GamePhase { PLAYING, ENDED }

## Current calendar day (1-indexed). Incremented after each day resolution (§2 step 5).
var current_day: int = 1

## Whether the player has already acted today (§3: one action per day).
var player_acted_today: bool = false

var game_phase: GamePhase = GamePhase.PLAYING

## Human-readable ending reason; set when game_phase becomes ENDED (§6).
var ending_reason: String = ""

# ---------------------------------------------------------------------------
# §1 — Cell data + economy
# ---------------------------------------------------------------------------

@onready var grid: TileMapLayer = $Grid
@onready var day_label: Label = %DayLabel
@onready var funding_label: Label = %FundingLabel
@onready var end_day_button: Button = %EndDayButton

var money: int = 0
var skills: Dictionary = {}
var original_total_population: int = 0
var zombie_cell := Vector2i.ZERO

## Each cell holds four numbers (§1): healthy, infected, cured, dead.
var cell_data: Dictionary[Vector2i, Dictionary] = {}

## Seeded RNG shared across spread rolls — set seed for reproducible test runs.
var _rng := RandomNumberGenerator.new()

# ---------------------------------------------------------------------------
# UI — hover popup
# ---------------------------------------------------------------------------

var hover_popup: PanelContainer
var hover_label: RichTextLabel
var hovered_cell := Vector2i(-1, -1)


func _ready() -> void:
	_rng.randomize()
	initialize_grid()
	_record_original_population()
	zombie_cell = random_outer_cell()
	seed_infection(zombie_cell, STARTING_ZOMBIES)
	update_all_cells()
	set_player_cell()
	add_cell_icons()
	create_hover_popup()
	_update_hud()


# ---------------------------------------------------------------------------
# §1 — Grid setup
# ---------------------------------------------------------------------------

func initialize_grid() -> void:
	cell_data.clear()
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var population := 0 if cell == BASE_CELL else randi_range(MIN_POPULATION, MAX_POPULATION)
			cell_data[cell] = {
				"healthy": population,
				"infected": 0,
				"cured": 0,
				"dead": 0,
			}
			grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[0])
	center_grid()


## Snapshot total neighborhood population at game start — needed for WIN % check (§6).
func _record_original_population() -> void:
	original_total_population = 0
	for cell in cell_data:
		if OutbreakSimulation.is_neighborhood(cell):
			original_total_population += OutbreakSimulation.get_total_population(cell_data[cell])


func seed_infection(cell: Vector2i, amount: int) -> void:
	var data := cell_data[cell]
	var converted: int = mini(amount, data["healthy"])
	data["healthy"] -= converted
	data["infected"] += converted


func center_grid() -> void:
	var grid_size_pixels := Vector2(GRID_SIZE * 200, GRID_SIZE * 200)
	var window_size := get_viewport_rect().size
	grid.position = (window_size - grid_size_pixels) / 2.0


func random_outer_cell() -> Vector2i:
	var outer_cells: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var is_outer_cell := (
				x == 0
				or x == GRID_SIZE - 1
				or y == 0
				or y == GRID_SIZE - 1
			)
			if is_outer_cell:
				outer_cells.append(cell)
	return outer_cells.pick_random()


# ---------------------------------------------------------------------------
# §1 — Heatmap visualization (infection level by ratio, not fixed MAX_ZOMBIES)
# ---------------------------------------------------------------------------

func get_infected(cell: Vector2i) -> int:
	return cell_data.get(cell, {}).get("infected", 0)


func get_zombie_level(cell: Vector2i) -> int:
	var data: Dictionary = cell_data[cell]
	var ratio: float = OutbreakSimulation.get_infection_ratio(data)
	# Map 0.0–1.0 infection ratio onto tile indices 0–3 (index 4 reserved for base).
	var max_level: int = COLOR_TILES.size() - 2
	var level: int = roundi(ratio * max_level)
	return clampi(level, 0, max_level)


func update_all_cells() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			update_individual_cell(Vector2i(x, y))


func update_individual_cell(cell: Vector2i) -> void:
	if cell == BASE_CELL:
		return  # Base tile is always set via set_player_cell().
	var zombie_level := get_zombie_level(cell)
	grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[zombie_level])


func set_player_cell() -> void:
	grid.set_cell(BASE_CELL, TILE_SOURCE_ID, COLOR_TILES[4])


# ---------------------------------------------------------------------------
# §2 — Day loop orchestration
# Rulebook: res://docs/GAME_DESIGN.md — §2
#
# Daily order:
#   1. Player acts (§3) — resolve_player_action() / end_day with WAIT for now
#   2. In-cell growth + natural death — OutbreakSimulation.apply_in_cell_infection_phase
#   3. Neighbor spread — OutbreakSimulation.apply_spread_phase
#   4. Money income — OutbreakSimulation.compute_daily_income
#   5. Day +1, check endings (§6)
# ---------------------------------------------------------------------------

## Called when the player finishes their action for the day (currently: End Day = WAIT).
## Returns false if the day could not be resolved (already ended or already acted).
func resolve_day() -> bool:
	if game_phase == GamePhase.ENDED:
		push_warning("resolve_day called after game ended.")
		return false
	if player_acted_today:
		push_warning("Player already acted today (§3: one action per day).")
		return false

	# §3 step 1: Player action slot — End Day button counts as WAIT until actions ship.
	player_acted_today = true

	var summary: Dictionary = OutbreakSimulation.run_day_resolution(
		cell_data,
		GRID_SIZE,
		_get_spread_multiplier(),
		_rng
	)

	# §4 step 4: Money comes in after simulation steps 2–3.
	earn_money(summary["income"])

	# §2 step 5: Advance calendar and evaluate endings (§6).
	current_day += 1
	player_acted_today = false  # §3: fresh action slot for the new day (unless game ended).
	_check_endings()

	update_all_cells()
	_update_hud()

	print(
		"[Day %d resolved] income=$%d | healthy=%d infected=%d cured=%d dead=%d"
		% [
			current_day - 1,
			summary["income"],
			summary["total_healthy"],
			summary["total_infected"],
			summary["total_cured"],
			summary["total_dead"],
		]
	)
	return true


## §5 — Quarantine halves all spread chances (§5 upgrade table).
func _get_spread_multiplier() -> float:
	if has_skill("quarantine"):
		return 0.5
	return 1.0


# ---------------------------------------------------------------------------
# §6 — Ending checks
# Rulebook: res://docs/GAME_DESIGN.md — §6
# ---------------------------------------------------------------------------

func _check_endings() -> void:
	# LOSS: all 24 neighborhoods fully infected/dead before vaccine (§6).
	if OutbreakSimulation.is_all_neighborhoods_lost(cell_data):
		_end_game("LOSS — All neighborhoods overwhelmed before the vaccine.")
		return

	# TODO(§6): Vaccine arrival on day ~25 (~22 rushed) — implement with upgrade wiring.
	if current_day > OutbreakSimulation.MAX_DAYS:
		_end_game("TIME UP — %d days elapsed (vaccine/endings not yet implemented)." % OutbreakSimulation.MAX_DAYS)


func _end_game(reason: String) -> void:
	game_phase = GamePhase.ENDED
	ending_reason = reason
	end_day_button.disabled = true
	print("[Game ended] ", reason)


# ---------------------------------------------------------------------------
# §4 / §5 — Economy + upgrades (purchase logic; effect wiring expands later)
# ---------------------------------------------------------------------------

func earn_money(amount: int) -> void:
	money += amount


func has_skill(skill: String) -> bool:
	return skills.get(skill, false)


func buy_skill(skill: String, cost: int) -> bool:
	if has_skill(skill):
		return false
	if money < cost:
		return false
	money -= cost
	skills[skill] = true
	print("Purchased upgrade: ", skill, " | Money remaining: ", money)
	return true


func _format_funding(amount: int) -> String:
	if amount == 0:
		return "$0"
	return "$%dK" % (amount / 1000)


func _update_hud() -> void:
	day_label.text = "Day %d / %d" % [current_day, OutbreakSimulation.MAX_DAYS]
	funding_label.text = "Funding: %s" % _format_funding(money)
	end_day_button.disabled = game_phase == GamePhase.ENDED or player_acted_today


# ---------------------------------------------------------------------------
# UI callbacks
# ---------------------------------------------------------------------------

func _on_end_day_pressed() -> void:
	resolve_day()


func _on_skills_pressed() -> void:
	var tree := preload("res://scenes/skill_tree.tscn").instantiate()
	add_child(tree)


# ---------------------------------------------------------------------------
# §1 — Cell icons + hover popup
# ---------------------------------------------------------------------------

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
			icon.position = grid.position + Vector2(x * 200 + 100, y * 200 + 100)
			icon.modulate.a = 0.85
			add_child(icon)


func create_hover_popup() -> void:
	hover_popup = PanelContainer.new()
	hover_popup.visible = false
	hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label = RichTextLabel.new()
	hover_label.bbcode_enabled = true
	hover_label.fit_content = true
	hover_label.scroll_active = false
	hover_label.custom_minimum_size = Vector2(190, 0)
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_popup.add_child(hover_label)
	$UI.add_child(hover_popup)


func _process(_delta: float) -> void:
	if hover_popup == null:
		return
	var cell := grid.local_to_map(grid.to_local(get_global_mouse_position()))
	if not cell_data.has(cell):
		hover_popup.visible = false
		hovered_cell = Vector2i(-1, -1)
		return
	if cell != hovered_cell:
		hovered_cell = cell
		hover_label.text = build_hover_text(cell)
	hover_popup.position = get_viewport().get_mouse_position() + Vector2(18, 18)
	hover_popup.visible = true


func build_hover_text(cell: Vector2i) -> String:
	var data := cell_data[cell]
	var title := "Base (Hospital)" if cell == BASE_CELL else "Neighborhood (%d, %d)" % [cell.x, cell.y]
	var spread_hint := ""
	if OutbreakSimulation.is_neighborhood(cell) and data["infected"] > 0:
		# Show per-neighbor spread odds when hovering an infected cell (debug/UX aid).
		var sample_chance: float = OutbreakSimulation.compute_spread_chance(
			data["infected"],
			cell_data[cell],  # self density for display; actual rolls use each neighbor
			_get_spread_multiplier()
		)
		spread_hint = "\n[color=#888]Spread chance (sample): %.0f%%[/color]" % (sample_chance * 100.0)

	return "[b]%s[/b]\n" % title \
		+ "[color=#7ed957]Healthy[/color]: %d\n" % data["healthy"] \
		+ "[color=#ff5b5b]Infected[/color]: %d\n" % data["infected"] \
		+ "[color=#5b9bff]Cured[/color]: %d\n" % data["cured"] \
		+ "[color=#b0b0b0]Dead[/color]: %d" % data["dead"] \
		+ spread_hint
