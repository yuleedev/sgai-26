## Pure simulation logic for the SGAI-26 day loop.
##
## This class has NO Godot node dependencies — only math and data transforms.
## That keeps the rules easy to test, port to the Python RL twin (see
## res://docs/GAME_DESIGN.md §9), and verify against the rulebook.
##
## Rulebook: res://docs/GAME_DESIGN.md
##   §1 — Board / cell data model
##   §2 — Day loop (implemented here)
##   §3 — Player actions (called BEFORE run_day_resolution from game_manager)
##   §4 — Money (compute_daily_income)
##   §5 — Upgrades (spread multiplier hook; more hooks added later)
##   §6 — Endings (checked in game_manager after day increment)
class_name OutbreakSimulation
extends RefCounted

# ---------------------------------------------------------------------------
# §2 — Day loop tunables (all marked ~ in the rulebook; change here + in doc)
# Rulebook: res://docs/GAME_DESIGN.md — §2
# ---------------------------------------------------------------------------

## Maximum number of days before the vaccine forces an end (§2, §6).
const MAX_DAYS := 30

## Fraction of a cell's infected that convert healthy → infected each day (§2 step 2).
## Applied with floori(); capped by healthy available in the cell.
const IN_CELL_CONVERSION_RATE := 0.30

## Fraction of a cell's infected that die naturally each day (§2 step 2).
## Applied with floori(); models "treat early or there's nobody left to treat."
const NATURAL_DEATH_RATE := 0.05

## Per-neighbor spread chance multiplier from source infected count (§2 step 3).
## spread_chance = (source_infected × SPREAD_SOURCE_RATE) × density_factor, capped below.
const SPREAD_SOURCE_RATE := 0.005  # 0.5% per infected in source cell

## Hard cap on spread probability per neighbor per day (§2 step 3).
const SPREAD_CHANCE_CAP := 0.60

## When a spread roll succeeds, this fraction of source infected jump to the neighbor.
## The rulebook example ("~2 infected" from 40 source) implies ~5%; marked tunable (~).
## Rulebook: res://docs/GAME_DESIGN.md — §2 step 3 (transfer count not fully specified).
const SPREAD_SUCCESS_TRANSFER_RATE := 0.05

## Minimum infected added on a successful spread roll (always at least 1 person).
const SPREAD_MIN_TRANSFER := 1

# ---------------------------------------------------------------------------
# §4 — Money tunables
# Rulebook: res://docs/GAME_DESIGN.md — §4
# ---------------------------------------------------------------------------

## Flat funding per day regardless of population (§4).
const DAILY_INCOME_FLAT := 10

## Extra funding per 100 healthy people alive across all neighborhoods (§4).
const DAILY_INCOME_PER_100_HEALTHY := 1

# ---------------------------------------------------------------------------
# §1 — Board geometry (shared with game_manager)
# Rulebook: res://docs/GAME_DESIGN.md — §1
# ---------------------------------------------------------------------------

## Center base/hospital cell — never infected, never a spread target (§1, §2 step 3).
const BASE_CELL := Vector2i(2, 2)

## Cardinal neighbor offsets used for spread (§2 step 3: up/down/left/right only).
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),  # up
	Vector2i(0, 1),   # down
	Vector2i(-1, 0),  # left
	Vector2i(1, 0),   # right
]

# ---------------------------------------------------------------------------
# Cell data helpers
# ---------------------------------------------------------------------------

## Returns true for the 24 neighborhood cells (every cell except the base).
## Rulebook: res://docs/GAME_DESIGN.md — §1
static func is_neighborhood(cell: Vector2i) -> bool:
	return cell != BASE_CELL


## Total people currently in a cell (all four buckets sum to constant population).
static func get_total_population(data: Dictionary) -> int:
	return data["healthy"] + data["infected"] + data["cured"] + data["dead"]


## Living people who can still participate in the outbreak (excludes dead).
static func get_living_population(data: Dictionary) -> int:
	return data["healthy"] + data["infected"] + data["cured"]


## Sum of healthy across all neighborhood cells — used for daily income (§4).
## Base cell is excluded because it holds no population (§1).
static func count_total_healthy(cell_data: Dictionary) -> int:
	var total := 0
	for cell in cell_data:
		if not is_neighborhood(cell):
			continue
		total += cell_data[cell]["healthy"]
	return total


## Infection heatmap ratio: infected ÷ total population in this cell (§1 heatmap).
static func get_infection_ratio(data: Dictionary) -> float:
	var total := get_total_population(data)
	if total <= 0:
		return 0.0
	return float(data["infected"]) / float(total)


# ---------------------------------------------------------------------------
# §2 step 2 — In-cell infection growth + natural death
# Rulebook: res://docs/GAME_DESIGN.md — §2 step 2
# ---------------------------------------------------------------------------

## Applies within-cell conversion (healthy → infected) then natural death (infected → dead).
## Mutates [param cell_data] in place. Skips the base cell and cells with zero infected.
static func apply_in_cell_infection_phase(cell_data: Dictionary) -> void:
	for cell in cell_data:
		if not is_neighborhood(cell):
			continue

		var data := cell_data[cell]
		var infected: int = data["infected"]
		if infected <= 0:
			continue

		# --- Conversion: floor(infected × 30%), capped by healthy available (§2 step 2) ---
		var converted: int = mini(
			data["healthy"],
			int(floor(float(infected) * IN_CELL_CONVERSION_RATE))
		)
		data["healthy"] -= converted
		data["infected"] += converted

		# Re-read infected count after conversion for the death step.
		infected = data["infected"]

		# --- Natural death: floor(infected × 5%) move to dead (§2 step 2) ---
		var deaths: int = int(floor(float(infected) * NATURAL_DEATH_RATE))
		data["infected"] -= deaths
		data["dead"] += deaths


# ---------------------------------------------------------------------------
# §2 step 3 — Neighbor spread (chance-based, one roll per direction per day)
# Rulebook: res://docs/GAME_DESIGN.md — §2 step 3
# ---------------------------------------------------------------------------

## Computes spread probability for one source→target pair (before rolling).
## Formula: (source_infected × 0.5%) × (target_population ÷ 100), capped at 60%.
## [param spread_multiplier] halves chances when Quarantine upgrade is owned (§5).
static func compute_spread_chance(
	source_infected: int,
	target_data: Dictionary,
	spread_multiplier: float = 1.0
) -> float:
	if source_infected <= 0:
		return 0.0

	# Target population drives density — crowded cells catch infection easier (§2 step 3).
	# We use total living population (healthy + infected + cured); cured are immune to
	# *receiving* new infection (checked in apply_spread_phase) but still count toward density.
	var target_population: int = get_living_population(target_data)
	if target_population <= 0:
		return 0.0

	var chance: float = (
		float(source_infected) * SPREAD_SOURCE_RATE
	) * (float(target_population) / 100.0)

	chance *= spread_multiplier
	return minf(chance, SPREAD_CHANCE_CAP)


## Returns valid in-bounds cardinal neighbors for [param cell].
static func get_neighbor_cells(cell: Vector2i, grid_size: int) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for offset in NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = cell + offset
		if (
			neighbor.x >= 0
			and neighbor.y >= 0
			and neighbor.x < grid_size
			and neighbor.y < grid_size
		):
			neighbors.append(neighbor)
	return neighbors


## Rolls spread for every infected neighborhood → each cardinal neighbor (§2 step 3).
## The base cell is never a spread target. Cured people are immune (§1) — only healthy
## in the target cell can be newly infected.
## [param rng] must be provided for reproducible runs (important for AI comparison, §8).
static func apply_spread_phase(
	cell_data: Dictionary,
	grid_size: int,
	spread_multiplier: float = 1.0,
	rng: RandomNumberGenerator = null
) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()

	# Collect transfers first so simultaneous spreads don't order-bias results.
	var pending_infections: Dictionary = {}  # Vector2i → int

	for source_cell in cell_data:
		if not is_neighborhood(source_cell):
			continue

		var source_data: Dictionary = cell_data[source_cell]
		var source_infected: int = source_data["infected"]
		if source_infected <= 0:
			continue

		for target_cell in get_neighbor_cells(source_cell, grid_size):
			# Base never receives spread (§2 step 3).
			if not is_neighborhood(target_cell):
				continue

			var target_data: Dictionary = cell_data[target_cell]
			if target_data["healthy"] <= 0:
				continue  # No susceptible people; cured are immune (§1).

			var chance: float = compute_spread_chance(
				source_infected,
				target_data,
				spread_multiplier
			)
			if chance <= 0.0:
				continue

			if rng.randf() >= chance:
				continue  # Roll failed — no spread this direction today.

			# Successful roll: transfer ~5% of source infected, min 1 (§2 step 3, tunable).
			var transfer: int = maxi(
				SPREAD_MIN_TRANSFER,
				int(floor(float(source_infected) * SPREAD_SUCCESS_TRANSFER_RATE))
			)
			transfer = mini(transfer, target_data["healthy"])

			if transfer <= 0:
				continue

			pending_infections[target_cell] = pending_infections.get(target_cell, 0) + transfer

	# Apply all pending infections atomically after all rolls resolve.
	for target_cell in pending_infections:
		var amount: int = pending_infections[target_cell]
		var target_data: Dictionary = cell_data[target_cell]
		var applied: int = mini(amount, target_data["healthy"])
		target_data["healthy"] -= applied
		target_data["infected"] += applied


# ---------------------------------------------------------------------------
# §4 — Daily income
# Rulebook: res://docs/GAME_DESIGN.md — §4
# ---------------------------------------------------------------------------

## Returns funding earned today: ~$10 flat + ~$1 per 100 healthy alive (integer division).
static func compute_daily_income(cell_data: Dictionary) -> int:
	var healthy_total: int = count_total_healthy(cell_data)
	return DAILY_INCOME_FLAT + (healthy_total / 100) * DAILY_INCOME_PER_100_HEALTHY


# ---------------------------------------------------------------------------
# §2 steps 2–4 — Full post-action day resolution (player action is step 1, §3)
# Rulebook: res://docs/GAME_DESIGN.md — §2
# ---------------------------------------------------------------------------

## Runs simulation steps 2–4 in strict rulebook order AFTER the player's action (§3).
## Does NOT increment the day counter or check endings — game_manager owns steps 5–6.
##
## Returns a summary dict useful for logging (§8) and debug output.
static func run_day_resolution(
	cell_data: Dictionary,
	grid_size: int,
	spread_multiplier: float = 1.0,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	apply_in_cell_infection_phase(cell_data)
	apply_spread_phase(cell_data, grid_size, spread_multiplier, rng)
	var income: int = compute_daily_income(cell_data)

	return {
		"income": income,
		"total_healthy": count_total_healthy(cell_data),
		"total_infected": count_totals(cell_data)["infected"],
		"total_cured": count_totals(cell_data)["cured"],
		"total_dead": count_totals(cell_data)["dead"],
	}


## Aggregates infected/cured/dead across all neighborhoods (for logging, §8).
static func count_totals(cell_data: Dictionary) -> Dictionary:
	var totals := {"infected": 0, "cured": 0, "dead": 0, "healthy": 0}
	for cell in cell_data:
		if not is_neighborhood(cell):
			continue
		var data: Dictionary = cell_data[cell]
		totals["healthy"] += data["healthy"]
		totals["infected"] += data["infected"]
		totals["cured"] += data["cured"]
		totals["dead"] += data["dead"]
	return totals


# ---------------------------------------------------------------------------
# §6 — Ending helpers (loss condition only; vaccine win checked in game_manager)
# Rulebook: res://docs/GAME_DESIGN.md — §6
# ---------------------------------------------------------------------------

## A neighborhood is "fully lost" when no healthy or cured remain (§6 LOSS).
## Infected and/or dead may still be present — the neighborhood cannot recover.
static func is_neighborhood_fully_lost(data: Dictionary) -> bool:
	if data["healthy"] > 0 or data["cured"] > 0:
		return false
	# No survivors and no cured — only infected and/or dead remain (or all dead).
	return data["infected"] > 0 or data["dead"] > 0


## LOSS ending: all 24 neighborhoods are fully infected/dead before vaccine (§6).
static func is_all_neighborhoods_lost(cell_data: Dictionary) -> bool:
	for cell in cell_data:
		if not is_neighborhood(cell):
			continue
		if not is_neighborhood_fully_lost(cell_data[cell]):
			return false
	return true
