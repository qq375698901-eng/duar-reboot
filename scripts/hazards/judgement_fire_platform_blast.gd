extends Node2D
class_name JudgementFirePlatformBlast

signal blast_finished(blast: JudgementFirePlatformBlast)

const ENEMY_COLLISION_GROUP := &"enemy_bodies"

@export var blast_duration_sec: float = 0.28
@export var blast_height_above_surface_px: float = 88.0
@export var blast_depth_below_surface_px: float = 10.0
@export var glow_color: Color = Color(1.0, 0.50, 0.18, 0.34)
@export var core_color: Color = Color(1.0, 0.88, 0.62, 0.92)
@export var ember_color: Color = Color(1.0, 0.62, 0.22, 0.60)

@onready var hit_area: Area2D = $HitArea
@onready var collision_shape: CollisionShape2D = $HitArea/CollisionShape2D

var owner_body: Node
var attack_payload: Dictionary = {}
var blast_width: float = 0.0
var _time_left: float = 0.0
var _hit_targets: Dictionary = {}


func _ready() -> void:
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	hit_area.monitoring = false
	hit_area.monitorable = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	if _time_left <= 0.0:
		return

	_time_left = maxf(0.0, _time_left - delta)
	if _time_left <= 0.0:
		_finish_blast()
	queue_redraw()


func configure(owner_node: Node, payload: Dictionary, surface_span: Dictionary) -> void:
	owner_body = owner_node
	attack_payload = payload.duplicate(true)
	var x_min: float = float(surface_span.get("x_min", 0.0))
	var x_max: float = float(surface_span.get("x_max", 0.0))
	var y_value: float = float(surface_span.get("y", 0.0))
	global_position = Vector2((x_min + x_max) * 0.5, y_value)
	blast_width = maxf(28.0, x_max - x_min)
	_configure_hit_shape()
	call_deferred("_activate_blast")


func _configure_hit_shape() -> void:
	if collision_shape == null:
		return
	if collision_shape.shape is not RectangleShape2D:
		return

	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	var total_height: float = blast_height_above_surface_px + blast_depth_below_surface_px
	rect_shape.size = Vector2(blast_width, total_height)
	collision_shape.position = Vector2(0.0, (-blast_height_above_surface_px + blast_depth_below_surface_px) * 0.5)


func _activate_blast() -> void:
	_time_left = blast_duration_sec
	_hit_targets.clear()
	hit_area.set_deferred("monitoring", true)
	hit_area.set_deferred("monitorable", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	call_deferred("_emit_existing_overlaps")
	queue_redraw()


func _finish_blast() -> void:
	_time_left = 0.0
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitorable", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	queue_redraw()
	blast_finished.emit(self)
	queue_free()


func _emit_existing_overlaps() -> void:
	if _time_left <= 0.0:
		return
	for body in hit_area.get_overlapping_bodies():
		_try_hit_body(body)


func _on_hit_area_body_entered(body: Node) -> void:
	_try_hit_body(body)


func _try_hit_body(body: Node) -> void:
	if _time_left <= 0.0:
		return
	if not _is_valid_damage_target(body):
		return

	var body_id: int = body.get_instance_id()
	if _hit_targets.has(body_id):
		return
	_hit_targets[body_id] = true
	call_deferred("_deliver_hit_deferred", body, attack_payload.duplicate(true))


func _deliver_hit_deferred(body: Node, payload: Dictionary) -> void:
	if not _is_valid_damage_target(body):
		return

	if body.has_method("receive_weapon_hit"):
		body.call("receive_weapon_hit", payload, self)
		return

	var target_x: float = global_position.x
	if body is Node2D:
		target_x = (body as Node2D).global_position.x
	var source_is_on_left: bool = global_position.x < target_x
	if String(payload.get("hit_effect", "stun")) == "launch":
		if body.has_method("apply_launch_by_distance_from_source"):
			body.call(
				"apply_launch_by_distance_from_source",
				source_is_on_left,
				payload.get("launch_height_px", 0.0),
				payload.get("launch_distance_px", 0.0)
			)
	elif body.has_method("apply_stun_from_source"):
		body.call(
			"apply_stun_from_source",
			source_is_on_left,
			payload.get("stun_duration_sec", 0.0)
		)


func _is_valid_damage_target(body: Node) -> bool:
	if body == null:
		return false
	if not is_instance_valid(body):
		return false
	if body == owner_body:
		return false
	if body.is_in_group(ENEMY_COLLISION_GROUP):
		return false
	if body.has_method("is_dead") and body.call("is_dead"):
		return false
	return true


func _draw() -> void:
	if _time_left <= 0.0:
		return

	var progress: float = 1.0
	if blast_duration_sec > 0.0:
		progress = clampf(1.0 - (_time_left / blast_duration_sec), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * 18.0)
	var height_scale: float = 0.72 + progress * 0.28
	var plume_height: float = blast_height_above_surface_px * height_scale
	var half_width: float = blast_width * 0.5

	var glow_points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_width * 0.62, 2.0),
		Vector2(-half_width * 0.48, -plume_height * 0.42),
		Vector2(-half_width * 0.16, -plume_height * (0.82 + pulse * 0.06)),
		Vector2(0.0, -plume_height),
		Vector2(half_width * 0.16, -plume_height * (0.80 + pulse * 0.06)),
		Vector2(half_width * 0.46, -plume_height * 0.44),
		Vector2(half_width * 0.64, 2.0),
		Vector2(0.0, blast_depth_below_surface_px * 0.55),
	])
	draw_colored_polygon(glow_points, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * (0.88 - progress * 0.28)))

	var core_points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_width * 0.30, 0.0),
		Vector2(-half_width * 0.18, -plume_height * 0.34),
		Vector2(-half_width * 0.06, -plume_height * 0.70),
		Vector2(0.0, -plume_height * 0.84),
		Vector2(half_width * 0.07, -plume_height * 0.68),
		Vector2(half_width * 0.20, -plume_height * 0.32),
		Vector2(half_width * 0.32, 0.0),
		Vector2(0.0, blast_depth_below_surface_px * 0.18),
	])
	draw_colored_polygon(core_points, Color(core_color.r, core_color.g, core_color.b, core_color.a * (0.94 - progress * 0.24)))

	for ember_index in range(4):
		var ember_offset_x: float = lerpf(-half_width * 0.42, half_width * 0.42, float(ember_index) / 3.0)
		var ember_height: float = plume_height * (0.26 + 0.12 * float(ember_index % 2))
		draw_circle(
			Vector2(ember_offset_x, -ember_height - pulse * 3.0),
			2.5 + pulse * 0.6,
			Color(ember_color.r, ember_color.g, ember_color.b, ember_color.a * (0.70 - progress * 0.22))
		)

	draw_line(
		Vector2(-half_width * 0.56, 0.0),
		Vector2(half_width * 0.56, 0.0),
		Color(core_color.r, core_color.g, core_color.b, 0.58),
		3.0
	)
