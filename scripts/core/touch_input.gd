extends Node
## Autoloaded singleton for single-finger drag steering.
## Works with both touch (mobile) and mouse (desktop testing).
## Drag from an anchor point to steer — distance from anchor = steering intensity.
## Supports exclusion zones so UI buttons can coexist with full-screen drag.

var is_active: bool = false
var anchor_position: Vector2 = Vector2.ZERO
var current_steering: Vector2 = Vector2.ZERO
var _raw_steering: Vector2 = Vector2.ZERO

## Rects where touches should NOT start a drag (button areas)
var _exclusion_rects: Array = []

## Pixels of drag required for full steering input
@export var drag_range: float = 100.0
## Central dead zone as fraction (0-1). Prevents twitchy micro-corrections.
@export var dead_zone: float = 0.05
## Smoothing speed (higher = more responsive, lower = smoother)
@export var smoothing: float = 18.0


func add_exclusion_rect(rect: Rect2) -> void:
	_exclusion_rects.append(rect)


func clear_exclusion_rects() -> void:
	_exclusion_rects.clear()


func _is_in_exclusion_zone(pos: Vector2) -> bool:
	for rect in _exclusion_rects:
		if rect.has_point(pos):
			return true
	return false


func _process(delta: float) -> void:
	# Smooth the output toward raw input (or zero if not touching)
	var target = _raw_steering if is_active else Vector2.ZERO
	current_steering = current_steering.lerp(target, clampf(smoothing * delta, 0.0, 1.0))


func _input(event: InputEvent) -> void:
	# --- Touch input (mobile) ---
	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_in_exclusion_zone(event.position):
				return
			is_active = true
			anchor_position = event.position
			_raw_steering = Vector2.ZERO
		else:
			is_active = false
			_raw_steering = Vector2.ZERO

	elif event is InputEventScreenDrag and is_active:
		_update_steering_from_position(event.position)

	# --- Mouse input (desktop testing) ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_in_exclusion_zone(event.position):
					return
				is_active = true
				anchor_position = event.position
				_raw_steering = Vector2.ZERO
			else:
				is_active = false
				_raw_steering = Vector2.ZERO

	elif event is InputEventMouseMotion and is_active:
		_update_steering_from_position(event.position)


func _update_steering_from_position(pos: Vector2) -> void:
	var delta_px = pos - anchor_position
	var normalized = delta_px / drag_range

	# Apply dead zone independently per axis
	normalized.x = _apply_dead_zone(normalized.x)
	normalized.y = _apply_dead_zone(-normalized.y)  # Invert Y so drag-up = steer-up

	# Clamp to unit circle so diagonal steering isn't faster
	if normalized.length() > 1.0:
		normalized = normalized.normalized()

	_raw_steering = normalized


func _apply_dead_zone(value: float) -> float:
	var abs_val = absf(value)
	if abs_val < dead_zone:
		return 0.0
	# Remap so output starts at 0 just outside the dead zone
	var remapped = (abs_val - dead_zone) / (1.0 - dead_zone)
	return signf(value) * remapped


## Returns the current smoothed steering vector. X = lateral, Y = vertical.
## Each axis ranges from -1 to +1.
func get_steering() -> Vector2:
	return current_steering
