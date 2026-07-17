extends Control

const CREAM := Color("f7edc5")
const INK := Color("2b2620")
const COMIC_FONT := preload("res://assets/Bangers-Regular.ttf")

@onready var start_button: Button = $StartComic

func _ready() -> void:
	build_background()
	build_title()
	style_start_button()
	fade_everything_in()

func build_background() -> void:
	# virus panel from the comic as a full-screen backdrop, dimmed for readability
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = load("res://assets/comic_1.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	move_child(dim, 1)

func build_title() -> void:
	var vp := get_viewport_rect().size
	var title := Label.new()
	title.name = "Title"
	title.text = "SGAI-26"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, vp.y * 0.16)
	title.size = Vector2(vp.x, 170)
	title.add_theme_font_override("font", COMIC_FONT)
	title.add_theme_font_size_override("font_size", 150)
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 26)
	add_child(title)
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "CONTAIN  THE  OUTBREAK"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, vp.y * 0.16 + 170)
	subtitle.size = Vector2(vp.x, 60)
	subtitle.add_theme_font_override("font", COMIC_FONT)
	subtitle.add_theme_font_size_override("font_size", 38)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	subtitle.add_theme_color_override("font_outline_color", INK)
	subtitle.add_theme_constant_override("outline_size", 10)
	add_child(subtitle)

func style_start_button() -> void:
	# cream caption-box look, matching the comic scene's button
	var vp := get_viewport_rect().size
	start_button.text = "START"
	start_button.size = Vector2(340, 100)
	start_button.position = Vector2((vp.x - 340) / 2.0, vp.y * 0.66)
	var normal := StyleBoxFlat.new()
	normal.bg_color = CREAM
	normal.border_color = INK
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("fff7d9")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("e0d3a0")
	start_button.add_theme_stylebox_override("normal", normal)
	start_button.add_theme_stylebox_override("hover", hover)
	start_button.add_theme_stylebox_override("pressed", pressed)
	start_button.add_theme_font_override("font", COMIC_FONT)
	start_button.add_theme_font_size_override("font_size", 46)
	start_button.add_theme_color_override("font_color", INK)
	start_button.add_theme_color_override("font_hover_color", INK)
	start_button.add_theme_color_override("font_pressed_color", INK)

func fade_everything_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func start_comic() -> void:
	# sets scene to comic
	print("starting comic")
	get_tree().change_scene_to_file("res://scenes/comic_scene.tscn")

func _on_start_comic_pressed() -> void:
	start_comic()
