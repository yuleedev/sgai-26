class_name ScenarioLoader


static func load_scenario(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var headers := file.get_csv_line()
	var cells: Dictionary = {}
	var origin := Vector2i(-1, -1)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2:
			continue
		var x := int(row[0])
		var y := int(row[1])
		var pos := Vector2i(x, y)
		var population := 0
		var is_origin := false
		var climate := "temperate"
		var terrain := "urban"
		var wealth := 1.0
		var pop_density := 1.0
		if row.size() > 2 and row[2].is_valid_int():
			population = int(row[2])
		if row.size() > 3 and row[3].is_valid_int():
			is_origin = int(row[3]) == 1
		if row.size() > 4 and row[4] != "":
			climate = row[4]
		if row.size() > 5 and row[5] != "":
			terrain = row[5]
		if row.size() > 6 and row[6].is_valid_float():
			wealth = float(row[6])
		if row.size() > 7 and row[7].is_valid_float():
			pop_density = float(row[7])
		cells[pos] = {
			"population": population,
			"climate": climate,
			"terrain": terrain,
			"wealth": wealth,
			"pop_density": pop_density,
		}
		if is_origin:
			origin = pos
	return {"cells": cells, "origin": origin}


static func load_virus_schedule(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var headers := file.get_csv_line()
	var schedule: Dictionary = {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2:
			continue
		var day_num := -1
		if row[0].is_valid_int():
			day_num = int(row[0])
		if day_num < 1:
			continue
		var upgrade_type := row[1] if row.size() > 1 else ""
		var value := 1.0
		if row.size() > 2 and row[2].is_valid_float():
			value = float(row[2])
		var target_x := -1
		if row.size() > 3 and row[3].is_valid_int():
			target_x = int(row[3])
		var target_y := -1
		if row.size() > 4 and row[4].is_valid_int():
			target_y = int(row[4])
		var description := row[5] if row.size() > 5 else ""
		var event := {
			"upgrade_type": upgrade_type,
			"value": value,
			"target_x": target_x,
			"target_y": target_y,
			"description": description,
		}
		if not schedule.has(day_num):
			schedule[day_num] = []
		schedule[day_num].append(event)
	return schedule
