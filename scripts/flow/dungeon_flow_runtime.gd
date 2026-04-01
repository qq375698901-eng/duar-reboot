extends Node

const TOWN_HUB_SCENE_PATH := "res://scenes/ui/town_hub_main_ui.tscn"
const TRANSITION_SCENE_PATH := "res://scenes/flow/dungeon_transition_scene.tscn"
const INSTANCE_ALLOCATOR_PATH := "/root/InstanceAllocatorSimulator"
const INSTANCE_RUNTIME_PATH := "/root/DungeonInstanceRuntime"
const ROOM_SESSION_RUNTIME_PATH := "/root/DungeonRoomSessionRuntime"
const MONSTER_ROOM_DIR := "res://scenes/maps/dungeon/monster_rooms"
const ELITE_ROOM_DIR := "res://scenes/maps/dungeon/elite_monster_rooms"
const BATTLE_ROOM_DIR := "res://scenes/maps/dungeon/battle_rooms"
const BOSS_ROOM_DIR := "res://scenes/maps/dungeon/boss_rooms"
const EXTRACTION_ROOM_DIR := "res://scenes/maps/dungeon/extraction_rooms"

const ROOM_DESCRIPTOR_ENCODED_BY_TYPE := {
	&"monster": "5L2O5Y2x5Zyw5bim",
	&"elite_monster": "5Lit5Y2x5Zyw5bim",
	&"battle_room": "55Sf5q275Y6u5p2A",
	&"boss": "6auY5Y2x5Zyw5bim",
	&"extraction": "5b2S6YCU",
}

const FIXED_ROOM_FLOW: Array[StringName] = [
	&"monster",
	&"elite_monster",
	&"battle_room",
	&"boss",
	&"extraction",
]

var _rng := RandomNumberGenerator.new()
var _run_active: bool = false
var _run_id: String = ""
var _current_stage_index: int = -1
var _current_room_plans: Array[Dictionary] = []
var _pending_room_plan: Dictionary = {}
var _pending_room_assignment: Dictionary = {}
var _active_room_assignment: Dictionary = {}


func _ready() -> void:
	_rng.randomize()


func start_fixed_dungeon_run() -> void:
	_current_room_plans = _build_fixed_room_flow()
	if _current_room_plans.is_empty():
		push_warning("DungeonFlowRuntime: no dungeon rooms found for fixed flow.")
		return

	_run_active = true
	_run_id = "run_%d" % Time.get_ticks_msec()
	_current_stage_index = 0
	_prepare_pending_room_for_current_stage()
	_go_to_transition_scene()


func advance_after_room_exit() -> void:
	if not _run_active:
		return

	_finish_room_session("advance_to_next_room")
	_release_active_room_instance()
	_current_stage_index += 1
	if _current_stage_index >= _current_room_plans.size():
		_finish_run_to_town()
		return

	_prepare_pending_room_for_current_stage()
	_go_to_transition_scene()


func has_pending_room() -> bool:
	return not _pending_room_plan.is_empty()


func is_run_active() -> bool:
	return _run_active


func get_pending_room_type_key() -> StringName:
	return StringName(_pending_room_plan.get("room_type", &"unknown"))


func get_pending_room_descriptor_text() -> String:
	var room_type: StringName = get_pending_room_type_key()
	var encoded: String = String(ROOM_DESCRIPTOR_ENCODED_BY_TYPE.get(room_type, "5pyq55+l5Yy65Z+f"))
	return Marshalls.base64_to_utf8(encoded)


func request_pending_room_instance() -> Dictionary:
	if _pending_room_plan.is_empty():
		return {}
	if not _pending_room_assignment.is_empty():
		return _pending_room_assignment.duplicate(true)

	var allocator: Node = get_node_or_null(INSTANCE_ALLOCATOR_PATH)
	if allocator == null or not allocator.has_method("request_room_instance"):
		return {}

	var request := {
		"run_id": _run_id,
		"stage_index": int(_pending_room_plan.get("stage_index", -1)),
		"room_type": String(_pending_room_plan.get("room_type", "unknown")),
		"room_scene_path": String(_pending_room_plan.get("room_scene_path", "")),
	}
	var assignment: Dictionary = allocator.call("request_room_instance", request) as Dictionary
	if assignment.is_empty():
		return {}

	_pending_room_assignment = assignment.duplicate(true)
	_set_instance_runtime_pending_assignment(_pending_room_assignment)
	return _pending_room_assignment.duplicate(true)


func get_pending_room_instance_status_text() -> String:
	if _pending_room_assignment.is_empty():
		return "ALLOCATING INSTANCE..."

	return "INSTANCE %s READY" % String(_pending_room_assignment.get("instance_id", "UNKNOWN"))


func get_active_room_assignment() -> Dictionary:
	return _active_room_assignment.duplicate(true)


func load_pending_room() -> void:
	if _pending_room_assignment.is_empty():
		request_pending_room_instance()
	if _pending_room_assignment.is_empty():
		push_warning("DungeonFlowRuntime: pending room instance assignment failed.")
		return

	_active_room_assignment = _pending_room_assignment.duplicate(true)
	var room_scene_path: String = String(_active_room_assignment.get("room_scene_path", ""))
	_pending_room_assignment.clear()
	_activate_instance_runtime_assignment(_active_room_assignment)
	if room_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(room_scene_path)


func cancel_run() -> void:
	_finish_room_session("run_cancelled")
	_release_active_room_instance()
	_release_pending_room_instance()
	_run_active = false
	_run_id = ""
	_current_stage_index = -1
	_current_room_plans.clear()
	_pending_room_plan.clear()
	_clear_instance_runtime_assignments()


func _build_fixed_room_flow() -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	for room_type_key in FIXED_ROOM_FLOW:
		var scene_path: String = _pick_room_scene_for_type(room_type_key)
		if scene_path.is_empty():
			push_warning("DungeonFlowRuntime: missing room scene for type %s" % String(room_type_key))
			return []
		plans.append({
			"room_type": room_type_key,
			"room_scene_path": scene_path,
		})
	return plans


func _pick_room_scene_for_type(room_type_key: StringName) -> String:
	match room_type_key:
		&"monster":
			return _pick_random_scene_from_dir(MONSTER_ROOM_DIR)
		&"elite_monster":
			return _pick_first_scene_from_dir(ELITE_ROOM_DIR)
		&"battle_room":
			return _pick_first_scene_from_dir(BATTLE_ROOM_DIR)
		&"boss":
			return _pick_first_scene_from_dir(BOSS_ROOM_DIR)
		&"extraction":
			return _pick_first_scene_from_dir(EXTRACTION_ROOM_DIR)
		_:
			return ""


func _pick_random_scene_from_dir(dir_path: String) -> String:
	var scene_paths: Array[String] = _list_scene_files(dir_path)
	if scene_paths.is_empty():
		return ""
	return scene_paths[_rng.randi_range(0, scene_paths.size() - 1)]


func _pick_first_scene_from_dir(dir_path: String) -> String:
	var scene_paths: Array[String] = _list_scene_files(dir_path)
	if scene_paths.is_empty():
		return ""
	return scene_paths[0]


func _list_scene_files(dir_path: String) -> Array[String]:
	var scene_paths: Array[String] = []
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	for file_name in files:
		if not file_name.ends_with(".tscn"):
			continue
		scene_paths.append("%s/%s" % [dir_path, file_name])
	scene_paths.sort()
	return scene_paths


func _prepare_pending_room_for_current_stage() -> void:
	_release_pending_room_instance()
	_pending_room_plan.clear()
	if _current_stage_index < 0 or _current_stage_index >= _current_room_plans.size():
		return

	_pending_room_plan = (_current_room_plans[_current_stage_index] as Dictionary).duplicate(true)
	_pending_room_plan["stage_index"] = _current_stage_index
	_clear_instance_runtime_pending_assignment()


func _go_to_transition_scene() -> void:
	if _pending_room_plan.is_empty():
		return
	get_tree().change_scene_to_file(TRANSITION_SCENE_PATH)


func _finish_run_to_town() -> void:
	_finish_room_session("run_completed")
	cancel_run()
	get_tree().change_scene_to_file(TOWN_HUB_SCENE_PATH)


func _release_pending_room_instance() -> void:
	_release_room_instance_by_assignment(_pending_room_assignment)
	_pending_room_assignment.clear()
	_clear_instance_runtime_pending_assignment()


func _release_active_room_instance() -> void:
	_release_room_instance_by_assignment(_active_room_assignment)
	_active_room_assignment.clear()
	_clear_instance_runtime_active_assignment()


func _release_room_instance_by_assignment(assignment: Dictionary) -> void:
	if assignment.is_empty():
		return

	var instance_id: String = String(assignment.get("instance_id", ""))
	if instance_id.is_empty():
		return

	var allocator: Node = get_node_or_null(INSTANCE_ALLOCATOR_PATH)
	if allocator == null or not allocator.has_method("release_room_instance"):
		return
	allocator.call("release_room_instance", instance_id)


func _set_instance_runtime_pending_assignment(assignment: Dictionary) -> void:
	var instance_runtime: Node = get_node_or_null(INSTANCE_RUNTIME_PATH)
	if instance_runtime == null or not instance_runtime.has_method("set_pending_assignment"):
		return
	instance_runtime.call("set_pending_assignment", assignment.duplicate(true))


func _activate_instance_runtime_assignment(assignment: Dictionary) -> void:
	var instance_runtime: Node = get_node_or_null(INSTANCE_RUNTIME_PATH)
	if instance_runtime == null:
		return
	if instance_runtime.has_method("set_active_assignment"):
		instance_runtime.call("set_active_assignment", assignment.duplicate(true))
	if instance_runtime.has_method("clear_pending_assignment"):
		instance_runtime.call("clear_pending_assignment")


func _clear_instance_runtime_pending_assignment() -> void:
	var instance_runtime: Node = get_node_or_null(INSTANCE_RUNTIME_PATH)
	if instance_runtime == null or not instance_runtime.has_method("clear_pending_assignment"):
		return
	instance_runtime.call("clear_pending_assignment")


func _clear_instance_runtime_active_assignment() -> void:
	var instance_runtime: Node = get_node_or_null(INSTANCE_RUNTIME_PATH)
	if instance_runtime == null or not instance_runtime.has_method("clear_active_assignment"):
		return
	instance_runtime.call("clear_active_assignment")


func _clear_instance_runtime_assignments() -> void:
	var instance_runtime: Node = get_node_or_null(INSTANCE_RUNTIME_PATH)
	if instance_runtime == null or not instance_runtime.has_method("clear_all"):
		return
	instance_runtime.call("clear_all")


func _finish_room_session(finish_reason: String) -> void:
	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime == null \
			or not room_session_runtime.has_method("has_active_session") \
			or not bool(room_session_runtime.call("has_active_session")) \
			or not room_session_runtime.has_method("finish_room_session"):
		return
	room_session_runtime.call("finish_room_session", finish_reason)
