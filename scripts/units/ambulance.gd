extends Node2D
class_name Ambulance
## Circle ambulance unit. Travels from the player hub to a target, then returns.
## Behavior will later be driven by the skill tree (mostly automated) with optional
## player control — neither is implemented here yet.

signal arrived_at_target
signal returned_to_hub

@export var radius: float = 28.0
@export var color: Color = Color(0.92, 0.22, 0.28, 1.0)
@export var travel_speed: float = 420.0

## Grid cell the player chooses as hub at run start (set externally).
var hub_cell: Vector2i = Vector2i(2, 2)
## World-space center of the hub cell.
var hub_position: Vector2 = Vector2.ZERO

var is_traveling: bool = false
var _travel_tween: Tween

func _ready() -> void:
	z_index = 10
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.85), 2.0, true)

## Call once after hub is known (default center until startup selection exists).
func setup(p_hub_cell: Vector2i, p_hub_position: Vector2) -> void:
	hub_cell = p_hub_cell
	hub_position = p_hub_position
	global_position = hub_position
	is_traveling = false

## Move from current position to a world-space target. Hook for dispatch / AI later.
func move_to(target_position: Vector2) -> void:
	_start_travel(target_position, _on_arrived_at_target)

## Return to the configured hub after a dispatch.
func return_to_hub() -> void:
	_start_travel(hub_position, _on_returned_to_hub)

func _start_travel(target_position: Vector2, on_finished: Callable) -> void:
	if _travel_tween and _travel_tween.is_running():
		_travel_tween.kill()
	is_traveling = true
	var distance := global_position.distance_to(target_position)
	var duration := distance / maxf(travel_speed, 1.0)
	_travel_tween = create_tween()
	_travel_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_travel_tween.tween_property(self, "global_position", target_position, duration)
	_travel_tween.finished.connect(on_finished, CONNECT_ONE_SHOT)

func _on_arrived_at_target() -> void:
	is_traveling = false
	arrived_at_target.emit()

func _on_returned_to_hub() -> void:
	is_traveling = false
	global_position = hub_position
	returned_to_hub.emit()
