extends Node2D

# starting constants
const GRID_SIZE := 5
const STARTING_ZOMBIES := 20
# TEMPORARY, sets number of ppl in region
const MAX_ZOMBIES := 100
# population per neighborhood is random at start (§1: ~50–150)
const MIN_POPULATION := 50
const MAX_POPULATION := 150
# the center cell (2,2) is the base/hospital — never a neighborhood, never infected
const BASE_CELL := Vector2i(2, 2)
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
var money := 0
var skills: Dictionary = {}
var zombie_cell := Vector2i.ZERO
# each cell is a box holding four numbers (§1): healthy, infected, cured, dead
var cell_data: Dictionary[Vector2i, Dictionary] = {}
# hover popup that shows a cell's four numbers and what they mean
var hover_popup: PanelContainer
var hover_label: RichTextLabel
var hovered_cell := Vector2i(-1, -1)

func _ready() -> void:
	initialize_grid()
	zombie_cell = random_outer_cell()
	seed_infection(zombie_cell, STARTING_ZOMBIES)
	update_all_cells()
	set_player_cell()
	add_cell_icons()
	create_hover_popup()

# white icons layered over the color tiles: hospital on the center/base cell,
# a house on the 24 neighborhoods (icons by game-icons.net, CC BY 3.0 — see CREDITS.md)
func add_cell_icons() -> void:
	var hospital_icon: Texture2D = load("res://assets/icons/hospital.png")
	var neighborhood_icon: Texture2D = load("res://assets/icons/neighborhood_SGAI.png")
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var icon := Sprite2D.new()
			icon.texture = hospital_icon if cell == BASE_CELL else neighborhood_icon
			# scale whatever the source size is down to ~110px on the 200px tile
			var target := 110.0 / icon.texture.get_width()
			icon.scale = Vector2(target, target)
			icon.position = grid.position + Vector2(x * 200 + 100, y * 200 + 100)
			icon.modulate.a = 0.85
			add_child(icon)

func initialize_grid() -> void:
	cell_data.clear()
	# generates each cell of grid
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			# grid location of cell
			var cell := Vector2i(x, y)
			# base cell holds no people; neighborhoods start with a random population
			var population := 0 if cell == BASE_CELL else randi_range(MIN_POPULATION, MAX_POPULATION)
			cell_data[cell] = {
				"healthy": population,
				"infected": 0,
				"cured": 0,
				"dead": 0,
			}
			grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[0])
	center_grid()

# turn some of a cell's healthy people into the initial infected
func seed_infection(cell: Vector2i, amount: int) -> void:
	var data := cell_data[cell]
	var converted: int = min(amount, data["healthy"])
	data["healthy"] -= converted
	data["infected"] += converted

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

func get_infected(cell: Vector2i) -> int:
	return cell_data.get(cell, {}).get("infected", 0)

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
	var zombie_level := get_zombie_level(get_infected(cell))
	grid.set_cell(cell, TILE_SOURCE_ID, COLOR_TILES[zombie_level])

func set_player_cell() -> void:
	grid.set_cell(BASE_CELL, TILE_SOURCE_ID, COLOR_TILES[4])

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

func _on_skills_pressed() -> void:
	var tree := preload("res://scenes/skill_tree.tscn").instantiate()
	add_child(tree)

# --- Hover popup: shows a cell's four numbers and what they mean (§1) ---

func create_hover_popup() -> void:
	hover_popup = PanelContainer.new()
	hover_popup.visible = false
	# ignore mouse so the popup never steals hover from the cell underneath it
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
	# keep the popup near the cursor, offset so it doesn't sit under it
	hover_popup.position = get_viewport().get_mouse_position() + Vector2(18, 18)
	hover_popup.visible = true

func build_hover_text(cell: Vector2i) -> String:
	var data := cell_data[cell]
	var title := "Base (Hospital)" if cell == BASE_CELL else "Neighborhood (%d, %d)" % [cell.x, cell.y]
	# color each number to match its meaning
	return "[b]%s[/b]\n" % title \
		+ "[color=#7ed957]Healthy[/color]: %d\n" % data["healthy"] \
		+ "[color=#ff5b5b]Infected[/color]: %d\n" % data["infected"] \
		+ "[color=#5b9bff]Cured[/color]: %d\n" % data["cured"] \
		+ "[color=#b0b0b0]Dead[/color]: %d" % data["dead"]
