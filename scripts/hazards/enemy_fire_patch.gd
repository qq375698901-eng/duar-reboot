extends Area2D

signal fire_patch_expired()

const ENEMY_COLLISION_GROUP := &"enemy_bodies"

@export var lifetime_sec: float = 10.0
@export var tick_interval_sec: float = 0.42
@export var fade_out_duration_sec: float = 0.35
@export var base_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var owner_body: Node
var attack_data: Dictionary = {}
var _lifetime_left := 0.0
var _body_cooldowns: Dictionary = {}
var _starting_scale := Vector2.ONE


func _ready() -> void:
	_lifetime_left = lifetime_sec
	_starting_scale = scale
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	_lifetime_left = maxf(0.0, _lifetime_left - delta)
	_update_visuals()
	_tick_overlapping_bodies(delta)

	if _lifetime_left <= 0.0:
		fire_patch_expired.emit()
		queue_free()


func configure(owner_node: Node, payload: Dictionary = {}, duration_sec: float = -1.0, interval_sec: float = -1.0) -> void:
	owner_body = owner_node
	attack_data = payload.duplicate(true)
	if duration_sec > 0.0:
		lifetime_sec = duration_sec
	if interval_sec > 0.0:
		tick_interval_sec = interval_sec
	_lifetime_left = lifetime_sec


func _on_body_entered(body: Node) -> void:
	if not _is_valid_damage_target(body):
		return

	var body_id := body.get_instance_id()
	_body_cooldowns[body_id] = tick_interval_sec
	_apply_hit_deferred(body)


func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	_body_cooldowns.erase(body.get_instance_id())


func _tick_overlapping_bodies(delta: float) -> void:
	var to_remove: Array[int] = []
	for key in _body_cooldowns.keys():
		var body_id := int(key)
		var body := instance_from_id(body_id) as Node
		if body == null or not is_instance_valid(body):
			to_remove.append(body_id)
			continue
		if not _is_valid_damage_target(body):
			to_remove.append(body_id)
			continue

		var next_cd := float(_body_cooldowns[body_id]) - delta
		if next_cd <= 0.0:
			next_cd = tick_interval_sec
			_apply_hit_deferred(body)
		_body_cooldowns[body_id] = next_cd

	for body_id in to_remove:
		_body_cooldowns.erase(body_id)


func _apply_hit_deferred(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	call_deferred("_deliver_hit_deferred", body, attack_data.duplicate(true))


func _deliver_hit_deferred(body: Node, payload: Dictionary) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if not _is_valid_damage_target(body):
		return

	if body.has_method("receive_weapon_hit"):
		body.call("receive_weapon_hit", payload, self)
		return

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


func _update_visuals() -> void:
	var alpha := 1.0
	if fade_out_duration_sec > 0.0 and _lifetime_left < fade_out_duration_sec:
		alpha = _lifetime_left / fade_out_duration_sec
	modulate = Color(base_color.r, base_color.g, base_color.b, alpha)
	var pulse := 1.0 + (0.06 * sin((lifetime_sec - _lifetime_left) * 12.0))
	scale = _starting_scale * pulse
