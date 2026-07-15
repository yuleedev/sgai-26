extends Node

func start_game() -> void:
	# ends comic, sets scene to map scene (real game)
	print("ending comic")
	get_tree().change_scene_to_file("res://scenes/map_scene.tscn")

func _on_start_game_pressed() -> void:
	start_game()
