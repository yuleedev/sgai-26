extends Node2D

# starting constants
const GRID_SIZE := 5
const STARTING_ZOMBIES := 20
# TEMPORARY, sets number of ppl in region
const MAX_ZOMBIES := 100
# sets source for each tile placed
const TILE_SOURCE_ID := 0
# identify the different types of tiles
const COLOR_TILES: Array[Vector2i] = [
	Vector2i(0, 0), # no zombies
	Vector2i(1, 0), # low zombies
	Vector2i(2, 0), # medium zombies
	Vector2i(3, 0), # high zombies
	Vector2i(4, 0), # player
]

# Shade overlay: 3x3 population markers inside each environment cell.
# Replace art in res://assets/shade_tiles.png (atlas slots below).
const SHADE_SUBDIV := 3
const PEOPLE_PER_SHADE_TILE := 10
const ENV_TILE_SIZE := 200
const SHADE_TILE_SIZE := 67 # ~ENV_TILE_SIZE / SHADE_SUBDIV
# Atlas coords in shade_tiles.png — paint these slots when ready:
const SHADE_TILES: Dictionary = {
	"empty": Vector2i(0, 0),
	"healthy": Vector2i(1, 0),
	"infected": Vector2i(2, 0),
	"critical": Vector2i(3, 0), # infected past cure threshold
	"dead": Vector2i(4, 0),
}

@onready var grid: TileMapLayer = $Grid
@onready var shade_grid: TileMapLayer = $ShadeGrid

var zombie_cell := Vector2i.ZERO
# store zombie count per environment cell
var zombie_counts: Dictionary[Vector2i, int] = {}
# people + status bags per environment cell (for shade overlay)
# each entry: { "healthy": int, "infected": int, "critical": int, "dead": int }
var cell_populations: Dictionary[Vector2i, Dictionary] = {}

func _ready() -> void:
	initialize_grid()
	zombie_cell = random_outer_cell()
	zombie_counts[zombie_cell] = STARTING_ZOMBIES
	_seed_starting_infection(zombie_cell)
	update_all_cells()
	set_player_cell()

func initialize_grid() -> void:
	zombie_counts.clear()
	cell_populations.clear()
	# generates each cell of grid
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			zombie_counts[cell] = 0
			cell_populations[cell] = {
				"healthy": 0,
				"infected": 0,
				"critical": 0,
				"dead": 0,
			}
			grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[0])
			clear_shade_cell(cell)
	center_grid()

func center_grid() -> void:
	var grid_size_pixels := Vector2(GRID_SIZE * ENV_TILE_SIZE, GRID_SIZE * ENV_TILE_SIZE)
	var window_size := get_viewport_rect().size
	var origin := (window_size - grid_size_pixels) / 2.0
	grid.position = origin
	# Shade tiles are smaller; keep the same origin so 3x3 lines up under each env cell.
	shade_grid.position = origin

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

func get_zombie_level(zombie_count: int) -> int:
	var percentage := float(zombie_count) / MAX_ZOMBIES
	var level := roundi(percentage * (COLOR_TILES.size() - 1))
	return clampi(level, 0, COLOR_TILES.size() - 1)

func update_all_cells() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			update_individual_cell(Vector2i(x, y))

func update_individual_cell(cell: Vector2i) -> void:
	var zombie_count: int = zombie_counts.get(cell, 0)
	var zombie_level := get_zombie_level(zombie_count)
	grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[zombie_level])
	update_shade_cell(cell)

func set_player_cell() -> void:
	var center_cell := Vector2i(2, 2)
	grid.set_cell(center_cell, TILE_SOURCE_ID, COLOR_TILES[4])

func _seed_starting_infection(cell: Vector2i) -> void:
	# Temporary: treat starting zombies as infected population for shade display.
	cell_populations[cell]["infected"] = STARTING_ZOMBIES

# --- Shade overlay (3x3 per environment cell; 1 tile = 10 people) ---

func env_to_shade_origin(env_cell: Vector2i) -> Vector2i:
	return env_cell * SHADE_SUBDIV

func clear_shade_cell(env_cell: Vector2i) -> void:
	var origin := env_to_shade_origin(env_cell)
	for sx in range(SHADE_SUBDIV):
		for sy in range(SHADE_SUBDIV):
			shade_grid.erase_cell(origin + Vector2i(sx, sy))

func update_shade_cell(env_cell: Vector2i) -> void:
	clear_shade_cell(env_cell)
	var pop: Dictionary = cell_populations.get(env_cell, {})
	# Fill order: infected → critical → healthy → dead (most urgent first).
	# Each placed shade tile represents PEOPLE_PER_SHADE_TILE people of that status.
	var slots: Array[String] = []
	for status in ["infected", "critical", "healthy", "dead"]:
		var count: int = int(pop.get(status, 0))
		var tiles_needed := count / PEOPLE_PER_SHADE_TILE
		for _i in range(tiles_needed):
			if slots.size() >= SHADE_SUBDIV * SHADE_SUBDIV:
				break
			slots.append(status)
		if slots.size() >= SHADE_SUBDIV * SHADE_SUBDIV:
			break

	var origin := env_to_shade_origin(env_cell)
	var slot_index := 0
	for sy in range(SHADE_SUBDIV):
		for sx in range(SHADE_SUBDIV):
			if slot_index >= slots.size():
				return
			var status: String = slots[slot_index]
			var atlas: Vector2i = SHADE_TILES[status]
			shade_grid.set_cell(origin + Vector2i(sx, sy), TILE_SOURCE_ID, atlas)
			slot_index += 1
