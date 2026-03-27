@tool
extends Node2D

@export var duration_sec: float = 0.24
@export var start_scale: float = 0.82
@export var end_scale: float = 1.06
@export var sweep_distance: float = 18.0
@export var fade_in_ratio: float = 0.18
@export var fade_out_ratio: float = 0.42

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _time_left: float = 0.0
var _base_position: Vector2 = Vector2.ZERO
var _travel_direction: Vector2 = Vector2.RIGHT
var _configured_scale: float = 1.0


func _ready() -> void:
	set_process(true)
	z_index = 50
	_restart()


func _process(delta: float) -> void:
	if duration_sec <= 0.0:
		queue_free()
		return

	_time_left = maxf(0.0, _time_left - delta)
	var t: float = 1.0 - (_time_left / duration_sec)
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var scale_value: float = lerpf(start_scale, end_scale, eased) * _configured_scale
	scale = Vector2.ONE * scale_value
	position = _base_position + (_travel_direction * sweep_distance * eased)

	var alpha: float = _compute_alpha(t)
	modulate = Color(1.0, 1.0, 1.0, alpha)

	if _time_left <= 0.0:
		queue_free()


func configure(local_position: Vector2, angle_degrees_value: float, effect_scale: float = 1.0, duration_value: float = -1.0, travel_value: float = -1.0) -> void:
	position = local_position
	_base_position = local_position
	rotation_degrees = angle_degrees_value
	_configured_scale = maxf(0.01, effect_scale)
	if duration_value > 0.0:
		duration_sec = duration_value
	if travel_value >= 0.0:
		sweep_distance = travel_value
	_travel_direction = Vector2.RIGHT.rotated(deg_to_rad(angle_degrees_value))
	_restart()


func _restart() -> void:
	_time_left = duration_sec
	_base_position = position
	scale = Vector2.ONE * (start_scale * _configured_scale)
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	if animated_sprite != null:
		animated_sprite.play(&"slash")
		animated_sprite.speed_scale = _compute_speed_scale()


func _compute_speed_scale() -> float:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return 1.0
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if not frames.has_animation(&"slash"):
		return 1.0
	var frame_count: int = frames.get_frame_count(&"slash")
	var animation_speed: float = frames.get_animation_speed(&"slash")
	if frame_count <= 0 or animation_speed <= 0.0 or duration_sec <= 0.0:
		return 1.0
	var base_duration: float = float(frame_count) / animation_speed
	return maxf(0.01, base_duration / duration_sec)


func _compute_alpha(t: float) -> float:
	var clamped_t: float = clampf(t, 0.0, 1.0)
	var fade_in_end: float = clampf(fade_in_ratio, 0.01, 0.49)
	var fade_out_start: float = clampf(1.0 - fade_out_ratio, fade_in_end + 0.01, 0.99)
	if clamped_t < fade_in_end:
		return clampf(clamped_t / fade_in_end, 0.0, 1.0)
	if clamped_t > fade_out_start:
		return clampf((1.0 - clamped_t) / (1.0 - fade_out_start), 0.0, 1.0)
	return 1.0
