class_name ScenarioGenerator

const GRID_SIZE := 5
const BASE_CELL := Vector2i(2, 2)

const CLIMATES: Array[String] = ["temperate", "tropical", "arid", "cold"]
const TERRAINS: Array[String] = ["urban", "suburban", "rural", "industrial"]

const MIN_POPULATION := 50
const MAX_POPULATION := 150


static func generate_scenario(id: String) -> String:
	var path := "res://data/%s.csv" % id
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ScenarioGenerator: could not write to %s" % path)
		return ""
	file.store_csv_line(PackedStringArray([
		"x", "y", "population", "origin", "climate", "terrain", "wealth", "pop_density",
	]))
	var origin_cell := Vector2i(randi_range(0, GRID_SIZE - 1), randi_range(0, GRID_SIZE - 1))
	while origin_cell == BASE_CELL:
		origin_cell = Vector2i(randi_range(0, GRID_SIZE - 1), randi_range(0, GRID_SIZE - 1))
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var population := 0
			var is_origin := 0
			if cell != BASE_CELL:
				population = randi_range(MIN_POPULATION, MAX_POPULATION)
				if cell == origin_cell:
					is_origin = 1
			var climate: String = CLIMATES.pick_random()
			var terrain: String = TERRAINS.pick_random()
			var wealth := snappedf(randf_range(0.5, 1.5), 0.1)
			var pop_density := snappedf(randf_range(0.6, 1.4), 0.1)
			file.store_csv_line(PackedStringArray([
				str(x), str(y), str(population), str(is_origin),
				climate, terrain, str(wealth), str(pop_density),
			]))
	return path


static func generate_virus_schedule(id: String, max_days: int = 30) -> String:
	var path := "res://data/%s_virus_schedule.csv" % id
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ScenarioGenerator: could not write to %s" % path)
		return ""
	file.store_csv_line(PackedStringArray([
		"day", "upgrade_type", "value", "target_x", "target_y", "description",
	]))
	var num_upgrades := randi_range(5, 8)
	var upgrade_days: Array[int] = []
	for i in range(num_upgrades):
		var d := randi_range(2, max_days - 1)
		while d in upgrade_days:
			d = randi_range(2, max_days - 1)
		upgrade_days.append(d)
	upgrade_days.sort()
	var early_count := maxi(1, num_upgrades / 3)
	for i in range(num_upgrades):
		var event := _generate_upgrade_event(i, early_count, num_upgrades)
		file.store_csv_line(PackedStringArray([
			str(upgrade_days[i]),
			event["upgrade_type"],
			str(event["value"]),
			str(event["target_x"]),
			str(event["target_y"]),
			event["description"],
		]))
	return path


static func _generate_upgrade_event(index: int, early_count: int, total: int) -> Dictionary:
	var tier := 0
	if index >= total - maxi(1, total / 3):
		tier = 2
	elif index >= early_count:
		tier = 1

	var pool: Array[String]
	match tier:
		0:
			pool = ["spread_boost", "infection_rate", "spread_boost"]
		1:
			pool = ["spread_boost", "infection_rate", "death_resistance", "new_origin"]
		2:
			pool = ["infection_rate", "mutation", "spread_boost", "death_resistance", "extra_spread_amount"]

	var upgrade_type: String = pool.pick_random()
	var value := 1.0
	var description := ""
	var target_x := -1
	var target_y := -1

	match upgrade_type:
		"spread_boost":
			match tier:
				0: value = snappedf(randf_range(1.1, 1.3), 0.1)
				1: value = snappedf(randf_range(1.4, 1.8), 0.1)
				2: value = snappedf(randf_range(1.8, 2.5), 0.1)
			description = "Spread multiplier increased"
		"infection_rate":
			match tier:
				0: value = snappedf(randf_range(0.32, 0.38), 0.01)
				1: value = snappedf(randf_range(0.38, 0.45), 0.01)
				2: value = snappedf(randf_range(0.45, 0.55), 0.01)
			description = "Infection conversion rate increased"
		"death_resistance":
			match tier:
				0: value = snappedf(randf_range(0.03, 0.04), 0.005)
				1: value = snappedf(randf_range(0.02, 0.03), 0.005)
				2: value = snappedf(randf_range(0.01, 0.02), 0.005)
			description = "Virus becomes harder to kill naturally"
		"new_origin":
			target_x = -1
			target_y = -1
			description = "Virus migrates to most-infected cell"
		"mutation":
			match tier:
				0: value = snappedf(randf_range(1.2, 1.4), 0.1)
				1: value = snappedf(randf_range(1.4, 1.7), 0.1)
				2: value = snappedf(randf_range(1.7, 2.2), 0.1)
			description = "Virus mutates — all parameters boosted"
		"extra_spread_amount":
			match tier:
				0: value = 3.0
				1: value = 4.0
				2: value = 5.0
			description = "More infected appear per spread event"

	return {
		"upgrade_type": upgrade_type,
		"value": value,
		"target_x": target_x,
		"target_y": target_y,
		"description": description,
	}
