extends "res://scripts/characters/player.gd"

@export var forced_get_up_hint_color: Color = Color(0.35, 1.0, 0.45, 1.0)
@export var damage_popup_rise_speed: float = 26.0
@export var damage_popup_lifetime: float = 0.55
@export var damage_popup_color: Color = Color(1.0, 0.92, 0.65, 1.0)

@onready var status_label: Label = $StatusLabel
@onready var status_bars: Control = $StatusBars
@onready var damage_popups_root: Node2D = $DamagePopups


func _ready() -> void:
	super._ready()
	if status_bars != null:
		status_bars.visible = false
	if status_label != null:
		status_label.visible = false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_damage_popups(delta)


func cache_input() -> void:
	_input_x = 0
	_input_y = 0


func handle_debug_weapon_inputs() -> void:
	pass


func handle_debug_hit_inputs() -> void:
	pass


func physics_operable(delta: float, _was_on_floor: bool) -> void:
	if is_on_floor():
		_move_phase = MovePhase.GROUND
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.y = 0.0
	else:
		_move_phase = MovePhase.AIR
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * 0.25 * delta)
		velocity.y += get_effective_gravity() * delta


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


func apply_damage(raw_damage: float) -> void:
	super.apply_damage(raw_damage)
	_show_damage_popup(maxf(0.0, raw_damage))

func can_show_forced_get_up_indicator() -> bool:
	return _top_state == TopState.LAUNCH and velocity.y > 0.0 and can_forced_get_up()


func _show_damage_popup(damage_value: float) -> void:
	if damage_popups_root == null or damage_value <= 0.0:
		return

	var popup := Label.new()
	popup.text = str(snappedf(damage_value, 0.1))
	popup.position = Vector2(-14.0, -52.0)
	popup.modulate = damage_popup_color
	popup.z_index = 10
	damage_popups_root.add_child(popup)
	popup.set_meta("lifetime_left", damage_popup_lifetime)


func _update_damage_popups(delta: float) -> void:
	if damage_popups_root == null:
		return

	for child in damage_popups_root.get_children():
		if child is not Label:
			continue

		var popup := child as Label
		var lifetime_left := float(popup.get_meta("lifetime_left", damage_popup_lifetime))
		lifetime_left = maxf(0.0, lifetime_left - delta)
		popup.set_meta("lifetime_left", lifetime_left)
		popup.position.y -= damage_popup_rise_speed * delta

		var alpha := 0.0
		if damage_popup_lifetime > 0.0:
			alpha = lifetime_left / damage_popup_lifetime
		var color := damage_popup_color
		color.a *= alpha
		popup.modulate = color

		if lifetime_left <= 0.0:
			popup.queue_free()
