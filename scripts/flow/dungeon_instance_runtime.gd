extends Node

signal pending_assignment_changed(assignment: Dictionary)
signal active_assignment_changed(assignment: Dictionary)
signal pending_assignment_cleared()
signal active_assignment_cleared()

var _pending_assignment: Dictionary = {}
var _active_assignment: Dictionary = {}


func has_pending_assignment() -> bool:
	return not _pending_assignment.is_empty()


func has_active_assignment() -> bool:
	return not _active_assignment.is_empty()


func set_pending_assignment(assignment: Dictionary) -> void:
	_pending_assignment = assignment.duplicate(true)
	pending_assignment_changed.emit(get_pending_assignment())


func clear_pending_assignment() -> void:
	if _pending_assignment.is_empty():
		return
	_pending_assignment.clear()
	pending_assignment_cleared.emit()


func get_pending_assignment() -> Dictionary:
	return _pending_assignment.duplicate(true)


func set_active_assignment(assignment: Dictionary) -> void:
	_active_assignment = assignment.duplicate(true)
	active_assignment_changed.emit(get_active_assignment())


func clear_active_assignment() -> void:
	if _active_assignment.is_empty():
		return
	_active_assignment.clear()
	active_assignment_cleared.emit()


func get_active_assignment() -> Dictionary:
	return _active_assignment.duplicate(true)


func clear_all() -> void:
	clear_pending_assignment()
	clear_active_assignment()


func get_active_instance_id() -> String:
	return String(_active_assignment.get("instance_id", ""))


func get_active_run_id() -> String:
	return String(_active_assignment.get("run_id", ""))


func get_active_stage_index() -> int:
	return int(_active_assignment.get("stage_index", -1))


func is_active_assignment_for_scene(scene_path: String) -> bool:
	if scene_path.is_empty() or _active_assignment.is_empty():
		return false
	return String(_active_assignment.get("room_scene_path", "")) == scene_path


func build_active_assignment_summary_text() -> String:
	if _active_assignment.is_empty():
		return "INSTANCE NONE"

	var stage_number: int = max(0, get_active_stage_index()) + 1
	return "INSTANCE %s | STAGE %d | RUN %s" % [
		String(_active_assignment.get("instance_id", "UNKNOWN")),
		stage_number,
		String(_active_assignment.get("run_id", "UNKNOWN")),
	]
