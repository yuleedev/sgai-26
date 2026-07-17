extends Button

# Reusable menu button: grows slightly on hover / keyboard focus.
# Pairs with the theme's color change for layered feedback.

@export var hover_scale: float = 1.08
@export var tween_time: float = 0.12

func _ready() -> void:
	_center_pivot()
	resized.connect(_center_pivot)
	mouse_entered.connect(_grow)
	mouse_exited.connect(_shrink)
	focus_entered.connect(_grow)
	focus_exited.connect(_shrink)

func _center_pivot() -> void:
	pivot_offset = size / 2.0

func _grow() -> void:
	_center_pivot()
	_scale_to(hover_scale)

func _shrink() -> void:
	_scale_to(1.0)

func _scale_to(target: float) -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(target, target), tween_time)
