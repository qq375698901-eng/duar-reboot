extends Area2D

signal projectile_hit(target: Node, attack_data: Dictionary)
signal projectile_expired()
signal projectile_exploded(position: Vector2)

const WORLD_LAYER := 1
const PLATFORM_LAYER := 3
const ENEMY_COLLISION_GROUP := &"enemy_bodies"

@export var gravity_force: float = 980.0
@export var lifetime_sec: float = 1.35
@export var min_flight_time_sec: float = 0.36
@export var max_flight_time_sec: float = 0.72
@export var target_speed_hint: float = 220.0
@export var destroy_on_hit: bool = true
@export var impact_damage_scale: float = 0.6
@export var fire_patch_scene: PackedScene
@export var fire_patch_duration_sec: float = 10.0
@export var fire_patch_tick_interval_sec: float = 0.42
@export var fire_patch_damage_scale: float = 0.5
@export var fire_patch_stun_duration_sec: float = 0.08

var attack_data: Dictionary = {}
var owner_body: Node
var velocity := Vector2.ZERO
var _lifetime_left := 0.0
var _is_resolving_hit := false
var _exploded := false


func _ready() -> void:
	_lifetime_left = lifetime_sec
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _exploded or _is_resolving_hit:
		return

	var start_position := global_position
	var next_position := global_position + (velocity * delta)
	var terrain_hit := _intersect_terrain(start_position, next_position)
	if not terrain_hit.is_empty():
		global_position = terrain_hit.position
		_explode()
		return

	global_position = next_position
	velocity.y += gravity_force * delta
	if velocity.length_squared() > 0.01:
		rotation = velocity.angle()

	_lifetime_left = maxf(0.0, _lifetime_left - delta)
	if _lifetime_left <= 0.0:
		_explode()


func launch_to(target_position: Vector2, payload: Dictionary = {}, owner_node: Node = null) -> void:
	attack_data = payload.duplicate(true)
	owner_body = owner_node

	var delta := target_position - global_position
	var distance := delta.length()
	var flight_time := clampf(distance / maxf(target_speed_hint, 1.0), min_flight_time_sec, max_flight_time_sec)
	velocity.x = delta.x / flight_time
	velocity.y = (delta.y - (0.5 * gravity_force * flight_time * flight_time)) / flight_time
	if velocity.length_squared() > 0.01:
		rotation = velocity.angle()


func configure(owner_node: Node, payload: Dictionary = {}) -> void:
	owner_body = owner_node
	attack_data = payload.duplicate(true)


func _on_body_entered(body: Node) -> void:
	if body == null or _exploded or _is_resolving_hit:
		return
	if body == owner_body:
		return
	if body.is_in_group(ENEMY_COLLISION_GROUP):
		return

	_is_resolving_hit = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)

	var payload := _build_impact_payload()
	call_deferred("_resolve_hit_deferred", body, payload)


func _resolve_hit_deferred(body: Node, payload: Dictionary) -> void:
	if body != null and is_instance_valid(body) and body != owner_body and not body.is_in_group(ENEMY_COLLISION_GROUP):
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
		_explode()
	else:
		_is_resolving_hit = false


func _build_impact_payload() -> Dictionary:
	var payload := attack_data.duplicate(true)
	payload["damage"] = maxf(1.0, float(attack_data.get("damage", 0.0)) * impact_damage_scale)
	return payload


func _spawn_fire_patch() -> void:
	if fire_patch_scene == null:
		return

	var patch := fire_patch_scene.instantiate()
	if patch == null:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		current_scene = self
	current_scene.add_child(patch)

	if patch is Node2D:
		(patch as Node2D).global_position = global_position

	var patch_payload := attack_data.duplicate(true)
	patch_payload["damage"] = maxf(1.0, float(attack_data.get("damage", 0.0)) * fire_patch_damage_scale)
	patch_payload["hit_effect"] = "stun"
	patch_payload["stun_duration_sec"] = fire_patch_stun_duration_sec
	if patch.has_method("configure"):
		patch.call(
			"configure",
			owner_body,
			patch_payload,
			fire_patch_duration_sec,
			fire_patch_tick_interval_sec
		)


func _explode() -> void:
	if _exploded:
		return

	_exploded = true
	projectile_exploded.emit(global_position)
	_spawn_fire_patch()
	projectile_expired.emit()
	queue_free()


func _intersect_terrain(from: Vector2, to: Vector2) -> Dictionary:
	if from.distance_squared_to(to) <= 0.0001:
		return {}

	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = _layer_bit(WORLD_LAYER) | _layer_bit(PLATFORM_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excludes: Array[RID] = [get_rid()]
	if owner_body is CollisionObject2D:
		excludes.append((owner_body as CollisionObject2D).get_rid())
	query.exclude = excludes
	return get_world_2d().direct_space_state.intersect_ray(query)


func _layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)
