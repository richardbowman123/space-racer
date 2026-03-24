extends Node3D
## Player ship: movement along track, spring-damper steering,
## chain-based speed system, ring collection, hazard response,
## fire and shield abilities.

# --- References (set by GameManager) ---
var track_curve: Curve3D = null

# --- Progress & Speed ---
var progress: float = 0.0
var current_speed: float = 0.0
var speed_bonus: float = 0.0

@export var base_speed: float = 70.0
@export var max_speed: float = 160.0

# --- Chain system ---
var chain_count: int = 0
var chain_multiplier: float = 1.0
var _stun_timer: float = 0.0

# --- Steering (direct response model) ---
@export var max_offset: float = 14.0
## Exponential smoothing rate for steering (higher = snappier)
@export var steer_smooth: float = 16.0
## How fast ship drifts back to centre when not steering
@export var centre_pull: float = 1.0
## How much track curves push the ship outward (like centrifugal force)
@export var centrifugal_strength: float = 40.0

var steering_offset: Vector2 = Vector2.ZERO
var _prev_steering_offset: Vector2 = Vector2.ZERO
var _curve_lateral: float = 0.0    # Raw track curvature — lateral component
var _curve_vertical: float = 0.0   # Raw track curvature — vertical component
var _visual_pos: Vector3 = Vector3.ZERO
var _visual_basis: Basis = Basis.IDENTITY
var _visual_initialized: bool = false

# --- Racing line mechanics ---
## Speed penalty for rapid steering changes (0 = none, higher = harsher)
@export var steer_drag_penalty: float = 0.18
## Speed bonus for being on inside of curves (fraction of base_speed)
@export var apex_bonus_strength: float = 0.12
## Speed penalty for being at extreme track edges (fraction of base_speed)
@export var edge_drag_strength: float = 0.10
## How far ahead to sample for curvature detection (track units)
@export var curvature_sample_dist: float = 40.0

# Exposed for HUD
var racing_line_bonus: float = 0.0   # Current combined bonus/penalty ratio (-1 to +1)
var _steer_drag: float = 0.0         # Current steering drag (0 to 1)
var _apex_bonus: float = 0.0         # Current apex bonus (-1 to +1)
var _edge_drag: float = 0.0          # Current edge drag (0 to 1)

# --- Drift boost ---
## How long you must hold a turn before drift starts building (seconds)
@export var drift_threshold_time: float = 0.4
## Maximum drift charge (speed bonus on release)
@export var drift_max_charge: float = 25.0
## Rate of drift charge build per second
@export var drift_charge_rate: float = 18.0
## Minimum steering offset ratio to count as "turning"
@export var drift_min_steer: float = 0.25

var drift_charge: float = 0.0
var drift_timer: float = 0.0       # How long steering has been held
var _drift_direction: float = 0.0  # Sign of the turn (-1 or +1)
var drift_active: bool = false     # Is drift currently building?

signal drift_released(boost: float)

# --- Crosswind ---
var crosswind_force: Vector2 = Vector2.ZERO  # Set by game_manager each frame

# --- Visuals ---
@export var bank_intensity: float = 0.7
@export var pitch_intensity: float = 0.35

# --- Fire ability ---
var fire_cooldown: float = 0.0
@export var fire_cooldown_max: float = 2.0

# --- Shield ability ---
var shield_charges: int = 1
var shield_active: bool = false
var shield_timer: float = 0.0
@export var shield_duration: float = 3.0

# --- State ---
var is_racing: bool = false
var race_time: float = 0.0

signal race_finished(time: float)
signal ring_collected(chain: int, value: int)
signal hazard_hit_signal()
signal fire_requested(from_progress: float)
signal shield_activated()
signal shield_broke()
signal shield_expired()


func get_speed_ratio() -> float:
	return clampf((current_speed - base_speed) / (max_speed - base_speed), 0.0, 1.0)


func get_progress_ratio() -> float:
	if not track_curve:
		return 0.0
	var length = track_curve.get_baked_length()
	if length < 1.0:
		return 0.0
	return clampf(progress / length, 0.0, 1.0)


func start_race() -> void:
	is_racing = true
	race_time = 0.0
	current_speed = base_speed
	speed_bonus = 0.0
	chain_count = 0
	chain_multiplier = 1.0
	steering_offset = Vector2.ZERO
	_prev_steering_offset = Vector2.ZERO
	_steer_drag = 0.0
	_apex_bonus = 0.0
	_edge_drag = 0.0
	racing_line_bonus = 0.0
	drift_charge = 0.0
	drift_timer = 0.0
	_drift_direction = 0.0
	drift_active = false
	crosswind_force = Vector2.ZERO
	_curve_lateral = 0.0
	_curve_vertical = 0.0
	_stun_timer = 0.0
	fire_cooldown = 0.0
	shield_charges = 1
	shield_active = false
	shield_timer = 0.0


func collect_ring(value: int) -> void:
	## Called by GameManager when ship flies through a ring.
	chain_count += 1
	chain_multiplier = 1.0 + chain_count * 0.08  # 8% per chain link
	speed_bonus = minf(speed_bonus + 4.0 * float(value), 70.0)
	ring_collected.emit(chain_count, value)
	# Gold rings award shield charges
	if value == 3:
		shield_charges += 1


func hit_hazard() -> void:
	## Called by GameManager when ship hits an asteroid wall.
	# Shield absorbs the hit!
	if shield_active:
		shield_active = false
		shield_timer = 0.0
		shield_broke.emit()
		return

	chain_count = 0
	chain_multiplier = 1.0
	speed_bonus = maxf(speed_bonus - 25.0, 0.0)
	_stun_timer = 0.6  # Brief massive slowdown
	hazard_hit_signal.emit()


func try_fire() -> bool:
	## Attempt to fire. Returns true if shot was fired.
	if fire_cooldown > 0.0 or not is_racing:
		return false
	fire_cooldown = fire_cooldown_max
	fire_requested.emit(progress)
	return true


func try_shield() -> bool:
	## Attempt to activate shield. Returns true if activated.
	if shield_active or shield_charges <= 0 or not is_racing:
		return false
	shield_charges -= 1
	shield_active = true
	shield_timer = shield_duration
	shield_activated.emit()
	return true


func _process(delta: float) -> void:
	if not is_racing or not track_curve:
		return

	var baked_length = track_curve.get_baked_length()
	if baked_length < 10.0:
		return

	race_time += delta

	# --- Cooldowns & timers ---
	if fire_cooldown > 0.0:
		fire_cooldown = maxf(fire_cooldown - delta, 0.0)

	if shield_active:
		shield_timer -= delta
		if shield_timer <= 0.0:
			shield_active = false
			shield_timer = 0.0
			shield_expired.emit()

	# --- Speed calculation ---
	speed_bonus = maxf(speed_bonus - 3.0 * delta, 0.0)
	if chain_count > 0 and speed_bonus < 1.0:
		chain_count = 0
		chain_multiplier = 1.0

	current_speed = (base_speed + speed_bonus) * chain_multiplier

	if _stun_timer > 0.0:
		_stun_timer -= delta
		current_speed *= 0.35

	# --- Racing line mechanics ---
	_compute_racing_line(delta)

	# Apply racing line speed modifiers
	# Steering drag: penalise rapid direction changes
	current_speed *= (1.0 - _steer_drag * steer_drag_penalty)
	# Apex bonus: reward inside-line positioning on curves
	current_speed *= (1.0 + _apex_bonus * apex_bonus_strength)
	# Edge drag: penalise extreme lateral positions
	current_speed *= (1.0 - _edge_drag * edge_drag_strength)

	racing_line_bonus = _apex_bonus * apex_bonus_strength - _steer_drag * steer_drag_penalty - _edge_drag * edge_drag_strength

	# --- Drift boost ---
	_process_drift(delta)

	current_speed = clampf(current_speed, base_speed * 0.3, max_speed)

	# Advance along track
	progress += current_speed * delta

	# Check finish
	if progress >= baked_length - 5.0:
		is_racing = false
		race_finished.emit(race_time)
		return

	# --- Steering (direct response) ---
	var input = TouchInput.get_steering()

	# Frame-rate independent exponential smoothing: 1 - e^(-rate * dt)
	var steer_factor = 1.0 - exp(-steer_smooth * delta)
	var centre_factor = 1.0 - exp(-centre_pull * delta)

	if input.length() > 0.01:
		var target_offset = input * max_offset
		steering_offset = steering_offset.lerp(target_offset, steer_factor)
	else:
		steering_offset = steering_offset.lerp(Vector2.ZERO, centre_factor)

	# Apply crosswind force (set by game_manager each frame)
	if crosswind_force.length() > 0.01:
		steering_offset += crosswind_force * delta

	# Centrifugal force — track curves push ship outward
	# On a right curve, the ship drifts left (outward). Player must steer
	# into the curve to stay in the tunnel. Stronger at higher speeds.
	var speed_factor = current_speed / maxf(base_speed, 1.0)
	steering_offset.x -= _curve_lateral * centrifugal_strength * speed_factor * delta
	steering_offset.y -= _curve_vertical * centrifugal_strength * speed_factor * delta

	# Wall contact — scraping the tunnel wall slows you down
	if steering_offset.length() > max_offset:
		steering_offset = steering_offset.normalized() * max_offset
		speed_bonus = maxf(speed_bonus - 12.0 * delta, 0.0)

	# --- Compute target position on track ---
	var safe_p = clampf(progress, 0.0, baked_length - 1.0)
	var track_pos = track_curve.sample_baked(safe_p)
	var track_up = track_curve.sample_baked_up_vector(safe_p)
	var ahead_p = clampf(progress + 5.0, 0.0, baked_length - 0.5)
	var track_ahead = track_curve.sample_baked(ahead_p)
	var track_fwd = (track_ahead - track_pos)
	if track_fwd.length() < 0.001:
		track_fwd = Vector3(0, 0, -1)
	track_fwd = track_fwd.normalized()
	var track_right = track_fwd.cross(track_up).normalized()
	track_up = track_right.cross(track_fwd).normalized()

	var target_pos = track_pos + track_right * steering_offset.x + track_up * steering_offset.y

	# --- Compute target orientation ---
	var look_p = clampf(progress + 25.0, 0.0, baked_length - 0.5)
	var look_target = track_curve.sample_baked(look_p)
	var bank_angle = -steering_offset.x / max_offset * bank_intensity
	var banked_up = track_up.rotated(track_fwd, bank_angle)

	# Build target basis by temporarily setting transform
	var saved_basis = global_transform.basis
	var saved_pos = global_position
	global_position = target_pos
	if target_pos.distance_to(look_target) > 0.5:
		look_at(look_target, banked_up)
		rotate_object_local(Vector3.RIGHT, -steering_offset.y / max_offset * pitch_intensity)
	var target_basis = global_transform.basis

	# --- Smooth visual interpolation (frame-rate independent) ---
	# High rates here so visual tracks the logical position tightly
	# without the multi-frame lag that causes "stepping" feel
	if not _visual_initialized:
		_visual_pos = target_pos
		_visual_basis = target_basis
		_visual_initialized = true
	else:
		var pos_factor = 1.0 - exp(-22.0 * delta)
		var rot_factor = 1.0 - exp(-16.0 * delta)
		_visual_pos = _visual_pos.lerp(target_pos, pos_factor)
		_visual_basis = _visual_basis.slerp(target_basis, rot_factor)

	global_position = _visual_pos
	global_transform.basis = _visual_basis

	# Store for next frame's drag calculation
	_prev_steering_offset = steering_offset


func _compute_racing_line(delta: float) -> void:
	## Calculates three racing-line factors that affect speed:
	## 1) Steering drag: how fast the player is changing direction
	## 2) Apex bonus: whether ship is on the inside of the current curve
	## 3) Edge drag: how close to the track boundary the ship is

	if not track_curve:
		return

	var baked_length = track_curve.get_baked_length()
	var safe_p = clampf(progress, 0.0, baked_length - 1.0)

	# --- 1. STEERING DRAG ---
	# Measure how fast the steering offset is changing (not the absolute position)
	var steer_velocity = (steering_offset - _prev_steering_offset) / maxf(delta, 0.001)
	# Normalise: max meaningful velocity is roughly max_offset * steer_smooth
	var steer_speed = steer_velocity.length() / (max_offset * 6.0)
	# Smooth the drag value to avoid jitter
	_steer_drag = lerpf(_steer_drag, clampf(steer_speed, 0.0, 1.0), 1.0 - exp(-6.0 * delta))

	# --- 2. APEX BONUS (3D curvature) ---
	# Sample track direction at current position and ahead to find curvature
	var ahead_dist = clampf(progress + curvature_sample_dist, 0.0, baked_length - 1.0)
	var behind_dist = clampf(progress - curvature_sample_dist * 0.5, 0.0, baked_length - 1.0)

	var pos_here = track_curve.sample_baked(safe_p)
	var pos_ahead = track_curve.sample_baked(ahead_dist)
	var pos_behind = track_curve.sample_baked(behind_dist)

	var dir_forward = (pos_ahead - pos_here)
	var dir_behind = (pos_here - pos_behind)
	if dir_forward.length() < 0.1 or dir_behind.length() < 0.1:
		_apex_bonus = lerpf(_apex_bonus, 0.0, 1.0 - exp(-4.0 * delta))
		_curve_lateral = lerpf(_curve_lateral, 0.0, 1.0 - exp(-10.0 * delta))
		_curve_vertical = lerpf(_curve_vertical, 0.0, 1.0 - exp(-10.0 * delta))
	else:
		dir_forward = dir_forward.normalized()
		dir_behind = dir_behind.normalized()

		# Curvature vector: difference in track direction = which way track is bending
		var curvature = dir_forward - dir_behind

		# Project curvature onto the local track frame (right and up)
		var track_up = track_curve.sample_baked_up_vector(safe_p)
		var track_right = dir_forward.cross(track_up).normalized()
		track_up = track_right.cross(dir_forward).normalized()

		# How much the track curves laterally (+ = curving right) and vertically (+ = curving up)
		var curve_right = curvature.dot(track_right)
		var curve_up = curvature.dot(track_up)

		# Store raw curvature for centrifugal force (lightly smoothed to avoid jitter)
		_curve_lateral = lerpf(_curve_lateral, curve_right, 1.0 - exp(-10.0 * delta))
		_curve_vertical = lerpf(_curve_vertical, curve_up, 1.0 - exp(-10.0 * delta))

		# The "inside" of a right curve is the LEFT side (negative x offset)
		# The "inside" of an upward curve is the BOTTOM (negative y offset)
		# So the ideal offset direction is opposite to the curvature direction
		var ideal_x = -curve_right  # If track curves right, ideal is left
		var ideal_y = -curve_up     # If track curves up, ideal is below

		# How strong is the curvature? (0 = straight, higher = sharper bend)
		var curvature_magnitude = Vector2(curve_right, curve_up).length()
		# Scale: typical curvature values are 0.0 to 0.05
		var curvature_strength = clampf(curvature_magnitude * 25.0, 0.0, 1.0)

		# How well does the ship's position match the ideal?
		# Dot product of normalised ship offset and normalised ideal direction
		var ship_norm = steering_offset / maxf(max_offset, 0.01)
		var ideal_dir = Vector2(ideal_x, ideal_y)
		var ideal_len = ideal_dir.length()

		if ideal_len > 0.01 and curvature_strength > 0.05:
			ideal_dir = ideal_dir.normalized()
			# How far off-centre the ship is (0 = centred, 1 = at max offset)
			var ship_displacement = ship_norm.length()
			# Alignment: +1 = perfectly on inside, -1 = on outside
			var alignment = ship_norm.dot(ideal_dir) if ship_displacement > 0.05 else 0.0
			# Apex bonus = curvature_strength * alignment * displacement
			# You need to actually BE off-centre on the right side to get the bonus
			var raw_bonus = curvature_strength * alignment * clampf(ship_displacement * 2.0, 0.0, 1.0)
			_apex_bonus = lerpf(_apex_bonus, clampf(raw_bonus, -1.0, 1.0), 1.0 - exp(-4.0 * delta))
		else:
			# Straight section — no apex bonus or penalty
			_apex_bonus = lerpf(_apex_bonus, 0.0, 1.0 - exp(-4.0 * delta))

	# --- 3. EDGE DRAG ---
	# Penalise being near the track boundary (squared for gentle centre, harsh edges)
	var edge_ratio = steering_offset.length() / max_offset
	var raw_edge_drag = clampf((edge_ratio - 0.6) / 0.4, 0.0, 1.0)  # Kicks in past 60% offset
	raw_edge_drag = raw_edge_drag * raw_edge_drag  # Squared curve: gentle near 60%, harsh at 100%
	_edge_drag = lerpf(_edge_drag, raw_edge_drag, 1.0 - exp(-8.0 * delta))


func _process_drift(delta: float) -> void:
	## Drift boost: sustained turning builds charge → released as speed burst.
	## The player must hold a consistent turn direction past drift_min_steer
	## for drift_threshold_time before charge starts building.

	var steer_ratio = steering_offset.x / max_offset  # -1 to +1
	var steer_magnitude = absf(steer_ratio)

	if steer_magnitude > drift_min_steer:
		var current_dir = signf(steer_ratio)

		if not drift_active:
			# Check if we're turning the same direction as before
			if current_dir == _drift_direction:
				drift_timer += delta
				if drift_timer >= drift_threshold_time:
					drift_active = true
			else:
				# Direction changed — reset
				drift_timer = 0.0
				_drift_direction = current_dir
				if drift_charge > 2.0:
					# Release any existing charge as a boost
					_release_drift()
		else:
			# Drift is active — build charge
			if current_dir == _drift_direction:
				var charge_speed = drift_charge_rate * steer_magnitude
				drift_charge = minf(drift_charge + charge_speed * delta, drift_max_charge)
			else:
				# Direction reversed — release drift!
				_release_drift()
	else:
		# Steering relaxed — release any built-up drift
		if drift_charge > 2.0:
			_release_drift()
		drift_timer = 0.0
		drift_active = false


func _release_drift() -> void:
	if drift_charge > 2.0:
		speed_bonus = minf(speed_bonus + drift_charge, 70.0)
		drift_released.emit(drift_charge)
	drift_charge = 0.0
	drift_timer = 0.0
	drift_active = false
	_drift_direction = 0.0


func apply_boost_pad(amount: float) -> void:
	## Called by game_manager when ship flies over a boost pad.
	speed_bonus = minf(speed_bonus + amount, 70.0)


func apply_slingshot(amount: float) -> void:
	## Called by game_manager for gravity well slingshot.
	speed_bonus = minf(speed_bonus + amount, 70.0)
