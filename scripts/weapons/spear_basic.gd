extends Node2D

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
	"light_attack_c_1": {"active_start_sec": 0.10, "active_end_sec": 0.17, "hit_effect": "stun", "stun_duration_sec": 0.20},
	"light_attack_c_2": {"active_start_sec": 0.13, "active_end_sec": 0.22, "hit_effect": "stun", "stun_duration_sec": 0.22},
	"light_attack_c_3": {"active_start_sec": 0.17, "active_end_sec": 0.28, "hit_effect": "launch", "launch_height_px": 8.0, "launch_distance_px": 72.0},
	"heavy_attack_x_1": {"active_start_sec": 0.22, "active_end_sec": 0.33, "hit_effect": "stun", "stun_duration_sec": 0.30},
	"heavy_attack_x_2": {"active_start_sec": 0.28, "active_end_sec": 0.40, "hit_effect": "launch", "launch_height_px": 12.0, "launch_distance_px": 96.0, "guard_break": true},
	"run_light_attack_c": {"active_start_sec": 0.10, "active_end_sec": 0.19, "hit_effect": "stun", "stun_duration_sec": 0.22},
	"run_heavy_attack_x": {"active_start_sec": 0.20, "active_end_sec": 0.32, "hit_effect": "launch", "launch_height_px": 10.0, "launch_distance_px": 92.0},
	"air_light_attack_c": {"active_start_sec": 0.12, "active_end_sec": 0.20, "hit_effect": "stun", "stun_duration_sec": 0.18},
	"air_heavy_attack_x": {"active_start_sec": 0.08, "active_end_sec": -1.0, "hit_effect": "stun", "stun_duration_sec": 0.28},
	"skill_zc": {"active_start_sec": 0.30, "active_end_sec": 0.46, "hit_effect": "launch", "launch_height_px": 92.0, "launch_distance_px": 20.0, "guard_break": true},
	"skill_zx_1": {"active_start_sec": 0.50, "active_end_sec": 0.54, "hit_effect": "stun", "stun_duration_sec": 0.16},
	"skill_zx_2": {"active_start_sec": 0.03, "active_end_sec": 0.06, "hit_effect": "stun", "stun_duration_sec": 0.16},
	"skill_zx_3": {"active_start_sec": 0.03, "active_end_sec": 0.07, "hit_effect": "launch", "launch_height_px": 6.0, "launch_distance_px": 116.0},
	"guard_counter_light": {"active_start_sec": 0.07, "active_end_sec": 0.15, "hit_effect": "stun", "stun_duration_sec": 0.18},
	"guard_counter_heavy": {"active_start_sec": 0.12, "active_end_sec": 0.24, "hit_effect": "launch", "launch_height_px": 8.0, "launch_distance_px": 104.0, "guard_break": true},
}

@export var light_combo_input_window: float = 0.4
@export var heavy_combo_input_window: float = 0.45
@export var display_name: String = "长枪"
@export var weapon_mastery_track_id: String = "spear"
@export var base_attack_power: float = 12.0
@export_range(0.0, 1.0, 0.01) var base_defense_ratio: float = 0.18
@export var equip_weight: float = 0.18
@export_range(1, 8, 1) var weapon_tier: int = 1
@export_range(0, 4, 1) var reinforcement_level: int = 0
@export var reinforcement_bonus_base_attack_power: float = 0.0
@export var reinforcement_bonus_base_defense_ratio: float = 0.0
@export var reinforcement_bonus_attack: int = 0
@export var reinforcement_bonus_agility: int = 0
@export var reinforcement_bonus_vitality: int = 0
@export var reinforcement_bonus_spirit: int = 0
@export var affixes: PackedStringArray = []

@export var coeff_light_attack_c_1: float = 0.82
@export var coeff_light_attack_c_2: float = 0.92
@export var coeff_light_attack_c_3: float = 1.2
@export var coeff_heavy_attack_x_1: float = 1.35
@export var coeff_heavy_attack_x_2: float = 1.75
@export var coeff_run_light_attack_c: float = 1.0
@export var coeff_run_heavy_attack_x: float = 1.45
@export var coeff_air_light_attack_c: float = 0.9
@export var coeff_air_heavy_attack_x: float = 1.2
@export var coeff_skill_zc: float = 1.45
@export var coeff_skill_zx_1: float = 0.72
@export var coeff_skill_zx_2: float = 0.78
@export var coeff_skill_zx_3: float = 1.55

@export var light_attack_c_2_motion_distance_px: float = 8.0
@export var light_attack_c_2_motion_duration_sec: float = 0.14
@export var heavy_attack_x_1_motion_distance_px: float = 6.0
@export var heavy_attack_x_1_motion_duration_sec: float = 0.16
@export var heavy_attack_x_2_motion_distance_px: float = 10.0
@export var heavy_attack_x_2_motion_duration_sec: float = 0.18
@export var run_light_attack_c_motion_distance_px: float = 10.0
@export var run_light_attack_c_motion_duration_sec: float = 0.14
@export var run_heavy_attack_x_motion_distance_px: float = 16.0
@export var run_heavy_attack_x_motion_duration_sec: float = 0.18
@export var air_light_attack_c_motion_distance_px: float = 8.0
@export var air_light_attack_c_motion_duration_sec: float = 0.14
@export var air_heavy_attack_x_motion_distance_px: float = 4.0
@export var air_heavy_attack_x_motion_duration_sec: float = 0.08
@export var air_heavy_attack_x_startup_hold_sec: float = 0.08
@export var skill_zc_motion_distance_px: float = 8.0
@export var skill_zc_motion_duration_sec: float = 0.18
@export var skill_zx_1_motion_distance_px: float = 8.0
@export var skill_zx_1_motion_duration_sec: float = 0.20
@export var skill_zx_2_motion_distance_px: float = 12.0
@export var skill_zx_2_motion_duration_sec: float = 0.08
@export var skill_zx_3_motion_distance_px: float = 14.0
@export var skill_zx_3_motion_duration_sec: float = 0.09
@export var guard_counter_light_motion_distance_px: float = 6.0
@export var guard_counter_light_motion_duration_sec: float = 0.10
@export var guard_counter_heavy_motion_distance_px: float = 10.0
@export var guard_counter_heavy_motion_duration_sec: float = 0.12
@export var skill_zx_mp_cost: float = 30.0
@export var skill_zxc_mp_cost: float = 50.0
@export var skill_zxc_buff_duration_sec: float = 12.0
@export var precision_buff_attack_multiplier: float = 1.2

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var spear_pivot: Node2D = $SpearPivot
@onready var grip_anchor: Marker2D = $SpearPivot/GripAnchor
@onready var attack_hitboxes_root: Node = $SpearPivot/AttackHitboxes
@onready var spear_sprite: Sprite2D = $SpearPivot/Sprite2D

var _light_combo_step := 0
var _light_combo_window_timer := 0.0
var _heavy_combo_step := 0
var _heavy_combo_window_timer := 0.0
var _attack_active := false
var _hold_recovery_pose := false
var _air_heavy_attack_active := false
var _air_heavy_attack_landing := false
var _precision_stance_timer := 0.0
var _precision_stance_visual_active := false
var _guard_hold_active := false
var _current_attack_id: StringName = &""
var _current_attack_phase: AttackPhase = AttackPhase.NONE
var _attack_hitboxes_by_id: Dictionary = {}
var _queued_recovery_method: StringName = &""
var _idle_pose_position: Vector2 = Vector2(6, -14)
var _idle_pose_rotation: float = 1.43117


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	_cache_attack_hitboxes()
	_cache_idle_pose_from_animation()
	_set_all_hitboxes_enabled(false)
	reset_weapon_pose_only()


func _process(delta: float) -> void:
	var was_precision_active := _precision_stance_timer > 0.0
	_precision_stance_timer = maxf(0.0, _precision_stance_timer - delta)
	var is_precision_active := _precision_stance_timer > 0.0
	if was_precision_active != is_precision_active:
		_precision_stance_visual_active = is_precision_active
		buff_visual_state_changed.emit(is_precision_active)

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
	_update_precision_sprite_tint()


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
	emit_attack_motion_for_animation(animation_name)


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
	var animation_name := "heavy_attack_x_%d" % _heavy_combo_step
	attack_state_changed.emit(true)
	_play_attack_animation(animation_name)
	_begin_attack_timeline(animation_name)
	emit_attack_motion_for_animation(animation_name)


func play_run_light_attack_c() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_run_light_attack_c")
		return
	_begin_single_attack("run_light_attack_c")


func play_run_heavy_attack_x() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_run_heavy_attack_x")
		return
	_begin_single_attack("run_heavy_attack_x")


func play_air_light_attack_c() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_air_light_attack_c")
		return
	_begin_single_attack("air_light_attack_c")


func play_air_heavy_attack_x() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_air_heavy_attack_x")
		return
	_begin_single_attack("air_heavy_attack_x")
	_air_heavy_attack_active = true
	_air_heavy_attack_landing = false
	startup_hold_requested.emit(air_heavy_attack_x_startup_hold_sec)


func play_skill_zc() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_skill_zc")
		return
	if not _try_consume_holder_mp(skill_zx_mp_cost * 0.5):
		return
	_begin_single_attack("skill_zc")


func play_skill_zx() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_skill_zx")
		return
	if not _try_consume_holder_mp(skill_zx_mp_cost):
		return
	_begin_single_attack("skill_zx_1")


func play_skill_zxc() -> void:
	if _attack_active:
		_queue_recovery_method_if_allowed(&"play_skill_zxc")
		return
	if not _try_consume_holder_mp(skill_zxc_mp_cost):
		return
	_begin_single_attack("skill_zxc")


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
	_begin_single_attack("guard_counter_light")


func play_guard_counter_heavy() -> void:
	if _attack_active:
		return
	_guard_hold_active = false
	_begin_single_attack("guard_counter_heavy")


func is_air_heavy_attack_active() -> bool:
	return _air_heavy_attack_active and not _air_heavy_attack_landing


func finish_air_heavy_attack_x() -> void:
	if not _air_heavy_attack_active or _air_heavy_attack_landing:
		return
	_air_heavy_attack_landing = true
	_set_attack_phase(AttackPhase.RECOVERY)
	_play_attack_animation("air_heavy_attack_x_land")


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


func reset_pose() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	reset_weapon_pose_only()
	if _attack_active:
		attack_state_changed.emit(false)
	_attack_active = false
	_hold_recovery_pose = false
	_guard_hold_active = false
	_light_combo_step = 0
	_light_combo_window_timer = 0.0
	_heavy_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_air_heavy_attack_active = false
	_air_heavy_attack_landing = false
	_queued_recovery_method = &""
	_clear_attack_timeline()
	_set_all_hitboxes_enabled(false)
	if _precision_stance_visual_active:
		_precision_stance_visual_active = false
		buff_visual_state_changed.emit(false)
	_precision_stance_timer = 0.0


func reset_weapon_pose_only() -> void:
	spear_pivot.position = _idle_pose_position
	spear_pivot.rotation = _idle_pose_rotation
	animation_player.speed_scale = 1.0
	_hold_recovery_pose = false


func emit_attack_motion_for_animation(animation_name: StringName) -> void:
	match animation_name:
		&"light_attack_c_2":
			attack_motion_requested.emit(light_attack_c_2_motion_distance_px, AttackMotionDirection.BACKWARD, light_attack_c_2_motion_duration_sec)
		&"heavy_attack_x_1":
			attack_motion_requested.emit(heavy_attack_x_1_motion_distance_px, AttackMotionDirection.BACKWARD, heavy_attack_x_1_motion_duration_sec)
		&"heavy_attack_x_2":
			attack_motion_requested.emit(heavy_attack_x_2_motion_distance_px, AttackMotionDirection.BACKWARD, heavy_attack_x_2_motion_duration_sec)
		&"run_light_attack_c":
			attack_motion_requested.emit(run_light_attack_c_motion_distance_px, AttackMotionDirection.FORWARD, run_light_attack_c_motion_duration_sec)
		&"run_heavy_attack_x":
			attack_motion_requested.emit(run_heavy_attack_x_motion_distance_px, AttackMotionDirection.FORWARD, run_heavy_attack_x_motion_duration_sec)
		&"air_light_attack_c":
			attack_motion_requested.emit(air_light_attack_c_motion_distance_px, AttackMotionDirection.FORWARD, air_light_attack_c_motion_duration_sec)
		&"air_heavy_attack_x":
			attack_motion_requested.emit(air_heavy_attack_x_motion_distance_px, AttackMotionDirection.FORWARD, air_heavy_attack_x_motion_duration_sec)
		&"skill_zc":
			attack_motion_requested.emit(skill_zc_motion_distance_px, AttackMotionDirection.FORWARD, skill_zc_motion_duration_sec)
		&"skill_zx_1":
			attack_motion_requested.emit(skill_zx_1_motion_distance_px, AttackMotionDirection.BACKWARD, skill_zx_1_motion_duration_sec)
		&"skill_zx_2":
			attack_motion_requested.emit(skill_zx_2_motion_distance_px, AttackMotionDirection.FORWARD, skill_zx_2_motion_duration_sec)
		&"skill_zx_3":
			attack_motion_requested.emit(skill_zx_3_motion_distance_px, AttackMotionDirection.FORWARD, skill_zx_3_motion_duration_sec)
		&"guard_counter_light":
			attack_motion_requested.emit(guard_counter_light_motion_distance_px, AttackMotionDirection.BACKWARD, guard_counter_light_motion_duration_sec)
		&"guard_counter_heavy":
			attack_motion_requested.emit(guard_counter_heavy_motion_distance_px, AttackMotionDirection.BACKWARD, guard_counter_heavy_motion_duration_sec)


func _begin_single_attack(animation_name: StringName) -> void:
	_attack_active = true
	_hold_recovery_pose = false
	_light_combo_window_timer = 0.0
	_light_combo_step = 0
	_heavy_combo_window_timer = 0.0
	_heavy_combo_step = 0
	attack_state_changed.emit(true)
	_play_attack_animation(animation_name)
	_begin_attack_timeline(animation_name)
	emit_attack_motion_for_animation(animation_name)


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
	if _precision_stance_timer > 0.0:
		attack_coefficient *= precision_buff_attack_multiplier

	var holder: Node = _get_weapon_holder()
	var attribute_attack_multiplier := 1.0
	if holder != null and holder.has_method("get_attack_attribute_damage_multiplier"):
		attribute_attack_multiplier = float(holder.call("get_attack_attribute_damage_multiplier"))

	var effective_base_attack_power := get_base_attack_power()
	attack_data["attack_id"] = String(attack_id)
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
		&"skill_zx_1":
			return coeff_skill_zx_1
		&"skill_zx_2":
			return coeff_skill_zx_2
		&"skill_zx_3":
			return coeff_skill_zx_3
		&"guard_counter_light":
			return coeff_light_attack_c_2
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


func _play_attack_animation(animation_name: StringName) -> void:
	animation_player.play(animation_name)
	animation_player.speed_scale = 1.0


func _cache_idle_pose_from_animation() -> void:
	if animation_player == null or not animation_player.has_animation("idle"):
		return

	var idle_animation: Animation = animation_player.get_animation("idle")
	if idle_animation == null:
		return

	var position_track := idle_animation.find_track(NodePath("SpearPivot:position"), Animation.TYPE_VALUE)
	if position_track != -1 and idle_animation.track_get_key_count(position_track) > 0:
		var position_value: Variant = idle_animation.track_get_key_value(position_track, 0)
		if position_value is Vector2:
			_idle_pose_position = position_value

	var rotation_track := idle_animation.find_track(NodePath("SpearPivot:rotation"), Animation.TYPE_VALUE)
	if rotation_track != -1 and idle_animation.track_get_key_count(rotation_track) > 0:
		_idle_pose_rotation = float(idle_animation.track_get_key_value(rotation_track, 0))


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == "skill_zx_1":
		_play_attack_animation("skill_zx_2")
		_begin_attack_timeline(&"skill_zx_2")
		emit_attack_motion_for_animation(&"skill_zx_2")
		return

	if animation_name == "skill_zx_2":
		_play_attack_animation("skill_zx_3")
		_begin_attack_timeline(&"skill_zx_3")
		emit_attack_motion_for_animation(&"skill_zx_3")
		return

	if animation_name == "air_heavy_attack_x":
		return

	if animation_name == "skill_zxc":
		_precision_stance_timer = skill_zxc_buff_duration_sec
		if not _precision_stance_visual_active:
			_precision_stance_visual_active = true
			buff_visual_state_changed.emit(true)

	if animation_name == "air_heavy_attack_x_land":
		_air_heavy_attack_active = false
		_air_heavy_attack_landing = false

	if String(animation_name).begins_with("light_attack_c_"):
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
		return

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

	_attack_active = false
	attack_state_changed.emit(false)
	_clear_attack_timeline()
	if _consume_queued_recovery_method():
		return
	reset_weapon_pose_only()


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
				target.call("apply_launch_from_source", source_is_on_left, 1.0, 1.0)
		_:
			if target.has_method("apply_stun_from_source"):
				target.call("apply_stun_from_source", source_is_on_left, attack_data.get("stun_duration_sec", 0.0))


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


func _try_consume_holder_mp(mp_cost: float) -> bool:
	var holder: Node = _get_weapon_holder()
	if holder != null and holder.has_method("consume_mp"):
		return bool(holder.call("consume_mp", mp_cost))
	return true


func _update_precision_sprite_tint() -> void:
	if spear_sprite == null:
		return
	if _precision_stance_timer > 0.0:
		spear_sprite.modulate = Color(0.88, 0.96, 1.0, 1.0)
	else:
		spear_sprite.modulate = Color(1, 1, 1, 1)
