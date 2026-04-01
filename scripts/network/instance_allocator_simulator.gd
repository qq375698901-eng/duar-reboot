extends Node

signal room_instance_allocated(assignment: Dictionary)
signal room_instance_released(instance_id: String)

const ALLOCATOR_BACKEND_ID := "instance_allocator_simulated"
const HOST_MODE_LOCAL_SCENE := "local_scene"

var _next_instance_serial: int = 1
var _active_assignments: Dictionary = {}


func request_room_instance(request: Dictionary) -> Dictionary:
	var room_scene_path: String = String(request.get("room_scene_path", ""))
	if room_scene_path.is_empty():
		return {}
	if not ResourceLoader.exists(room_scene_path):
		return {}

	var instance_id: String = "sim_room_%04d" % _next_instance_serial
	_next_instance_serial += 1

	var assignment := {
		"instance_id": instance_id,
		"allocator_backend": ALLOCATOR_BACKEND_ID,
		"host_mode": HOST_MODE_LOCAL_SCENE,
		"listen_port": 0,
		"room_type": String(request.get("room_type", "unknown")),
		"room_scene_path": room_scene_path,
		"stage_index": int(request.get("stage_index", -1)),
		"run_id": String(request.get("run_id", "")),
	}
	_active_assignments[instance_id] = assignment.duplicate(true)
	print("InstanceAllocatorSimulator allocate -> %s (%s)" % [instance_id, room_scene_path])
	room_instance_allocated.emit(assignment.duplicate(true))
	return assignment


func release_room_instance(instance_id: String) -> bool:
	if instance_id.is_empty() or not _active_assignments.has(instance_id):
		return false
	_active_assignments.erase(instance_id)
	print("InstanceAllocatorSimulator release -> %s" % instance_id)
	room_instance_released.emit(instance_id)
	return true


func get_active_instance_count() -> int:
	return _active_assignments.size()


func get_assignment(instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	return (_active_assignments.get(instance_id, {}) as Dictionary).duplicate(true)
