extends Control

const TOOTH_COUNT := 8

var color: Color = Palette.ICON_TINT

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	if radius <= 0.0:
		return
	var center := size / 2.0
	var band := radius * 0.30
	var ring_radius := radius * 0.52

	for i in range(TOOTH_COUNT):
		var angle := TAU * float(i) / float(TOOTH_COUNT)
		var dir := Vector2(cos(angle), sin(angle))
		var side := Vector2(-dir.y, dir.x)
		var base := center + dir * (ring_radius + band * 0.2)
		var tip := center + dir * radius
		var base_half := side * radius * 0.24
		var tip_half := side * radius * 0.17
		draw_colored_polygon(PackedVector2Array([
			base - base_half,
			tip - tip_half,
			tip + tip_half,
			base + base_half,
		]), color)

	draw_arc(center, ring_radius, 0.0, TAU, 48, color, band, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
