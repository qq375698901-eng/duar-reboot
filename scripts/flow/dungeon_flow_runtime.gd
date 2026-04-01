extends Node

const TOWN_HUB_SCENE_PATH := "res://scenes/ui/town_hub_main_ui.tscn"
const TRANSITION_SCENE_PATH := "res://scenes/flow/dungeon_transition_scene.tscn"
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
var _current_stage_index: int = -1
var _current_room_paths: Array[String] = []
var _pending_room_type: StringName = &"unknown"
var _pending_room_path: String = ""


func _ready() -> void:
	_rng.randomize()


func start_fixed_dungeon_run() -> void:
	_current_room_paths = _build_fixed_room_flow()
	if _current_room_paths.is_empty():
		push_warning("DungeonFlowRuntime: no dungeon rooms found for fixed flow.")
		return

	_run_active = true
	_current_stage_index = 0
	_prepare_pending_room_for_current_stage()
	_go_to_transition_scene()


func advance_after_room_exit() -> void:
	if not _run_active:
		return

	_current_stage_index += 1
	if _current_stage_index >= _current_room_paths.size():
		_finish_run_to_town()
		return

	_prepare_pending_room_for_current_stage()
	_go_to_transition_scene()


func has_pending_room() -> bool:
	return not _pending_room_path.is_empty()


func is_run_active() -> bool:
	return _run_active


func get_pending_room_type_key() -> StringName:
	return _pending_room_type


func get_pending_room_descriptor_text() -> String:
	var encoded: String = String(ROOM_DESCRIPTOR_ENCODED_BY_TYPE.get(_pending_room_type, "5pyq55+l5Yy65Z+f"))
	return Marshalls.base64_to_utf8(encoded)


func load_pending_room() -> void:
	if _pending_room_path.is_empty():
		return
	get_tree().change_scene_to_file(_pending_room_path)


func cancel_run() -> void:
	_run_active = false
	_current_stage_index = -1
	_current_room_paths.clear()
	_pending_room_type = &"unknown"
	_pending_room_path = ""


func _build_fixed_room_flow() -> Array[String]:
	var paths: Array[String] = []
	for room_type_key in FIXED_ROOM_FLOW:
		var scene_path: String = _pick_room_scene_for_type(room_type_key)
		if scene_path.is_empty():
			push_warning("DungeonFlowRuntime: missing room scene for type %s" % String(room_type_key))
			return []
		paths.append(scene_path)
	return paths


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
	if _current_stage_index < 0 or _current_stage_index >= _current_room_paths.size():
		_pending_room_type = &"unknown"
		_pending_room_path = ""
		return

	_pending_room_type = FIXED_ROOM_FLOW[_current_stage_index]
	_pending_room_path = _current_room_paths[_current_stage_index]


func _go_to_transition_scene() -> void:
	if _pending_room_path.is_empty():
		return
	get_tree().change_scene_to_file(TRANSITION_SCENE_PATH)


func _finish_run_to_town() -> void:
	cancel_run()
	get_tree().change_scene_to_file(TOWN_HUB_SCENE_PATH)
