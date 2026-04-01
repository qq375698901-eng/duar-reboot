@tool
extends Node2D


func _enter_tree() -> void:
	_sync_visibility()


func _ready() -> void:
	_sync_visibility()


func _sync_visibility() -> void:
	visible = Engine.is_editor_hint()
