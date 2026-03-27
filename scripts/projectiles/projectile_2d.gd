extends Area2D
class_name Projectile2D

signal projectile_hit(target: Node, attack_data: Dictionary)
signal projectile_expired()

@export var speed: float = 260.0
@export var lifetime_sec: float = 0.9
@export var travel_direction: Vector2 = Vector2.RIGHT
@export var destroy_on_hit: bool = true
@export var impact_animation_name: StringName = &"hit"

var attack_data: Dictionary = {}
var _lifetime_left := 0.0
var _is_impacting := false
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	_lifetime_left = lifetime_sec
	body_entered.connect(_on_body_entered)
	if animated_sprite != null and not animated_sprite.animation_finished.is_connected(_on_animated_sprite_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_finished)


func _physics_process(delta: float) -> void:
	if _is_impacting:
		return
	global_position += travel_direction.normalized() * speed * delta
	_lifetime_left = maxf(0.0, _lifetime_left - delta)
	if _lifetime_left <= 0.0:
		projectile_expired.emit()
		queue_free()


func launch(direction: Vector2, payload: Dictionary = {}) -> void:
	if direction.length_squared() > 0.0:
		travel_direction = direction.normalized()
	rotation = travel_direction.angle()
	attack_data = payload.duplicate(true)


func set_attack_data(payload: Dictionary) -> void:
	attack_data = payload.duplicate(true)


func _on_body_entered(body: Node) -> void:
	if body == null or _is_impacting:
		return

	projectile_hit.emit(body, attack_data)
	if body.has_method("receive_weapon_hit"):
		body.call("receive_weapon_hit", attack_data.duplicate(true), self)

	if destroy_on_hit:
		if not _begin_impact():
			queue_free()


func _begin_impact() -> bool:
	if animated_sprite == null:
		return false
	if impact_animation_name == &"":
		return false
	if not animated_sprite.sprite_frames.has_animation(impact_animation_name):
		return false

	_is_impacting = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
	animated_sprite.play(impact_animation_name)
	return true


func _on_animated_sprite_finished() -> void:
	if not _is_impacting:
		return
	if animated_sprite == null:
		return
	if animated_sprite.animation != impact_animation_name:
		return

	projectile_expired.emit()
	queue_free()
