extends Node

var people_lost: int = 0
var zombies_killed: int = 0
var zombies_cured: int = 0
var run_id: int = 1

func reset() -> void:
	people_lost = 0
	zombies_killed = 0
	zombies_cured = 0
	run_id = 1
