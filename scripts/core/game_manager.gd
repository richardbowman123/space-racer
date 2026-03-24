extends Node3D
## Orchestrates the race: wires references, manages countdown,
## detects ring collection, spawns & moves hazard walls, checks collisions,
## manages projectiles from the fire ability.

@onready var track: Path3D = $Track
@onready var ship: Node3D = $PlayerShip
@onready var camera: Camera3D = $Camera
@onready var hud: CanvasLayer = $HUD

var race_state: String = "waiting"  # waiting | countdown | racing | finished
var countdown_timer: float = 0.0
var _last_countdown: int = -1

# Ring & hazard data (fetched from track_manager)
var ring_data: Array = []
var hazard_wave_data: Array = []

# Racing feature data
var boost_pad_data: Array = []
var speed_gate_data: Array = []
var crosswind_data: Array = []
var gravity_well_data: Array = []

# Hazard wall spawning
var _hazard_spawn_distance: float = 250.0
var _hazard_despawn_distance: float = 80.0
var _race_elapsed: float = 0.0

# Ring detection tolerances
var _ring_progress_tolerance: float = 8.0
var _ring_offset_tolerance: float = 5.0

# Hazard collision tolerance
var _hazard_progress_tolerance: float = 4.0

# Projectile system
var _projectiles: Array = []  # [{progress, node, speed}]
var _projectile_speed: float = 300.0
var _projectile_max_range: float = 400.0


func _ready() -> void:
	# Ship needs the track curve
	ship.track_curve = track.curve
	ship.race_finished.connect(_on_race_finished)
	ship.ring_collected.connect(_on_ring_collected)
	ship.hazard_hit_signal.connect(_on_hazard_hit)
	ship.fire_requested.connect(_on_fire_requested)
	ship.shield_activated.connect(_on_shield_activated)
	ship.shield_broke.connect(_on_shield_broke)
	ship.shield_expired.connect(_on_shield_expired)

	# Apply difficulty parameters from GameSettings
	var params = GameSettings.get_params()
	ship.base_speed = params["base_speed"]
	ship.max_speed = params["max_speed"]
	ship.centrifugal_strength = params["centrifugal_strength"]
	ship.centre_pull = params["centre_pull"]
	ship.max_offset = params["max_offset"]
	ship.steer_smooth = params["steer_smooth"]

	# Camera needs ship and curve references
	camera.ship = ship
	camera.track_curve = track.curve

	# Grab ring and hazard data from track
	ring_data = track.get_ring_data()
	hazard_wave_data = track.get_hazard_wave_data()
	boost_pad_data = track.get_boost_pad_data()
	speed_gate_data = track.get_speed_gate_data()
	crosswind_data = track.get_crosswind_data()
	gravity_well_data = track.get_gravity_well_data()

	# Wire drift boost signal
	ship.drift_released.connect(_on_drift_released)

	# Wire HUD button signals
	hud.fire_pressed.connect(_on_fire_button)
	hud.shield_pressed.connect(_on_shield_button)

	# Wire HUD navigation signals
	hud.restart_pressed.connect(_on_restart)
	hud.menu_pressed.connect(_on_menu)

	# Position ship at the starting line
	if track.curve and track.curve.get_baked_length() > 20.0:
		var start_pos = track.curve.sample_baked(10.0)
		var start_up = track.curve.sample_baked_up_vector(10.0)
		ship.global_position = start_pos + start_up * 1.0
		ship.progress = 10.0

		var look_pos = track.curve.sample_baked(30.0)
		ship.look_at(look_pos, start_up)

		var cam_pos = track.curve.sample_baked(0.0)
		camera.global_position = cam_pos + start_up * 6.0

	_start_countdown()


func _start_countdown() -> void:
	race_state = "countdown"
	countdown_timer = 3.5
	_last_countdown = 4


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if race_state == "racing":
			hud.toggle_pause()
		elif race_state == "finished":
			_on_menu()


func _process(delta: float) -> void:
	match race_state:
		"countdown":
			_process_countdown(delta)
		"racing":
			_race_elapsed += delta
			_process_rings()
			# Asteroids disabled while tuning pure racing feel
			#_process_hazard_spawning()
			#_process_hazard_movement()
			#_process_hazard_collision()
			#_process_projectiles(delta)
			_process_boost_pads()
			_process_speed_gates()
			_process_crosswinds(delta)
			_process_gravity_wells(delta)
			_process_racing_hud()


func _process_countdown(delta: float) -> void:
	countdown_timer -= delta
	var count = ceili(countdown_timer)

	if count != _last_countdown:
		_last_countdown = count
		if count <= 0:
			hud.show_countdown_go()
			race_state = "racing"
			ship.start_race()
		elif count <= 3:
			hud.show_countdown(count)


# =========================================================================
#  BUTTON HANDLING
# =========================================================================

func _on_fire_button() -> void:
	if race_state == "racing":
		ship.try_fire()


func _on_shield_button() -> void:
	if race_state == "racing":
		ship.try_shield()


func _on_shield_activated() -> void:
	hud.show_shield_active(true)


func _on_shield_broke() -> void:
	hud.show_shield_active(false)
	hud.show_flash("SHIELD!", Color(0.3, 0.7, 1.0, 1.0))


func _on_shield_expired() -> void:
	hud.show_shield_active(false)


# =========================================================================
#  RING COLLECTION
# =========================================================================

func _process_rings() -> void:
	var ship_prog = ship.progress
	var ship_offset = ship.steering_offset
	var max_off = ship.max_offset

	for ring in ring_data:
		if ring["collected"]:
			continue

		var ring_prog = ring["progress"]
		var dist_along = absf(ship_prog - ring_prog)
		if dist_along > _ring_progress_tolerance:
			continue

		var ring_world_x = ring["offset_x"] * max_off
		var ring_world_y = ring["offset_y"] * max_off * 0.5
		var dx = ship_offset.x - ring_world_x
		var dy = ship_offset.y - ring_world_y
		var offset_dist = sqrt(dx * dx + dy * dy)

		if offset_dist < _ring_offset_tolerance:
			ring["collected"] = true
			ship.collect_ring(ring["value"])
			if ring["visual_node"] and is_instance_valid(ring["visual_node"]):
				ring["visual_node"].visible = false


func _on_ring_collected(chain: int, value: int) -> void:
	hud.show_ring_collect(chain, value)


# =========================================================================
#  BOOST PADS
# =========================================================================

func _process_boost_pads() -> void:
	var ship_prog = ship.progress
	var ship_offset = ship.steering_offset
	var max_off = ship.max_offset

	for pad in boost_pad_data:
		if pad["triggered"]:
			continue

		var pad_prog = pad["progress"]
		if absf(ship_prog - pad_prog) > 8.0:
			continue

		# Check lateral proximity
		var pad_world_x = pad["offset_x"] * max_off
		var pad_world_y = pad["offset_y"] * max_off
		var dx = ship_offset.x - pad_world_x
		var dy = ship_offset.y - pad_world_y
		var dist = sqrt(dx * dx + dy * dy)

		if dist < 4.0:  # Must fly reasonably close to the pad
			pad["triggered"] = true
			ship.apply_boost_pad(pad["boost_amount"])
			hud.show_flash("BOOST!", Color(0.0, 1.0, 0.5, 1.0))
			# Flash the pad visual
			if pad["visual_node"] and is_instance_valid(pad["visual_node"]):
				var tween = create_tween()
				tween.tween_property(pad["visual_node"], "modulate:a", 0.0, 0.3)


# =========================================================================
#  SPEED GATES
# =========================================================================

func _process_speed_gates() -> void:
	var ship_prog = ship.progress
	var ship_offset = ship.steering_offset
	var max_off = ship.max_offset

	for gate in speed_gate_data:
		if gate["passed"]:
			continue

		var gate_prog = gate["progress"]
		var dist_along = ship_prog - gate_prog

		if dist_along < -6.0 or dist_along > 6.0:
			continue

		if dist_along > 2.0:
			# Ship has passed the gate — evaluate
			gate["passed"] = true

			var gate_world_x = gate["offset_x"] * max_off
			var gate_world_y = gate["offset_y"] * max_off
			var dx = ship_offset.x - gate_world_x
			var dy = ship_offset.y - gate_world_y
			var dist_from_centre = sqrt(dx * dx + dy * dy)
			var ghw = gate["gate_half_width"]

			if dist_from_centre < ghw * 0.4:
				# Dead centre — max boost!
				ship.apply_boost_pad(gate["boost_centre"])
				hud.show_flash("PERFECT!", Color(1.0, 0.8, 0.0, 1.0))
			elif dist_from_centre < ghw:
				# Clipped the edges — partial boost
				ship.apply_boost_pad(gate["boost_edge"])
				hud.show_flash("GATE!", Color(1.0, 0.6, 0.2, 1.0))
			# else: missed entirely, no feedback needed


# =========================================================================
#  CROSSWIND ZONES
# =========================================================================

func _process_crosswinds(delta: float) -> void:
	var ship_prog = ship.progress
	var in_wind = false

	for zone in crosswind_data:
		if ship_prog >= zone["progress_start"] and ship_prog <= zone["progress_end"]:
			# Ship is in this crosswind zone — apply lateral force
			ship.crosswind_force = Vector2(zone["wind_x"], zone["wind_y"])
			in_wind = true
			break

	if not in_wind:
		ship.crosswind_force = Vector2.ZERO


# =========================================================================
#  GRAVITY WELLS
# =========================================================================

func _process_gravity_wells(delta: float) -> void:
	var ship_prog = ship.progress
	var ship_offset = ship.steering_offset
	var max_off = ship.max_offset

	for well in gravity_well_data:
		var well_prog = well["progress"]
		var dist_along = absf(ship_prog - well_prog)

		# Only active when ship is near enough along track
		if dist_along > well["pull_radius"] * 3.0:
			continue

		# Calculate 2D distance from ship to well in track-local space
		var well_x = well["offset_x"] * max_off
		var well_y = well["offset_y"] * max_off
		var dx = ship_offset.x - well_x
		var dy = ship_offset.y - well_y
		var dist_2d = sqrt(dx * dx + dy * dy)

		if dist_2d < well["pull_radius"]:
			# Apply gravitational pull towards the well
			var pull_dir = Vector2(well_x - ship_offset.x, well_y - ship_offset.y)
			if pull_dir.length() > 0.1:
				pull_dir = pull_dir.normalized()
				# Pull strength increases as you get closer (inverse square-ish)
				var closeness = 1.0 - (dist_2d / well["pull_radius"])
				var pull_force = well["pull_strength"] * closeness * closeness
				ship.crosswind_force += pull_dir * pull_force

			# Slingshot check — close flyby gives speed boost
			if dist_2d < well["slingshot_radius"] and not well["triggered"]:
				if dist_along < 8.0:
					well["triggered"] = true
					ship.apply_slingshot(well["slingshot_bonus"])
					hud.show_flash("SLINGSHOT!", Color(0.7, 0.2, 1.0, 1.0))


# =========================================================================
#  DRIFT BOOST FEEDBACK
# =========================================================================

func _on_drift_released(boost: float) -> void:
	if boost > 5.0:
		hud.show_flash("DRIFT +%d!" % int(boost), Color(0.2, 0.8, 1.0, 1.0))


# =========================================================================
#  HAZARD WAVE SPAWNING
# =========================================================================

func _process_hazard_spawning() -> void:
	var ship_prog = ship.progress
	var baked_length = track.curve.get_baked_length()

	for wave in hazard_wave_data:
		var wave_prog = wave["progress"]

		if not wave["spawned"] and not wave["passed"]:
			if ship_prog > wave_prog - _hazard_spawn_distance and ship_prog < wave_prog:
				_spawn_hazard_wall(wave, baked_length)

		if wave["spawned"] and ship_prog > wave_prog + _hazard_despawn_distance:
			_despawn_hazard_wall(wave)


func _spawn_hazard_wall(wave: Dictionary, baked_length: float) -> void:
	var c = track.curve
	var prog = wave["progress"]
	if prog >= baked_length - 2.0:
		return

	var track_pos = c.sample_baked(prog)
	var track_up = c.sample_baked_up_vector(prog)
	var next = c.sample_baked(clampf(prog + 3.0, 0.0, baked_length - 0.1))
	var track_fwd = (next - track_pos)
	if track_fwd.length() < 0.001:
		track_fwd = Vector3(0, 0, -1)
	track_fwd = track_fwd.normalized()
	var track_right = track_fwd.cross(track_up).normalized()
	track_up = track_right.cross(track_fwd).normalized()

	var field_node = Node3D.new()
	field_node.name = "HazardField_%d" % hazard_wave_data.find(wave)

	wave["_track_pos"] = track_pos
	wave["_track_fwd"] = track_fwd
	wave["_track_right"] = track_right
	wave["_track_up"] = track_up
	wave["_phase_offset"] = _race_elapsed

	# Materials
	var ast_mats: Array = []
	for ci in range(3):
		var mat = StandardMaterial3D.new()
		var hue = randf_range(0.02, 0.08)
		mat.albedo_color = Color(0.35 + hue, 0.12 + hue * 0.3, 0.05, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.6 + hue, 0.15, 0.05, 1.0)
		mat.emission_energy_multiplier = 1.2
		mat.roughness = randf_range(0.6, 0.95)
		ast_mats.append(mat)

	# Place asteroids with a built-in gap hole at the CENTRE of the field.
	# The entire field_node will physically sweep across the track,
	# so the gap moves with it. All asteroids are always visible.
	var field_width = 30.0
	var field_height = 18.0
	var field_depth = 22.0
	var gap_hw = wave["gap_half_width"]
	var num_asteroids = 50

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(prog)

	var placed = 0
	var attempts = 0
	while placed < num_asteroids and attempts < 200:
		attempts += 1
		var local_x = rng.randf_range(-field_width * 0.5, field_width * 0.5)
		var local_y = rng.randf_range(-field_height * 0.45, field_height * 0.55)
		var local_z = rng.randf_range(-field_depth * 0.5, field_depth * 0.5)

		# Skip if inside the gap cylinder (centred at x=0, y=0)
		var dist_from_centre = sqrt(local_x * local_x + local_y * local_y)
		if dist_from_centre < gap_hw + 1.0:
			continue

		var sphere_mi = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		var base_size = rng.randf_range(1.0, 2.8)
		sphere.radius = base_size
		sphere.height = base_size * rng.randf_range(1.4, 2.2)
		sphere.radial_segments = rng.randi_range(6, 10)
		sphere.rings = rng.randi_range(3, 5)
		sphere_mi.mesh = sphere
		sphere_mi.material_override = ast_mats[rng.randi_range(0, 2)]

		sphere_mi.rotation = Vector3(
			rng.randf_range(0, TAU),
			rng.randf_range(0, TAU),
			rng.randf_range(0, TAU))

		# Store LOCAL offset relative to field_node origin
		sphere_mi.set_meta("local_x", local_x)
		sphere_mi.set_meta("local_y", local_y)
		sphere_mi.set_meta("local_z", local_z)
		sphere_mi.set_meta("spin_speed", rng.randf_range(0.3, 1.2) * (1.0 if rng.randf() > 0.5 else -1.0))

		# Position immediately in track-local space
		sphere_mi.position = track_right * local_x + track_up * local_y + track_fwd * local_z
		field_node.add_child(sphere_mi)
		placed += 1

	field_node.global_position = track_pos
	add_child(field_node)
	wave["wall_node"] = field_node
	wave["spawned"] = true


func _despawn_hazard_wall(wave: Dictionary) -> void:
	if wave["wall_node"] and is_instance_valid(wave["wall_node"]):
		wave["wall_node"].queue_free()
	wave["wall_node"] = null
	wave["spawned"] = false
	wave["passed"] = true


# =========================================================================
#  HAZARD WALL MOVEMENT
# =========================================================================

func _get_gap_position(wave: Dictionary) -> Vector2:
	## Returns the gap centre in local (x, y) space for this wave at current time.
	var time = _race_elapsed - wave.get("_phase_offset", 0.0)
	var osc_val = sin(time * wave["osc_speed"]) * wave["osc_range"]
	var sweep_type = wave.get("sweep_type", 0)

	match sweep_type:
		0:  # Horizontal sweep
			return Vector2(osc_val, 0.0)
		1:  # Vertical sweep — gap moves up and down
			return Vector2(0.0, osc_val)
		2:  # Diagonal sweep
			var angle = wave.get("diag_angle", 1.0)
			return Vector2(osc_val * cos(angle), osc_val * sin(angle))
		_:
			return Vector2(osc_val, 0.0)


func _process_hazard_movement() -> void:
	var frame_delta = get_process_delta_time()

	for wave in hazard_wave_data:
		if not wave["spawned"] or wave["wall_node"] == null:
			continue
		if not is_instance_valid(wave["wall_node"]):
			continue

		var field_node = wave["wall_node"]
		var track_pos = wave["_track_pos"]
		var track_right = wave["_track_right"]
		var track_up = wave["_track_up"]

		# The gap is baked into the asteroid placement at (0,0).
		# We move the ENTIRE field to sweep the gap across the track.
		var gap_offset = _get_gap_position(wave)
		# Shift field so the gap (at field origin) aligns with gap_offset
		# This means moving the field in the OPPOSITE direction
		field_node.global_position = track_pos - track_right * gap_offset.x - track_up * gap_offset.y

		# Spin individual asteroids for life
		for child in field_node.get_children():
			if child is MeshInstance3D:
				var spin = child.get_meta("spin_speed", 0.0)
				child.rotate_y(spin * frame_delta)


# =========================================================================
#  HAZARD COLLISION DETECTION
# =========================================================================

func _process_hazard_collision() -> void:
	var ship_prog = ship.progress
	var ship_offset = ship.steering_offset  # Vector2(x, y)
	var ship_world_pos = ship.global_position

	for wave in hazard_wave_data:
		if wave["passed"] or not wave["spawned"]:
			continue

		var wave_prog = wave["progress"]
		var dist_along = ship_prog - wave_prog

		# Wider tolerance because field has depth now
		if dist_along < -12.0 or dist_along > 12.0:
			continue

		# The gap is at the field origin, but the field has been shifted.
		# In world terms the gap centre is at gap_offset from track centre.
		# Ship needs to be near the gap centre to be safe.
		var gap_offset = _get_gap_position(wave)
		var gap_hw = wave["gap_half_width"]

		var dx = ship_offset.x - gap_offset.x
		var dy = ship_offset.y - gap_offset.y
		var dist_from_gap = sqrt(dx * dx + dy * dy)

		if dist_from_gap > gap_hw:
			# Ship is outside the gap — find and destroy nearest asteroid(s)
			_explode_nearest_asteroids(wave, ship_world_pos, 3)
			ship.hit_hazard()
			wave["passed"] = true
			# Don't despawn the whole field — it stays with missing rocks
		elif dist_along > 10.0:
			wave["passed"] = true


func _explode_nearest_asteroids(wave: Dictionary, ship_pos: Vector3, count: int) -> void:
	## Find the closest 'count' asteroids to the ship and destroy them
	## with a brief explosion effect. The rest of the field stays intact.
	var field_node = wave["wall_node"]
	if not field_node or not is_instance_valid(field_node):
		return

	# Build list of (distance, child) pairs
	var dist_list: Array = []
	for child in field_node.get_children():
		if child is MeshInstance3D and child.visible:
			var d = child.global_position.distance_to(ship_pos)
			dist_list.append({"dist": d, "node": child})

	# Sort by distance
	dist_list.sort_custom(func(a, b): return a["dist"] < b["dist"])

	# Destroy the nearest ones with explosion
	var destroyed = 0
	for entry in dist_list:
		if destroyed >= count:
			break
		var asteroid = entry["node"]
		_spawn_explosion_at(asteroid.global_position)
		asteroid.visible = false  # Hide immediately
		asteroid.queue_free()     # Clean up next frame
		destroyed += 1


func _spawn_explosion_at(pos: Vector3) -> void:
	## Creates a brief burst of small debris meshes that scatter outward.
	var explosion_root = Node3D.new()
	explosion_root.global_position = pos
	add_child(explosion_root)

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Spawn 8 small debris chunks that fly outward
	var debris_count = 8
	for i in range(debris_count):
		var chunk = MeshInstance3D.new()
		var mesh = SphereMesh.new()
		mesh.radius = rng.randf_range(0.2, 0.6)
		mesh.height = mesh.radius * rng.randf_range(1.2, 2.0)
		mesh.radial_segments = 4
		mesh.rings = 2
		chunk.mesh = mesh

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.5 + rng.randf_range(0, 0.4), 0.1, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.1, 1.0)
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		chunk.material_override = mat

		chunk.position = Vector3.ZERO
		explosion_root.add_child(chunk)

		# Animate: scatter outward and fade
		var dir = Vector3(
			rng.randf_range(-1, 1),
			rng.randf_range(-1, 1),
			rng.randf_range(-1, 1)).normalized()
		var end_pos = dir * rng.randf_range(3.0, 8.0)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(chunk, "position", end_pos, 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(chunk, "scale", Vector3(0.1, 0.1, 0.1), 0.5) \
			.set_ease(Tween.EASE_IN)

	# Clean up after animation
	var cleanup_tween = create_tween()
	cleanup_tween.tween_interval(0.6)
	cleanup_tween.tween_callback(func(): explosion_root.queue_free())


func _on_hazard_hit() -> void:
	hud.show_hazard_hit()
	_shake_camera(0.4, 1.5)


# =========================================================================
#  PROJECTILE SYSTEM (Fire ability)
# =========================================================================

func _on_fire_requested(from_progress: float) -> void:
	_spawn_projectile(from_progress)
	hud.show_flash("FIRE!", Color(1.0, 0.6, 0.1, 1.0))


func _spawn_projectile(start_progress: float) -> void:
	var c = track.curve
	var baked_length = c.get_baked_length()
	var prog = clampf(start_progress + 5.0, 0.0, baked_length - 1.0)
	var pos = c.sample_baked(prog)

	# Bolt visual: elongated glowing mesh
	var bolt_node = MeshInstance3D.new()
	var bolt_mesh = SphereMesh.new()
	bolt_mesh.radius = 0.5
	bolt_mesh.height = 3.0
	bolt_mesh.radial_segments = 6
	bolt_mesh.rings = 2
	bolt_node.mesh = bolt_mesh

	var bolt_mat = StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(1.0, 0.5, 0.0, 0.9)
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(1.0, 0.7, 0.1, 1.0)
	bolt_mat.emission_energy_multiplier = 4.0
	bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_node.material_override = bolt_mat
	bolt_node.name = "Projectile_%d" % _projectiles.size()

	bolt_node.global_position = pos
	add_child(bolt_node)

	_projectiles.append({
		"progress": prog,
		"start_progress": start_progress,
		"node": bolt_node,
		"speed": _projectile_speed,
	})


func _process_projectiles(delta: float) -> void:
	var c = track.curve
	var baked_length = c.get_baked_length()
	var to_remove: Array = []

	for i in range(_projectiles.size()):
		var proj = _projectiles[i]
		proj["progress"] += proj["speed"] * delta

		# Check if out of range or past track end
		var travelled = proj["progress"] - proj["start_progress"]
		if proj["progress"] >= baked_length - 2.0 or travelled > _projectile_max_range:
			to_remove.append(i)
			continue

		# Update visual position
		var pos = c.sample_baked(clampf(proj["progress"], 0.0, baked_length - 1.0))
		if is_instance_valid(proj["node"]):
			proj["node"].global_position = pos

			# Orient along track
			var ahead = c.sample_baked(clampf(proj["progress"] + 3.0, 0.0, baked_length - 0.5))
			if pos.distance_to(ahead) > 0.5:
				var up = c.sample_baked_up_vector(clampf(proj["progress"], 0.0, baked_length - 1.0))
				proj["node"].look_at(ahead, up)

		# Check if projectile hits a hazard wall — destroys nearby asteroids
		if is_instance_valid(proj["node"]):
			var bolt_pos = proj["node"].global_position
			for wave in hazard_wave_data:
				if wave["passed"] or not wave["spawned"]:
					continue
				var wave_prog = wave["progress"]
				if absf(proj["progress"] - wave_prog) < 6.0:
					# Projectile blasts a hole — destroy nearby asteroids
					_explode_nearest_asteroids(wave, bolt_pos, 5)
					_spawn_explosion_at(bolt_pos)
					to_remove.append(i)
					hud.show_flash("BLASTED!", Color(1.0, 0.4, 0.0, 1.0))
					break

	# Remove spent projectiles (reverse order to preserve indices)
	to_remove.sort()
	to_remove.reverse()
	for idx in to_remove:
		if idx < _projectiles.size():
			var proj = _projectiles[idx]
			if is_instance_valid(proj["node"]):
				proj["node"].queue_free()
			_projectiles.remove_at(idx)


# =========================================================================
#  HUD UPDATES
# =========================================================================

func _process_racing_hud() -> void:
	hud.update_speed(ship.current_speed, ship.get_speed_ratio())
	hud.update_progress(ship.get_progress_ratio())
	hud.update_time(ship.race_time)
	hud.update_chain(ship.chain_count, ship.chain_multiplier)
	hud.update_fire_cooldown(ship.fire_cooldown / ship.fire_cooldown_max)
	hud.update_shield_charges(ship.shield_charges, ship.shield_active)
	hud.update_racing_line(ship.racing_line_bonus)
	hud.update_drift(ship.drift_charge, ship.drift_max_charge, ship.drift_active)


func _shake_camera(duration: float, intensity: float) -> void:
	if camera and is_instance_valid(camera):
		camera.start_shake(duration, intensity)


func _on_race_finished(time: float) -> void:
	race_state = "finished"
	hud.show_finish(time)
	GameSettings.save_best_time(time)


func _on_restart() -> void:
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
