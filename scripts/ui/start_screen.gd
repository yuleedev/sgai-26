extends Control

func start_comic() -> void:
	# sets scene to comic
	print("starting comic")
	get_tree().change_scene_to_file("res://scenes/comic_scene.tscn")

func _on_start_comic_pressed() -> void:
	start_comic()
