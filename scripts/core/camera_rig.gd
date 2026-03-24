extends Camera3D
## Chase camera that follows the player ship along the track.
## Sits behind and above the ship, tracks laterally with ship movement,
## banks into turns, and widens FOV at high speed.

## References (set by GameManager after scene loads)
var ship: Node3D = null
var track_curve: Curve3D = null

## Follow tuning
@export var follow_distance: float = 18.0
@export var follow_height: float = 6.0
@export var look_ahead: float = 35.0
@export var position_speed: float = 10.0
@export var rotation_speed: float = 6.0

## Lateral tracking — camera follows the ship's sideways movement
@export var lateral_follow: float = 0.4   # How much camera shifts with ship (0=none, 1=full)
@export var vertical_follow: float = 0.25  # How much camera shifts with ship's vertical offset

## Camera bank — tilts into the direction the ship is steering
@export var bank_follow: float = 0.3      # Roll angle from ship offset (radians)

## FOV
@export var base_fov: float = 70.0
@export var max_fov: float = 100.0
@export var fov_speed: float = 4.0

## Dynamic distance — camera pulls back at high speed
@export var min_follow_distance: float = 14.0
@export var max_follow_distance: float = 26.0

## Screen shake
var _shake_intensity: float = 0.0
var _shake_decay: float = 5.0


func start_shake(duration: float, intensity: float) -> void:
	_shake_intensity = intensity


func _process(delta: float) -> void:
	if not ship or not track_curve:
		return

	var baked_length = track_curve.get_baked_length()
	if baked_length < 20.0:
		return

	var progress: float = ship.progress

	# Dynamic follow distance based on speed
	var speed_ratio: float = ship.get_speed_ratio()
	var dynamic_distance = lerpf(min_follow_distance, max_follow_distance, speed_ratio)
	var dynamic_height = follow_height + speed_ratio * 2.0  # Slightly higher at speed too

	# Sample track positions
	var ship_dist = clampf(progress, 0.0, baked_length - 1.0)
	var behind_dist = clampf(progress - dynamic_distance, 0.0, baked_length - 1.0)
	var ahead_dist = clampf(progress + look_ahead, 0.0, baked_length - 1.0)

	var track_up = track_curve.sample_baked_up_vector(ship_dist)
	var behind_pos = track_curve.sample_baked(behind_dist)
	var ahead_pos = track_curve.sample_baked(ahead_dist)

	# Get track basis at camera position for lateral offset
	var behind_up = track_curve.sample_baked_up_vector(behind_dist)
	var behind_ahead = track_curve.sample_baked(clampf(behind_dist + 3.0, 0.0, baked_length - 0.5))
	var behind_fwd = (behind_ahead - behind_pos)
	if behind_fwd.length() < 0.001:
		behind_fwd = Vector3(0, 0, -1)
	behind_fwd = behind_fwd.normalized()
	var behind_right = behind_fwd.cross(behind_up).normalized()
	behind_up = behind_right.cross(behind_fwd).normalized()

	# Camera follows ship's lateral/vertical offset partially
	var ship_offset = ship.steering_offset  # Vector2(x, y)
	var lateral_offset = behind_right * ship_offset.x * lateral_follow
	var vertical_offset = behind_up * ship_offset.y * vertical_follow

	# Target camera position: behind ship + height + partial lateral tracking
	var target_pos = behind_pos + track_up * dynamic_height + lateral_offset + vertical_offset

	# Faster position interpolation for less lag
	global_position = global_position.lerp(target_pos, clampf(position_speed * delta, 0.0, 1.0))

	# Look target also shifts slightly with ship offset for dynamic feel
	var look_lateral = behind_right * ship_offset.x * 0.6
	var look_target = ahead_pos + track_up * 2.0 + look_lateral

	# Smooth rotation
	var cur_basis = global_transform.basis
	if global_position.distance_to(look_target) > 1.0:
		look_at(look_target, track_up)

	# Apply bank roll — camera tilts in the direction the ship is moving
	var bank_amount = -ship_offset.x / ship.max_offset * bank_follow
	rotate_object_local(Vector3.FORWARD, bank_amount)

	var target_basis = global_transform.basis
	global_transform.basis = cur_basis.slerp(target_basis, clampf(rotation_speed * delta, 0.0, 1.0))

	# Dynamic FOV
	var target_fov = lerpf(base_fov, max_fov, speed_ratio)
	fov = lerpf(fov, target_fov, clampf(fov_speed * delta, 0.0, 1.0))

	# Screen shake
	if _shake_intensity > 0.01:
		var shake_offset = Vector3(
			randf_range(-1, 1) * _shake_intensity,
			randf_range(-1, 1) * _shake_intensity,
			randf_range(-1, 1) * _shake_intensity * 0.3)
		global_position += shake_offset
		_shake_intensity = lerpf(_shake_intensity, 0.0, clampf(_shake_decay * delta, 0.0, 1.0))
