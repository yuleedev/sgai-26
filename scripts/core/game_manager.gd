extends Node2D

const GRID_SIZE := 5
const STARTING_ZOMBIES := 20
const ZOMBIE_LEVELS := 4
const MIN_POPULATION := 50
const MAX_POPULATION := 150
const BASE_CELL := Vector2i(2, 2)

const MAX_DAYS := 30
const INFECT_CONVERT_RATE := 0.30
const INFECT_DEATH_RATE := 0.05
const SPREAD_CHANCE_PER_INFECTED := 0.005
const SPREAD_CHANCE_CAP := 0.60
const SPREAD_INFECT_AMOUNT := 2
const INCOME_PER_DAY := 10
const INCOME_PER_HEALTHY := 100
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]

const TREAT_CURE_RATE := 0.20
const CLEAR_KILL_RATE := 0.40
const STARTING_DOSES := 10
const TILE_PX := 200
const TILE_SOURCE_ID := 0
const COLOR_TILES: Array[Vector2i] =[
	Vector2i(0,0),
	Vector2i(1,0),
	Vector2i(2,0),
	Vector2i(3,0),
	Vector2i(4,0),
]

@onready var grid: TileMapLayer = $Grid
var money := 0
var day := 1
var skills: Dictionary = {}
var doses := STARTING_DOSES
var selected_cell := Vector2i(-1, -1)
var status_label: Label
var action_label: Label
var treat_button: Button
var selection_highlight: Line2D
var origin_marker: Label
var zombie_cell := Vector2i.ZERO
var cell_data: Dictionary[Vector2i, Dictionary] = {}
var hover_popup: PanelContainer
var hover_label: RichTextLabel
var hovered_cell := Vector2i(-1, -1)

var total_people_lost: int = 0
var total_zombies_killed: int = 0
var total_zombies_cured: int = 0
var game_ended := false
@export_file("*.tscn")
var end_screen_path := "res://scenes/end_screen.tscn"

func _ready() -> void:
	initialize_grid()
	zombie_cell = random_outer_cell()
	seed_infection(zombie_cell, STARTING_ZOMBIES)
	update_all_cells()
	set_player_cell()
	add_cell_icons()
	create_hover_popup()
	create_day_controls()
	create_origin_marker()
	refresh_status()

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
			add_child(icon)

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
	var population: int = data.get("healthy", 0) + infected + data.get("cured", 0)
	if population <= 0:
		return 0
	var fraction := float(infected) / population
	var level := roundi(fraction * (ZOMBIE_LEVELS - 1))
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

func set_player_cell() -> void:
	grid.set_cell(BASE_CELL, TILE_SOURCE_ID, COLOR_TILES[4])

func earn_money(amount: int) -> void:
	money += amount

func advance_day() -> void:
	if game_ended:
		return
	grow_infection()
	spread_infection()
	collect_income()
	update_all_cells()
	if day >= MAX_DAYS:
		end_game()
		return
	day += 1
	refresh_status()

func end_game() -> void:
	if game_ended:
		return
	game_ended = true
	GameResults.people_lost = total_people_lost
	GameResults.zombies_killed = total_zombies_killed
	GameResults.zombies_cured = total_zombies_cured
	get_tree().change_scene_to_file(end_screen_path)

func grow_infection() -> void:
	for cell in cell_data:
		if cell == BASE_CELL:
			continue
		var data := cell_data[cell]
		var infected: int = data["infected"]
		if infected <= 0:
			continue
		var converted: int = min(int(floor(infected * INFECT_CONVERT_RATE)), data["healthy"])
		var died: int = min(int(floor(infected * INFECT_DEATH_RATE)), infected)
		data["healthy"] -= converted
		data["infected"] += converted - died
		data["dead"] += died
		total_people_lost += died

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
			)
			if randf() < chance:
				var appear: int = min(SPREAD_INFECT_AMOUNT, target_data["healthy"])
				target_data["healthy"] -= appear
				target_data["infected"] += appear

func collect_income() -> void:
	var total_healthy := 0
	for cell in cell_data:
		total_healthy += cell_data[cell]["healthy"]
	earn_money(INCOME_PER_DAY + total_healthy / INCOME_PER_HEALTHY)

func has_valid_selection() -> bool:
	return cell_data.has(selected_cell) and selected_cell != BASE_CELL

func _on_treat_pressed() -> void:
	if game_ended:
		return
	if not has_valid_selection():
		set_last_action("Select a neighborhood first")
		return
	if doses <= 0:
		set_last_action("No doses left")
		return
	var data := cell_data[selected_cell]
	var cured: int = int(floor(data["infected"] * TREAT_CURE_RATE))
	data["infected"] -= cured
	data["cured"] += cured
	total_zombies_cured += cured
	doses -= 1
	set_last_action("Treated (%d, %d): -%d infected, +%d cured" % [selected_cell.x, selected_cell.y, cured, cured])
	advance_day()

func _on_clear_pressed() -> void:
	if game_ended:
		return
	if not has_valid_selection():
		set_last_action("Select a neighborhood first")
		return
	var data := cell_data[selected_cell]
	var killed: int = int(floor(data["infected"] * CLEAR_KILL_RATE))
	data["infected"] -= killed
	data["dead"] += killed
	total_zombies_killed += killed
	set_last_action("Cleared (%d, %d): -%d infected, +%d dead" % [selected_cell.x, selected_cell.y, killed, killed])
	advance_day()

func _on_wait_pressed() -> void:
	if game_ended:
		return
	set_last_action("Waited")
	advance_day()

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
	skills[skill] = true
	print("Purchased upgrade: ", skill, " | Money remaining: ", money)
	return true

func _on_skills_pressed() -> void:
	var tree := preload("res://scenes/skill_tree.tscn").instantiate()
	add_child(tree)

func create_day_controls() -> void:
	status_label = Label.new()
	status_label.position = Vector2(10, 10)
	$UI.add_child(status_label)
	action_label = Label.new()
	action_label.position = Vector2(10, 40)
	$UI.add_child(action_label)
	treat_button = add_action_button("Treat", 60.0, _on_treat_pressed)
	add_action_button("Clear", 110.0, _on_clear_pressed)
	add_action_button("Wait", 160.0, _on_wait_pressed)
	selection_highlight = Line2D.new()
	selection_highlight.width = 5.0
	selection_highlight.default_color = Color.WHITE
	selection_highlight.visible = false
	add_child(selection_highlight)

func add_action_button(label: String, top: float, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -160.0
	button.offset_top = top
	button.offset_right = -10.0
	button.offset_bottom = top + 40.0
	button.pressed.connect(handler)
	$UI.add_child(button)
	return button

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
	if selection_highlight == null or not has_valid_selection():
		if selection_highlight != null:
			selection_highlight.visible = false
		return
	var corner := grid.position + Vector2(selected_cell.x * TILE_PX, selected_cell.y * TILE_PX)
	selection_highlight.points = PackedVector2Array([
		corner,
		corner + Vector2(TILE_PX, 0),
		corner + Vector2(TILE_PX, TILE_PX),
		corner + Vector2(0, TILE_PX),
		corner,
	])
	selection_highlight.visible = true

func create_origin_marker() -> void:
	origin_marker = Label.new()
	origin_marker.text = "ORIGIN"
	origin_marker.add_theme_font_size_override("font_size", 30)
	origin_marker.add_theme_color_override("font_color", Color.WHITE)
	origin_marker.add_theme_color_override("font_outline_color", Color.BLACK)
	origin_marker.add_theme_constant_override("outline_size", 8)
	origin_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	origin_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	origin_marker.size = Vector2(TILE_PX, TILE_PX)
	origin_marker.position = grid.position + Vector2(zombie_cell.x * TILE_PX, zombie_cell.y * TILE_PX)
	add_child(origin_marker)

func refresh_status() -> void:
	if status_label == null:
		return
	var selection_text := "(%d, %d)" % [selected_cell.x, selected_cell.y] if has_valid_selection() else "none"
	status_label.text = "Day %d / %d    Funding: $%dk    Doses: %d    Selected: %s" % [
		day, MAX_DAYS, money, doses, selection_text,
	]
	if treat_button != null:
		treat_button.disabled = doses <= 0

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
	return "[b]%s[/b]\n" % title \
		+ "[color=#7ed957]Healthy[/color]: %d\n" % data["healthy"] \
		+ "[color=#ff5b5b]Infected[/color]: %d\n" % data["infected"] \
		+ "[color=#5b9bff]Cured[/color]: %d\n" % data["cured"] \
		+ "[color=#b0b0b0]Dead[/color]: %d" % data["dead"]
