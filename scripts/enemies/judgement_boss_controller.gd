extends Node
class_name JudgementBossController

signal boss_battle_started()
signal boss_battle_finished()

const JUDGEMENT_HEAD_GROUP := &"judgement_head_units"
const FIRE_HEAD_KIND := &"fire"
const PHASE_ONE_END_SEC := 60.0
const PHASE_TWO_END_SEC := 120.0
const PHASE_THREE_END_SEC := 180.0

@export_group("Boss Timing")
@export var public_cooldown_sec: float = 3.0
@export var empty_selection_retry_sec: float = 0.5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _head_units: Array[Node2D] = []
var _active_wave_heads: Array[Node2D] = []
var _battle_started: bool = false
var _battle_finished: bool = false
var _initialized: bool = false
var _wave_in_progress: bool = false
var _battle_elapsed_sec: float = 0.0
var _public_cooldown_left: float = 0.0
var _locked_fire_heads: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	call_deferred("_initialize_head_units")


func _physics_process(delta: float) -> void:
	if not _initialized or _battle_finished:
		return
	if not _battle_started:
		return

	_battle_elapsed_sec += delta

	if _public_cooldown_left > 0.0:
		_public_cooldown_left = maxf(0.0, _public_cooldown_left - delta)

	if _wave_in_progress:
		return

	if _public_cooldown_left > 0.0:
		return

	_try_start_next_wave()


func has_battle_started() -> bool:
	return _battle_started


func get_battle_elapsed_sec() -> float:
	return _battle_elapsed_sec


func _initialize_head_units() -> void:
	_head_units.clear()
	for node in get_tree().get_nodes_in_group(JUDGEMENT_HEAD_GROUP):
		if node is not Node2D:
			continue
		var head: Node2D = node as Node2D
		_head_units.append(head)
		if head.has_method("set_controller_driven"):
			head.call("set_controller_driven", true)
		_connect_head_signal(head, &"head_damaged", Callable(self, "_on_head_damaged"))
		_connect_head_signal(head, &"head_cycle_finished", Callable(self, "_on_head_cycle_finished"))
		_connect_head_signal(head, &"head_async_cycle_resolved", Callable(self, "_on_head_async_cycle_resolved"))
		_connect_head_signal(head, &"head_broken", Callable(self, "_on_head_broken"))

	_initialized = true
	if _collect_alive_heads().is_empty():
		_finish_battle()


func _connect_head_signal(head: Node, signal_name: StringName, callable: Callable) -> void:
	if not head.has_signal(signal_name):
		return
	if head.is_connected(signal_name, callable):
		return
	head.connect(signal_name, callable)


func _on_head_damaged(head: Node, _source: Node) -> void:
	if _battle_finished:
		return
	if not _battle_started and _is_head_alive(head):
		_start_battle()


func _on_head_cycle_finished(head: Node) -> void:
	if not _wave_in_progress:
		return
	_remove_active_wave_head(head)
	_check_wave_completion()


func _on_head_broken(head: Node) -> void:
	_remove_active_wave_head(head)
	_unlock_fire_head(head)
	if _collect_alive_heads().is_empty():
		_finish_battle()
		return
	_check_wave_completion()


func _on_head_async_cycle_resolved(head: Node) -> void:
	_unlock_fire_head(head)


func _start_battle() -> void:
	if _battle_started or _battle_finished:
		return
	_battle_started = true
	_battle_elapsed_sec = 0.0
	_public_cooldown_left = 0.0
	boss_battle_started.emit()
	_try_start_next_wave()


func _finish_battle() -> void:
	if _battle_finished:
		return
	_battle_finished = true
	_wave_in_progress = false
	_active_wave_heads.clear()
	_public_cooldown_left = 0.0
	_locked_fire_heads.clear()
	boss_battle_finished.emit()


func _try_start_next_wave() -> void:
	if not _battle_started or _battle_finished or _wave_in_progress:
		return

	var alive_heads: Array[Node2D] = _collect_alive_heads()
	if alive_heads.is_empty():
		_finish_battle()
		return

	var desired_count: int = mini(_get_phase_active_count(), alive_heads.size())
	if desired_count <= 0:
		return

	var available_heads: Array[Node2D] = _collect_available_heads(alive_heads)
	if available_heads.is_empty():
		_public_cooldown_left = empty_selection_retry_sec
		return

	var preferred_pool: Array[Node2D] = _build_selection_pool(available_heads, desired_count, true)
	var selection_pool: Array[Node2D] = preferred_pool
	if selection_pool.size() < desired_count:
		selection_pool = _build_selection_pool(available_heads, desired_count, false)

	if selection_pool.is_empty():
		_public_cooldown_left = empty_selection_retry_sec
		return

	desired_count = mini(desired_count, selection_pool.size())
	if desired_count <= 0:
		_public_cooldown_left = empty_selection_retry_sec
		return

	var chosen_heads: Array[Node2D] = _pick_random_subset(selection_pool, desired_count)
	if chosen_heads.is_empty():
		_public_cooldown_left = empty_selection_retry_sec
		return

	_start_wave(chosen_heads)


func _start_wave(chosen_heads: Array[Node2D]) -> void:
	var started_heads: Array[Node2D] = []
	for head in chosen_heads:
		if _is_fire_head(head) and head.has_method("set_controller_bind_candidates"):
			var bind_candidates: Array[Node2D] = _build_fire_bind_candidates(head)
			head.call("set_controller_bind_candidates", bind_candidates)

	for head in chosen_heads:
		if not head.has_method("begin_controlled_skill_cycle"):
			continue
		var started: bool = bool(head.call("begin_controlled_skill_cycle"))
		if started:
			started_heads.append(head)

	if started_heads.is_empty():
		_public_cooldown_left = empty_selection_retry_sec
		return

	_active_wave_heads = started_heads
	_wave_in_progress = true
	_public_cooldown_left = _get_phase_public_cooldown_sec()
	for head in started_heads:
		if _is_fire_head(head):
			_lock_fire_head(head)


func _check_wave_completion() -> void:
	if not _wave_in_progress:
		return
	if not _active_wave_heads.is_empty():
		return

	_wave_in_progress = false

	if _battle_finished:
		return

	if _public_cooldown_left <= 0.0:
		_try_start_next_wave()


func _remove_active_wave_head(head: Node) -> void:
	if head is not Node2D:
		return
	var typed_head: Node2D = head as Node2D
	var next_active_heads: Array[Node2D] = []
	for active_head in _active_wave_heads:
		if active_head == typed_head:
			continue
		next_active_heads.append(active_head)
	_active_wave_heads = next_active_heads


func _collect_alive_heads() -> Array[Node2D]:
	var results: Array[Node2D] = []
	for head in _head_units:
		if _is_head_alive(head):
			results.append(head)
	return results


func _collect_available_heads(alive_heads: Array[Node2D]) -> Array[Node2D]:
	var results: Array[Node2D] = []
	for head in alive_heads:
		if not _is_head_available_for_controller(head):
			continue
		results.append(head)
	return results


func _build_selection_pool(available_heads: Array[Node2D], desired_count: int, respect_fire_repeat: bool) -> Array[Node2D]:
	var results: Array[Node2D] = []
	for head in available_heads:
		if _is_fire_head(head):
			if desired_count <= 1:
				continue
			if respect_fire_repeat and _is_fire_head_locked(head):
				continue
		results.append(head)
	return results


func _pick_random_subset(pool: Array[Node2D], count: int) -> Array[Node2D]:
	var shuffled: Array[Node2D] = []
	for head in pool:
		shuffled.append(head)

	var index: int = shuffled.size() - 1
	while index > 0:
		var swap_index: int = _rng.randi_range(0, index)
		var temporary_head: Node2D = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = temporary_head
		index -= 1

	var results: Array[Node2D] = []
	var limit: int = mini(count, shuffled.size())
	for result_index in range(limit):
		results.append(shuffled[result_index])
	return results


func _build_fire_bind_candidates(fire_head: Node2D) -> Array[Node2D]:
	var results: Array[Node2D] = []
	for candidate in _collect_alive_heads():
		if candidate == fire_head:
			continue
		if not _is_head_alive(candidate):
			continue
		if not _can_head_trigger_fire_binding(candidate):
			continue
		results.append(candidate)
	return results


func _is_head_alive(head: Variant) -> bool:
	if head == null:
		return false
	if not is_instance_valid(head):
		return false
	if head.has_method("is_dead"):
		return not bool(head.call("is_dead"))
	return true


func _is_head_available_for_controller(head: Variant) -> bool:
	if not _is_head_alive(head):
		return false
	if head.has_method("is_available_for_controller"):
		return bool(head.call("is_available_for_controller"))
	return false


func _is_fire_head(head: Variant) -> bool:
	if head == null:
		return false
	if not is_instance_valid(head):
		return false
	if not head.has_method("get_judgement_head_kind"):
		return false
	return StringName(head.call("get_judgement_head_kind")) == FIRE_HEAD_KIND


func _lock_fire_head(head: Variant) -> void:
	if not _is_fire_head(head):
		return
	var fire_node: Node = head as Node
	if fire_node == null:
		return
	_locked_fire_heads[fire_node.get_instance_id()] = true


func _unlock_fire_head(head: Variant) -> void:
	if head == null:
		return
	if not is_instance_valid(head):
		return
	var node_head: Node = head as Node
	if node_head == null:
		return
	_locked_fire_heads.erase(node_head.get_instance_id())


func _is_fire_head_locked(head: Variant) -> bool:
	if not _is_fire_head(head):
		return false
	var fire_node: Node = head as Node
	if fire_node == null:
		return false
	return _locked_fire_heads.has(fire_node.get_instance_id())


func _can_head_trigger_fire_binding(head: Variant) -> bool:
	if not _is_head_alive(head):
		return false
	if not head.has_method("get_judgement_head_kind"):
		return false

	var head_kind: StringName = StringName(head.call("get_judgement_head_kind"))
	match head_kind:
		&"restore":
			return _has_healable_target_for_restore(head)
		FIRE_HEAD_KIND:
			return false
		_:
			return true


func _has_healable_target_for_restore(restore_head: Variant) -> bool:
	for candidate in _collect_alive_heads():
		if candidate == restore_head:
			continue
		if not candidate.has_method("can_receive_head_heal"):
			continue
		if bool(candidate.call("can_receive_head_heal")):
			return true
	return false


func _get_phase_active_count() -> int:
	if _battle_elapsed_sec < PHASE_ONE_END_SEC:
		return 1
	if _battle_elapsed_sec < PHASE_TWO_END_SEC:
		return 2
	return 3


func _get_phase_public_cooldown_sec() -> float:
	if _battle_elapsed_sec < PHASE_THREE_END_SEC:
		return public_cooldown_sec
	return 0.0
