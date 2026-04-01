extends Area2D
class_name EnemyAttackHitbox2D

signal target_hit(target: Node, attack_id: StringName, attack_data: Dictionary)

const ENEMY_COLLISION_GROUP := &"enemy_bodies"

@export var attack_id: StringName = &"attack"
@export var show_debug_shape := true
@export_enum("rect", "slash") var debug_visual_style: String = "rect"
@export var debug_active_color: Color = Color(1.0, 0.28, 0.12, 0.4)
@export var debug_outline_color: Color = Color(1.0, 0.52, 0.35, 0.95)
@export var debug_glow_color: Color = Color(1.0, 0.28, 0.12, 0.12)
@export var debug_highlight_color: Color = Color(1.0, 0.92, 0.88, 0.22)
@export var debug_glow_expand: float = 8.0
@export var debug_pulse_speed: float = 6.0
@export var debug_corner_length: float = 7.0
@export var debug_slash_angle_degrees: float = 12.0
@export var debug_slash_length_scale: float = 1.25
@export var debug_slash_thickness_scale: float = 0.72

var _active := false
var _owner_body: Node
var _attack_data: Dictionary = {}
var _hit_targets: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = false
	monitorable = false
	set_process(true)
	_set_collision_shapes_enabled(false)
	queue_redraw()


func _process(_delta: float) -> void:
	if _active and show_debug_shape:
		queue_redraw()


func _physics_process(_delta: float) -> void:
	if not _active:
		return

	_emit_existing_overlaps()


func configure(owner_body: Node, attack_data: Dictionary) -> void:
	_owner_body = owner_body
	set_attack_data(attack_data)


func set_attack_data(attack_data: Dictionary) -> void:
	_attack_data = attack_data.duplicate(true)


func set_debug_slash_style(angle_degrees_value: float, length_scale: float = 1.25, thickness_scale: float = 0.72) -> void:
	debug_visual_style = "slash"
	debug_slash_angle_degrees = angle_degrees_value
	debug_slash_length_scale = maxf(0.1, length_scale)
	debug_slash_thickness_scale = maxf(0.1, thickness_scale)
	queue_redraw()


func set_active(enabled: bool) -> void:
	_active = enabled
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)
	_set_collision_shapes_enabled(enabled)
	queue_redraw()
	if enabled:
		call_deferred("_emit_existing_overlaps")


func reset_hit_memory() -> void:
	_hit_targets.clear()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	if not _owner_can_deal_damage():
		return
	if body == null:
		return
	if body == _owner_body:
		return
	if _is_friendly_enemy_target(body):
		return
	if _hit_targets.has(body.get_instance_id()):
		return

	_queue_target_hit(body)


func _emit_existing_overlaps() -> void:
	if not _active:
		return
	if not _owner_can_deal_damage():
		return

	for body in get_overlapping_bodies():
		if body == null:
			continue
		if body == _owner_body:
			continue
		if _is_friendly_enemy_target(body):
			continue
		if _hit_targets.has(body.get_instance_id()):
			continue

		_queue_target_hit(body)


func _queue_target_hit(body: Node) -> void:
	if body == null:
		return
	if not _owner_can_deal_damage():
		return
	if _is_friendly_enemy_target(body):
		return

	_hit_targets[body.get_instance_id()] = true
	var payload := _attack_data.duplicate(true)
	call_deferred("_emit_target_hit_deferred", body, attack_id, payload)


func _emit_target_hit_deferred(body: Node, resolved_attack_id: StringName, attack_data: Dictionary) -> void:
	if body == null:
		return
	if not is_instance_valid(body):
		return
	if body == _owner_body:
		return
	if not _owner_can_deal_damage():
		return
	if _is_friendly_enemy_target(body):
		return

	target_hit.emit(body, resolved_attack_id, attack_data)


func _owner_can_deal_damage() -> bool:
	if _owner_body == null:
		return false
	if not is_instance_valid(_owner_body):
		return false
	if _owner_body.has_method("is_attack_disabled") and bool(_owner_body.call("is_attack_disabled")):
		return false
	if _owner_body.has_method("is_dead") and bool(_owner_body.call("is_dead")):
		return false
	return true


func _is_friendly_enemy_target(body: Node) -> bool:
	if body == null:
		return false
	return body.is_in_group(ENEMY_COLLISION_GROUP)


func _draw() -> void:
	if not show_debug_shape:
		return
	if not _active:
		return

	for child in get_children():
		if child is not CollisionShape2D:
			continue

		var collision_shape := child as CollisionShape2D
		if collision_shape.shape == null:
			continue

		if collision_shape.shape is RectangleShape2D:
			var rect_shape := collision_shape.shape as RectangleShape2D
			var rect := Rect2(
				collision_shape.position - rect_shape.size * 0.5,
				rect_shape.size
			)
			if debug_visual_style == "slash":
				_draw_debug_slash_effect(rect)
			else:
				_draw_debug_rect_effect(rect)
		elif collision_shape.shape is CircleShape2D:
			var circle_shape := collision_shape.shape as CircleShape2D
			_draw_debug_circle_effect(collision_shape.position, circle_shape.radius)


func _set_collision_shapes_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not enabled)


func _draw_debug_rect_effect(rect: Rect2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * debug_pulse_speed)
	var glow_expand_large: float = debug_glow_expand * (0.9 + pulse * 0.25)
	var glow_expand_mid: float = debug_glow_expand * 0.55
	var glow_expand_small: float = debug_glow_expand * 0.25

	var glow_large: Rect2 = rect.grow(glow_expand_large)
	var glow_mid: Rect2 = rect.grow(glow_expand_mid)
	var glow_small: Rect2 = rect.grow(glow_expand_small)

	var outer_glow: Color = debug_glow_color
	outer_glow.a *= 0.55 + pulse * 0.25
	draw_rect(glow_large, outer_glow, true)

	var mid_glow: Color = debug_glow_color.lerp(debug_highlight_color, 0.28)
	mid_glow.a *= 0.42 + pulse * 0.18
	draw_rect(glow_mid, mid_glow, true)

	var inner_fill: Color = debug_active_color.lerp(debug_highlight_color, 0.24 + pulse * 0.2)
	draw_rect(glow_small, inner_fill, true)
	draw_rect(rect, debug_active_color, true)

	var border_color: Color = debug_outline_color.lerp(debug_highlight_color, pulse * 0.35)
	draw_rect(rect, border_color, false, 1.5)
	draw_rect(rect.grow(1.0), border_color.darkened(0.18), false, 1.0)

	var center_line_color: Color = debug_highlight_color
	center_line_color.a *= 0.65 + pulse * 0.25
	var center_y: float = rect.position.y + rect.size.y * 0.5
	draw_line(
		Vector2(rect.position.x + 4.0, center_y),
		Vector2(rect.end.x - 4.0, center_y),
		center_line_color,
		1.4
	)

	_draw_rect_corners(rect, border_color)


func _draw_rect_corners(rect: Rect2, color: Color) -> void:
	var corner_len: float = minf(debug_corner_length, minf(rect.size.x, rect.size.y) * 0.45)
	var top_left: Vector2 = rect.position
	var top_right: Vector2 = Vector2(rect.end.x, rect.position.y)
	var bottom_left: Vector2 = Vector2(rect.position.x, rect.end.y)
	var bottom_right: Vector2 = rect.end

	draw_line(top_left, top_left + Vector2(corner_len, 0.0), color, 1.6)
	draw_line(top_left, top_left + Vector2(0.0, corner_len), color, 1.6)
	draw_line(top_right, top_right + Vector2(-corner_len, 0.0), color, 1.6)
	draw_line(top_right, top_right + Vector2(0.0, corner_len), color, 1.6)
	draw_line(bottom_left, bottom_left + Vector2(corner_len, 0.0), color, 1.6)
	draw_line(bottom_left, bottom_left + Vector2(0.0, -corner_len), color, 1.6)
	draw_line(bottom_right, bottom_right + Vector2(-corner_len, 0.0), color, 1.6)
	draw_line(bottom_right, bottom_right + Vector2(0.0, -corner_len), color, 1.6)


func _draw_debug_circle_effect(center: Vector2, radius: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * debug_pulse_speed)
	var glow_color: Color = debug_glow_color
	glow_color.a *= 0.55 + pulse * 0.2
	draw_circle(center, radius + debug_glow_expand * (0.7 + pulse * 0.18), glow_color)

	var mid_color: Color = debug_active_color.lerp(debug_highlight_color, 0.18 + pulse * 0.18)
	draw_circle(center, radius + debug_glow_expand * 0.2, mid_color)
	draw_circle(center, radius, debug_active_color)

	var border_color: Color = debug_outline_color.lerp(debug_highlight_color, pulse * 0.35)
	draw_arc(center, radius, 0.0, TAU, 32, border_color, 1.5)


func _draw_debug_slash_effect(rect: Rect2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * debug_pulse_speed)
	var center: Vector2 = rect.position + rect.size * 0.5
	var angle_rad: float = deg_to_rad(debug_slash_angle_degrees)
	var direction: Vector2 = Vector2.RIGHT.rotated(angle_rad)
	var normal: Vector2 = Vector2(-direction.y, direction.x)

	var length_value: float = maxf(rect.size.x, rect.size.y) * debug_slash_length_scale
	var thickness_value: float = minf(rect.size.x, rect.size.y) * debug_slash_thickness_scale
	var tail_half: float = thickness_value * 0.18
	var body_half: float = thickness_value * (0.42 + pulse * 0.06)
	var tip_half: float = thickness_value * 0.10

	var start: Vector2 = center - direction * (length_value * 0.5)
	var mid: Vector2 = center + direction * (length_value * 0.02)
	var end: Vector2 = center + direction * (length_value * 0.42)
	var tip: Vector2 = center + direction * (length_value * 0.62)

	_draw_slash_layer(start, mid, end, tip, normal, tail_half + debug_glow_expand * 0.24, body_half + debug_glow_expand * 0.36, tip_half + debug_glow_expand * 0.16, _scale_alpha(debug_glow_color, 0.58 + pulse * 0.2))
	_draw_slash_layer(start, mid, end, tip, normal, tail_half + debug_glow_expand * 0.12, body_half + debug_glow_expand * 0.18, tip_half + debug_glow_expand * 0.08, _scale_alpha(debug_glow_color.lerp(debug_highlight_color, 0.18), 0.48 + pulse * 0.16))
	_draw_slash_layer(start, mid, end, tip, normal, tail_half, body_half, tip_half, debug_active_color.lerp(debug_highlight_color, 0.18 + pulse * 0.16))
	_draw_slash_layer(start + direction * 6.0, mid + direction * 6.0, end + direction * 6.0, tip + direction * 5.0, normal, tail_half * 0.36, body_half * 0.42, tip_half * 0.28, _scale_alpha(debug_highlight_color, 0.62 + pulse * 0.22))

	draw_line(start + direction * 10.0, end, _scale_alpha(debug_highlight_color, 0.32 + pulse * 0.16), 1.4)


func _draw_slash_layer(start: Vector2, mid: Vector2, end: Vector2, tip: Vector2, normal: Vector2, tail_half: float, body_half: float, tip_half: float, color: Color) -> void:
	var polygon: PackedVector2Array = PackedVector2Array([
		start + normal * tail_half,
		mid + normal * body_half,
		end + normal * tip_half,
		tip,
		end - normal * tip_half,
		mid - normal * body_half,
		start - normal * tail_half,
	])
	draw_colored_polygon(polygon, color)


func _scale_alpha(color: Color, multiplier: float) -> Color:
	var scaled: Color = color
	scaled.a *= multiplier
	return scaled
