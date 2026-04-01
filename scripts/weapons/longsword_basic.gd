extends Node2D

const SWORD_WAVE_PROJECTILE_SCENE := preload("res://scenes/projectiles/sword_wave_projectile.tscn")

signal attack_motion_requested(distance_px: float, direction_mode: int, duration_sec: float)
signal attack_state_changed(active: bool)
signal startup_hold_requested(duration_sec: float)
signal attack_hit_registered(target: Node, attack_id: StringName)
signal buff_visual_state_changed(active: bool)
signal super_armor_state_changed(active: bool)

enum AttackMotionDirection {
	NONE = 0,
	FORWARD = 1,
	BACKWARD = -1,
}

enum AttackPhase {
	NONE,
	STARTUP,
	ACTIVE,
	RECOVERY,
}

const ATTACK_DEFINITIONS := {
	"light_attack_c_1": {
		"active_start_sec": 0.15,
		"active_end_sec": 0.24,
		"hit_effect": "stun",
		"stun_duration_sec": 0.22,
	},
	"light_attack_c_2": {
		"active_start_sec": 0.0,
		"active_end_sec": 0.18,
		"hit_effect": "stun",
		"stun_duration_sec": 0.22,
	},
	"light_attack_c_3": {
		"active_start_sec": 0.19,
		"active_end_sec": 0.29,
		"hit_effect": "launch",
		"launch_height_px": 14.0,
		"launch_distance_px": 42.0,
	},
	"heavy_attack_x_1": {
		"active_start_sec": 0.24,
		"active_end_sec": 0.35,
		"hit_effect": "stun",
		"stun_duration_sec": 0.22,
	},
	"heavy_attack_x_2": {
		"active_start_sec": 0.18,
		"active_end_sec": 0.35,
		"hit_effect": "launch",
		"launch_height_px": 112.0,
		"launch_distance_px": 28.0,
	},
	"run_light_attack_c": {
		"active_start_sec": 0.14,
		"active_end_sec": 0.20,
		"hit_effect": "launch",
		"launch_height_px": 14.0,
		"launch_distance_px": 42.0,
	},
	"run_heavy_attack_x": {
		"active_start_sec": 0.24,
		"active_end_sec": 0.36,
		"hit_effect": "launch",
		"launch_height_px": 112.0,
		"launch_distance_px": 28.0,
	},
	"air_light_attack_c": {
		"active_start_sec": 0.16,
		"active_end_sec": 0.25,
		"hit_effect": "launch",
		"launch_height_px": 14.0,
		"launch_distance_px": 42.0,
	},
	"air_heavy_attack_x": {
		"active_start_sec": 0.08,
		"active_end_sec": -1.0,
		"hit_effect": "stun",
		"stun_duration_sec": 0.22,
	},
	"skill_zc": {
		"hit_effect": "stun",
		"stun_duration_sec": 0.22,
	},
	"skill_zx_dash_1": {
		"active_start_sec": 0.10,
		"active_end_sec": 0.18,
		"hit_effect": "stun",
		"stun_duration_sec": 0.22,
	},
	"skill_zx_dash_2": {
		"active_start_sec": 0.08,
		"active_end_sec": 0.16,
		"hit_effect": "stun",
		"stun_duration_sec": 0.22,
	},
	"skill_zx_finisher": {
		"active_start_sec": 0.16,
		"active_end_sec": 0.28,
		"hit_effect": "launch",
		"launch_height_px": 112.0,
		"launch_distance_px": 28.0,
	},
	"guard_counter_light": {
		"active_start_sec": 0.0,
		"active_end_sec": 0.16,
		"hit_effect": "launch",
		"launch_height_px": 14.0,
		"launch_distance_px": 42.0,
	},
	"guard_counter_heavy": {
		"active_start_sec": 0.0,
		"active_end_sec": 0.18,
		"hit_effect": "launch",
		"launch_height_px": 112.0,
		"launch_distance_px": 28.0,
	},
}

@export var light_combo_input_window: float = 0.5
@export var heavy_combo_input_window: float = 0.5
@export var display_name: String = "Longsword"
@export var weapon_mastery_track_id: String = "longsword"
@export var base_attack_power: float = 10.0
@export_range(0.0, 1.0, 0.01) var base_defense_ratio: float = 0.3
@export var equip_weight: float = 0.0
@export_range(1, 8, 1) var weapon_tier: int = 1
@export_range(0, 4, 1) var reinforcement_level: int = 0
@export var reinforcement_bonus_base_attack_power: float = 0.0
@export var reinforcement_bonus_base_defense_ratio: float = 0.0
@export var reinforcement_bonus_attack: int = 0
@export var reinforcement_bonus_agility: int = 0
@export var reinforcement_bonus_vitality: int = 0
@export var reinforcement_bonus_spirit: int = 0
@export var affixes: PackedStringArray = []
@export var coeff_light_attack_c_1: float = 0.7
@export var coeff_light_attack_c_2: float = 0.5
@export var coeff_light_attack_c_3: float = 1.1
@export var coeff_heavy_attack_x_1: float = 1.1
@export var coeff_heavy_attack_x_2: float = 1.3
@export var coeff_run_light_attack_c: float = 1.0
@export var coeff_run_heavy_attack_x: float = 1.1
@export var coeff_air_light_attack_c: float = 0.7
@export var coeff_air_heavy_attack_x: float = 0.8
@export var coeff_skill_zc: float = 1.0
@export var coeff_skill_zx_dash_1: float = 0.8
@export var coeff_skill_zx_dash_2: float = 0.8
@export var coeff_skill_zx_finisher: float = 1.6
@export var light_attack_c_1_motion_distance_px: float = 0.0
@export var light_attack_c_1_motion_duration_sec: float = 0.0
@export var light_attack_c_2_motion_distance_px: float = 7.0
@export var light_attack_c_2_motion_duration_sec: float = 0.08
@export var light_attack_c_3_motion_distance_px: float = 14.0
@export var light_attack_c_3_motion_duration_sec: float = 0.1
@export var air_heavy_attack_x_motion_distance_px: float = 20.0
@export var air_heavy_attack_x_motion_duration_sec: float = 0.06
@export var air_heavy_attack_x_startup_hold_sec: float = 0.08
@export var skill_zx_mp_cost: float = 40.0
@export var skill_zxc_mp_cost: float = 60.0
@export var skill_zxc_buff_duration_sec: float = 15.0
@export var skill_zxc_attack_speed_multiplier: float = 1.5
@export var skill_zc_projectile_speed: float = 560.0
@export var skill_zc_projectile_lifetime_sec: float = 0.9
@export var skill_zx_dash_1_motion_distance_px: float = 20.0
@export var skill_zx_dash_1_motion_duration_sec: float = 0.05
@export var skill_zx_dash_2_motion_distance_px: float = 24.0
@export var skill_zx_dash_2_motion_duration_sec: float = 0.06
@export var skill_zx_grab_slot_offset: Vector2 = Vector2(28.0, -18.0)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var grip_anchor: Marker2D = $SwordPivot/GripAnchor
@onready var attack_hitboxes_root: Node = $SwordPivot/AttackHitboxes
@onready var projectile_spawn: Marker2D = $SwordPivot/ProjectileSpawn

var _light_combo_step := 0
var _light_combo_window_timer := 0.0
var _heavy_combo_step := 0
var _heavy_combo_window_timer := 0.0
var _attack_active := false
var _hold_recovery_pose := false
var _air_heavy_attack_active := false
var _air_heavy_attack_landing := false
var _current_attack_id: StringName = &""
var _current_attack_phase: AttackPhase = AttackPhase.NONE
var _attack_hitboxes_by_id: Dictionary = {}
var _queued_recovery_method: StringName = &""
var _skill_zx_active := false
var _skill_zx_grabbed_target: Node
var _skill_zx_finisher_resolved := false
var _attack_speed_buff_timer := 0.0
var _attack_speed_buff_visual_active := false
var _guard_hold_active := false
var _super_armor_active := false


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	_cache_attack_hitboxes()
	_set_all_hitboxes_enabled(false)


func _process(delta: float) -> void:
	var was_buff_active := _attack_speed_buff_timer > 0.0
	_attack_speed_buff_timer = maxf(0.0, _attack_speed_buff_timer - delta)
	var is_buff_active := _attack_speed_buff_timer > 0.0
	if was_buff_active != is_buff_active:
		_attack_speed_buff_visual_active = is_buff_active
		buff_visual_state_changed.emit(is_buff_active)

	if _light_combo_window_timer > 0.0:
		_light_combo_window_timer = maxf(0.0, _light_combo_window_timer - delta)
		if _hold_recovery_pose and _has_owner_operation_input():
			reset_weapon_pose_only()
			_light_combo_window_timer = 0.0
			_light_combo_step = 0
		if _light_combo_window_timer <= 0.0:
			reset_weapon_pose_only()
			_light_combo_step = 0

	if _heavy_combo_window_timer > 0.0:
		_heavy_combo_window_timer = maxf(0.0, _heavy_combo_window_timer - delta)
		if _hold_recovery_pose and _has_owner_operation_input():
			reset_weapon_pose_only()
			_heavy_combo_window_timer = 0.0
			_heavy_combo_step = 0
		if _heavy_combo_window_timer <= 0.0:
			reset_weapon_pose_only()
			_heavy_combo_step = 0

	_update_attack_phase_from_timeline()


func play_light_attack_c() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_light_attack_c")
		return

	if _light_combo_window_timer > 0.0 and _light_combo_step < 3:
		_light_combo_step += 1
	else:
		_light_combo_step = 1

	_attack_active = true
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	var animation_name := "light_attack_c_%d" % _light_combo_step
	attack_state_changed.emit(true)
	_play_attack_animation(animation_name)
	_begin_attack_timeline(animation_name)
	emit_attack_motion_for_combo_step(_light_combo_step, animation_name)


func get_grip_offset() -> Vector2:
	return grip_anchor.position


func get_display_name() -> String:
	return display_name


func get_weapon_mastery_track_id() -> String:
	return weapon_mastery_track_id


func get_base_attack_power() -> float:
	return maxf(0.0, base_attack_power + reinforcement_bonus_base_attack_power)


func get_base_defense_ratio() -> float:
	return clampf(base_defense_ratio + reinforcement_bonus_base_defense_ratio, 0.0, 1.0)


func get_equip_weight() -> float:
	return equip_weight


func get_weapon_tier() -> int:
	return weapon_tier


func get_reinforcement_level() -> int:
	return reinforcement_level


func get_reinforcement_bonus_data() -> Dictionary:
	return {
		"base_attack_power": reinforcement_bonus_base_attack_power,
		"base_defense_ratio": reinforcement_bonus_base_defense_ratio,
		"attack": reinforcement_bonus_attack,
		"agility": reinforcement_bonus_agility,
		"vitality": reinforcement_bonus_vitality,
		"spirit": reinforcement_bonus_spirit,
	}


func get_attribute_bonus_value(attribute_id: StringName) -> int:
	match String(attribute_id):
		"attack":
			return reinforcement_bonus_attack
		"agility":
			return reinforcement_bonus_agility
		"vitality":
			return reinforcement_bonus_vitality
		"spirit":
			return reinforcement_bonus_spirit
		_:
			return 0


func get_affixes() -> PackedStringArray:
	return affixes


func apply_runtime_item_data(item_data: Dictionary) -> void:
	if item_data.is_empty():
		return

	display_name = String(item_data.get("display_name", display_name))
	weapon_mastery_track_id = String(item_data.get("weapon_mastery_track_id", weapon_mastery_track_id))
	base_attack_power = float(item_data.get("base_attack_power", base_attack_power))
	base_defense_ratio = float(item_data.get("base_defense_ratio", base_defense_ratio))
	equip_weight = float(item_data.get("equip_weight", equip_weight))
	weapon_tier = max(1, int(item_data.get("weapon_tier", weapon_tier)))
	reinforcement_level = clampi(int(item_data.get("reinforcement_level", reinforcement_level)), 0, 4)
	affixes = _coerce_affixes(item_data.get("affixes", affixes))

	var reinforcement_bonus := _normalize_reinforcement_bonus_data(item_data.get("reinforcement_bonus", {}))
	reinforcement_bonus_base_attack_power = float(reinforcement_bonus.get("base_attack_power", 0.0))
	reinforcement_bonus_base_defense_ratio = float(reinforcement_bonus.get("base_defense_ratio", 0.0))
	reinforcement_bonus_attack = int(reinforcement_bonus.get("attack", 0))
	reinforcement_bonus_agility = int(reinforcement_bonus.get("agility", 0))
	reinforcement_bonus_vitality = int(reinforcement_bonus.get("vitality", 0))
	reinforcement_bonus_spirit = int(reinforcement_bonus.get("spirit", 0))


func _normalize_reinforcement_bonus_data(value: Variant) -> Dictionary:
	var normalized := {
		"base_attack_power": 0.0,
		"base_defense_ratio": 0.0,
		"attack": 0,
		"agility": 0,
		"vitality": 0,
		"spirit": 0,
	}
	if not (value is Dictionary):
		return normalized

	var source: Dictionary = value as Dictionary
	normalized["base_attack_power"] = float(source.get("base_attack_power", 0.0))
	normalized["base_defense_ratio"] = float(source.get("base_defense_ratio", 0.0))
	normalized["attack"] = int(source.get("attack", 0))
	normalized["agility"] = int(source.get("agility", 0))
	normalized["vitality"] = int(source.get("vitality", 0))
	normalized["spirit"] = int(source.get("spirit", 0))
	return normalized


func _coerce_affixes(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value

	var normalized := PackedStringArray()
	if value is Array:
		for entry in value as Array:
			normalized.append(String(entry))
	return normalized


func reset_pose() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	reset_weapon_pose_only()
	if _attack_active:
		attack_state_changed.emit(false)
	_attack_active = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	_air_heavy_attack_active = false
	_air_heavy_attack_landing = false
	_skill_zx_active = false
	_skill_zx_finisher_resolved = false
	_release_skill_zx_grabbed_target(false)
	_queued_recovery_method = &""
	_guard_hold_active = false
	_set_super_armor_active(false)
	_attack_speed_buff_timer = 0.0
	if _attack_speed_buff_visual_active:
		_attack_speed_buff_visual_active = false
		buff_visual_state_changed.emit(false)
	_clear_attack_timeline()


func emit_attack_motion_for_combo_step(combo_step: int, animation_name: StringName) -> void:
	var distance_px := 0.0
	var duration_sec := 0.0
	match combo_step:
		1:
			distance_px = light_attack_c_1_motion_distance_px
			duration_sec = light_attack_c_1_motion_duration_sec
		2:
			distance_px = light_attack_c_2_motion_distance_px
			duration_sec = light_attack_c_2_motion_duration_sec
		3:
			distance_px = light_attack_c_3_motion_distance_px
			duration_sec = light_attack_c_3_motion_duration_sec

	if duration_sec <= 0.0:
		duration_sec = animation_player.get_animation(animation_name).length

	attack_motion_requested.emit(distance_px, AttackMotionDirection.FORWARD, _scaled_attack_duration(duration_sec))


func play_heavy_attack_x() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_heavy_attack_x")
		return

	if _heavy_combo_window_timer > 0.0 and _heavy_combo_step < 2:
		_heavy_combo_step += 1
	else:
		_heavy_combo_step = 1

	_attack_active = true
	_hold_recovery_pose = false
	_heavy_combo_window_timer = 0.0
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	attack_state_changed.emit(true)
	var animation_name := "heavy_attack_x_%d" % _heavy_combo_step
	_play_attack_animation(animation_name)
	_begin_attack_timeline(animation_name)


func play_run_heavy_attack_x() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_run_heavy_attack_x")
		return

	_attack_active = true
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	_play_attack_animation("run_heavy_attack_x")
	_begin_attack_timeline(&"run_heavy_attack_x")


func play_run_light_attack_c() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_run_light_attack_c")
		return

	_attack_active = true
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	_play_attack_animation("run_light_attack_c")
	_begin_attack_timeline(&"run_light_attack_c")


func play_air_light_attack_c() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_air_light_attack_c")
		return

	_attack_active = true
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	_play_attack_animation("air_light_attack_c")
	_begin_attack_timeline(&"air_light_attack_c")


func play_air_heavy_attack_x() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_air_heavy_attack_x")
		return

	_attack_active = true
	_air_heavy_attack_active = true
	_air_heavy_attack_landing = false
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	startup_hold_requested.emit(_scaled_attack_duration(air_heavy_attack_x_startup_hold_sec))
	_play_attack_animation("air_heavy_attack_x")
	_begin_attack_timeline(&"air_heavy_attack_x")


func play_skill_zc() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_skill_zc")
		return

	_attack_active = true
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	_play_attack_animation("skill_zc")
	_begin_attack_timeline(&"skill_zc")


func play_skill_zx() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_skill_zx")
		return

	var holder: Node = _get_weapon_holder()
	if holder != null and holder.has_method("consume_mp"):
		if not holder.call("consume_mp", skill_zx_mp_cost):
			return

	_attack_active = true
	_skill_zx_active = true
	_skill_zx_finisher_resolved = false
	_set_super_armor_active(true)
	_release_skill_zx_grabbed_target(false)
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	_play_attack_animation("skill_zx_dash_1")
	_begin_attack_timeline(&"skill_zx_dash_1")
	attack_motion_requested.emit(skill_zx_dash_1_motion_distance_px, AttackMotionDirection.FORWARD, _scaled_attack_duration(skill_zx_dash_1_motion_duration_sec))


func play_skill_zxc() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_skill_zxc")
		return

	var holder: Node = _get_weapon_holder()
	if holder != null and holder.has_method("consume_mp"):
		if not holder.call("consume_mp", skill_zxc_mp_cost):
			return

	_attack_active = true
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	_play_attack_animation("skill_zxc")
	_begin_attack_timeline(&"")


func start_guard_hold() -> void:
	if _attack_active or _guard_hold_active:
		return
	_guard_hold_active = true
	animation_player.play("guard_hold")
	animation_player.speed_scale = 1.0


func stop_guard_hold() -> void:
	if not _guard_hold_active:
		return
	_guard_hold_active = false
	if animation_player.current_animation == "guard_hold":
		animation_player.stop()
		reset_weapon_pose_only()


func play_guard_counter_light() -> void:
	if _attack_active:
		return
	_guard_hold_active = false
	_attack_active = true
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	_play_attack_animation("guard_counter_light")
	_begin_attack_timeline(&"guard_counter_light")


func play_guard_counter_heavy() -> void:
	if _attack_active:
		return
	_guard_hold_active = false
	_attack_active = true
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	_play_attack_animation("guard_counter_heavy")
	_begin_attack_timeline(&"guard_counter_heavy")


func emit_air_heavy_attack_dash() -> void:
	attack_motion_requested.emit(air_heavy_attack_x_motion_distance_px, AttackMotionDirection.FORWARD, _scaled_attack_duration(air_heavy_attack_x_motion_duration_sec))


func is_air_heavy_attack_active() -> bool:
	return _air_heavy_attack_active and not _air_heavy_attack_landing


func finish_air_heavy_attack_x() -> void:
	if not _air_heavy_attack_active or _air_heavy_attack_landing:
		return

	_air_heavy_attack_landing = true
	_set_attack_phase(AttackPhase.RECOVERY)
	_play_attack_animation("air_heavy_attack_x_land")


func spawn_skill_zc_projectile() -> void:
	var projectile: Node = SWORD_WAVE_PROJECTILE_SCENE.instantiate()
	if projectile == null:
		return

	var holder: Node = _get_weapon_holder()
	if holder == null:
		return
	if holder.has_method("consume_mp"):
		var mp_cost: float = float(holder.get("skill_zc_mp_cost"))
		if not holder.call("consume_mp", mp_cost):
			return

	var facing_sign: float = 1.0
	facing_sign = float(holder.get("facing"))

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = holder

	parent_node.add_child(projectile)
	if projectile is Node2D:
		var spawn_position := projectile_spawn.global_position
		if holder.has_node("Visuals/BodyPivot/WeaponAnchor"):
			var hand_anchor := holder.get_node("Visuals/BodyPivot/WeaponAnchor") as Marker2D
			if hand_anchor != null:
				spawn_position = hand_anchor.global_position + Vector2(18.0 * facing_sign, 0.0)
		(projectile as Node2D).global_position = spawn_position
	if projectile is Projectile2D:
		(projectile as Projectile2D).speed = skill_zc_projectile_speed
		(projectile as Projectile2D).lifetime_sec = skill_zc_projectile_lifetime_sec
	if projectile.has_method("launch"):
		projectile.call("launch", Vector2(facing_sign, 0.0), _build_attack_payload(&"skill_zc"))


func reset_weapon_pose_only() -> void:
	$SwordPivot.position = Vector2.ZERO
	$SwordPivot.rotation_degrees = 0.0
	_hold_recovery_pose = false
	animation_player.speed_scale = 1.0


func _cache_attack_hitboxes() -> void:
	_attack_hitboxes_by_id.clear()
	for child in attack_hitboxes_root.get_children():
		if not child.has_method("get_attack_id"):
			continue
		var attack_id: StringName = child.call("get_attack_id")
		if attack_id == &"":
			continue
		_attack_hitboxes_by_id[attack_id] = child
		if child.has_signal("target_hit"):
			child.connect("target_hit", Callable(self, "_on_attack_hitbox_target_hit"))


func _begin_attack_timeline(attack_id: StringName) -> void:
	_current_attack_id = attack_id
	_set_attack_phase(AttackPhase.STARTUP)
	_reset_hit_memory_for_attack(attack_id)


func _clear_attack_timeline() -> void:
	_current_attack_id = &""
	_set_attack_phase(AttackPhase.NONE)


func _update_attack_phase_from_timeline() -> void:
	if not _attack_active or _current_attack_id == &"":
		return
	if not ATTACK_DEFINITIONS.has(String(_current_attack_id)):
		return

	var attack_data: Dictionary = ATTACK_DEFINITIONS[String(_current_attack_id)]
	var active_start_sec: float = attack_data.get("active_start_sec", 0.0)
	var active_end_sec: float = attack_data.get("active_end_sec", -1.0)
	var current_time := animation_player.current_animation_position
	var next_phase := AttackPhase.STARTUP

	if current_time >= active_start_sec:
		next_phase = AttackPhase.ACTIVE
	if active_end_sec >= 0.0 and current_time >= active_end_sec:
		next_phase = AttackPhase.RECOVERY

	_set_attack_phase(next_phase)


func _set_attack_phase(next_phase: AttackPhase) -> void:
	if _current_attack_phase == next_phase:
		return

	_current_attack_phase = next_phase
	var hitboxes_enabled := _current_attack_phase == AttackPhase.ACTIVE
	_set_hitboxes_enabled_for_attack(_current_attack_id, hitboxes_enabled)
	if _current_attack_phase == AttackPhase.ACTIVE:
		_on_attack_active_started(_current_attack_id)


func _set_all_hitboxes_enabled(enabled: bool) -> void:
	for hitbox in _attack_hitboxes_by_id.values():
		if hitbox.has_method("set_middle_phase_enabled"):
			hitbox.call("set_middle_phase_enabled", enabled)


func _set_hitboxes_enabled_for_attack(attack_id: StringName, enabled: bool) -> void:
	for registered_attack_id in _attack_hitboxes_by_id.keys():
		var hitbox = _attack_hitboxes_by_id[registered_attack_id]
		if not hitbox.has_method("set_middle_phase_enabled"):
			continue
		hitbox.call("set_middle_phase_enabled", enabled and registered_attack_id == attack_id)


func _reset_hit_memory_for_attack(attack_id: StringName) -> void:
	if not _attack_hitboxes_by_id.has(attack_id):
		return
	var hitbox = _attack_hitboxes_by_id[attack_id]
	if hitbox.has_method("reset_hit_memory"):
		hitbox.call("reset_hit_memory")


func _on_attack_hitbox_target_hit(target: Node, attack_id: StringName) -> void:
	if target == _get_weapon_holder():
		return
	var weapon_holder := _get_weapon_holder()
	if weapon_holder != null and weapon_holder.has_method("can_resolve_network_combat_hits") and not bool(weapon_holder.call("can_resolve_network_combat_hits")):
		return
	if attack_id != _current_attack_id:
		return
	if not ATTACK_DEFINITIONS.has(String(attack_id)):
		return

	_apply_attack_to_target(target, attack_id)
	if attack_id == &"skill_zx_dash_1" or attack_id == &"skill_zx_dash_2":
		_try_grab_target_for_skill_zx(target)


func _get_weapon_holder() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current is CharacterBody2D:
			return current
		current = current.get_parent()
	return null


func _build_attack_payload(attack_id: StringName) -> Dictionary:
	var attack_data: Dictionary = ATTACK_DEFINITIONS.get(String(attack_id), {}).duplicate(true)
	var attack_coefficient := _get_attack_coefficient(attack_id)
	var holder: Node = _get_weapon_holder()
	var attribute_attack_multiplier := 1.0
	if holder != null and holder.has_method("get_attack_attribute_damage_multiplier"):
		attribute_attack_multiplier = float(holder.call("get_attack_attribute_damage_multiplier"))

	attack_data["attack_id"] = String(attack_id)
	var effective_base_attack_power := get_base_attack_power()
	attack_data["base_attack_power"] = effective_base_attack_power
	attack_data["attack_coefficient"] = attack_coefficient
	attack_data["attribute_attack_multiplier"] = attribute_attack_multiplier
	attack_data["damage"] = effective_base_attack_power * attack_coefficient * attribute_attack_multiplier
	return attack_data


func _get_attack_coefficient(attack_id: StringName) -> float:
	match attack_id:
		&"light_attack_c_1":
			return coeff_light_attack_c_1
		&"light_attack_c_2":
			return coeff_light_attack_c_2
		&"light_attack_c_3":
			return coeff_light_attack_c_3
		&"heavy_attack_x_1":
			return coeff_heavy_attack_x_1
		&"heavy_attack_x_2":
			return coeff_heavy_attack_x_2
		&"run_light_attack_c":
			return coeff_run_light_attack_c
		&"run_heavy_attack_x":
			return coeff_run_heavy_attack_x
		&"air_light_attack_c":
			return coeff_air_light_attack_c
		&"air_heavy_attack_x":
			return coeff_air_heavy_attack_x
		&"skill_zc":
			return coeff_skill_zc
		&"skill_zx_dash_1":
			return coeff_skill_zx_dash_1
		&"skill_zx_dash_2":
			return coeff_skill_zx_dash_2
		&"skill_zx_finisher":
			return coeff_skill_zx_finisher
		&"guard_counter_light":
			return coeff_light_attack_c_3
		&"guard_counter_heavy":
			return coeff_heavy_attack_x_2
		_:
			return 1.0


func _has_owner_operation_input() -> bool:
	return (
		Input.is_action_just_pressed("move_left")
		or Input.is_action_just_pressed("move_right")
		or Input.is_action_just_pressed("move_jump")
		or Input.is_action_just_pressed("interact_up")
		or Input.is_action_just_pressed("interact_down")
	)


func _queue_recovery_method_if_allowed(method_name: StringName) -> void:
	if _current_attack_phase != AttackPhase.RECOVERY:
		return
	_queued_recovery_method = method_name


func _consume_queued_recovery_method() -> bool:
	if _queued_recovery_method == &"":
		return false
	if not has_method(_queued_recovery_method):
		_queued_recovery_method = &""
		return false

	var method_name := _queued_recovery_method
	_queued_recovery_method = &""
	call(method_name)
	return true


func _get_attack_speed_multiplier() -> float:
	if _attack_speed_buff_timer > 0.0:
		return skill_zxc_attack_speed_multiplier
	return 1.0


func _play_attack_animation(animation_name: StringName) -> void:
	animation_player.play(animation_name)
	animation_player.speed_scale = _get_attack_speed_multiplier()


func _scaled_attack_duration(duration_sec: float) -> float:
	var speed_multiplier := _get_attack_speed_multiplier()
	if speed_multiplier <= 0.0:
		return duration_sec
	return duration_sec / speed_multiplier


func activate_skill_zxc_buff() -> void:
	_attack_speed_buff_timer = skill_zxc_buff_duration_sec
	if not _attack_speed_buff_visual_active:
		_attack_speed_buff_visual_active = true
		buff_visual_state_changed.emit(true)


func _on_animation_finished(animation_name: StringName) -> void:
	if String(animation_name).begins_with("heavy_attack_x_"):
		_attack_active = false
		attack_state_changed.emit(false)
		_clear_attack_timeline()
		if _heavy_combo_step >= 2:
			_heavy_combo_step = 0
			_heavy_combo_window_timer = 0.0
			reset_weapon_pose_only()
		else:
			_heavy_combo_window_timer = heavy_combo_input_window
			if not _consume_queued_recovery_method():
				_hold_recovery_pose = true
		return

	if animation_name == "run_heavy_attack_x":
		_attack_active = false
		attack_state_changed.emit(false)
		_clear_attack_timeline()
		if _consume_queued_recovery_method():
			return
		reset_weapon_pose_only()
		return

	if animation_name == "run_light_attack_c":
		_attack_active = false
		attack_state_changed.emit(false)
		_clear_attack_timeline()
		if _consume_queued_recovery_method():
			return
		reset_weapon_pose_only()
		return

	if animation_name == "air_light_attack_c":
		_attack_active = false
		attack_state_changed.emit(false)
		_clear_attack_timeline()
		if _consume_queued_recovery_method():
			return
		reset_weapon_pose_only()
		return

	if animation_name == "air_heavy_attack_x":
		return

	if animation_name == "air_heavy_attack_x_land":
		_attack_active = false
		_air_heavy_attack_active = false
		_air_heavy_attack_landing = false
		attack_state_changed.emit(false)
		_clear_attack_timeline()
		if _consume_queued_recovery_method():
			return
		reset_weapon_pose_only()
		return

	if animation_name == "skill_zc":
		_attack_active = false
		attack_state_changed.emit(false)
		_clear_attack_timeline()
		if _consume_queued_recovery_method():
			return
		reset_weapon_pose_only()
		return

	if animation_name == "skill_zxc":
		activate_skill_zxc_buff()
		_attack_active = false
		attack_state_changed.emit(false)
		_clear_attack_timeline()
		if _consume_queued_recovery_method():
			return
		reset_weapon_pose_only()
		return

	if animation_name == "guard_counter_light" or animation_name == "guard_counter_heavy":
		_attack_active = false
		attack_state_changed.emit(false)
		_clear_attack_timeline()
		if _consume_queued_recovery_method():
			return
		reset_weapon_pose_only()
		return

	if animation_name == "skill_zx_dash_1":
		_play_attack_animation("skill_zx_dash_2")
		_begin_attack_timeline(&"skill_zx_dash_2")
		attack_motion_requested.emit(skill_zx_dash_2_motion_distance_px, AttackMotionDirection.FORWARD, _scaled_attack_duration(skill_zx_dash_2_motion_duration_sec))
		return

	if animation_name == "skill_zx_dash_2":
		_play_attack_animation("skill_zx_finisher")
		_begin_attack_timeline(&"skill_zx_finisher")
		return

	if animation_name == "skill_zx_finisher":
		_attack_active = false
		_skill_zx_active = false
		_set_super_armor_active(false)
		attack_state_changed.emit(false)
		_clear_attack_timeline()
		_release_skill_zx_grabbed_target(false)
		if _consume_queued_recovery_method():
			return
		reset_weapon_pose_only()
		return

	if not String(animation_name).begins_with("light_attack_c_"):
		return

	_attack_active = false
	attack_state_changed.emit(false)
	_clear_attack_timeline()

	if _light_combo_step >= 3:
		_light_combo_step = 0
		_light_combo_window_timer = 0.0
		reset_weapon_pose_only()
	else:
		_light_combo_window_timer = light_combo_input_window
		if not _consume_queued_recovery_method():
			_hold_recovery_pose = true


func _on_attack_active_started(attack_id: StringName) -> void:
	if attack_id == &"skill_zx_dash_2" and is_instance_valid(_skill_zx_grabbed_target):
		_apply_grabbed_damage_to_target(_skill_zx_grabbed_target, attack_id)

	if attack_id == &"skill_zx_finisher" and not _skill_zx_finisher_resolved:
		_skill_zx_finisher_resolved = true
		if is_instance_valid(_skill_zx_grabbed_target):
			var grabbed_target := _skill_zx_grabbed_target
			_release_skill_zx_grabbed_target(false)
			_apply_attack_to_target(grabbed_target, attack_id)


func _apply_attack_to_target(target: Node, attack_id: StringName) -> void:
	var attack_data: Dictionary = _build_attack_payload(attack_id)
	attack_hit_registered.emit(target, attack_id)
	if target.has_method("receive_weapon_hit"):
		target.call("receive_weapon_hit", attack_data.duplicate(true), self)
		return

	var target_x := global_position.x
	if target is Node2D:
		target_x = (target as Node2D).global_position.x
	var source_is_on_left: bool = global_position.x < target_x
	var hit_effect: String = attack_data.get("hit_effect", "stun")
	match hit_effect:
		"launch":
			if target.has_method("apply_launch_by_distance_from_source"):
				target.call(
					"apply_launch_by_distance_from_source",
					source_is_on_left,
					attack_data.get("launch_height_px", 0.0),
					attack_data.get("launch_distance_px", 0.0)
				)
			elif target.has_method("apply_launch_from_source"):
				target.call(
					"apply_launch_from_source",
					source_is_on_left,
					attack_data.get("launch_height_coef", 1.0),
					attack_data.get("launch_distance_coef", 1.0)
				)
		_:
			if target.has_method("apply_stun_from_source"):
				target.call(
					"apply_stun_from_source",
					source_is_on_left,
					attack_data.get("stun_duration_sec", 0.0)
				)


func _try_grab_target_for_skill_zx(target: Node) -> void:
	if not _skill_zx_active:
		return
	if is_instance_valid(_skill_zx_grabbed_target):
		return
	if target == null:
		return
	if not target.has_method("enter_grabbed_by"):
		return

	_skill_zx_grabbed_target = target
	target.call("enter_grabbed_by", _get_weapon_holder(), skill_zx_grab_slot_offset)


func _apply_grabbed_damage_to_target(target: Node, attack_id: StringName) -> void:
	var weapon_holder := _get_weapon_holder()
	if weapon_holder != null and weapon_holder.has_method("can_resolve_network_combat_hits") and not bool(weapon_holder.call("can_resolve_network_combat_hits")):
		return
	var attack_data: Dictionary = _build_attack_payload(attack_id)
	attack_hit_registered.emit(target, attack_id)
	if target.has_method("receive_grabbed_weapon_hit"):
		target.call("receive_grabbed_weapon_hit", attack_data.duplicate(true), self)
		return
	if target.has_method("receive_weapon_hit"):
		target.call("receive_weapon_hit", attack_data.duplicate(true), self)


func _release_skill_zx_grabbed_target(apply_launch: bool) -> void:
	if not is_instance_valid(_skill_zx_grabbed_target):
		_skill_zx_grabbed_target = null
		return

	var grabbed_target := _skill_zx_grabbed_target
	_skill_zx_grabbed_target = null
	if grabbed_target.has_method("release_grabbed"):
		grabbed_target.call("release_grabbed")
	if apply_launch and grabbed_target.has_method("apply_launch_by_distance_from_source"):
		var attack_data: Dictionary = _build_attack_payload(&"skill_zx_finisher")
		var source_is_on_left := true
		if grabbed_target is Node2D:
			source_is_on_left = global_position.x < (grabbed_target as Node2D).global_position.x
		grabbed_target.call(
			"apply_launch_by_distance_from_source",
			source_is_on_left,
			attack_data.get("launch_height_px", 0.0),
			attack_data.get("launch_distance_px", 0.0)
		)


func _set_super_armor_active(active: bool) -> void:
	if _super_armor_active == active:
		return
	_super_armor_active = active
	super_armor_state_changed.emit(active)
