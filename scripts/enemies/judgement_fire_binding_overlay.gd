extends Node2D
class_name JudgementFireBindingOverlay

var _last_visible_state: bool = false


func _process(_delta: float) -> void:
	var parent_head: Node = get_parent()
	if parent_head == null:
		return
	if not parent_head.has_method("get_fire_binding_visual_data"):
		return

	var visual_data: Dictionary = parent_head.call("get_fire_binding_visual_data")
	var is_visible_now: bool = bool(visual_data.get("visible", false))
	if is_visible_now or _last_visible_state != is_visible_now:
		queue_redraw()
	_last_visible_state = is_visible_now


func _draw() -> void:
	var parent_head: Node = get_parent()
	if parent_head == null:
		return
	if not parent_head.has_method("get_fire_binding_visual_data"):
		return

	var visual_data: Dictionary = parent_head.call("get_fire_binding_visual_data")
	if not bool(visual_data.get("visible", false)):
		return

	var effective_state: int = int(visual_data.get("state", 0))
	var pulse_speed: float = 4.0 if effective_state == 1 or effective_state == 2 else 7.0
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed)

	var base_color: Color = visual_data.get("base_color", Color(1.0, 0.8, 0.2, 0.9))
	var is_guard_kind: bool = bool(visual_data.get("is_guard_kind", false))
	var eye_alpha_scale: float = float(visual_data.get("eye_alpha_scale", 0.5))

	var eye_color: Color = Color(base_color.r, base_color.g, base_color.b, base_color.a * eye_alpha_scale)
	var outer_color: Color = eye_color
	if is_guard_kind:
		outer_color = Color(0.62, 0.66, 0.72, 0.26 + pulse * 0.08)
	else:
		outer_color.a = maxf(0.18, outer_color.a * 0.46)

	var left_eye: Vector2 = Vector2(-11.0, -34.0)
	var right_eye: Vector2 = Vector2(11.0, -34.0)
	var eye_radius: float = 7.0 + pulse * 1.1
	draw_circle(left_eye, eye_radius, outer_color)
	draw_circle(right_eye, eye_radius, outer_color)
	draw_rect(Rect2(left_eye + Vector2(-5.0, -2.0), Vector2(10.0, 4.0)), eye_color)
	draw_rect(Rect2(right_eye + Vector2(-5.0, -2.0), Vector2(10.0, 4.0)), eye_color)

	var glow_alpha: float = 0.18 + pulse * 0.10
	var core_alpha: float = 0.52 + pulse * 0.20
	if effective_state == 3:
		glow_alpha += 0.10
		core_alpha += 0.12
	elif effective_state == 5:
		glow_alpha += 0.16
		core_alpha += 0.16

	var glow_color: Color = Color(base_color.r, base_color.g, base_color.b, glow_alpha)
	var core_color: Color = Color(base_color.r, base_color.g, base_color.b, core_alpha)
	if is_guard_kind:
		glow_color = Color(0.62, 0.66, 0.72, glow_alpha)
		core_color = Color(0.18, 0.18, 0.18, core_alpha)

	var face_center: Vector2 = Vector2(0.0, -30.0)
	var ring_radius_x: float = 23.0 + pulse * 1.6
	var ring_radius_y: float = 18.0 + pulse * 1.1

	var forehead_glow: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -49.0 - pulse * 1.5),
		Vector2(12.0 + pulse, -36.0),
		Vector2(0.0, -20.0 + pulse * 0.6),
		Vector2(-12.0 - pulse, -36.0),
	])
	draw_colored_polygon(forehead_glow, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.72))

	var forehead_core: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -45.0),
		Vector2(7.0, -36.0),
		Vector2(0.0, -26.0),
		Vector2(-7.0, -36.0),
	])
	draw_colored_polygon(forehead_core, core_color)

	var left_chevron: PackedVector2Array = PackedVector2Array([
		Vector2(-24.0, -36.0),
		Vector2(-15.0, -39.0),
		Vector2(-8.0, -34.0),
		Vector2(-15.0, -29.0),
	])
	var right_chevron: PackedVector2Array = PackedVector2Array([
		Vector2(24.0, -36.0),
		Vector2(15.0, -39.0),
		Vector2(8.0, -34.0),
		Vector2(15.0, -29.0),
	])
	draw_colored_polygon(left_chevron, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.86))
	draw_colored_polygon(right_chevron, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.86))

	if effective_state == 3 or effective_state == 4 or effective_state == 5:
		var ring_color: Color = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.92)
		draw_arc(face_center, ring_radius_x, PI * 0.16, PI * 0.84, 18, ring_color, 2.0)
		draw_arc(face_center, ring_radius_x, PI * 1.16, PI * 1.84, 18, ring_color, 2.0)
		draw_arc(face_center, ring_radius_y, -PI * 0.38, PI * 0.38, 14, ring_color, 1.6)

	if effective_state == 5:
		var spike_len: float = 10.0 + pulse * 2.4
		draw_line(Vector2(-18.0, -18.0), Vector2(-18.0, -18.0 - spike_len), Color(core_color.r, core_color.g, core_color.b, 0.74), 2.0)
		draw_line(Vector2(18.0, -18.0), Vector2(18.0, -18.0 - spike_len), Color(core_color.r, core_color.g, core_color.b, 0.74), 2.0)
		draw_line(Vector2(0.0, -14.0), Vector2(0.0, -14.0 - spike_len * 0.82), Color(core_color.r, core_color.g, core_color.b, 0.74), 2.0)
