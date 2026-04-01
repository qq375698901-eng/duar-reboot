extends Area2D

signal projectile_hit(target: Node, attack_data: Dictionary)
signal projectile_expired()

@export var speed: float = 240.0
@export var lifetime_sec: float = 1.2
@export var travel_direction: Vector2 = Vector2.RIGHT
@export var destroy_on_hit: bool = true

var attack_data: Dictionary = {}
var owner_body: Node
var _lifetime_left := 0.0
var _is_resolving_hit := false


func _ready() -> void:
	_lifetime_left = lifetime_sec
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _is_resolving_hit:
		return

	global_position += travel_direction.normalized() * speed * delta
	_lifetime_left = maxf(0.0, _lifetime_left - delta)
	if _lifetime_left <= 0.0:
		_expire()


func launch(direction: Vector2, payload: Dictionary = {}, owner_node: Node = null) -> void:
	if direction.length_squared() > 0.0:
		travel_direction = direction.normalized()
	rotation = travel_direction.angle()
	attack_data = payload.duplicate(true)
	owner_body = owner_node


func configure(owner_node: Node, payload: Dictionary = {}) -> void:
	owner_body = owner_node
	attack_data = payload.duplicate(true)


func _on_body_entered(body: Node) -> void:
	if body == null or _is_resolving_hit:
		return
	if body == owner_body:
		return

	_is_resolving_hit = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)

	var payload := attack_data.duplicate(true)
	call_deferred("_resolve_hit_deferred", body, payload)


func _resolve_hit_deferred(body: Node, payload: Dictionary) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		_expire()
		return
	if body != null and is_instance_valid(body) and body != owner_body:
		projectile_hit.emit(body, payload)
		if body.has_method("receive_weapon_hit"):
			body.call("receive_weapon_hit", payload.duplicate(true), self)
		else:
			var target_x := global_position.x
			if body is Node2D:
				target_x = (body as Node2D).global_position.x
			var source_is_on_left := global_position.x < target_x
			match String(payload.get("hit_effect", "stun")):
				"launch":
					if body.has_method("apply_launch_by_distance_from_source"):
						body.call(
							"apply_launch_by_distance_from_source",
							source_is_on_left,
							payload.get("launch_height_px", 0.0),
							payload.get("launch_distance_px", 0.0)
						)
				_:
					if body.has_method("apply_stun_from_source"):
						body.call(
							"apply_stun_from_source",
							source_is_on_left,
							payload.get("stun_duration_sec", 0.0)
						)

	if destroy_on_hit:
		_expire()
	else:
		_is_resolving_hit = false


func _expire() -> void:
	projectile_expired.emit()
	queue_free()
