extends Control

# makes a variable to hold everything
@export_file("*.tscn") var game_scene_path := "res://game.tscn"

@onready var background:  TextureRect = $Background
@onready var fog: TextureRect = $Fog
@onready var left_hand:  TextureRect = $LeftHand
@onready var right_hand:  TextureRect = $RightHand
@onready var fingers: TextureRect = $Fingers
@onready var title: TextureRect = $Title
@onready var try_again_art: TextureRect = $TryAgainArt
@onready var try_again_button: Button = $TryAgainButton
@onready var fade_overlay: ColorRect = $FadeOverlay

@onready var hand1: TextureRect = $"RevealMask/1"
@onready var hand2: TextureRect = $"RevealMask/2"
@onready var hand3: TextureRect = $"RevealMask/3"
@onready var hand4: TextureRect = $"RevealMask/4"
@onready var hand5: TextureRect = $"RevealMask/5"
@onready var hand6: TextureRect = $"RevealMask/6"
@onready var hand7: TextureRect = $"RevealMask/7"
@onready var hand8: TextureRect = $"RevealMask/8"
@onready var hand9: TextureRect = $"RevealMask/9"
@onready var hand10: TextureRect = $"RevealMask/10"

# sound effects
@onready var start_game_sound: AudioStreamPlayer = $StartGameSound

# button textures
@export var try_again_normal_texture: Texture2D
@export var try_again_hover_texture: Texture2D
@export var try_again_pressed_texture: Texture2D
@export var try_again_animation_time := 0.7

# store starting info
var bg_start_pos: Vector2
var bg_start_scale: Vector2
var left_hand_start_pos: Vector2
var left_hand_start_rot: float
var right_hand_start_pos: Vector2
var right_hand_start_rot: float
var title_start_pos: Vector2
var try_again_art_start_pos: Vector2
var fog_start_pos: Vector2

var hand1_pos: Vector2
var hand2_pos: Vector2
var hand3_pos: Vector2
var hand4_pos: Vector2
var hand5_pos: Vector2
var hand6_pos: Vector2
var hand7_pos: Vector2
var hand8_pos: Vector2
var hand9_pos: Vector2
var hand10_pos: Vector2

var is_pressing_try_again := false
var is_transitioning := false

# showing scores
const FONT: FontFile = preload("res://assets/Bangers-Regular.ttf")
const LOST_Y := 430
const KILLED_Y := 520
const CURED_Y = 610
@onready var people_lost: Label = $PeopleLost
@onready var zombies_killed: Label = $ZombiesKilled
@onready var zombies_cured: Label = $ZombiesCured

func _ready() -> void:
	# center pivots
	left_hand.pivot_offset = left_hand.size / 2.0
	right_hand.pivot_offset = right_hand.size / 2.0
	fingers.pivot_offset = right_hand.size / 2.0
	try_again_art.pivot_offset = try_again_art.size / 2.0
	
	# save starting info
	bg_start_pos = background.position
	bg_start_scale = background.scale
	left_hand_start_pos = left_hand.position
	left_hand_start_rot  = left_hand.rotation
	right_hand_start_pos = right_hand.position
	right_hand_start_rot = right_hand.rotation
	title_start_pos = title.position
	try_again_art_start_pos = try_again_art.position
	fog_start_pos = fog.position
	
	# set initial state visibility with alpha
	fade_overlay.modulate.a = 1.0
	title.modulate.a = 0.0
	try_again_art.modulate.a = 0.0
	left_hand.modulate.a = 0.0
	right_hand.modulate.a = 0.0
	fingers.modulate.a = 0.0
	fog.modulate.a = 0.0
	
	hand1.modulate.a = 0.0
	hand2.modulate.a = 0.0
	hand3.modulate.a = 0.0
	hand4.modulate.a = 0.0
	hand5.modulate.a = 0.0
	hand6.modulate.a = 0.0
	hand7.modulate.a = 0.0
	hand8.modulate.a = 0.0
	hand9.modulate.a = 0.0
	hand10.modulate.a = 0.0
	
	people_lost.modulate.a = 0.0
	zombies_killed.modulate.a = 0.0
	zombies_cured.modulate.a = 0.0
	
	# offset initial position before motion
	title.position += Vector2(0,-80)
	try_again_art.scale = Vector2(1.02, 1.02)
	left_hand.position += Vector2(-80,-20)
	right_hand.position += Vector2(80, -20)
	fingers.position += Vector2(80,-20)
	
	hand1.position += Vector2(0, 200)
	hand2.position += Vector2(0, 200)
	hand3.position += Vector2(0, 200)
	hand4.position += Vector2(0, 200)
	hand5.position += Vector2(0, 200)
	hand6.position += Vector2(0, 200)
	hand7.position += Vector2(0, 200)
	hand8.position += Vector2(0, 200)
	hand9.position += Vector2(0, 200)
	hand10.position += Vector2(0, 200)
	
	# button stuff
	try_again_button.text = ""
	try_again_button.flat = true
	try_again_button.modulate.a = 0.0
	try_again_button.disabled = true
	
	# connect button signals
	try_again_button.mouse_entered.connect(_on_try_again_button_mouse_entered)
	try_again_button.mouse_exited.connect(_on_try_again_button_mouse_exited)
	try_again_button.button_down.connect(_on_try_again_button_down)
	ClickSound.exclude(try_again_button)
	
	# call anim
	play_intro()

func play_intro() -> void:
	# makes tween and runs every animation at same time
	var tween := create_tween()
	tween.set_parallel(true)
	
	# fade in
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 1.0)
	tween.tween_property(background, "modulate:a", 1.0, 0.6)
	
	# wait for these animations to finish
	await tween.finished
	await animate_title_intro()
	await animate_hands_intro()
	
	# show results
	setup_label(people_lost, "People lost: %d" % GameResults.people_lost, LOST_Y)
	setup_label(zombies_killed, "Zombies killed: %d" % GameResults.zombies_killed, KILLED_Y)
	setup_label(zombies_cured, "Zombies cured: %d" % GameResults.zombies_cured, CURED_Y)
	show_results()
	
	animate_try_again_intro()
	
	# emables try again button
	try_again_button.disabled = false
	
	# loop background motion
	fog_loop()
	left_hand_loop()
	right_hand_loop()
	try_again_button_loop()

func animate_title_intro() -> void:
	title.modulate.a = 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(title, "position", title_start_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

func animate_hands_intro() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(left_hand, "modulate:a", 1.0, 0.2)
	tween.tween_property(right_hand, "modulate:a", 1.0, 0.2)
	tween.tween_property(fingers, "modulate:a", 1.0, 0.2)
	
	# moves hand from start position to where it should be
	tween.tween_property(left_hand, "position", left_hand_start_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(right_hand, "position", right_hand_start_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(fingers, "position", right_hand_start_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

func animate_try_again_intro() -> void:
	await get_tree().create_timer(0.8).timeout
	try_again_art.modulate.a = 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(try_again_art, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(try_again_art, "modulate:a", 1.0,0.35)
	await tween.finished

func left_hand_loop() -> void:
	# idle background left hand movement
	while is_inside_tree():
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(left_hand, "rotation", left_hand_start_rot + deg_to_rad(2.0), 2.0)
		tween.tween_property(left_hand, "position", left_hand_start_pos + Vector2(6,4), 2.0)
		await tween.finished
		var tween_back := create_tween()
		tween_back.set_parallel(true)
		tween_back.set_trans(Tween.TRANS_SINE)
		tween_back.set_ease(Tween.EASE_IN_OUT)
		tween_back.tween_property(left_hand, "rotation", left_hand_start_rot - deg_to_rad(1.5), 2.2)
		tween_back.tween_property(left_hand, "position", left_hand_start_pos + Vector2(-4.0,-2.0), 2.2)
		await tween_back.finished

func right_hand_loop() -> void:
	# idle background right hand movement
	while is_inside_tree():
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(right_hand, "rotation", right_hand_start_rot - deg_to_rad(2.2), 2.0)
		tween.tween_property(right_hand, "position", right_hand_start_pos + Vector2(6,4), 2.0)
		tween.tween_property(fingers, "rotation", right_hand_start_rot - deg_to_rad(2.2), 2.0)
		tween.tween_property(fingers, "position", right_hand_start_pos + Vector2(6,4), 2.0)
		await tween.finished
		var tween_back := create_tween()
		tween_back.set_parallel(true)
		tween_back.set_trans(Tween.TRANS_SINE)
		tween_back.set_ease(Tween.EASE_IN_OUT)
		tween_back.tween_property(right_hand, "rotation", right_hand_start_rot + deg_to_rad(1.7), 2.2)
		tween_back.tween_property(right_hand, "position", right_hand_start_pos + Vector2(-4.0,-2.0), 2.2)
		tween_back.tween_property(fingers, "rotation", right_hand_start_rot + deg_to_rad(1.7), 2.2)
		tween_back.tween_property(fingers, "position", right_hand_start_pos + Vector2(-4.0,-2.0), 2.2)
		await tween_back.finished

func try_again_button_loop() -> void:
	while is_inside_tree():
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(try_again_art, "scale", Vector2(1.02, 1.02), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		var tween_back := create_tween()
		tween_back.set_parallel(true)
		tween_back.tween_property(try_again_art, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween_back.finished

func fog_loop() -> void:
	while is_inside_tree():
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(fog, "position", fog_start_pos + Vector2(20,0), 4.0).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(fog, "modulate:a", 0.35, 4.0)
		await tween.finished
		var tween_back := create_tween()
		tween_back.set_parallel(true)
		tween_back.tween_property(fog, "position", fog_start_pos, 4.0).set_trans(Tween.TRANS_LINEAR)
		tween_back.tween_property(fog, "modulate:a", 0.5, 4.0)
		await tween_back.finished

func _on_try_again_button_mouse_entered() -> void:
	if is_pressing_try_again or is_transitioning:
		return
	try_again_art.texture = try_again_hover_texture

func _on_try_again_button_mouse_exited() -> void:
	if is_pressing_try_again or is_transitioning:
		return
	try_again_art.texture = try_again_normal_texture

func _on_try_again_button_down() -> void:
	if is_pressing_try_again or is_transitioning:
		return
	
	is_pressing_try_again = true
	try_again_button.disabled = true
	try_again_art.texture = try_again_pressed_texture
	
	play_try_again_animation()

func play_try_again_animation() -> void:
	# hands animation
	var tween := create_tween()
	tween.set_parallel(false)
	
	start_game_sound.play()
	
	hand1.modulate.a = 1.0
	tween.tween_property(hand1, "position", hand1_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hand2.modulate.a = 1.0
	tween.tween_property(hand2, "position", hand2_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hand3.modulate.a = 1.0
	tween.tween_property(hand3, "position", hand3_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hand4.modulate.a = 1.0
	tween.tween_property(hand4, "position", hand4_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hand5.modulate.a = 1.0
	tween.tween_property(hand5, "position", hand5_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hand6.modulate.a = 1.0
	tween.tween_property(hand6, "position", hand6_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hand7.modulate.a = 1.0
	tween.tween_property(hand7, "position", hand7_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)	
	hand8.modulate.a = 1.0
	tween.tween_property(hand8, "position", hand8_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hand9.modulate.a = 1.0
	tween.tween_property(hand9, "position", hand9_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hand10.modulate.a = 1.0
	tween.tween_property(hand10, "position", hand10_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(try_again_animation_time).timeout
	transition_fade()

func transition_fade() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.3)
	await fade_tween.finished
	start_game()

func start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/map_scene.tscn")

func setup_label(label: Label, text: String, y: float) -> void:
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 54)
	label.add_theme_color_override("font_color", Color("f7edc5"))
	label.position = Vector2(0,y)
	label.size = Vector2(1920,1080)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func show_results() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(people_lost, "modulate:a", 1.0, 0.6)
	tween.tween_property(zombies_killed, "modulate:a", 1.0, 0.6)
	tween.tween_property(zombies_cured, "modulate:a", 1.0, 0.6)
