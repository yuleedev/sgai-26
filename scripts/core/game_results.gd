extends Node

var people_lost: int = 0
var zombies_killed: int = 0
var zombies_cured: int = 0
var playthrough_number: int = 1
var playthrough_results: Array[Dictionary] = []

func begin_next_playthrough() -> void:
	playthrough_number += 1

func record_playthrough(result: Dictionary) -> void:
	var result_index := playthrough_number - 1
	if result_index < playthrough_results.size():
		playthrough_results[result_index] = result
	else:
		playthrough_results.append(result)

func reset() -> void:
	people_lost = 0
	zombies_killed = 0
	zombies_cured = 0
	playthrough_number = 1
	playthrough_results.clear()
