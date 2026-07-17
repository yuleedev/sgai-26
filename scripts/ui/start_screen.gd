extends Control

func _on_play_pressed() -> void:
	# starts the comic intro, then the real game
	print("starting comic")
	get_tree().change_scene_to_file("res://scenes/comic_scene.tscn")

func _on_credits_pressed() -> void:
	print("opening credits")
	get_tree().change_scene_to_file("res://scenes/credits_scene.tscn")

func _on_settings_pressed() -> void:
	print("opening settings")
	get_tree().change_scene_to_file("res://scenes/settings_scene.tscn")
