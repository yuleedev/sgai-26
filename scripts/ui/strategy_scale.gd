extends Control

const TRACK := Color("51545d")
const SCALE_BG := Color(0.12, 0.125, 0.14, 0.55)
const PLAYTHROUGH_COLORS: Array[Color] = [
	Color("65c9d4"),
	Color("e2b857"),
	Color("b38bd4"),
]

var scale_title := ""
var left_label := ""
var right_label := ""
var overall_value := 0.0
var playthrough_values: Array[float] = []
var show_playthroughs := false
var _font: Font

func _get_font() -> Font:
	if _font == null:
		_font = HudStyle.make_ui_font()
	return _font

func setup(title: String, left: String, right: String, overall: float, values: Array[float], show_pts := false) -> void:
	scale_title = title
	left_label = left
	right_label = right
	overall_value = overall
	playthrough_values = values
	show_playthroughs = show_pts
	custom_minimum_size = Vector2(0, (82 + values.size() * 21) if show_pts else 92)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var font := _get_font()
	var track_start := 184.0
	var track_end := size.x - 22.0
	draw_string(font, Vector2(0, 25), scale_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Palette.TEXT_BONE)
	draw_string(font, Vector2(track_start, 49), left_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.TEXT_BONE_MUTED)
	var right_width := font.get_string_size(right_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(track_end - right_width, 49), right_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.TEXT_BONE_MUTED)

	var pt_count := playthrough_values.size()
	var lane_y = [65.0]
	var lane_labels := ["ALL"]
	if show_playthroughs:
		for i in range(pt_count):
			lane_y.append(65.0 + (i + 1) * 21.0)
			lane_labels.append("P%d" % [i + 1])
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = SCALE_BG
	bg_style.set_corner_radius_all(6)
	var bg_rect := Rect2(0, lane_y[0] - 12, size.x, lane_y[-1] - lane_y[0] + 26)
	draw_style_box(bg_style, bg_rect)
	for i in range(lane_y.size()):
		var y: float = lane_y[i]
		draw_string(font, Vector2(0, y + 6), lane_labels[i], HORIZONTAL_ALIGNMENT_LEFT, 48, 17, Palette.TEXT_BONE_MUTED)
		draw_line(Vector2(track_start, y), Vector2(track_end, y), TRACK, 3.0)
		draw_line(Vector2((track_start + track_end) / 2.0, y - 5), Vector2((track_start + track_end) / 2.0, y + 5), Palette.TEXT_BONE_MUTED, 1.0)

	var overall_x := _value_position(overall_value, track_start, track_end)
	var diamond := PackedVector2Array([
		Vector2(overall_x, lane_y[0] - 8),
		Vector2(overall_x + 8, lane_y[0]),
		Vector2(overall_x, lane_y[0] + 8),
		Vector2(overall_x - 8, lane_y[0]),
	])
	draw_colored_polygon(diamond, Palette.TEXT_BONE)

	if show_playthroughs:
		var color_count := PLAYTHROUGH_COLORS.size()
		for i in range(playthrough_values.size()):
			var marker_x := _value_position(playthrough_values[i], track_start, track_end)
			draw_circle(Vector2(marker_x, lane_y[i + 1]), 6.0, PLAYTHROUGH_COLORS[i % color_count])
			draw_arc(Vector2(marker_x, lane_y[i + 1]), 7.0, 0.0, TAU, 20, Color.BLACK, 2.0)

func _value_position(value: float, start: float, end: float) -> float:
	return lerpf(start, end, (clampf(value, -1.0, 1.0) + 1.0) / 2.0)
