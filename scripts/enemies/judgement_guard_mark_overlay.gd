extends Node2D

var _last_active_state: bool = false


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	var active_now: bool = _has_active_guard_mark()
	if active_now or _last_active_state != active_now:
		queue_redraw()
	_last_active_state = active_now


func _draw() -> void:
	if not _has_active_guard_mark():
		return

	var host: Node = get_parent()
	if host == null or not host.has_method("get_guard_mark_visual_data"):
		return

	var visual_data: Dictionary = host.call("get_guard_mark_visual_data")
	var center: Vector2 = visual_data.get("center", Vector2.ZERO)
	var outer_color: Color = visual_data.get("outer_color", Color(0.7, 0.78, 0.86, 0.42))
	var core_color: Color = visual_data.get("core_color", Color(0.92, 0.95, 1.0, 0.86))
	var radius: float = float(visual_data.get("radius", 26.0))
	var pulse_speed: float = float(visual_data.get("pulse_speed", 5.2))

	var time_value: float = Time.get_ticks_msec() * 0.001
	var pulse: float = 0.5 + 0.5 * sin(time_value * pulse_speed)
	var outer_radius: float = radius + pulse * 1.6
	var inner_radius: float = radius * 0.74 + pulse * 0.8

	var shield_fill: PackedVector2Array = _build_guard_barrier_polygon(center, outer_radius, 6.0 + pulse * 1.2, 18)
	var fill_color: Color = outer_color
	fill_color.a *= 0.46 + pulse * 0.08
	draw_colored_polygon(shield_fill, fill_color)

	var inner_fill: PackedVector2Array = _build_guard_barrier_polygon(center, inner_radius, 3.0 + pulse * 0.8, 18)
	var core_fill: Color = core_color
	core_fill.a *= 0.18 + pulse * 0.05
	draw_colored_polygon(inner_fill, core_fill)

	var outline_color: Color = core_color
	outline_color.a *= 0.84 + pulse * 0.10
	draw_polyline(shield_fill, outline_color, 2.0, true)

	var inner_line_color: Color = core_color
	inner_line_color.a *= 0.42 + pulse * 0.08
	draw_polyline(inner_fill, inner_line_color, 1.2, true)

	draw_circle(center, 5.0 + pulse * 0.9, Color(core_color.r, core_color.g, core_color.b, 0.22))


func _has_active_guard_mark() -> bool:
	var host: Node = get_parent()
	if host == null:
		return false
	if not host.has_method("has_active_guard_mark"):
		return false
	return bool(host.call("has_active_guard_mark"))


func _build_guard_barrier_polygon(center: Vector2, base_radius: float, spike_length: float, point_count: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	for index in range(point_count):
		var angle: float = TAU * float(index) / float(point_count)
		var spike_radius: float = base_radius
		if index % 2 == 0:
			spike_radius += spike_length
		var point: Vector2 = center + Vector2.RIGHT.rotated(angle) * spike_radius
		polygon.append(point)
	if polygon.size() > 0:
		polygon.append(polygon[0])
	return polygon
