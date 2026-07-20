extends Node2D

# starting constants
const GRID_SIZE := 5
const STARTING_ZOMBIES := 20
# TEMPORARY, sets number of ppl in region
const MAX_ZOMBIES := 100
# sets source for each tile placed
const TILE_SOURCE_ID := 0
# identify the different types of tiles
const COLOR_TILES: Array[Vector2i] =[
	Vector2i(0,0), # no zombies
	Vector2i(1,0), # low zombies
	Vector2i(2,0), # medium zombies
	Vector2i(3,0), # high zombies
	Vector2i(4,0), # player
]
# set variables for assets
@onready var grid: TileMapLayer = $Grid
var zombie_cell := Vector2i.ZERO
# store zombie count per cell
var zombie_counts: Dictionary[Vector2i, int] = {}

func _ready() -> void:
	initialize_grid()
	zombie_cell = random_outer_cell()
	zombie_counts[zombie_cell] = STARTING_ZOMBIES
	update_all_cells()
	set_player_cell()
	add_cell_icons()

# white icons layered over the color tiles: hospital on the center/base cell,
# a house on the 24 neighborhoods (icons by game-icons.net, CC BY 3.0 — see CREDITS.md)
func add_cell_icons() -> void:
	var hospital_icon: Texture2D = load("res://assets/icons/hospital.png")
	var neighborhood_icon: Texture2D = load("res://assets/icons/neighborhood_SGAI.png")
	var center := Vector2i(2, 2)
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var icon := Sprite2D.new()
			icon.texture = hospital_icon if cell == center else neighborhood_icon
			# scale whatever the source size is down to ~110px on the 200px tile
			var target := 110.0 / icon.texture.get_width()
			icon.scale = Vector2(target, target)
			icon.position = grid.position + Vector2(x * 200 + 100, y * 200 + 100)
			icon.modulate.a = 0.85
			add_child(icon)

func initialize_grid() -> void:
	zombie_counts.clear()
	# generates each cell of grid
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			# grid location of cell
			var cell := Vector2i(x, y)
			zombie_counts[cell] = 0
			grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[0])
	center_grid()

func center_grid() -> void:
	var grid_size_pixels := Vector2(GRID_SIZE * 200, GRID_SIZE * 200)
	var window_size := get_viewport_rect().size
	grid.position = (window_size - grid_size_pixels) / 2.0

func random_outer_cell() -> Vector2i:
	# make array of outer cells
	var outer_cells: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x,y)
			# returns true if coords are along edges = is an outer cell
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
	# prob TEMPORARY
	var percentage := float(zombie_count) / MAX_ZOMBIES
	# convert percentage to color tile
	var level := roundi(percentage * (COLOR_TILES.size() - 1))
	# clampi keeps returned level within what is possible
	return clampi(level, 0, COLOR_TILES.size() - 1)

func update_all_cells() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			update_individual_cell(Vector2i(x,y))

func update_individual_cell(cell: Vector2i) -> void:
	var zombie_count : int = zombie_counts.get(cell,0)
	var zombie_level := get_zombie_level(zombie_count)
	grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[zombie_level])

func set_player_cell() -> void:
	var center_cell := Vector2i(2,2)
	grid.set_cell(center_cell, TILE_SOURCE_ID, COLOR_TILES[4])
