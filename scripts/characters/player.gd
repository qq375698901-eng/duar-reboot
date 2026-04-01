extends CharacterBody2D

signal attribute_profile_changed(snapshot: Dictionary)
signal resources_changed(current_hp: float, max_hp: float, current_mp: float, max_mp: float)
signal death_state_changed(dead: bool)

enum TopState {
	OPERABLE,
	STUN,
	LAUNCH,
	DOWN,
	GRABBED,
	DEAD,
}

enum MovePhase {
	GROUND,
	AIR,
	CLIMB,
	RUN_SKID,
}

const WORLD_LAYER := 1
const CHARACTER_LAYER := 2
const PLATFORM_LAYER := 3
const LADDER_AREA_LAYER := 4
const LONGSWORD_BASIC_SCENE := preload("res://scenes/weapons/longsword_basic.tscn")
const SPEAR_BASIC_SCENE := preload("res://scenes/weapons/spear_basic.tscn")
const BATTLE_ATTRIBUTE_DEBUG_PANEL_SCENE := preload("res://scenes/ui/battle_attribute_debug_panel.tscn")
const BATTLE_INVENTORY_PANEL_SCENE := preload("res://scenes/ui/battle_inventory_panel.tscn")
const BATTLE_DEATH_OVERLAY_SCENE := preload("res://scenes/ui/battle_death_overlay.tscn")
const ATTACK_MOTION_NONE := 0
const ATTACK_MOTION_FORWARD := 1
const ATTACK_MOTION_BACKWARD := -1
const POTION_USE_MOVEMENT_MODIFIER := &"potion_use"
const POTION_USE_JUMP_MODIFIER := &"potion_use"

@export var facing: int = 1

@export_group("Horizontal Move")
@export var walk_accel: float = 1300.0
@export var max_walk_speed: float = 85.0
@export var run_speed_bonus_ratio: float = 0.735
@export var ground_friction: float = 1600.0
@export var air_accel_scale: float = 0.28
@export var air_no_input_decel_scale: float = 0.2
@export var air_run_carry_threshold: float = 1.05
@export var run_jump_horizontal_mult: float = 1.30

@export_group("Run And Skid")
@export var double_tap_window: float = 0.28
@export var skid_friction: float = 400.0
@export var skid_end_speed: float = 14.0

@export_group("Jump")
@export var gravity_force: float = 1325.0
@export var jump_velocity_full: float = -500.0
@export var jump_cut_release_window: float = 0.05
@export var jump_cut_multiplier: float = 0.36
@export var fall_gravity_scale: float = 1.2

@export_group("Ladder")
@export var climb_speed: float = 200.0
@export var ladder_jump_height_ratio: float = 1.0 / 3.0
@export var platform_drop_duration_sec: float = 0.18
@export var platform_drop_nudge_speed: float = 48.0
@export var character_head_slide_drop_duration_sec: float = 0.12
@export var character_head_slide_nudge_speed: float = 28.0

@export_group("Hit And Launch")
@export var hit_stun_horizontal_decel: float = 3800.0
@export var stun_base_duration_sec: float = 0.22
@export var stun_base_knockback_distance_px: float = 7.0
@export var launch_base_height_px: float = 80.0
@export var launch_base_speed_x: float = 140.0
@export var down_duration_sec: float = 1.0
@export var forced_get_up_height_px: float = 4.0
@export var debug_launch_height_coef: float = 1.0
@export var debug_launch_distance_coef: float = 1.0
@export var hit_flash_duration: float = 0.12
@export var hit_flash_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var max_hp: float = 100.0
@export var max_mp: float = 100.0
@export var base_mp_regen_per_sec: float = 0.0
@export var debug_hit_damage: float = 10.0
@export var skill_zc_mp_cost: float = 10.0
@export var zxc_input_link_window: float = 0.06
@export var buff_eye_trail_max_points: int = 8
@export var buff_eye_glow_color: Color = Color(0.35, 0.75, 1.0, 0.95)
@export var buff_eye_trail_color: Color = Color(0.2, 0.65, 1.0, 0.75)
@export var buff_eye_trail_dot_scale_start: float = 1.0
@export var buff_eye_trail_dot_scale_end: float = 0.35
@export var buff_eye_afterimage_interval: float = 0.04
@export var buff_eye_afterimage_lifetime: float = 0.32

@export_group("Grabbed")
@export var grabbed_slot_offset_x: float = 40.0
@export var grabbed_slot_offset_y: float = -30.0

@export_group("Guard")
@export_range(0.0, 1.0, 0.01) var guard_damage_reduction_ratio: float = 0.9
@export var guard_counter_window_sec: float = 0.2
@export var guard_input_link_window: float = 0.05

@export_group("Potion")
@export var potion_use_default_startup_sec: float = 3.0
@export var potion_use_icon_offset: Vector2 = Vector2(0.0, -56.0)
@export var potion_use_icon_scale: float = 0.6

@export_group("Character Attributes")
@export_enum("MartialArtist") var starting_profession: int = 0
@export var starting_free_stat_points: int = 0
@export var spawn_runtime_attribute_debug_panel: bool = true
@export var spawn_runtime_battle_inventory_panel: bool = true
@export var spawn_runtime_battle_death_overlay: bool = true
@export var fall_death_y: float = 100000.0

@export_group("Networking")
@export var enable_local_input: bool = true
@export var network_replica_mode: bool = false
@export var use_account_runtime_state: bool = true
@export var use_inventory_runtime_state: bool = true
@export var default_network_weapon_scene_path: String = ""
@export var network_snapshot_interval_sec: float = 0.05
@export var network_combat_snapshot_interval_sec: float = 0.016
@export var network_combat_snapshot_boost_duration_sec: float = 0.2
@export var network_interpolation_speed: float = 14.0

@onready var visuals: Node2D = $Visuals
@onready var body_pivot: Node2D = $Visuals/BodyPivot
@onready var torso: Node2D = $Visuals/BodyPivot/Torso
@onready var head_pivot: Node2D = $Visuals/BodyPivot/HeadPivot
@onready var head_sprite: Sprite2D = $Visuals/BodyPivot/HeadPivot/Head
@onready var left_leg_pivot: Node2D = $Visuals/BodyPivot/LeftLegPivot
@onready var right_leg_pivot: Node2D = $Visuals/BodyPivot/RightLegPivot
@onready var weapon_anchor: Marker2D = $Visuals/BodyPivot/WeaponAnchor
@onready var left_eye_glow: Polygon2D = $Visuals/BodyPivot/HeadPivot/EyeEffects/LeftEyeGlow
@onready var right_eye_glow: Polygon2D = $Visuals/BodyPivot/HeadPivot/EyeEffects/RightEyeGlow
@onready var trail_dots_root: Node2D = $Visuals/BodyPivot/HeadPivot/EyeEffects/TrailDots
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var ground_check: RayCast2D = $GroundCheck
@onready var ladder_detector: Area2D = $LadderDetector
@onready var overlap_probe: Area2D = $OverlapProbe
@onready var hp_fill: ColorRect = $StatusBars/HpBar/HpFill
@onready var mp_fill: ColorRect = $StatusBars/MpBar/MpFill
@onready var screen_hud: CanvasLayer = $ScreenHud
@onready var mastery_exp_bar: Control = $ScreenHud/BottomExpBars/MasteryExpBar
@onready var mastery_exp_fill: ColorRect = $ScreenHud/BottomExpBars/MasteryExpBar/Fill
@onready var mastery_ticks: Control = $ScreenHud/BottomExpBars/MasteryExpBar/Ticks
@onready var spec_exp_bar: Control = $ScreenHud/BottomExpBars/SpecExpBar
@onready var spec_exp_fill: ColorRect = $ScreenHud/BottomExpBars/SpecExpBar/Fill
@onready var spec_ticks: Control = $ScreenHud/BottomExpBars/SpecExpBar/Ticks
@onready var battle_hud_portrait: TextureRect = $ScreenHud/BattleInfoCard/PortraitFrame/Portrait
@onready var battle_weapon_value_label: Label = $ScreenHud/BattleInfoCard/WeaponValue
@onready var battle_spec_value_label: Label = $ScreenHud/BattleInfoCard/SpecValue
@onready var battle_mastery_value_label: Label = $ScreenHud/BattleInfoCard/MasteryValue
@onready var battle_hp_fill: ColorRect = $ScreenHud/BattleInfoCard/HpBar/Fill
@onready var battle_hp_value_label: Label = $ScreenHud/BattleInfoCard/HpValue
@onready var battle_mp_fill: ColorRect = $ScreenHud/BattleInfoCard/MpBar/Fill
@onready var battle_mp_value_label: Label = $ScreenHud/BattleInfoCard/MpValue

var _top_state: TopState = TopState.OPERABLE
var _move_phase: MovePhase = MovePhase.GROUND
var _run_active := false
var _run_sign := 1
var _input_x := 0
var _input_y := 0
var _air_speed_cap := 0.0
var _jump_started_at := -1.0
var _last_left_press_at := -10.0
var _last_right_press_at := -10.0
var _stun_timer := 0.0
var _stun_from_launch := false
var _launch_has_left_floor := false
var _down_timer := 0.0
var _ladder_snap_x := 0.0
var _ladder_reentry_locked := false
var _external_action_lock := false
var _grabber: Node2D
var _current_animation := ""
var _stun_airborne := false
var _hit_flash_timer := 0.0
var _air_stun_freeze_timer := 0.0
var _equipped_weapon: Node2D
var _attack_motion_timer := 0.0
var _attack_motion_speed := 0.0
var _attack_motion_sign := 0
var _weapon_attack_locked := false
var _weapon_attack_hold_run := false
var _weapon_startup_hold_timer := 0.0
var _platform_drop_timer := 0.0
var _character_drop_timer := 0.0
var _standing_on_platform := false
var _last_received_damage_raw := 0.0
var _last_received_damage_final := 0.0
var _current_hp := 100.0
var _current_mp := 100.0
var _infinite_mp := false
var _grabbed_slot_offset := Vector2.ZERO
var _pending_z_skill_method: StringName = &""
var _pending_z_skill_expire_at := 0.0
var _attack_buff_visual_active := false
var _left_eye_trail_dots: Array[Polygon2D] = []
var _right_eye_trail_dots: Array[Polygon2D] = []
var _left_eye_afterimages: Array[Dictionary] = []
var _right_eye_afterimages: Array[Dictionary] = []
var _eye_afterimage_timer := 0.0
var _guard_active := false
var _guard_counter_timer := 0.0
var _guard_counter_light_count := 0
var _guard_counter_heavy_count := 0
var _guard_counter_ready := false
var _super_armor_active := false
var _pending_plain_action_method: StringName = &""
var _pending_plain_action_expire_at := 0.0
var _potion_use_active := false
var _potion_use_timer := 0.0
var _potion_use_item: Dictionary = {}
var _potion_use_icon_sprite: Sprite2D
var _death_overlay: Control
var _movement_speed_modifiers: Dictionary = {}
var _jump_height_modifiers: Dictionary = {}
var _attribute_profile: PlayerAttributeProfile
var _equipped_weapon_scene_path := ""
var _network_snapshot_timer := 0.0
var _network_combat_snapshot_boost_timer := 0.0
var _network_received_state: Dictionary = {}
var _network_state_ready := false


func _ready() -> void:
	_ensure_input_actions()
	_setup_attribute_profile()
	_air_speed_cap = get_attribute_walk_speed()
	_current_hp = get_effective_max_hp()
	_current_mp = get_effective_max_mp()
	reset_visual_pose()
	update_facing(facing)
	apply_collision_profile()
	_setup_network_presentation()
	_setup_battle_info_card()
	_setup_screen_exp_ticks()
	update_animation_state()
	update_status_bars()
	attribute_profile_changed.emit(get_attribute_snapshot())
	_setup_eye_trail_dots()
	_setup_potion_use_icon()
	_refresh_buff_eye_visuals()
	if use_inventory_runtime_state:
		_connect_inventory_runtime_signals()
		_sync_equipped_weapon_from_inventory_runtime()
	elif not default_network_weapon_scene_path.is_empty():
		equip_weapon_scene_path(default_network_weapon_scene_path)
	_ensure_runtime_attribute_debug_panel()
	call_deferred("_ensure_runtime_battle_inventory_panel")
	call_deferred("_ensure_runtime_battle_death_overlay")


func _physics_process(delta: float) -> void:
	if network_replica_mode:
		_physics_process_network_replica(delta)
		return

	_physics_process_local(delta)
	_broadcast_network_snapshot(delta)


func _physics_process_local(delta: float) -> void:
	if _top_state != TopState.DEAD and global_position.y >= fall_death_y:
		enter_dead()

	var was_on_floor := is_on_floor()
	_platform_drop_timer = maxf(0.0, _platform_drop_timer - delta)
	_character_drop_timer = maxf(0.0, _character_drop_timer - delta)
	_weapon_startup_hold_timer = maxf(0.0, _weapon_startup_hold_timer - delta)
	_guard_counter_timer = maxf(0.0, _guard_counter_timer - delta)
	_network_combat_snapshot_boost_timer = maxf(0.0, _network_combat_snapshot_boost_timer - delta)
	if _guard_counter_timer <= 0.0:
		_reset_guard_counter_window()
	if _pending_plain_action_method != &"" and get_time_seconds() >= _pending_plain_action_expire_at:
		_consume_pending_plain_action()

	cache_input()
	refresh_ladder_state()
	handle_potion_input()
	handle_debug_weapon_inputs()
	handle_debug_hit_inputs()
	update_potion_use_state(delta)
	update_hit_flash(delta)
	_apply_passive_mp_regen(delta)
	update_attack_buff_visuals()

	if _top_state == TopState.GRABBED:
		update_grabbed_state()
		update_animation_state()
		return

	if _top_state == TopState.OPERABLE and _move_phase != MovePhase.CLIMB and not was_on_floor and _move_phase != MovePhase.AIR:
		stop_guard()
		_exit_run_state()
		_move_phase = MovePhase.AIR
		_air_speed_cap = compute_fall_air_cap()

	match _top_state:
		TopState.OPERABLE:
			physics_operable(delta, was_on_floor)
		TopState.STUN:
			physics_stun(delta)
		TopState.LAUNCH:
			physics_launch(delta)
		TopState.DOWN:
			physics_down(delta)
		TopState.DEAD:
			physics_dead(delta)

	apply_attack_motion_velocity(delta)
	apply_collision_profile()
	move_and_slide()

	if _move_phase == MovePhase.CLIMB:
		global_position.x = _ladder_snap_x

	post_move_update()
	update_animation_state()


func _physics_process_network_replica(delta: float) -> void:
	if not _network_state_ready:
		update_animation_state()
		update_status_bars()
		return

	var target_position := _get_network_state_vector2("position", global_position)
	var target_velocity := _get_network_state_vector2("velocity", velocity)
	var follow_weight := clampf(delta * network_interpolation_speed, 0.0, 1.0)

	global_position = global_position.lerp(target_position, follow_weight)
	if global_position.distance_to(target_position) <= 0.5:
		global_position = target_position
	velocity = target_velocity
	_current_hp = _get_network_state_float("current_hp", _current_hp)
	_current_mp = _get_network_state_float("current_mp", _current_mp)
	_hit_flash_timer = _get_network_state_float("hit_flash_timer", _hit_flash_timer)
	_run_active = _get_network_state_bool("run_active", false)
	_input_x = _get_network_state_int("input_x", 0)
	_top_state = _get_network_state_int("top_state", TopState.OPERABLE)
	_move_phase = _get_network_state_int("move_phase", MovePhase.GROUND)
	_stun_airborne = _top_state == TopState.STUN and not _get_network_state_bool("on_floor", true)
	update_facing(_get_network_state_int("facing", facing))
	_sync_network_weapon_scene(_get_network_state_string("weapon_scene_path", _equipped_weapon_scene_path))
	apply_collision_profile()
	update_animation_state()
	update_status_bars()


func _setup_network_presentation() -> void:
	if screen_hud != null:
		screen_hud.visible = enable_local_input and not network_replica_mode


func _broadcast_network_snapshot(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or network_replica_mode or not is_multiplayer_authority():
		return

	_network_snapshot_timer = maxf(0.0, _network_snapshot_timer - delta)
	if _network_snapshot_timer > 0.0:
		return

	_network_snapshot_timer = _get_active_network_snapshot_interval()
	receive_network_snapshot.rpc(_build_network_snapshot())


func _broadcast_network_snapshot_immediately() -> void:
	if not multiplayer.has_multiplayer_peer() or network_replica_mode or not is_multiplayer_authority():
		return

	_network_snapshot_timer = _get_active_network_snapshot_interval()
	receive_network_snapshot.rpc(_build_network_snapshot())


func _build_network_snapshot() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"facing": facing,
		"top_state": int(_top_state),
		"move_phase": int(_move_phase),
		"run_active": _run_active,
		"input_x": _input_x,
		"on_floor": is_on_floor(),
		"current_hp": _current_hp,
		"current_mp": _current_mp,
		"hit_flash_timer": _hit_flash_timer,
		"weapon_scene_path": _equipped_weapon_scene_path,
	}


func _get_active_network_snapshot_interval() -> float:
	if _should_use_fast_network_snapshot():
		return maxf(network_combat_snapshot_interval_sec, 0.008)
	return maxf(network_snapshot_interval_sec, 0.02)


func _should_use_fast_network_snapshot() -> bool:
	if _network_combat_snapshot_boost_timer > 0.0:
		return true
	if _weapon_attack_locked or _attack_motion_timer > 0.0 or _weapon_startup_hold_timer > 0.0:
		return true
	if _guard_active:
		return true
	if _top_state != TopState.OPERABLE:
		return true
	return absf(velocity.y) > 45.0


func _boost_network_snapshot_priority(duration_sec: float = -1.0, broadcast_now: bool = false) -> void:
	if duration_sec <= 0.0:
		duration_sec = network_combat_snapshot_boost_duration_sec
	_network_combat_snapshot_boost_timer = maxf(_network_combat_snapshot_boost_timer, duration_sec)
	if broadcast_now:
		_broadcast_network_snapshot_immediately()


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_network_snapshot(snapshot: Dictionary) -> void:
	if not network_replica_mode:
		return

	_network_received_state = snapshot.duplicate(true)
	_network_state_ready = true
	_sync_network_weapon_scene(_get_network_state_string("weapon_scene_path", _equipped_weapon_scene_path))


func _sync_network_weapon_scene(scene_path: String) -> void:
	if scene_path == _equipped_weapon_scene_path:
		return
	if scene_path.is_empty():
		unequip_weapon()
		return
	equip_weapon_scene_path(scene_path)


func _get_network_state_vector2(key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _network_received_state.get(key, fallback)
	return value if value is Vector2 else fallback


func _get_network_state_float(key: String, fallback: float) -> float:
	return float(_network_received_state.get(key, fallback))


func _get_network_state_int(key: String, fallback: int) -> int:
	return int(_network_received_state.get(key, fallback))


func _get_network_state_bool(key: String, fallback: bool) -> bool:
	return bool(_network_received_state.get(key, fallback))


func _get_network_state_string(key: String, fallback: String) -> String:
	return String(_network_received_state.get(key, fallback))


func _node_to_path_string(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	return str(node.get_path())


func _resolve_node_from_path_string(node_path: String) -> Node:
	if node_path.is_empty():
		return null
	return get_node_or_null(NodePath(node_path))


func _is_rpc_from_server() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.get_remote_sender_id() == 1


@rpc("any_peer", "call_remote", "reliable")
func request_player_receive_weapon_hit(attack_data: Dictionary, source_path: String) -> void:
	if not multiplayer.is_server():
		return
	receive_weapon_hit(attack_data, _resolve_node_from_path_string(source_path))


@rpc("any_peer", "call_remote", "reliable")
func server_apply_authoritative_weapon_hit(attack_data: Dictionary, source_path: String) -> void:
	if not _is_rpc_from_server():
		return
	_apply_received_weapon_hit_local(attack_data, _resolve_node_from_path_string(source_path))


@rpc("any_peer", "call_remote", "reliable")
func request_player_receive_grabbed_weapon_hit(attack_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	receive_grabbed_weapon_hit(attack_data, null)


@rpc("any_peer", "call_remote", "reliable")
func server_apply_authoritative_grabbed_weapon_hit(attack_data: Dictionary) -> void:
	if not _is_rpc_from_server():
		return
	_apply_received_grabbed_weapon_hit_local(attack_data)


@rpc("any_peer", "call_remote", "reliable")
func request_player_apply_stun_from_source(source_is_on_left: bool, duration_sec: float) -> void:
	if not multiplayer.is_server():
		return
	apply_stun_from_source(source_is_on_left, duration_sec)


@rpc("any_peer", "call_remote", "reliable")
func server_apply_authoritative_stun_from_source(source_is_on_left: bool, duration_sec: float) -> void:
	if not _is_rpc_from_server():
		return
	_apply_stun_from_source_local(source_is_on_left, duration_sec)


@rpc("any_peer", "call_remote", "reliable")
func request_player_apply_launch_by_distance(source_is_on_left: bool, height_px: float, distance_px: float) -> void:
	if not multiplayer.is_server():
		return
	apply_launch_by_distance_from_source(source_is_on_left, height_px, distance_px)


@rpc("any_peer", "call_remote", "reliable")
func server_apply_authoritative_launch_by_distance(source_is_on_left: bool, height_px: float, distance_px: float) -> void:
	if not _is_rpc_from_server():
		return
	_apply_launch_by_distance_local(source_is_on_left, height_px, distance_px)


@rpc("any_peer", "call_remote", "reliable")
func request_player_enter_grabbed_by(grabber_path: String, slot_offset: Vector2) -> void:
	if not multiplayer.is_server():
		return
	enter_grabbed_by(_resolve_node_from_path_string(grabber_path) as Node2D, slot_offset)


@rpc("any_peer", "call_remote", "reliable")
func server_enter_authoritative_grabbed(grabber_path: String, slot_offset: Vector2) -> void:
	if not _is_rpc_from_server():
		return
	_enter_grabbed_by_local(_resolve_node_from_path_string(grabber_path) as Node2D, slot_offset)


@rpc("any_peer", "call_remote", "reliable")
func request_player_release_grabbed() -> void:
	if not multiplayer.is_server():
		return
	release_grabbed()


@rpc("any_peer", "call_remote", "reliable")
func server_release_authoritative_grabbed() -> void:
	if not _is_rpc_from_server():
		return
	_release_grabbed_local()


@rpc("any_peer", "call_remote", "reliable")
func server_apply_authoritative_respawn(respawn_position: Vector2, restore_full_resources: bool = true) -> void:
	if not _is_rpc_from_server():
		return
	_respawn_at_local(respawn_position, restore_full_resources)


func _should_broadcast_combat_state() -> bool:
	return multiplayer.has_multiplayer_peer() and is_multiplayer_authority()


func can_resolve_network_combat_hits() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _invoke_weapon_action(method_name: StringName, hold_run: bool = false, broadcast: bool = true) -> bool:
	if _equipped_weapon == null or not _equipped_weapon.has_method(method_name):
		return false
	if hold_run:
		_weapon_attack_hold_run = true
	_equipped_weapon.call(method_name)
	if broadcast and _should_broadcast_combat_state():
		_boost_network_snapshot_priority()
		sync_weapon_action.rpc(String(method_name), hold_run)
		_broadcast_network_snapshot_immediately()
	return true


@rpc("authority", "call_remote", "unreliable_ordered")
func sync_weapon_action(method_name: String, hold_run: bool = false) -> void:
	_invoke_weapon_action(StringName(method_name), hold_run, false)


func _set_guard_state(active: bool, broadcast: bool = true) -> void:
	if active:
		if _guard_active:
			return
		_guard_active = true
		_reset_guard_counter_window()
		_exit_run_state()
		velocity.x = 0.0
		if _equipped_weapon != null and _equipped_weapon.has_method("start_guard_hold"):
			_equipped_weapon.call("start_guard_hold")
	else:
		if not _guard_active:
			return
		_guard_active = false
		if _equipped_weapon != null and _equipped_weapon.has_method("stop_guard_hold"):
			_equipped_weapon.call("stop_guard_hold")

	if broadcast and _should_broadcast_combat_state():
		_boost_network_snapshot_priority()
		sync_guard_state.rpc(active)
		_broadcast_network_snapshot_immediately()


@rpc("authority", "call_remote", "unreliable_ordered")
func sync_guard_state(active: bool) -> void:
	_set_guard_state(active, false)


func physics_operable(delta: float, was_on_floor: bool) -> void:
	if _move_phase == MovePhase.CLIMB:
		physics_climb()
		return

	try_drop_through_platform()

	try_enter_climb()
	if _move_phase == MovePhase.CLIMB:
		physics_climb()
		return

	handle_double_tap()

	if was_on_floor and Input.is_action_just_pressed("move_jump"):
		begin_ground_jump()

	if _move_phase == MovePhase.AIR or not was_on_floor:
		physics_air(delta)
	elif _move_phase == MovePhase.RUN_SKID:
		physics_run_skid(delta)
	else:
		physics_ground(delta)

	handle_jump_cut()


func physics_ground(delta: float) -> void:
	if _guard_active:
		_exit_run_state()
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * 2.0 * delta)
		velocity.y = 0.0
		return

	if _run_active:
		if _weapon_attack_hold_run:
			velocity.x = _run_sign * get_max_run_speed()
			update_facing(_run_sign)
			velocity.y = 0.0
			return

		if _input_x == 0:
			start_run_skid()
			physics_run_skid(delta)
			return

		if _input_x == _run_sign:
			velocity.x = move_toward(velocity.x, _run_sign * get_max_run_speed(), get_effective_walk_accel() * delta)
		else:
			_run_sign = _input_x
			velocity.x = _run_sign * get_max_run_speed()

		update_facing(_run_sign)
		return

	if _input_x != 0:
		velocity.x = move_toward(velocity.x, _input_x * get_effective_walk_speed(), get_effective_walk_accel() * delta)
		update_facing(_input_x)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	velocity.y = 0.0


func physics_run_skid(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, skid_friction * delta)
	if absf(velocity.x) <= skid_end_speed:
		velocity.x = 0.0
		_move_phase = MovePhase.GROUND

	velocity.y = 0.0


func physics_air(delta: float) -> void:
	_move_phase = MovePhase.AIR
	stop_guard()
	_exit_run_state()

	if _weapon_startup_hold_timer > 0.0:
		velocity = Vector2.ZERO
		return

	var target_speed := float(_input_x) * get_effective_air_speed_cap()
	var accel := get_effective_walk_accel() * air_no_input_decel_scale
	if _input_x != 0:
		accel = get_effective_walk_accel() * air_accel_scale
		update_facing(_input_x)

	velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	velocity.y += get_effective_gravity() * delta


func physics_climb() -> void:
	if not has_ladder_overlap():
		exit_climb_to_air(get_attribute_walk_speed())
		return

	global_position.x = _ladder_snap_x

	if Input.is_action_just_pressed("move_jump"):
		start_ladder_jump()
		return

	velocity = Vector2(0.0, -float(_input_y) * get_effective_climb_speed())


func physics_stun(delta: float) -> void:
	_stun_timer = maxf(0.0, _stun_timer - delta)
	velocity.x = move_toward(velocity.x, 0.0, get_stun_knockback_decel() * delta)

	if _stun_airborne:
		if _air_stun_freeze_timer > 0.0:
			_air_stun_freeze_timer = maxf(0.0, _air_stun_freeze_timer - delta)
			velocity.y = 0.0
		else:
			velocity.y += get_effective_gravity() * delta
	else:
		velocity.y = 0.0

	if _stun_airborne and _stun_timer <= 0.0:
		_stun_timer = 0.0
		return

	if _stun_timer <= 0.0:
		_top_state = TopState.OPERABLE
		velocity.x = 0.0
		_move_phase = MovePhase.GROUND if is_on_floor() else MovePhase.AIR
		_stun_from_launch = false
		_stun_airborne = false
		_air_stun_freeze_timer = 0.0


func physics_launch(delta: float) -> void:
	_move_phase = MovePhase.AIR
	velocity.y += get_effective_gravity() * delta


func physics_down(delta: float) -> void:
	_down_timer = maxf(0.0, _down_timer - delta)
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	if not is_on_floor():
		velocity.y += get_effective_gravity() * delta
	else:
		velocity.y = 0.0

	if _down_timer <= 0.0:
		_top_state = TopState.OPERABLE
		_move_phase = MovePhase.GROUND if is_on_floor() else MovePhase.AIR
		resolve_overlap_after_get_up()


func physics_dead(delta: float) -> void:
	_exit_run_state()
	velocity.x = 0.0
	if not is_on_floor():
		_move_phase = MovePhase.AIR
		velocity.y += get_effective_gravity() * delta
	else:
		_move_phase = MovePhase.GROUND
		velocity.y = 0.0


func post_move_update() -> void:
	_update_platform_floor_state()

	if _equipped_weapon != null and is_on_floor() and _equipped_weapon.has_method("is_air_heavy_attack_active") and _equipped_weapon.call("is_air_heavy_attack_active"):
		_invoke_weapon_action(&"finish_air_heavy_attack_x")

	if _top_state == TopState.OPERABLE:
		if _move_phase != MovePhase.CLIMB and _is_standing_on_character():
			_begin_character_head_slide()

		if _character_drop_timer <= 0.0 and _move_phase == MovePhase.AIR and is_on_floor():
			_move_phase = MovePhase.GROUND
			velocity.y = 0.0

		if _character_drop_timer <= 0.0 and _move_phase != MovePhase.CLIMB and is_on_floor():
			cancel_platform_sticky()
	elif _top_state == TopState.LAUNCH:
		if not is_on_floor():
			_launch_has_left_floor = true
		elif _launch_has_left_floor and velocity.y > -2.0:
			enter_down()
	elif _top_state == TopState.STUN and _stun_airborne:
		if not is_on_floor():
			_launch_has_left_floor = true
		elif _launch_has_left_floor and velocity.y > -2.0:
			enter_down()
	elif _top_state == TopState.DEAD and is_on_floor():
		velocity.y = 0.0

	if not has_ladder_overlap():
		_ladder_reentry_locked = false


func handle_double_tap() -> void:
	if _top_state != TopState.OPERABLE or _move_phase == MovePhase.CLIMB or not is_on_floor():
		return

	var now := get_time_seconds()
	if Input.is_action_just_pressed("move_left"):
		if now - _last_left_press_at <= double_tap_window:
			enter_run(-1)
		_last_left_press_at = now
	elif Input.is_action_just_pressed("move_right"):
		if now - _last_right_press_at <= double_tap_window:
			enter_run(1)
		_last_right_press_at = now


func begin_ground_jump() -> void:
	var run_jump := _run_active or _move_phase == MovePhase.RUN_SKID
	var horizontal_sign := facing

	if _input_x != 0:
		horizontal_sign = _input_x
	elif absf(velocity.x) > 0.1:
		horizontal_sign = sign_to_int(velocity.x)

	velocity.y = jump_velocity_full * get_jump_height_scale()
	_jump_started_at = get_time_seconds()
	_move_phase = MovePhase.AIR

	if run_jump:
		var carry_speed := maxf(absf(velocity.x), get_max_run_speed()) * run_jump_horizontal_mult
		_air_speed_cap = get_base_run_speed() * run_jump_horizontal_mult
		velocity.x = float(horizontal_sign) * carry_speed
	else:
		_air_speed_cap = get_attribute_walk_speed()


func handle_jump_cut() -> void:
	if _move_phase != MovePhase.AIR:
		return

	if not Input.is_action_just_released("move_jump"):
		return

	if _jump_started_at < 0.0:
		return

	if get_time_seconds() - _jump_started_at > jump_cut_release_window:
		return

	if velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func try_enter_climb() -> void:
	if _top_state != TopState.OPERABLE or _move_phase == MovePhase.CLIMB:
		return
	if _guard_active:
		return

	if _ladder_reentry_locked or not has_ladder_overlap():
		return

	if _input_y == 0:
		return

	var ladder_area := get_primary_ladder_area()
	if ladder_area == null:
		return

	_ladder_snap_x = ladder_area.global_position.x
	global_position.x = _ladder_snap_x
	velocity = Vector2.ZERO
	_move_phase = MovePhase.CLIMB
	_exit_run_state()
	_ladder_reentry_locked = true


func exit_climb_to_air(air_cap: float) -> void:
	_move_phase = MovePhase.AIR
	_air_speed_cap = air_cap


func start_ladder_jump() -> void:
	var jump_sign := facing
	if _input_x != 0:
		jump_sign = _input_x

	_move_phase = MovePhase.AIR
	_air_speed_cap = get_base_run_speed()
	velocity.x = float(jump_sign) * get_max_run_speed()
	velocity.y = jump_velocity_full * get_jump_height_scale() * sqrt(ladder_jump_height_ratio)
	_jump_started_at = get_time_seconds()
	update_facing(jump_sign)


func start_run_skid() -> void:
	if not _run_active and _move_phase != MovePhase.RUN_SKID:
		return

	_exit_run_state()
	if absf(velocity.x) > skid_end_speed:
		_move_phase = MovePhase.RUN_SKID
	else:
		_move_phase = MovePhase.GROUND
		velocity.x = 0.0


func enter_run(direction: int) -> void:
	_run_active = true
	_run_sign = sign_to_int(direction)
	_move_phase = MovePhase.GROUND
	update_facing(_run_sign)


func _exit_run_state() -> void:
	_run_active = false


func _setup_attribute_profile() -> void:
	_attribute_profile = PlayerAttributeProfile.new()
	if not use_account_runtime_state:
		_attribute_profile.set_profession(starting_profession)
		if starting_free_stat_points > 0:
			_attribute_profile.add_free_stat_points(starting_free_stat_points)
		return

	var account_runtime: Node = get_node_or_null("/root/AccountRuntime")
	if account_runtime != null \
			and account_runtime.has_method("is_logged_in") \
			and bool(account_runtime.call("is_logged_in")) \
			and account_runtime.has_method("get_current_profile_state"):
		var profile_state: Dictionary = account_runtime.call("get_current_profile_state") as Dictionary
		if not profile_state.is_empty():
			_attribute_profile.load_persisted_state(profile_state)
			return

	_attribute_profile.set_profession(starting_profession)
	if starting_free_stat_points > 0:
		_attribute_profile.add_free_stat_points(starting_free_stat_points)


func _connect_inventory_runtime_signals() -> void:
	if not use_inventory_runtime_state:
		return

	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if inventory_runtime == null or not inventory_runtime.has_signal("equipped_weapon_changed"):
		return

	var callback := Callable(self, "_on_inventory_equipped_weapon_changed")
	if not inventory_runtime.is_connected("equipped_weapon_changed", callback):
		inventory_runtime.connect("equipped_weapon_changed", callback)


func _on_inventory_equipped_weapon_changed(_item: Dictionary = {}) -> void:
	_sync_equipped_weapon_from_inventory_runtime()


func _sync_equipped_weapon_from_inventory_runtime() -> void:
	if not use_inventory_runtime_state:
		if not default_network_weapon_scene_path.is_empty():
			equip_weapon_scene_path(default_network_weapon_scene_path)
		return

	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if inventory_runtime == null or not inventory_runtime.has_method("get_equipped_weapon"):
		return

	var equipped_item: Dictionary = inventory_runtime.call("get_equipped_weapon") as Dictionary
	var scene_path: String = String(equipped_item.get("scene_path", ""))
	if scene_path.is_empty():
		unequip_weapon()
		return
	equip_weapon_scene_path(scene_path, equipped_item)


func _ensure_runtime_attribute_debug_panel() -> void:
	if not spawn_runtime_attribute_debug_panel:
		return
	for child in get_children():
		if child.name == "BattleAttributeDebugPanel":
			return

	var panel: CanvasLayer = BATTLE_ATTRIBUTE_DEBUG_PANEL_SCENE.instantiate() as CanvasLayer
	if panel == null:
		return
	panel.name = "BattleAttributeDebugPanel"
	panel.set("player_path", NodePath(".."))
	add_child(panel)


func _ensure_runtime_battle_inventory_panel() -> void:
	if not spawn_runtime_battle_inventory_panel:
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var existing_panel: Node = current_scene.find_child("BattleInventoryPanel", true, false)
	if existing_panel != null:
		existing_panel.set("player_path", get_path())
		return

	var panel: Control = BATTLE_INVENTORY_PANEL_SCENE.instantiate() as Control
	if panel == null:
		return
	panel.name = "BattleInventoryPanel"
	var panel_parent: Node = current_scene.find_child("UiLayer", true, false)
	if panel_parent == null:
		var runtime_ui_layer := CanvasLayer.new()
		runtime_ui_layer.name = "RuntimeUiLayer"
		current_scene.add_child(runtime_ui_layer)
		panel_parent = runtime_ui_layer
	panel_parent.add_child(panel)
	panel.set("player_path", get_path())


func _ensure_runtime_battle_death_overlay() -> void:
	if not spawn_runtime_battle_death_overlay:
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var existing_overlay: Node = current_scene.find_child("BattleDeathOverlay", true, false)
	if existing_overlay is Control:
		_death_overlay = existing_overlay as Control
		if _death_overlay.has_method("hide_overlay"):
			_death_overlay.call("hide_overlay")
		return

	var overlay: Control = BATTLE_DEATH_OVERLAY_SCENE.instantiate() as Control
	if overlay == null:
		return

	overlay.name = "BattleDeathOverlay"
	var overlay_parent: Node = current_scene.find_child("UiLayer", true, false)
	if overlay_parent == null:
		overlay_parent = current_scene.find_child("RuntimeUiLayer", true, false)
	if overlay_parent == null:
		var runtime_ui_layer := CanvasLayer.new()
		runtime_ui_layer.name = "RuntimeUiLayer"
		current_scene.add_child(runtime_ui_layer)
		overlay_parent = runtime_ui_layer
	overlay_parent.add_child(overlay)
	_death_overlay = overlay
	if _death_overlay.has_method("hide_overlay"):
		_death_overlay.call("hide_overlay")


func get_attribute_snapshot() -> Dictionary:
	if _attribute_profile == null:
		return {}

	var snapshot := _attribute_profile.build_snapshot()
	snapshot["equipment_bonus_stats"] = _build_equipment_bonus_snapshot()
	snapshot["effective_total_stats"] = _build_effective_total_stats_snapshot()
	snapshot["effective_max_hp"] = get_effective_max_hp()
	snapshot["effective_max_mp"] = get_effective_max_mp()
	snapshot["current_hp"] = _current_hp
	snapshot["current_mp"] = _current_mp
	return snapshot


func get_profession_name() -> String:
	if _attribute_profile == null:
		return ""
	return _attribute_profile.get_profession_name()


func get_free_stat_points() -> int:
	if _attribute_profile == null:
		return 0
	return _attribute_profile.get_free_stat_points()


func add_free_stat_points(amount: int) -> void:
	if _attribute_profile == null or amount <= 0:
		return

	var old_max_hp := get_effective_max_hp()
	var old_max_mp := get_effective_max_mp()
	_attribute_profile.add_free_stat_points(amount)
	_apply_attribute_runtime_refresh(old_max_hp, old_max_mp)
	_persist_account_profile_state()


func allocate_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	if _attribute_profile == null:
		return false

	var old_max_hp := get_effective_max_hp()
	var old_max_mp := get_effective_max_mp()
	var spent := _attribute_profile.spend_free_stat_points(attribute_id, amount)
	if not spent:
		return false

	_apply_attribute_runtime_refresh(old_max_hp, old_max_mp)
	_persist_account_profile_state()
	return true


func refund_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	if _attribute_profile == null:
		return false

	var old_max_hp := get_effective_max_hp()
	var old_max_mp := get_effective_max_mp()
	var refunded := _attribute_profile.refund_free_stat_points(attribute_id, amount)
	if not refunded:
		return false

	_apply_attribute_runtime_refresh(old_max_hp, old_max_mp)
	_persist_account_profile_state()
	return true


func get_total_attribute_value(attribute_id: StringName) -> int:
	var profile_total: int = 0
	if _attribute_profile != null:
		profile_total = _attribute_profile.get_total_stat(attribute_id)
	return profile_total + get_equipped_weapon_attribute_bonus(attribute_id)


func get_attack_attribute_damage_multiplier() -> float:
	return 1.0 + 0.1 * float(get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_ATTACK))


func get_attribute_movement_speed_scale() -> float:
	return 1.0 + 0.02 * float(get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_AGILITY))


func get_attribute_acceleration_multiplier() -> float:
	var agility_total: float = float(get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_AGILITY))
	var acceleration_time_scale: float = clampf(1.0 - 0.1 * agility_total, 0.1, 1.0)
	if acceleration_time_scale <= 0.0:
		return 1.0
	return 1.0 / acceleration_time_scale


func get_effective_max_hp() -> float:
	return max_hp * (1.0 + 0.1 * float(get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_VITALITY)))


func get_effective_max_mp() -> float:
	return max_mp + float(get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_SPIRIT))


func get_effective_mp_regen_per_sec() -> float:
	return maxf(0.0, base_mp_regen_per_sec) + float(get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_SPIRIT))


func get_current_hp() -> float:
	return _current_hp


func get_current_mp() -> float:
	return _current_mp


func get_equipped_potion() -> Dictionary:
	if not use_inventory_runtime_state:
		return {}
	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if inventory_runtime != null and inventory_runtime.has_method("get_equipped_potion"):
		return inventory_runtime.call("get_equipped_potion") as Dictionary
	return {}


func is_potion_use_active() -> bool:
	return _potion_use_active


func is_dead() -> bool:
	return _top_state == TopState.DEAD


func get_display_name() -> String:
	if not use_account_runtime_state:
		return "Adventurer"
	var account_runtime: Node = get_node_or_null("/root/AccountRuntime")
	if account_runtime != null and account_runtime.has_method("get_current_display_name"):
		return String(account_runtime.call("get_current_display_name"))
	return "Adventurer"


func get_specialization_level() -> int:
	if _attribute_profile == null:
		return PlayerAttributeProfile.DEFAULT_SPECIALIZATION_LEVEL
	return _attribute_profile.get_specialization_level()


func get_specialization_exp() -> int:
	if _attribute_profile == null:
		return PlayerAttributeProfile.DEFAULT_SPECIALIZATION_EXP
	return _attribute_profile.get_specialization_exp()


func get_specialization_exp_to_next_level() -> int:
	if _attribute_profile == null:
		return 100
	return _attribute_profile.get_specialization_exp_to_next_level()


func get_weapon_mastery_level() -> int:
	if _attribute_profile == null:
		return PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_LEVEL
	return _attribute_profile.get_weapon_mastery_level(get_current_weapon_mastery_track_id())


func get_weapon_mastery_exp() -> int:
	if _attribute_profile == null:
		return PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_EXP
	return _attribute_profile.get_weapon_mastery_exp(get_current_weapon_mastery_track_id())


func get_weapon_mastery_exp_to_next_level() -> int:
	if _attribute_profile == null:
		return 80
	return _attribute_profile.get_weapon_mastery_exp_to_next_level(get_current_weapon_mastery_track_id())


func get_equipped_weapon_node() -> Node2D:
	return _equipped_weapon


func get_current_weapon_mastery_track_id() -> String:
	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if use_inventory_runtime_state and inventory_runtime != null and inventory_runtime.has_method("get_equipped_weapon"):
		var equipped_item: Dictionary = inventory_runtime.call("get_equipped_weapon") as Dictionary
		var mastery_track_id_from_item: String = String(equipped_item.get("weapon_mastery_track_id", ""))
		if not mastery_track_id_from_item.is_empty():
			return mastery_track_id_from_item

	if _equipped_weapon != null and _equipped_weapon.has_method("get_weapon_mastery_track_id"):
		return String(_equipped_weapon.call("get_weapon_mastery_track_id"))

	return PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK


func add_specialization_levels(amount: int) -> void:
	if _attribute_profile == null or amount <= 0:
		return
	_attribute_profile.add_specialization_levels(amount)
	update_status_bars()
	attribute_profile_changed.emit(get_attribute_snapshot())
	_persist_account_profile_state()


func add_specialization_exp(amount: int) -> void:
	if _attribute_profile == null or amount <= 0:
		return
	_attribute_profile.add_specialization_exp(amount)
	update_status_bars()
	attribute_profile_changed.emit(get_attribute_snapshot())
	_persist_account_profile_state()


func add_current_weapon_mastery_levels(amount: int) -> void:
	if _attribute_profile == null or amount <= 0:
		return
	_attribute_profile.add_weapon_mastery_levels(get_current_weapon_mastery_track_id(), amount)
	update_status_bars()
	attribute_profile_changed.emit(get_attribute_snapshot())
	_persist_account_profile_state()


func add_current_weapon_mastery_exp(amount: int) -> void:
	if _attribute_profile == null or amount <= 0:
		return
	_attribute_profile.add_weapon_mastery_exp(get_current_weapon_mastery_track_id(), amount)
	update_status_bars()
	attribute_profile_changed.emit(get_attribute_snapshot())
	_persist_account_profile_state()


func _apply_attribute_runtime_refresh(old_max_hp: float, old_max_mp: float) -> void:
	var new_max_hp := get_effective_max_hp()
	var new_max_mp := get_effective_max_mp()
	var hp_ratio := 1.0
	var mp_ratio := 1.0
	if old_max_hp > 0.0:
		hp_ratio = clampf(_current_hp / old_max_hp, 0.0, 1.0)
	if old_max_mp > 0.0:
		mp_ratio = clampf(_current_mp / old_max_mp, 0.0, 1.0)

	_current_hp = clampf(new_max_hp * hp_ratio, 0.0, new_max_hp)
	_current_mp = clampf(new_max_mp * mp_ratio, 0.0, new_max_mp)
	if _infinite_mp:
		_current_mp = new_max_mp
	if _move_phase == MovePhase.AIR:
		_air_speed_cap = compute_fall_air_cap()
	else:
		_air_speed_cap = get_attribute_walk_speed()

	_clamp_velocity_to_current_movement_caps()
	update_status_bars()
	attribute_profile_changed.emit(get_attribute_snapshot())


func get_equipped_weapon_attribute_bonus(attribute_id: StringName) -> int:
	if _equipped_weapon != null and _equipped_weapon.has_method("get_attribute_bonus_value"):
		return int(_equipped_weapon.call("get_attribute_bonus_value", attribute_id))
	return 0


func _build_equipment_bonus_snapshot() -> Dictionary:
	return {
		String(PlayerAttributeProfile.ATTRIBUTE_ATTACK): get_equipped_weapon_attribute_bonus(PlayerAttributeProfile.ATTRIBUTE_ATTACK),
		String(PlayerAttributeProfile.ATTRIBUTE_AGILITY): get_equipped_weapon_attribute_bonus(PlayerAttributeProfile.ATTRIBUTE_AGILITY),
		String(PlayerAttributeProfile.ATTRIBUTE_VITALITY): get_equipped_weapon_attribute_bonus(PlayerAttributeProfile.ATTRIBUTE_VITALITY),
		String(PlayerAttributeProfile.ATTRIBUTE_SPIRIT): get_equipped_weapon_attribute_bonus(PlayerAttributeProfile.ATTRIBUTE_SPIRIT),
	}


func _build_effective_total_stats_snapshot() -> Dictionary:
	return {
		String(PlayerAttributeProfile.ATTRIBUTE_ATTACK): get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_ATTACK),
		String(PlayerAttributeProfile.ATTRIBUTE_AGILITY): get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_AGILITY),
		String(PlayerAttributeProfile.ATTRIBUTE_VITALITY): get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_VITALITY),
		String(PlayerAttributeProfile.ATTRIBUTE_SPIRIT): get_total_attribute_value(PlayerAttributeProfile.ATTRIBUTE_SPIRIT),
	}


func _persist_account_profile_state() -> void:
	if not use_account_runtime_state:
		return
	var account_runtime: Node = get_node_or_null("/root/AccountRuntime")
	if account_runtime == null \
			or not account_runtime.has_method("is_logged_in") \
			or not bool(account_runtime.call("is_logged_in")) \
			or not account_runtime.has_method("overwrite_current_profile_state") \
			or _attribute_profile == null:
		return
	account_runtime.call("overwrite_current_profile_state", _attribute_profile.export_persisted_state())


func _apply_passive_mp_regen(delta: float) -> void:
	if delta <= 0.0 or _infinite_mp:
		if _infinite_mp:
			var max_effective_mp := get_effective_max_mp()
			if not is_equal_approx(_current_mp, max_effective_mp):
				_current_mp = max_effective_mp
				update_status_bars()
		return

	var regen_per_sec := get_effective_mp_regen_per_sec()
	if regen_per_sec <= 0.0 or _current_mp >= get_effective_max_mp():
		return

	_current_mp = clampf(_current_mp + regen_per_sec * delta, 0.0, get_effective_max_mp())
	update_status_bars()


func get_attribute_walk_speed() -> float:
	return max_walk_speed * get_attribute_movement_speed_scale()


func get_base_run_speed() -> float:
	return get_attribute_walk_speed() * (1.0 + run_speed_bonus_ratio)


func get_movement_speed_scale() -> float:
	var modifier_scale: float = 1.0
	for key in _movement_speed_modifiers.keys():
		modifier_scale *= clampf(float(_movement_speed_modifiers[key]), 0.1, 4.0)
	return clampf(modifier_scale, 0.1, 4.0)


func get_jump_height_scale() -> float:
	var modifier_scale: float = 1.0
	for key in _jump_height_modifiers.keys():
		modifier_scale *= clampf(float(_jump_height_modifiers[key]), 0.1, 4.0)
	return clampf(modifier_scale, 0.1, 4.0)


func get_effective_walk_speed() -> float:
	return get_attribute_walk_speed() * get_movement_speed_scale()


func get_max_run_speed() -> float:
	return get_base_run_speed() * get_movement_speed_scale()


func get_effective_climb_speed() -> float:
	return climb_speed * get_attribute_movement_speed_scale() * get_movement_speed_scale()


func get_effective_walk_accel() -> float:
	return walk_accel * get_attribute_acceleration_multiplier()


func get_effective_air_speed_cap() -> float:
	return _air_speed_cap * get_movement_speed_scale()


func set_movement_speed_modifier(source_key: StringName, modifier_scale: float) -> void:
	if source_key == &"":
		return

	var clamped_scale: float = clampf(modifier_scale, 0.1, 4.0)
	if is_equal_approx(clamped_scale, 1.0):
		_movement_speed_modifiers.erase(source_key)
	else:
		_movement_speed_modifiers[source_key] = clamped_scale
	_clamp_velocity_to_current_movement_caps()


func clear_movement_speed_modifier(source_key: StringName) -> void:
	if source_key == &"":
		return

	_movement_speed_modifiers.erase(source_key)
	_clamp_velocity_to_current_movement_caps()


func set_jump_height_modifier(source_key: StringName, modifier_scale: float) -> void:
	if source_key == &"":
		return

	var clamped_scale: float = clampf(modifier_scale, 0.1, 4.0)
	if is_equal_approx(clamped_scale, 1.0):
		_jump_height_modifiers.erase(source_key)
	else:
		_jump_height_modifiers[source_key] = clamped_scale


func clear_jump_height_modifier(source_key: StringName) -> void:
	if source_key == &"":
		return

	_jump_height_modifiers.erase(source_key)


func _clamp_velocity_to_current_movement_caps() -> void:
	if _move_phase == MovePhase.CLIMB:
		var climb_cap: float = get_effective_climb_speed()
		velocity.y = clampf(velocity.y, -climb_cap, climb_cap)
		return

	var horizontal_cap: float = get_effective_walk_speed()
	if _move_phase == MovePhase.AIR:
		horizontal_cap = get_effective_air_speed_cap()
	elif _run_active or _move_phase == MovePhase.RUN_SKID:
		horizontal_cap = get_max_run_speed()

	velocity.x = signf(velocity.x) * minf(absf(velocity.x), horizontal_cap)


func get_effective_gravity() -> float:
	return gravity_force if velocity.y < 0.0 else gravity_force * fall_gravity_scale


func get_launch_travel_time_for_height(height_px: float) -> float:
	if height_px <= 0.0:
		return 0.0

	var rise_time := sqrt((2.0 * height_px) / gravity_force)
	var fall_time := sqrt((2.0 * height_px) / (gravity_force * fall_gravity_scale))
	return rise_time + fall_time


func compute_fall_air_cap() -> float:
	if absf(velocity.x) > get_effective_walk_speed() * air_run_carry_threshold:
		return get_max_run_speed()
	return get_attribute_walk_speed()


func refresh_ladder_state() -> void:
	if has_ladder_overlap():
		var ladder_area := get_primary_ladder_area()
		if ladder_area != null:
			_ladder_snap_x = ladder_area.global_position.x


func try_drop_through_platform() -> void:
	if _top_state != TopState.OPERABLE:
		return

	if _move_phase == MovePhase.CLIMB or _move_phase == MovePhase.AIR:
		return

	if not _standing_on_platform:
		return

	if not Input.is_action_just_pressed("interact_down"):
		return

	_platform_drop_timer = platform_drop_duration_sec
	_move_phase = MovePhase.AIR
	velocity.y = maxf(velocity.y, platform_drop_nudge_speed)


func has_ladder_overlap() -> bool:
	return ladder_detector.get_overlapping_areas().size() > 0


func get_primary_ladder_area() -> Area2D:
	var areas := ladder_detector.get_overlapping_areas()
	if areas.is_empty():
		return null
	return areas[0]


func cache_input() -> void:
	if _top_state != TopState.OPERABLE or _external_action_lock or _weapon_attack_locked or _guard_active:
		_input_x = 0
		_input_y = 0
		return

	var raw_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var raw_y := Input.get_action_strength("interact_up") - Input.get_action_strength("interact_down")

	_input_x = sign_to_int(raw_x)
	_input_y = sign_to_int(raw_y)


func update_facing(direction: int) -> void:
	if direction == 0:
		return

	facing = sign_to_int(direction)
	visuals.scale.x = facing


func sign_to_int(value: float) -> int:
	if value > 0.0:
		return 1
	if value < 0.0:
		return -1
	return 0


func apply_stun(duration_sec: float) -> void:
	if _top_state == TopState.DOWN or _top_state == TopState.DEAD:
		return

	if _top_state == TopState.LAUNCH and velocity.y > 0.0 and can_forced_get_up():
		var ground_point := ground_check.get_collision_point()
		global_position.y = ground_point.y
		velocity = Vector2.ZERO
		_move_phase = MovePhase.GROUND
		_launch_has_left_floor = false
		_stun_from_launch = false
		enter_stun(duration_sec, false)
		return

	var airborne_stun := not is_on_floor() or _move_phase == MovePhase.AIR or _move_phase == MovePhase.CLIMB or _top_state == TopState.LAUNCH
	enter_stun(duration_sec, airborne_stun)


func apply_stun_from_source(source_is_on_left: bool, duration_sec: float) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server() and not is_multiplayer_authority():
			server_apply_authoritative_stun_from_source.rpc_id(get_multiplayer_authority(), source_is_on_left, duration_sec)
			return
		if not multiplayer.is_server() and is_multiplayer_authority():
			request_player_apply_stun_from_source.rpc_id(1, source_is_on_left, duration_sec)
			return

	_apply_stun_from_source_local(source_is_on_left, duration_sec)


func enter_stun(duration_sec: float, from_launch: bool) -> void:
	interrupt_weapon_operation_state()
	_stun_timer = duration_sec
	_stun_from_launch = from_launch
	_stun_airborne = from_launch
	_air_stun_freeze_timer = duration_sec * 0.5 if from_launch else 0.0
	_top_state = TopState.STUN
	_exit_run_state()
	_launch_has_left_floor = not is_on_floor()

	if _move_phase == MovePhase.CLIMB:
		_move_phase = MovePhase.AIR
	elif _move_phase == MovePhase.RUN_SKID:
		_move_phase = MovePhase.GROUND

	if not from_launch:
		velocity.y = 0.0
	else:
		_move_phase = MovePhase.AIR


func apply_launch(height_coef: float, distance_coef: float, horizontal_sign: int) -> void:
	if _top_state == TopState.DOWN or _top_state == TopState.DEAD:
		return

	interrupt_weapon_operation_state()
	var launch_height := launch_base_height_px * height_coef
	var launch_vy := -sqrt(maxf(0.0, 2.0 * gravity_force * launch_height))
	var launch_vx := launch_base_speed_x * distance_coef * float(sign_to_int(horizontal_sign))

	_top_state = TopState.LAUNCH
	_stun_timer = 0.0
	_stun_from_launch = false
	_exit_run_state()
	_move_phase = MovePhase.AIR
	velocity = Vector2(launch_vx, launch_vy)
	_launch_has_left_floor = false
	_stun_airborne = false
	trigger_hit_flash()


func apply_launch_by_distance_from_source(source_is_on_left: bool, height_px: float, distance_px: float) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server() and not is_multiplayer_authority():
			server_apply_authoritative_launch_by_distance.rpc_id(get_multiplayer_authority(), source_is_on_left, height_px, distance_px)
			return
		if not multiplayer.is_server() and is_multiplayer_authority():
			request_player_apply_launch_by_distance.rpc_id(1, source_is_on_left, height_px, distance_px)
			return

	_apply_launch_by_distance_local(source_is_on_left, height_px, distance_px)


func apply_launch_from_source(source_is_on_left: bool, height_coef: float, distance_coef: float) -> void:
	var launch_sign := 1 if source_is_on_left else -1
	apply_launch(height_coef, distance_coef, launch_sign)


func receive_weapon_hit(attack_data: Dictionary, source: Node) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server() and not is_multiplayer_authority():
			server_apply_authoritative_weapon_hit.rpc_id(get_multiplayer_authority(), attack_data.duplicate(true), _node_to_path_string(source))
			return
		if not multiplayer.is_server() and is_multiplayer_authority():
			request_player_receive_weapon_hit.rpc_id(1, attack_data.duplicate(true), _node_to_path_string(source))
			return

	_apply_received_weapon_hit_local(attack_data, source)


func _apply_received_weapon_hit_local(attack_data: Dictionary, source: Node) -> void:
	if _top_state == TopState.DOWN or _top_state == TopState.DEAD:
		return

	_boost_network_snapshot_priority()
	var raw_damage: float = attack_data.get("damage", 0.0)
	var defense_ratio := get_equipped_defense_ratio()
	var guard_break: bool = bool(attack_data.get("guard_break", false))
	var source_is_on_left := true
	if source is Node2D:
		source_is_on_left = (source as Node2D).global_position.x < global_position.x

	if not guard_break and can_guard_attack_from(source):
		_last_received_damage_raw = raw_damage
		_last_received_damage_final = raw_damage * (1.0 - defense_ratio) * (1.0 - guard_damage_reduction_ratio)
		apply_damage(_last_received_damage_final)
		trigger_hit_flash()
		start_guard_counter_window()
		return

	stop_guard()
	_last_received_damage_raw = raw_damage
	_last_received_damage_final = raw_damage * (1.0 - defense_ratio)
	apply_damage(_last_received_damage_final)
	if _top_state == TopState.DEAD:
		return
	if _super_armor_active:
		trigger_hit_flash()
		return

	var hit_effect: String = attack_data.get("hit_effect", "stun")
	match hit_effect:
		"launch":
			_apply_launch_by_distance_local(
				source_is_on_left,
				attack_data.get("launch_height_px", launch_base_height_px),
				attack_data.get("launch_distance_px", launch_base_speed_x)
			)
		_:
			_apply_stun_from_source_local(
				source_is_on_left,
				attack_data.get("stun_duration_sec", stun_base_duration_sec)
			)
	_broadcast_network_snapshot_immediately()


func _apply_debug_hit_from_side(source_is_on_left: bool, launch: bool) -> void:
	if _top_state == TopState.DOWN or _top_state == TopState.DEAD:
		return

	if can_guard_attack_from_side(source_is_on_left):
		var guarded_damage := debug_hit_damage * (1.0 - get_equipped_defense_ratio()) * (1.0 - guard_damage_reduction_ratio)
		_last_received_damage_raw = debug_hit_damage
		_last_received_damage_final = guarded_damage
		apply_damage(guarded_damage)
		trigger_hit_flash()
		start_guard_counter_window()
		return

	stop_guard()
	var final_damage := debug_hit_damage * (1.0 - get_equipped_defense_ratio())
	_last_received_damage_raw = debug_hit_damage
	_last_received_damage_final = final_damage
	apply_damage(final_damage)
	if _top_state == TopState.DEAD:
		return
	if _super_armor_active:
		trigger_hit_flash()
		return
	if launch:
		apply_launch_from_source(source_is_on_left, debug_launch_height_coef, debug_launch_distance_coef)
	else:
		apply_stun_from_source(source_is_on_left, stun_base_duration_sec)
	_broadcast_network_snapshot_immediately()


func receive_grabbed_weapon_hit(attack_data: Dictionary, _source: Node) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server() and not is_multiplayer_authority():
			server_apply_authoritative_grabbed_weapon_hit.rpc_id(get_multiplayer_authority(), attack_data.duplicate(true))
			return
		if not multiplayer.is_server() and is_multiplayer_authority():
			request_player_receive_grabbed_weapon_hit.rpc_id(1, attack_data.duplicate(true))
			return

	_apply_received_grabbed_weapon_hit_local(attack_data)


func _apply_received_grabbed_weapon_hit_local(attack_data: Dictionary) -> void:
	if _top_state == TopState.DOWN or _top_state == TopState.DEAD:
		return

	_boost_network_snapshot_priority()
	var raw_damage: float = attack_data.get("damage", 0.0)
	var defense_ratio := get_equipped_defense_ratio()
	_last_received_damage_raw = raw_damage
	_last_received_damage_final = raw_damage * (1.0 - defense_ratio)
	apply_damage(_last_received_damage_final)
	if _top_state == TopState.DEAD:
		return
	trigger_hit_flash()
	_broadcast_network_snapshot_immediately()


func _apply_stun_from_source_local(source_is_on_left: bool, duration_sec: float) -> void:
	if _top_state == TopState.DOWN or _top_state == TopState.DEAD:
		return
	_boost_network_snapshot_priority()
	trigger_hit_flash()
	var knockback_speed := get_stun_knockback_speed()
	velocity.x = knockback_speed if source_is_on_left else -knockback_speed
	apply_stun(duration_sec)
	_broadcast_network_snapshot_immediately()


func _apply_launch_by_distance_local(source_is_on_left: bool, height_px: float, distance_px: float) -> void:
	if _top_state == TopState.DOWN or _top_state == TopState.DEAD:
		return

	_boost_network_snapshot_priority()
	interrupt_weapon_operation_state()
	var horizontal_sign := 1 if source_is_on_left else -1
	var launch_height := maxf(0.0, height_px)
	var launch_vy := -sqrt(maxf(0.0, 2.0 * gravity_force * launch_height))
	var travel_time := get_launch_travel_time_for_height(launch_height)
	var launch_vx := 0.0
	if travel_time > 0.0:
		launch_vx = (distance_px / travel_time) * float(horizontal_sign)

	_top_state = TopState.LAUNCH
	_stun_timer = 0.0
	_stun_from_launch = false
	_exit_run_state()
	_move_phase = MovePhase.AIR
	velocity = Vector2(launch_vx, launch_vy)
	_launch_has_left_floor = false
	_stun_airborne = false
	trigger_hit_flash()
	_broadcast_network_snapshot_immediately()


func _enter_grabbed_by_local(grabber: Node2D, slot_offset: Vector2 = Vector2.ZERO) -> void:
	if _top_state == TopState.DOWN or _top_state == TopState.DEAD:
		return
	_boost_network_snapshot_priority()
	if can_guard_attack_from(grabber):
		start_guard_counter_window()
		return
	if _super_armor_active:
		trigger_hit_flash()
		return
	interrupt_weapon_operation_state()
	stop_guard()
	_grabber = grabber
	_grabbed_slot_offset = slot_offset
	_top_state = TopState.GRABBED
	_exit_run_state()
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_broadcast_network_snapshot_immediately()


func _release_grabbed_local() -> void:
	_boost_network_snapshot_priority()
	_grabber = null
	_grabbed_slot_offset = Vector2.ZERO
	_top_state = TopState.OPERABLE
	_move_phase = MovePhase.GROUND if is_on_floor() else MovePhase.AIR
	_broadcast_network_snapshot_immediately()


func get_equipped_defense_ratio() -> float:
	if _equipped_weapon != null and _equipped_weapon.has_method("get_base_defense_ratio"):
		return clampf(_equipped_weapon.call("get_base_defense_ratio"), 0.0, 1.0)
	return 0.0


func apply_damage(raw_damage: float) -> void:
	if _top_state == TopState.DEAD:
		return
	var final_damage := maxf(0.0, raw_damage)
	_current_hp = clampf(_current_hp - final_damage, 0.0, get_effective_max_hp())
	update_status_bars()
	if _current_hp <= 0.0:
		enter_dead()


func restore_hp(amount: float) -> void:
	if _top_state == TopState.DEAD:
		return
	if amount <= 0.0:
		return
	_current_hp = clampf(_current_hp + amount, 0.0, get_effective_max_hp())
	update_status_bars()


func update_status_bars() -> void:
	var effective_max_hp := get_effective_max_hp()
	var effective_max_mp := get_effective_max_mp()
	_update_bar_fill(hp_fill, _current_hp, effective_max_hp)
	_update_bar_fill(mp_fill, _current_mp, effective_max_mp)
	_update_screen_progress_bar(mastery_exp_bar, mastery_exp_fill, get_weapon_mastery_exp(), get_weapon_mastery_exp_to_next_level())
	_update_screen_progress_bar(spec_exp_bar, spec_exp_fill, get_specialization_exp(), get_specialization_exp_to_next_level())
	_refresh_battle_info_card(effective_max_hp, effective_max_mp)
	resources_changed.emit(_current_hp, effective_max_hp, _current_mp, effective_max_mp)


func _update_bar_fill(fill_rect: ColorRect, current_value: float, max_value: float) -> void:
	if fill_rect == null:
		return

	var ratio := 0.0
	if max_value > 0.0:
		ratio = clampf(current_value / max_value, 0.0, 1.0)

	var full_width := 32.0
	var center_x := 18.0
	var visible_width := full_width * ratio
	fill_rect.offset_left = center_x - visible_width * 0.5
	fill_rect.offset_right = center_x + visible_width * 0.5


func _update_screen_progress_bar(bar_root: Control, fill_rect: ColorRect, current_value: float, max_value: float) -> void:
	if bar_root == null or fill_rect == null:
		return

	var ratio := 0.0
	if max_value > 0.0:
		ratio = clampf(current_value / max_value, 0.0, 1.0)

	var full_width := bar_root.size.x
	if full_width <= 0.0:
		full_width = bar_root.offset_right - bar_root.offset_left
	if full_width <= 0.0:
		full_width = get_viewport_rect().size.x
	fill_rect.offset_left = 0.0
	fill_rect.offset_right = full_width * ratio


func _setup_screen_exp_ticks() -> void:
	_populate_screen_exp_ticks(mastery_exp_bar, mastery_ticks)
	_populate_screen_exp_ticks(spec_exp_bar, spec_ticks)


func _setup_battle_info_card() -> void:
	if battle_hud_portrait != null and head_sprite != null:
		battle_hud_portrait.texture = head_sprite.texture
		battle_hud_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	battle_weapon_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_weapon_value_label.clip_text = true


func _refresh_battle_info_card(effective_max_hp: float, effective_max_mp: float) -> void:
	if battle_weapon_value_label == null:
		return

	battle_weapon_value_label.text = _get_current_weapon_display_name()
	battle_spec_value_label.text = "Lv.%d" % get_specialization_level()
	battle_mastery_value_label.text = "Lv.%d" % get_weapon_mastery_level()
	_update_screen_progress_bar(battle_hp_fill.get_parent() as Control, battle_hp_fill, _current_hp, effective_max_hp)
	_update_screen_progress_bar(battle_mp_fill.get_parent() as Control, battle_mp_fill, _current_mp, effective_max_mp)
	battle_hp_value_label.text = "%.0f / %.0f" % [_current_hp, effective_max_hp]
	battle_mp_value_label.text = "%.0f / %.0f" % [_current_mp, effective_max_mp]


func _get_current_weapon_display_name() -> String:
	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if use_inventory_runtime_state and inventory_runtime != null and inventory_runtime.has_method("get_equipped_weapon"):
		var equipped_item: Dictionary = inventory_runtime.call("get_equipped_weapon") as Dictionary
		if not equipped_item.is_empty():
			return String(equipped_item.get("display_name", "Longsword"))

	if _equipped_weapon != null and _equipped_weapon.has_method("get_display_name"):
		return String(_equipped_weapon.call("get_display_name"))
	if _equipped_weapon != null:
		var display_name: Variant = _equipped_weapon.get("display_name")
		if display_name != null:
			return String(display_name)
	return "Unarmed"


func _populate_screen_exp_ticks(bar_root: Control, tick_root: Control) -> void:
	if bar_root == null or tick_root == null:
		return

	for child in tick_root.get_children():
		child.queue_free()

	for step in range(1, 10):
		var tick := ColorRect.new()
		tick.name = "Tick%d" % step
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.color = Color(1.0, 1.0, 1.0, 0.28)
		tick.anchor_left = float(step) / 10.0
		tick.anchor_right = float(step) / 10.0
		tick.anchor_top = 0.0
		tick.anchor_bottom = 1.0
		tick.offset_left = -0.5
		tick.offset_right = 0.5
		tick.offset_top = 0.0
		tick.offset_bottom = 0.0
		tick_root.add_child(tick)


func can_pay_mp(cost: float) -> bool:
	if _infinite_mp:
		return true
	return _current_mp >= cost


func consume_mp(cost: float) -> bool:
	if not can_pay_mp(cost):
		return false

	if _infinite_mp:
		return true

	_current_mp = clampf(_current_mp - maxf(0.0, cost), 0.0, get_effective_max_mp())
	update_status_bars()
	return true


func restore_debug_resources() -> void:
	if _top_state == TopState.DEAD:
		return
	_current_hp = get_effective_max_hp()
	_current_mp = get_effective_max_mp()
	update_status_bars()


func toggle_infinite_mp() -> void:
	_infinite_mp = not _infinite_mp
	if _infinite_mp:
		_current_mp = get_effective_max_mp()
	update_status_bars()


func can_forced_get_up() -> bool:
	ground_check.force_raycast_update()
	if not ground_check.is_colliding():
		return false

	return ground_check.get_collision_point().distance_to(ground_check.global_position) <= forced_get_up_height_px


func enter_down() -> void:
	_top_state = TopState.DOWN
	_down_timer = down_duration_sec
	_move_phase = MovePhase.GROUND
	velocity.y = 0.0
	_stun_airborne = false
	_broadcast_network_snapshot_immediately()


func enter_dead() -> void:
	if _top_state == TopState.DEAD:
		return

	interrupt_weapon_operation_state()
	if _top_state == TopState.GRABBED:
		_grabber = null
		_grabbed_slot_offset = Vector2.ZERO
	_top_state = TopState.DEAD
	_external_action_lock = true
	_stun_timer = 0.0
	_down_timer = 0.0
	_air_stun_freeze_timer = 0.0
	_stun_airborne = false
	_launch_has_left_floor = false
	_exit_run_state()
	_run_active = false
	stop_guard()
	_attack_buff_visual_active = false
	_left_eye_afterimages.clear()
	_right_eye_afterimages.clear()
	_eye_afterimage_timer = 0.0
	_refresh_buff_eye_visuals()
	_move_phase = MovePhase.GROUND if is_on_floor() else MovePhase.AIR
	velocity.x = 0.0
	if is_on_floor():
		velocity.y = 0.0
	_apply_death_inventory_penalty()
	apply_collision_profile()
	_refresh_equipped_weapon_visibility()
	_show_death_overlay()
	death_state_changed.emit(true)
	_broadcast_network_snapshot_immediately()


func respawn_at(respawn_position: Vector2, restore_full_resources: bool = true) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not is_multiplayer_authority():
		server_apply_authoritative_respawn.rpc_id(get_multiplayer_authority(), respawn_position, restore_full_resources)
		return
	_respawn_at_local(respawn_position, restore_full_resources)


func _respawn_at_local(respawn_position: Vector2, restore_full_resources: bool = true) -> void:
	interrupt_weapon_operation_state()
	_grabber = null
	_grabbed_slot_offset = Vector2.ZERO
	_top_state = TopState.OPERABLE
	_external_action_lock = false
	_stun_timer = 0.0
	_down_timer = 0.0
	_stun_from_launch = false
	_launch_has_left_floor = false
	_stun_airborne = false
	_air_stun_freeze_timer = 0.0
	_hit_flash_timer = 0.0
	_potion_use_active = false
	_potion_use_timer = 0.0
	_hide_potion_use_icon()
	global_position = respawn_position
	velocity = Vector2.ZERO
	_move_phase = MovePhase.GROUND
	_exit_run_state()
	stop_guard()
	if restore_full_resources:
		_current_hp = get_effective_max_hp()
		_current_mp = get_effective_max_mp()
	else:
		_current_hp = maxf(1.0, _current_hp)
	update_status_bars()
	apply_collision_profile()
	_refresh_equipped_weapon_visibility()
	update_animation_state()
	if _death_overlay != null and _death_overlay.has_method("hide_overlay"):
		_death_overlay.call("hide_overlay")
	death_state_changed.emit(false)
	_boost_network_snapshot_priority()
	_broadcast_network_snapshot_immediately()


func enter_grabbed(grabber: Node2D) -> void:
	enter_grabbed_by(grabber, Vector2(grabbed_slot_offset_x, grabbed_slot_offset_y))


func enter_grabbed_by(grabber: Node2D, slot_offset: Vector2 = Vector2.ZERO) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server() and not is_multiplayer_authority():
			server_enter_authoritative_grabbed.rpc_id(get_multiplayer_authority(), _node_to_path_string(grabber), slot_offset)
			return
		if not multiplayer.is_server() and is_multiplayer_authority():
			request_player_enter_grabbed_by.rpc_id(1, _node_to_path_string(grabber), slot_offset)
			return

	_enter_grabbed_by_local(grabber, slot_offset)


func release_grabbed() -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server() and not is_multiplayer_authority():
			server_release_authoritative_grabbed.rpc_id(get_multiplayer_authority())
			return
		if not multiplayer.is_server() and is_multiplayer_authority():
			request_player_release_grabbed.rpc_id(1)
			return

	_release_grabbed_local()


func update_grabbed_state() -> void:
	if not is_instance_valid(_grabber):
		release_grabbed()
		return

	var grab_facing := 1.0
	var grabber_facing_value: Variant = _grabber.get("facing")
	if grabber_facing_value != null:
		grab_facing = float(grabber_facing_value)
	var resolved_offset := Vector2(_grabbed_slot_offset.x * grab_facing, _grabbed_slot_offset.y)
	global_position = _grabber.global_position + resolved_offset
	velocity = Vector2.ZERO


func can_guard_attack_from(source: Node) -> bool:
	if not _guard_active:
		return false
	if _top_state != TopState.OPERABLE:
		return false
	if _move_phase != MovePhase.GROUND:
		return false
	var source_node := _resolve_guard_source_node(source)
	if source_node == null:
		return false

	var source_x := source_node.global_position.x
	if facing >= 0:
		return source_x >= global_position.x
	return source_x <= global_position.x


func can_guard_attack_from_side(source_is_on_left: bool) -> bool:
	if not _guard_active:
		return false
	if _top_state != TopState.OPERABLE:
		return false
	if _move_phase != MovePhase.GROUND:
		return false
	return (facing < 0 and source_is_on_left) or (facing > 0 and not source_is_on_left)


func resolve_overlap_after_get_up() -> void:
	for body in overlap_probe.get_overlapping_bodies():
		if body == self:
			continue
		if body is CharacterBody2D:
			var push_dir := -1.0 if body.global_position.x < global_position.x else 1.0
			body.global_position.x += push_dir * 6.0


func cancel_platform_sticky() -> void:
	var collision := get_last_slide_collision()
	if collision == null:
		return

	var collider := collision.get_collider()
	if collider is CharacterBody2D:
		return


func _update_platform_floor_state() -> void:
	_standing_on_platform = false
	if not is_on_floor():
		return

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue

		if collision.get_normal().y > -0.7:
			continue

		var collider := collision.get_collider()
		if collider is CollisionObject2D and ((collider as CollisionObject2D).collision_layer & layer_bit(PLATFORM_LAYER)) != 0:
			_standing_on_platform = true
			return


func apply_collision_profile() -> void:
	if multiplayer.has_multiplayer_peer():
		if _top_state == TopState.DOWN or _top_state == TopState.DEAD or _top_state == TopState.GRABBED:
			collision_layer = 0
			collision_mask = layer_bit(WORLD_LAYER)
			if _platform_drop_timer <= 0.0:
				collision_mask |= layer_bit(PLATFORM_LAYER)
			return

		collision_layer = layer_bit(CHARACTER_LAYER)
		collision_mask = layer_bit(WORLD_LAYER)
		if _platform_drop_timer <= 0.0:
			collision_mask |= layer_bit(PLATFORM_LAYER)
		return

	if _top_state == TopState.DOWN or _top_state == TopState.DEAD:
		collision_layer = 0
		collision_mask = layer_bit(WORLD_LAYER)
		if _platform_drop_timer <= 0.0:
			collision_mask |= layer_bit(PLATFORM_LAYER)
		return

	if _top_state == TopState.LAUNCH:
		collision_layer = layer_bit(CHARACTER_LAYER)
		collision_mask = layer_bit(WORLD_LAYER)
		if _platform_drop_timer <= 0.0:
			collision_mask |= layer_bit(PLATFORM_LAYER)
		if _character_drop_timer <= 0.0:
			collision_mask |= layer_bit(CHARACTER_LAYER)
		return

	collision_layer = layer_bit(CHARACTER_LAYER)
	if _move_phase == MovePhase.CLIMB:
		collision_mask = layer_bit(WORLD_LAYER)
	else:
		collision_mask = layer_bit(WORLD_LAYER)
		if _platform_drop_timer <= 0.0:
			collision_mask |= layer_bit(PLATFORM_LAYER)
	if _character_drop_timer <= 0.0:
		collision_mask |= layer_bit(CHARACTER_LAYER)


func layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)


func _resolve_guard_source_node(source: Node) -> Node2D:
	if source is Node2D:
		return source as Node2D
	if source == null:
		return null

	var parent := source.get_parent()
	if parent is Node2D:
		return parent as Node2D

	return null


func _should_auto_equip_test_weapon() -> bool:
	if use_inventory_runtime_state and get_node_or_null("/root/InventoryRuntime") != null:
		return false
	return Input.is_action_pressed("attack_light") or Input.is_action_pressed("attack_heavy")


func _is_standing_on_character() -> bool:
	if not is_on_floor():
		return false

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		if collision.get_normal().y > -0.7:
			continue
		if collision.get_collider() is CharacterBody2D:
			return true

	return false


func _begin_character_head_slide() -> void:
	_character_drop_timer = maxf(_character_drop_timer, character_head_slide_drop_duration_sec)
	if _top_state == TopState.OPERABLE and _move_phase != MovePhase.CLIMB:
		_move_phase = MovePhase.AIR
	velocity.y = maxf(velocity.y, character_head_slide_nudge_speed)


func set_external_action_lock(locked: bool) -> void:
	_external_action_lock = locked


func notify_external_cc_interrupt() -> void:
	_exit_run_state()


func get_animation_state_payload() -> Dictionary:
	return {
		"facing": facing,
		"vx": velocity.x,
		"vy": velocity.y,
		"on_floor": is_on_floor(),
		"move_phase": _move_phase,
		"run_active": _run_active,
		"input_x": _input_x,
		"hit_stun": _top_state == TopState.STUN,
		"launch": _top_state == TopState.LAUNCH,
		"knocked_down": _top_state == TopState.DOWN,
		"grabbed": _top_state == TopState.GRABBED,
		"dead": _top_state == TopState.DEAD,
	}


func get_time_seconds() -> float:
	return Time.get_ticks_usec() / 1000000.0


func update_animation_state() -> void:
	if animation_player == null:
		return

	var target := "idle"
	var speed_scale := 1.0

	match _top_state:
		TopState.STUN:
			target = "air_stun" if _stun_airborne else "stun"
		TopState.LAUNCH:
			target = "launch"
		TopState.DOWN:
			target = "down"
		TopState.GRABBED:
			target = "grabbed"
		TopState.DEAD:
			target = "death"
		TopState.OPERABLE:
			match _move_phase:
				MovePhase.CLIMB:
					if absf(velocity.y) > 5.0:
						target = "climb"
						speed_scale = clampf(absf(velocity.y) / maxf(1.0, get_effective_climb_speed()) * 1.6, 0.8, 1.8)
					else:
						target = "climb_idle"
				MovePhase.RUN_SKID:
					target = "skid"
				MovePhase.AIR:
					target = "jump_up" if velocity.y < 0.0 else "fall"
				MovePhase.GROUND:
					if _run_active or absf(velocity.x) > get_effective_walk_speed() + 10.0:
						target = "run"
						speed_scale = clampf(absf(velocity.x) / maxf(1.0, get_max_run_speed()) * 1.35, 0.9, 1.5)
					elif absf(velocity.x) > 8.0:
						target = "walk"
						speed_scale = clampf(absf(velocity.x) / maxf(1.0, get_effective_walk_speed()) * 1.25, 0.8, 1.35)
					else:
						target = "idle"

	if _current_animation != target:
		_current_animation = target
		reset_visual_pose()
		animation_player.play(target)

	animation_player.speed_scale = speed_scale


func reset_visual_pose() -> void:
	if body_pivot == null:
		return

	body_pivot.position = Vector2.ZERO
	body_pivot.rotation_degrees = 0.0
	torso.position = Vector2(0, -17)
	torso.rotation_degrees = 0.0
	head_pivot.position = Vector2(0, -24)
	head_pivot.rotation_degrees = 0.0
	left_leg_pivot.position = Vector2(-3, -10)
	left_leg_pivot.rotation_degrees = 0.0
	right_leg_pivot.position = Vector2(3, -10)
	right_leg_pivot.rotation_degrees = 0.0
	visuals.modulate = Color(1, 1, 1, 1)
	_refresh_buff_eye_visuals()
	_refresh_equipped_weapon_visibility()


func update_hit_flash(delta: float) -> void:
	if visuals == null:
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		var t := 0.0
		if hit_flash_duration > 0.0:
			t = _hit_flash_timer / hit_flash_duration
		visuals.modulate = Color(1, 1, 1, 1).lerp(hit_flash_color, t)
	else:
		visuals.modulate = Color(1, 1, 1, 1)


func trigger_hit_flash() -> void:
	_hit_flash_timer = hit_flash_duration


func get_stun_knockback_speed() -> float:
	if stun_base_duration_sec <= 0.0:
		return 0.0
	return (2.0 * stun_base_knockback_distance_px) / stun_base_duration_sec


func get_stun_knockback_decel() -> float:
	if stun_base_duration_sec <= 0.0:
		return hit_stun_horizontal_decel
	return get_stun_knockback_speed() / stun_base_duration_sec


func handle_debug_hit_inputs() -> void:
	if Input.is_action_just_pressed("debug_hit_stun_left"):
		_apply_debug_hit_from_side(true, false)
	elif Input.is_action_just_pressed("debug_hit_stun_right"):
		_apply_debug_hit_from_side(false, false)
	elif Input.is_action_just_pressed("debug_hit_launch_left"):
		_apply_debug_hit_from_side(true, true)
	elif Input.is_action_just_pressed("debug_hit_launch_right"):
		_apply_debug_hit_from_side(false, true)
	elif Input.is_action_just_pressed("debug_restore_resources"):
		restore_debug_resources()
	elif Input.is_action_just_pressed("debug_toggle_infinite_mp"):
		toggle_infinite_mp()
	elif Input.is_action_just_pressed("debug_kill_all_enemies"):
		kill_all_debug_enemies()


func kill_all_debug_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemy_bodies"):
		if not (node is Node):
			continue
		var enemy: Node = node as Node
		if enemy == self or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		if enemy.has_method("die"):
			enemy.call("die")
			continue
		if enemy.has_method("apply_damage"):
			enemy.call("apply_damage", 999999.0)


func handle_debug_weapon_inputs() -> void:
	var weapon_operation_blocked := _move_phase == MovePhase.RUN_SKID or _move_phase == MovePhase.CLIMB

	if weapon_operation_blocked:
		stop_guard()
		_clear_pending_z_skill()
		return

	if _potion_use_active:
		stop_guard()
		_clear_pending_z_skill()
		_clear_pending_plain_action()
		return

	if Input.is_action_just_pressed("debug_equip_longsword"):
		equip_debug_longsword()
	elif Input.is_action_just_pressed("debug_equip_spear"):
		equip_debug_spear()
	elif Input.is_action_just_pressed("debug_unequip_weapon"):
		unequip_weapon()

	if _equipped_weapon == null and _should_auto_equip_test_weapon():
		equip_debug_longsword()

	if _equipped_weapon == null:
		stop_guard()
		_clear_pending_z_skill()
		_clear_pending_plain_action()
		return

	if _top_state != TopState.OPERABLE or _external_action_lock:
		stop_guard()
		_clear_pending_z_skill()
		_clear_pending_plain_action()
		return

	var z_modifier_active := _move_phase == MovePhase.GROUND and Input.is_action_pressed("skill_modifier_z")
	if _guard_counter_ready and _guard_counter_timer > 0.0 and not z_modifier_active and not _weapon_attack_locked:
		_handle_guard_counter_inputs()
		return

	var guard_input_active := Input.is_action_pressed("attack_light") and Input.is_action_pressed("attack_heavy") and not Input.is_action_pressed("skill_modifier_z")
	if _move_phase == MovePhase.GROUND and guard_input_active and not _weapon_attack_locked:
		_clear_pending_plain_action()
		start_guard()
		_handle_guard_counter_inputs()
		return
	stop_guard()

	if _try_process_pending_z_skill():
		return

	var light_pressed := Input.is_action_just_pressed("attack_light")
	var heavy_pressed := Input.is_action_just_pressed("attack_heavy")

	if z_modifier_active and _equipped_weapon.has_method("play_skill_zxc"):
		if (light_pressed and (Input.is_action_pressed("attack_heavy") or _pending_z_skill_method == &"play_skill_zx")) \
		or (heavy_pressed and (Input.is_action_pressed("attack_light") or _pending_z_skill_method == &"play_skill_zc")):
			_clear_pending_z_skill()
			_invoke_weapon_action(&"play_skill_zxc")
			return

	if z_modifier_active and light_pressed and _equipped_weapon.has_method("play_skill_zc"):
		_queue_pending_z_skill(&"play_skill_zc")
		return
	if z_modifier_active and heavy_pressed and _equipped_weapon.has_method("play_skill_zx"):
		_queue_pending_z_skill(&"play_skill_zx")
		return

	if _move_phase == MovePhase.GROUND and not z_modifier_active and not _weapon_attack_locked:
		if light_pressed and Input.is_action_pressed("attack_heavy"):
			_clear_pending_plain_action()
			start_guard()
			return
		if heavy_pressed and Input.is_action_pressed("attack_light"):
			_clear_pending_plain_action()
			start_guard()
			return
		if light_pressed:
			_queue_pending_plain_action(&"_execute_plain_light_action")
			return
		if heavy_pressed:
			_queue_pending_plain_action(&"_execute_plain_heavy_action")
			return

	if light_pressed:
		if _move_phase == MovePhase.AIR and _equipped_weapon.has_method("play_air_light_attack_c"):
			_invoke_weapon_action(&"play_air_light_attack_c")
			return
		elif _run_active and _move_phase == MovePhase.GROUND and _equipped_weapon.has_method("play_run_light_attack_c"):
			_invoke_weapon_action(&"play_run_light_attack_c", true)
			return
		elif _equipped_weapon.has_method("play_light_attack_c"):
			_invoke_weapon_action(&"play_light_attack_c")
	elif heavy_pressed:
		if _move_phase == MovePhase.AIR and _equipped_weapon.has_method("play_air_heavy_attack_x"):
			_invoke_weapon_action(&"play_air_heavy_attack_x")
			return
		elif _run_active and _move_phase == MovePhase.GROUND and _equipped_weapon.has_method("play_run_heavy_attack_x"):
			_invoke_weapon_action(&"play_run_heavy_attack_x", true)
			return
		elif _equipped_weapon.has_method("play_heavy_attack_x"):
			_invoke_weapon_action(&"play_heavy_attack_x")


func _queue_pending_z_skill(method_name: StringName) -> void:
	_pending_z_skill_method = method_name
	_pending_z_skill_expire_at = get_time_seconds() + zxc_input_link_window


func _clear_pending_z_skill() -> void:
	_pending_z_skill_method = &""
	_pending_z_skill_expire_at = 0.0


func _queue_pending_plain_action(method_name: StringName) -> void:
	_pending_plain_action_method = method_name
	_pending_plain_action_expire_at = get_time_seconds() + guard_input_link_window


func _clear_pending_plain_action() -> void:
	_pending_plain_action_method = &""
	_pending_plain_action_expire_at = 0.0


func handle_potion_input() -> void:
	if not Input.is_action_just_pressed("use_equipped_potion"):
		return
	if not can_start_equipped_potion_use():
		return
	start_equipped_potion_use()


func can_start_equipped_potion_use() -> bool:
	if _potion_use_active:
		return false
	if _top_state != TopState.OPERABLE or _external_action_lock:
		return false
	if _weapon_attack_locked or _guard_active:
		return false
	if _move_phase == MovePhase.CLIMB or _move_phase == MovePhase.RUN_SKID:
		return false
	return not get_equipped_potion().is_empty()


func start_equipped_potion_use() -> bool:
	if not use_inventory_runtime_state:
		return false
	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if inventory_runtime == null or not inventory_runtime.has_method("consume_equipped_potion_one"):
		return false

	var consumed_item: Dictionary = inventory_runtime.call("consume_equipped_potion_one") as Dictionary
	if consumed_item.is_empty():
		return false

	stop_guard()
	_clear_pending_z_skill()
	_clear_pending_plain_action()
	_potion_use_item = consumed_item.duplicate(true)
	_potion_use_active = true
	_potion_use_timer = maxf(0.0, float(_potion_use_item.get("use_startup_sec", potion_use_default_startup_sec)))
	set_movement_speed_modifier(POTION_USE_MOVEMENT_MODIFIER, float(_potion_use_item.get("use_move_scale", 0.3)))
	set_jump_height_modifier(POTION_USE_JUMP_MODIFIER, float(_potion_use_item.get("use_jump_scale", 0.3)))
	_show_potion_use_icon(_potion_use_item)
	if _potion_use_timer <= 0.0:
		finish_equipped_potion_use()
	return true


func update_potion_use_state(delta: float) -> void:
	if not _potion_use_active:
		return
	_potion_use_timer = maxf(0.0, _potion_use_timer - delta)
	if _potion_use_timer <= 0.0:
		finish_equipped_potion_use()


func finish_equipped_potion_use() -> void:
	if not _potion_use_active:
		return
	var effect_key: String = String(_potion_use_item.get("potion_effect_key", ""))
	match effect_key:
		"restore_hp":
			restore_hp(float(_potion_use_item.get("restore_hp_value", 0.0)))
	_end_potion_use_state()


func interrupt_potion_use() -> void:
	if not _potion_use_active:
		return
	_end_potion_use_state()


func _end_potion_use_state() -> void:
	_potion_use_active = false
	_potion_use_timer = 0.0
	_potion_use_item = {}
	clear_movement_speed_modifier(POTION_USE_MOVEMENT_MODIFIER)
	clear_jump_height_modifier(POTION_USE_JUMP_MODIFIER)
	_hide_potion_use_icon()


func _consume_pending_plain_action() -> void:
	if _pending_plain_action_method == &"":
		return
	var method_name := _pending_plain_action_method
	_clear_pending_plain_action()
	if has_method(method_name):
		call(method_name)


func _try_process_pending_z_skill() -> bool:
	if _pending_z_skill_method == &"":
		return false

	if _equipped_weapon == null or not Input.is_action_pressed("skill_modifier_z") or _move_phase != MovePhase.GROUND:
		_clear_pending_z_skill()
		return false

	if get_time_seconds() < _pending_z_skill_expire_at:
		return false

	var pending_method := _pending_z_skill_method
	_clear_pending_z_skill()
	return _invoke_weapon_action(pending_method)


func _execute_plain_light_action() -> void:
	if _equipped_weapon == null or _guard_active:
		return
	if _move_phase == MovePhase.AIR and _equipped_weapon.has_method("play_air_light_attack_c"):
		_invoke_weapon_action(&"play_air_light_attack_c")
		return
	if _run_active and _move_phase == MovePhase.GROUND and _equipped_weapon.has_method("play_run_light_attack_c"):
		_invoke_weapon_action(&"play_run_light_attack_c", true)
		return
	if _equipped_weapon.has_method("play_light_attack_c"):
		_invoke_weapon_action(&"play_light_attack_c")


func _execute_plain_heavy_action() -> void:
	if _equipped_weapon == null or _guard_active:
		return
	if _move_phase == MovePhase.AIR and _equipped_weapon.has_method("play_air_heavy_attack_x"):
		_invoke_weapon_action(&"play_air_heavy_attack_x")
		return
	if _run_active and _move_phase == MovePhase.GROUND and _equipped_weapon.has_method("play_run_heavy_attack_x"):
		_invoke_weapon_action(&"play_run_heavy_attack_x", true)
		return
	if _equipped_weapon.has_method("play_heavy_attack_x"):
		_invoke_weapon_action(&"play_heavy_attack_x")


func apply_attack_motion_velocity(delta: float) -> void:
	if _attack_motion_timer <= 0.0:
		return

	_attack_motion_timer = maxf(0.0, _attack_motion_timer - delta)
	velocity.x = _attack_motion_speed * float(_attack_motion_sign)
	if _attack_motion_timer <= 0.0:
		_attack_motion_speed = 0.0
		_attack_motion_sign = 0


func _on_weapon_attack_motion_requested(distance_px: float, direction_mode: int, duration_sec: float) -> void:
	if duration_sec <= 0.0 or distance_px == 0.0:
		_attack_motion_timer = 0.0
		_attack_motion_speed = 0.0
		_attack_motion_sign = 0
		return

	var resolved_sign := 0
	match direction_mode:
		ATTACK_MOTION_FORWARD:
			resolved_sign = facing
		ATTACK_MOTION_BACKWARD:
			resolved_sign = -facing
		_:
			resolved_sign = 0

	_attack_motion_timer = duration_sec
	_attack_motion_speed = absf(distance_px) / duration_sec
	_attack_motion_sign = resolved_sign


func _on_weapon_attack_state_changed(active: bool) -> void:
	_weapon_attack_locked = active
	if active:
		stop_guard()
	if not active and _weapon_attack_hold_run:
		_weapon_attack_hold_run = false
		_exit_run_state()
		if _move_phase == MovePhase.GROUND:
			velocity.x = signf(velocity.x) * minf(absf(velocity.x), get_effective_walk_speed())


func _on_weapon_startup_hold_requested(duration_sec: float) -> void:
	_weapon_startup_hold_timer = maxf(0.0, duration_sec)
	velocity = Vector2.ZERO


func _on_weapon_super_armor_state_changed(active: bool) -> void:
	_super_armor_active = active


func start_guard() -> void:
	_set_guard_state(true, _should_broadcast_combat_state())


func stop_guard() -> void:
	_set_guard_state(false, _should_broadcast_combat_state())


func interrupt_weapon_operation_state() -> void:
	interrupt_potion_use()
	stop_guard()
	_reset_guard_counter_window()
	_clear_pending_z_skill()
	_clear_pending_plain_action()
	_attack_motion_timer = 0.0
	_attack_motion_speed = 0.0
	_attack_motion_sign = 0
	_weapon_attack_locked = false
	_weapon_attack_hold_run = false
	_weapon_startup_hold_timer = 0.0
	if _equipped_weapon != null and _equipped_weapon.has_method("reset_pose"):
		_equipped_weapon.call("reset_pose")


func start_guard_counter_window() -> void:
	_guard_counter_ready = true
	_guard_counter_timer = guard_counter_window_sec
	_guard_counter_light_count = 0
	_guard_counter_heavy_count = 0


func _reset_guard_counter_window() -> void:
	_guard_counter_ready = false
	_guard_counter_timer = 0.0
	_guard_counter_light_count = 0
	_guard_counter_heavy_count = 0


func _handle_guard_counter_inputs() -> void:
	if not _guard_counter_ready or _guard_counter_timer <= 0.0 or _equipped_weapon == null:
		return

	if Input.is_action_just_pressed("attack_heavy"):
		_guard_counter_heavy_count += 1
		_guard_counter_light_count = 0
		if _guard_counter_heavy_count >= 2 and _equipped_weapon.has_method("play_guard_counter_heavy"):
			stop_guard()
			_reset_guard_counter_window()
			_invoke_weapon_action(&"play_guard_counter_heavy")
			return

	if Input.is_action_just_pressed("attack_light"):
		_guard_counter_light_count += 1
		_guard_counter_heavy_count = 0
		if _guard_counter_light_count >= 2 and _equipped_weapon.has_method("play_guard_counter_light"):
			stop_guard()
			_reset_guard_counter_window()
			_invoke_weapon_action(&"play_guard_counter_light")


func _on_weapon_buff_visual_state_changed(active: bool) -> void:
	_attack_buff_visual_active = active
	if not active:
		_left_eye_afterimages.clear()
		_right_eye_afterimages.clear()
		_eye_afterimage_timer = 0.0
	_refresh_buff_eye_visuals()


func equip_debug_longsword() -> void:
	_equip_weapon_scene(LONGSWORD_BASIC_SCENE)


func equip_debug_spear() -> void:
	_equip_weapon_scene(SPEAR_BASIC_SCENE)


func equip_weapon_scene_path(scene_path: String, item_data: Dictionary = {}) -> void:
	if scene_path.is_empty():
		unequip_weapon()
		return

	_equipped_weapon_scene_path = scene_path
	var scene_resource: Resource = load(scene_path)
	if scene_resource is PackedScene:
		_equip_weapon_scene(scene_resource as PackedScene, item_data)


func _equip_weapon_scene(scene: PackedScene, item_data: Dictionary = {}) -> void:
	if scene == null:
		return
	var old_max_hp := get_effective_max_hp()
	var old_max_mp := get_effective_max_mp()
	if _equipped_weapon != null:
		unequip_weapon()
		old_max_hp = get_effective_max_hp()
		old_max_mp = get_effective_max_mp()

	_equipped_weapon = scene.instantiate() as Node2D
	if _equipped_weapon == null:
		return

	weapon_anchor.add_child(_equipped_weapon)
	if _equipped_weapon.has_method("get_grip_offset"):
		_equipped_weapon.position = -_equipped_weapon.call("get_grip_offset")
	else:
		_equipped_weapon.position = Vector2.ZERO
	_equipped_weapon.rotation_degrees = 0.0
	_equipped_weapon.scale = Vector2.ONE
	if _equipped_weapon.has_signal("attack_motion_requested"):
		_equipped_weapon.connect("attack_motion_requested", Callable(self, "_on_weapon_attack_motion_requested"))
	if _equipped_weapon.has_signal("attack_state_changed"):
		_equipped_weapon.connect("attack_state_changed", Callable(self, "_on_weapon_attack_state_changed"))
	if _equipped_weapon.has_signal("startup_hold_requested"):
		_equipped_weapon.connect("startup_hold_requested", Callable(self, "_on_weapon_startup_hold_requested"))
	if _equipped_weapon.has_signal("buff_visual_state_changed"):
		_equipped_weapon.connect("buff_visual_state_changed", Callable(self, "_on_weapon_buff_visual_state_changed"))
	if _equipped_weapon.has_signal("super_armor_state_changed"):
		_equipped_weapon.connect("super_armor_state_changed", Callable(self, "_on_weapon_super_armor_state_changed"))
	if not item_data.is_empty() and _equipped_weapon.has_method("apply_runtime_item_data"):
		_equipped_weapon.call("apply_runtime_item_data", item_data)
	if _equipped_weapon.has_method("reset_pose"):
		_equipped_weapon.call("reset_pose")
	update_facing(facing)
	_refresh_equipped_weapon_visibility()
	_apply_attribute_runtime_refresh(old_max_hp, old_max_mp)


func unequip_weapon() -> void:
	_equipped_weapon_scene_path = ""
	if _equipped_weapon == null:
		return

	var old_max_hp := get_effective_max_hp()
	var old_max_mp := get_effective_max_mp()
	_attack_motion_timer = 0.0
	_attack_motion_speed = 0.0
	_attack_motion_sign = 0
	_weapon_attack_locked = false
	_weapon_attack_hold_run = false
	_weapon_startup_hold_timer = 0.0
	_attack_buff_visual_active = false
	_super_armor_active = false
	_left_eye_afterimages.clear()
	_right_eye_afterimages.clear()
	_eye_afterimage_timer = 0.0
	_refresh_buff_eye_visuals()
	_equipped_weapon.queue_free()
	_equipped_weapon = null
	_apply_attribute_runtime_refresh(old_max_hp, old_max_mp)


func _ensure_input_actions() -> void:
	ensure_key_action("move_left", [KEY_LEFT])
	ensure_key_action("move_right", [KEY_RIGHT])
	ensure_key_action("move_jump", [KEY_V])
	ensure_key_action("use_equipped_potion", [KEY_G])
	ensure_key_action("skill_modifier_z", [KEY_Z])
	ensure_key_action("attack_light", [KEY_C])
	ensure_key_action("attack_heavy", [KEY_X])
	ensure_key_action("interact_up", [KEY_UP])
	ensure_key_action("interact_down", [KEY_DOWN])
	ensure_key_action("debug_hit_stun_left", [KEY_KP_1])
	ensure_key_action("debug_hit_stun_right", [KEY_KP_2])
	ensure_key_action("debug_hit_launch_left", [KEY_KP_4])
	ensure_key_action("debug_hit_launch_right", [KEY_KP_5])
	ensure_key_action("debug_equip_spear", [KEY_KP_6])
	ensure_key_action("debug_equip_longsword", [KEY_KP_7])
	ensure_key_action("debug_restore_resources", [KEY_KP_8])
	ensure_key_action("debug_toggle_infinite_mp", [KEY_KP_9])
	ensure_key_action("debug_unequip_weapon", [KEY_KP_0])
	ensure_key_action("debug_kill_all_enemies", [KEY_0])


func ensure_key_action(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if InputMap.action_get_events(action_name).is_empty():
		for keycode in keycodes:
			var event := InputEventKey.new()
			event.keycode = keycode as Key
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action_name, event)


func update_attack_buff_visuals() -> void:
	if trail_dots_root == null:
		return

	if not _attack_buff_visual_active:
		_update_eye_trail_dots(_left_eye_trail_dots, [])
		_update_eye_trail_dots(_right_eye_trail_dots, [])
		return

	var left_eye_global := left_eye_glow.global_position
	var right_eye_global := right_eye_glow.global_position
	_eye_afterimage_timer -= get_physics_process_delta_time()
	if _eye_afterimage_timer <= 0.0:
		_eye_afterimage_timer = buff_eye_afterimage_interval
		_spawn_eye_afterimage(_left_eye_afterimages, left_eye_global)
		_spawn_eye_afterimage(_right_eye_afterimages, right_eye_global)

	_prune_eye_afterimages(_left_eye_afterimages)
	_prune_eye_afterimages(_right_eye_afterimages)
	_update_eye_afterimage_dots(_left_eye_trail_dots, _left_eye_afterimages)
	_update_eye_afterimage_dots(_right_eye_trail_dots, _right_eye_afterimages)


func _setup_eye_trail_dots() -> void:
	if trail_dots_root == null:
		return
	if not _left_eye_trail_dots.is_empty() or not _right_eye_trail_dots.is_empty():
		return

	for i in range(buff_eye_trail_max_points):
		var left_dot := _create_eye_trail_dot("LeftEyeTrailDot%d" % i)
		var right_dot := _create_eye_trail_dot("RightEyeTrailDot%d" % i)
		trail_dots_root.add_child(left_dot)
		trail_dots_root.add_child(right_dot)
		_left_eye_trail_dots.append(left_dot)
		_right_eye_trail_dots.append(right_dot)


func _create_eye_trail_dot(node_name: String) -> Polygon2D:
	var dot := Polygon2D.new()
	dot.name = node_name
	dot.visible = false
	dot.color = buff_eye_trail_color
	dot.polygon = PackedVector2Array([
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(1, 1),
		Vector2(-1, 1),
	])
	return dot


func _update_eye_trail_dots(dots: Array[Polygon2D], points: Array[Vector2]) -> void:
	for i in range(dots.size()):
		var dot := dots[i]
		if dot == null:
			continue
		if i >= points.size():
			dot.visible = false
			continue

		var point := points[points.size() - 1 - i]
		var fade_t := 0.0
		if dots.size() > 1:
			fade_t = float(i) / float(dots.size() - 1)
		var color := buff_eye_trail_color
		color.a *= lerpf(1.0, 0.0, fade_t)
		dot.visible = true
		dot.global_position = point
		dot.color = color
		var dot_scale := lerpf(buff_eye_trail_dot_scale_start, buff_eye_trail_dot_scale_end, fade_t)
		dot.scale = Vector2.ONE * dot_scale


func _spawn_eye_afterimage(store: Array[Dictionary], point: Vector2) -> void:
	store.append({
		"position": point,
		"spawn_time": get_time_seconds(),
	})
	while store.size() > buff_eye_trail_max_points:
		store.remove_at(0)


func _prune_eye_afterimages(store: Array[Dictionary]) -> void:
	var now := get_time_seconds()
	for i in range(store.size() - 1, -1, -1):
		var age := now - float(store[i].get("spawn_time", now))
		if age > buff_eye_afterimage_lifetime:
			store.remove_at(i)


func _update_eye_afterimage_dots(dots: Array[Polygon2D], store: Array[Dictionary]) -> void:
	var now := get_time_seconds()
	for i in range(dots.size()):
		var dot := dots[i]
		if dot == null:
			continue
		if i >= store.size():
			dot.visible = false
			continue

		var afterimage := store[store.size() - 1 - i]
		var spawn_time := float(afterimage.get("spawn_time", now))
		var age := now - spawn_time
		var life_t := 1.0
		if buff_eye_afterimage_lifetime > 0.0:
			life_t = clampf(age / buff_eye_afterimage_lifetime, 0.0, 1.0)
		var color := buff_eye_trail_color
		color.a *= (1.0 - life_t)
		var dot_scale := lerpf(buff_eye_trail_dot_scale_start, buff_eye_trail_dot_scale_end, life_t)
		dot.visible = true
		dot.global_position = afterimage.get("position", Vector2.ZERO)
		dot.color = color
		dot.scale = Vector2.ONE * dot_scale


func _refresh_buff_eye_visuals() -> void:
	if left_eye_glow == null or right_eye_glow == null or trail_dots_root == null:
		return

	left_eye_glow.visible = _attack_buff_visual_active
	right_eye_glow.visible = _attack_buff_visual_active
	left_eye_glow.color = buff_eye_glow_color
	right_eye_glow.color = buff_eye_glow_color
	if not _attack_buff_visual_active:
		_update_eye_trail_dots(_left_eye_trail_dots, [])
		_update_eye_trail_dots(_right_eye_trail_dots, [])


func _setup_potion_use_icon() -> void:
	if _potion_use_icon_sprite != null:
		return

	_potion_use_icon_sprite = Sprite2D.new()
	_potion_use_icon_sprite.name = "PotionUseIcon"
	_potion_use_icon_sprite.visible = false
	_potion_use_icon_sprite.centered = true
	_potion_use_icon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_potion_use_icon_sprite.z_index = 30
	_potion_use_icon_sprite.position = potion_use_icon_offset
	_potion_use_icon_sprite.scale = Vector2.ONE * potion_use_icon_scale
	add_child(_potion_use_icon_sprite)


func _show_potion_use_icon(item: Dictionary) -> void:
	if _potion_use_icon_sprite == null:
		return

	var icon_path: String = String(item.get("icon_path", ""))
	if icon_path.is_empty():
		_potion_use_icon_sprite.texture = null
		_potion_use_icon_sprite.visible = false
		return

	var resource: Resource = load(icon_path)
	if resource is Texture2D:
		_potion_use_icon_sprite.texture = resource as Texture2D
		_potion_use_icon_sprite.position = potion_use_icon_offset
		_potion_use_icon_sprite.scale = Vector2.ONE * potion_use_icon_scale
		_potion_use_icon_sprite.visible = true


func _hide_potion_use_icon() -> void:
	if _potion_use_icon_sprite == null:
		return
	_potion_use_icon_sprite.visible = false
	_potion_use_icon_sprite.texture = null


func _refresh_equipped_weapon_visibility() -> void:
	if _equipped_weapon == null:
		return
	_equipped_weapon.visible = _top_state != TopState.DEAD


func _show_death_overlay() -> void:
	if _death_overlay == null:
		return
	if _death_overlay.has_method("show_overlay"):
		_death_overlay.call("show_overlay")


func _apply_death_inventory_penalty() -> void:
	if not use_inventory_runtime_state:
		return
	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if inventory_runtime == null:
		return
	if inventory_runtime.has_method("apply_player_death_penalty"):
		inventory_runtime.call("apply_player_death_penalty")


func set_fall_death_y(value: float) -> void:
	fall_death_y = value
