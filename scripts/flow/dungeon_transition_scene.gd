extends Control

const PREFIX_TEXT_B64 := "5YmN5pa55piv4oCm4oCm"
const REVEAL_DELAY_SEC := 5.0
const LOAD_DELAY_AFTER_REVEAL_SEC := 1.0

@onready var hint_label: Label = $CenterContainer/HintLabel
@onready var reveal_timer: Timer = $RevealTimer
@onready var load_timer: Timer = $LoadTimer

var _prefix_text: String = ""
var _full_text: String = ""
var _instance_status_text: String = ""


func _ready() -> void:
	_prefix_text = Marshalls.base64_to_utf8(PREFIX_TEXT_B64)
	_full_text = _prefix_text
	_resolve_transition_text()

	hint_label.text = _prefix_text
	reveal_timer.wait_time = REVEAL_DELAY_SEC
	load_timer.wait_time = LOAD_DELAY_AFTER_REVEAL_SEC
	reveal_timer.timeout.connect(_on_reveal_timer_timeout)
	load_timer.timeout.connect(_on_load_timer_timeout)
	reveal_timer.start()


func _resolve_transition_text() -> void:
	var flow_runtime: Node = get_node_or_null("/root/DungeonFlowRuntime")
	if flow_runtime == null:
		return

	var descriptor_text: String = ""
	if flow_runtime.has_method("get_pending_room_descriptor_text"):
		descriptor_text = String(flow_runtime.call("get_pending_room_descriptor_text"))

	var instance_assignment: Dictionary = {}
	if flow_runtime.has_method("request_pending_room_instance"):
		instance_assignment = flow_runtime.call("request_pending_room_instance") as Dictionary

	if flow_runtime.has_method("get_pending_room_instance_status_text"):
		_instance_status_text = String(flow_runtime.call("get_pending_room_instance_status_text"))
	elif not instance_assignment.is_empty():
		_instance_status_text = "INSTANCE %s READY" % String(instance_assignment.get("instance_id", "UNKNOWN"))
	else:
		_instance_status_text = "INSTANCE ALLOCATION FAILED"

	_full_text = "%s%s" % [_prefix_text, descriptor_text]
	if not _instance_status_text.is_empty():
		_full_text = "%s\n%s" % [_full_text, _instance_status_text]


func _on_reveal_timer_timeout() -> void:
	hint_label.text = _full_text
	load_timer.start()


func _on_load_timer_timeout() -> void:
	var flow_runtime: Node = get_node_or_null("/root/DungeonFlowRuntime")
	if flow_runtime != null and flow_runtime.has_method("load_pending_room"):
		flow_runtime.call("load_pending_room")
