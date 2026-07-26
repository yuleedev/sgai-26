extends AudioStreamPlayer

const CLICK: AudioStream = preload("res://assets/audio/click.mp3")
const HOVER: AudioStream = preload("res://assets/audio/hover.mp3")
const CLICK_VOLUME_DB := -26.0
const HOVER_VOLUME_DB := -22.0

var hover_player: AudioStreamPlayer

func _ready() -> void:
	stream = CLICK
	volume_db = CLICK_VOLUME_DB
	bus = AudioSettings.SFX_BUS
	process_mode = Node.PROCESS_MODE_ALWAYS

	hover_player = AudioStreamPlayer.new()
	hover_player.stream = HOVER
	hover_player.volume_db = HOVER_VOLUME_DB
	hover_player.bus = AudioSettings.SFX_BUS
	hover_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hover_player)

	get_tree().node_added.connect(_hook_button)
	_hook_existing(get_tree().root)

func _hook_existing(node: Node) -> void:
	_hook_button(node)
	for child in node.get_children():
		_hook_existing(child)

func _hook_button(node: Node) -> void:
	if not node is BaseButton:
		return
	if not node.button_down.is_connected(_on_button_down):
		node.button_down.connect(_on_button_down)
	if not node.mouse_entered.is_connected(_on_button_hover.bind(node)):
		node.mouse_entered.connect(_on_button_hover.bind(node))

func exclude(button: BaseButton) -> void:
	if button.button_down.is_connected(_on_button_down):
		button.button_down.disconnect(_on_button_down)

func exclude_hover(button: BaseButton) -> void:
	if button.mouse_entered.is_connected(_on_button_hover.bind(button)):
		button.mouse_entered.disconnect(_on_button_hover.bind(button))

func _on_button_down() -> void:
	play()

func _on_button_hover(button: BaseButton) -> void:
	if button.disabled:
		return
	hover_player.play()
