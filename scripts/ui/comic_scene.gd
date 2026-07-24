extends Node2D

# comic frames shown in order, one more panel revealed per click
const FRAMES: Array[String] = [
	"res://assets/comic_1.png",
	"res://assets/comic_2.png",
	"res://assets/comic_3.png",
	"res://assets/comic_4.png",
]
const FADE_TIME := 0.5

@onready var comic: Sprite2D = $Comic
@onready var start_button: Button = $StartGame

var frame_index := 0
var overlay: Sprite2D
var fading := false

func _ready() -> void:
	# overlay sprite sits on top of the comic; new frames fade in on it
	overlay = Sprite2D.new()
	overlay.position = comic.position
	overlay.modulate.a = 0.0
	add_child(overlay)
	style_start_button()
	comic.texture = load(FRAMES[0])
	start_button.visible = false
	start_button.modulate.a = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# left click, space, or enter reveals the next panel
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		next_frame()
	elif event.is_action_pressed("ui_accept"):
		next_frame()

func next_frame() -> void:
	if fading or frame_index >= FRAMES.size() - 1:
		return
	fading = true
	frame_index += 1
	overlay.texture = load(FRAMES[frame_index])
	overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, FADE_TIME)
	tween.tween_callback(finish_fade)

func finish_fade() -> void:
	# bake the finished frame into the base sprite and hide the overlay again
	comic.texture = overlay.texture
	overlay.modulate.a = 0.0
	fading = false
	if frame_index == FRAMES.size() - 1:
		show_start_button()

func show_start_button() -> void:
	start_button.visible = true
	var tween := create_tween()
	tween.tween_property(start_button, "modulate:a", 1.0, 0.4)

func style_start_button() -> void:
	# cream caption-box look to match the comic's text boxes
	start_button.text = "START"
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f7edc5")
	normal.border_color = Color("2b2620")
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("fff7d9")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("e0d3a0")
	start_button.add_theme_stylebox_override("normal", normal)
	start_button.add_theme_stylebox_override("hover", hover)
	start_button.add_theme_stylebox_override("pressed", pressed)
	start_button.add_theme_font_override("font", load("res://assets/Play-Regular.ttf"))
	start_button.add_theme_font_size_override("font_size", 44)
	start_button.add_theme_color_override("font_color", Color("2b2620"))
	start_button.add_theme_color_override("font_hover_color", Color("2b2620"))
	start_button.add_theme_color_override("font_pressed_color", Color("2b2620"))

func start_game() -> void:
	# ends comic, sets scene to tutorial before the real game
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")

func _on_start_game_pressed() -> void:
	start_game()
