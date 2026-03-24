extends Path3D
## Builds the test track: curve geometry, visual elements,
## energy ring positions, and hazard wave definitions.

# Data exposed to GameManager
var ring_data: Array = []
var hazard_wave_data: Array = []
var boost_pad_data: Array = []
var speed_gate_data: Array = []
var crosswind_data: Array = []
var gravity_well_data: Array = []

# Track visual parameters
@export var track_width: float = 14.0
@export var track_segments: int = 200
@export var gate_spacing: float = 60.0

# Wire tube parameters
@export var tube_radius: float = 8.0
@export var tube_ring_sides: int = 12
@export var tube_ring_spacing: float = 15.0
@export var tube_longitude_count: int = 8


func _ready() -> void:
	_build_curve()
	_define_rings()
	_define_hazard_waves()
	_define_boost_pads()
	_define_speed_gates()
	_define_crosswinds()
	_define_gravity_wells()
	_generate_track_ribbon()
	_generate_edge_lines()
	_generate_wire_tube()
	_generate_gate_markers()
	_generate_ring_visuals()
	_generate_boost_pad_visuals()
	_generate_speed_gate_visuals()
	_generate_crosswind_visuals()
	_generate_gravity_well_visuals()


func _process(delta: float) -> void:
	# Spin energy crystals that haven't been collected
	for ring in ring_data:
		if ring["collected"]:
			continue
		var node = ring["visual_node"]
		if node and is_instance_valid(node):
			var spin = node.get_meta("spin_speed", 1.5)
			node.rotate_y(spin * delta)

	# Spin gravity wells
	for well in gravity_well_data:
		var node = well["visual_node"]
		if node and is_instance_valid(node):
			var spin = node.get_meta("spin_speed", 0.8)
			node.rotate_y(spin * delta)


func get_ring_data() -> Array:
	return ring_data


func get_hazard_wave_data() -> Array:
	return hazard_wave_data

func get_boost_pad_data() -> Array:
	return boost_pad_data

func get_speed_gate_data() -> Array:
	return speed_gate_data

func get_crosswind_data() -> Array:
	return crosswind_data

func get_gravity_well_data() -> Array:
	return gravity_well_data


# =========================================================================
#  CURVE BUILDING
# =========================================================================

func _build_curve() -> void:
	var c = Curve3D.new()
	c.up_vector_enabled = true
	c.bake_interval = 2.0

	var points = [
		{"pos": Vector3(0, 0, 0), "tilt": 0.0},
		{"pos": Vector3(0, 0, -80), "tilt": 0.0},
		{"pos": Vector3(40, 5, -180), "tilt": 0.2},
		{"pos": Vector3(20, 0, -300), "tilt": 0.0},
		{"pos": Vector3(-30, -5, -420), "tilt": -0.2},
		{"pos": Vector3(-10, 0, -540), "tilt": 0.0},
		{"pos": Vector3(35, 15, -660), "tilt": 0.3},
		{"pos": Vector3(-25, 5, -760), "tilt": -0.3},
		{"pos": Vector3(20, -10, -860), "tilt": 0.2},
		{"pos": Vector3(0, -30, -960), "tilt": 0.0},
		{"pos": Vector3(-20, -70, -1080), "tilt": -0.15},
		{"pos": Vector3(10, -90, -1200), "tilt": 0.1},
		{"pos": Vector3(40, -60, -1320), "tilt": 0.8},
		{"pos": Vector3(-10, -30, -1400), "tilt": -0.8},
		{"pos": Vector3(-40, -60, -1480), "tilt": 0.6},
		{"pos": Vector3(10, -40, -1560), "tilt": -0.4},
		{"pos": Vector3(0, -35, -1680), "tilt": 0.0},
		{"pos": Vector3(0, -30, -1900), "tilt": 0.0},
		{"pos": Vector3(0, -25, -2100), "tilt": 0.0},
		{"pos": Vector3(35, -15, -2250), "tilt": 0.25},
		{"pos": Vector3(-30, -5, -2380), "tilt": -0.25},
		{"pos": Vector3(15, 0, -2480), "tilt": 0.1},
		{"pos": Vector3(0, 0, -2600), "tilt": 0.0},
	]

	for i in range(points.size()):
		var p = points[i]
		c.add_point(p["pos"])
		c.set_point_tilt(i, p["tilt"])
		if i > 0 and i < points.size() - 1:
			var prev_pos = points[i - 1]["pos"]
			var next_pos = points[i + 1]["pos"]
			var handle = (next_pos - prev_pos) * 0.25
			c.set_point_in(i, -handle)
			c.set_point_out(i, handle)
		elif i == 0 and points.size() > 1:
			var handle = (points[1]["pos"] - p["pos"]) * 0.3
			c.set_point_out(i, handle)
		elif i == points.size() - 1 and points.size() > 1:
			var handle = (p["pos"] - points[i - 1]["pos"]) * 0.3
			c.set_point_in(i, -handle)

	curve = c


# =========================================================================
#  ENERGY RINGS (boost collectibles)
# =========================================================================

func _define_rings() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 123
	var baked_length = curve.get_baked_length()

	# Place rings at semi-regular intervals with varying offsets
	var ring_spacing = 45.0
	var count = int((baked_length - 200.0) / ring_spacing)

	for i in range(count):
		var prog = 80.0 + float(i) * ring_spacing + rng.randf_range(-10.0, 10.0)
		prog = clampf(prog, 50.0, baked_length - 80.0)

		# Offset from track centre (normalised -1 to 1)
		var ox = rng.randf_range(-0.8, 0.8)
		var oy = rng.randf_range(-0.4, 0.4)

		# Difficulty determines value: harder to reach = more reward
		var difficulty = absf(ox) + absf(oy) * 1.5
		var value = 1
		if difficulty > 0.8:
			value = 3  # Gold
		elif difficulty > 0.45:
			value = 2  # Silver

		ring_data.append({
			"progress": prog,
			"offset_x": ox,
			"offset_y": oy,
			"value": value,
			"collected": false,
			"visual_node": null,
		})


func _generate_ring_visuals() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()

	# Materials for different crystal values
	var crystal_mats = {
		1: _make_crystal_material(Color(0.1, 0.9, 0.2, 0.85), Color(0.05, 0.8, 0.15, 1.0)),   # Green
		2: _make_crystal_material(Color(0.2, 0.5, 1.0, 0.85), Color(0.15, 0.45, 0.95, 1.0)),   # Blue
		3: _make_crystal_material(Color(1.0, 0.85, 0.1, 0.9), Color(0.95, 0.75, 0.05, 1.0)),   # Gold
	}

	for ring in ring_data:
		var prog = ring["progress"]
		if prog >= baked_length - 1.0:
			continue

		var pos = c.sample_baked(prog)
		var up = c.sample_baked_up_vector(prog)
		var next = c.sample_baked(clampf(prog + 2.0, 0.0, baked_length - 0.1))
		var fwd = (next - pos)
		if fwd.length() < 0.001:
			fwd = Vector3(0, 0, -1)
		fwd = fwd.normalized()
		var right = fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()

		# Crystal world position = track pos + offset
		var max_off = 14.0
		var crystal_pos = pos + right * ring["offset_x"] * max_off + up * ring["offset_y"] * max_off * 0.5

		# Create a diamond crystal (two cones tip-to-tip)
		var crystal_root = Node3D.new()
		crystal_root.position = crystal_pos
		crystal_root.name = "Crystal_%d" % ring_data.find(ring)

		var value = ring["value"]
		var crystal_scale = 0.8 + float(value) * 0.25  # Bigger crystals = more valuable

		# Top cone (point up)
		var top_cone = MeshInstance3D.new()
		var top_mesh = CylinderMesh.new()
		top_mesh.top_radius = 0.0
		top_mesh.bottom_radius = 0.8 * crystal_scale
		top_mesh.height = 1.6 * crystal_scale
		top_mesh.radial_segments = 6  # Hexagonal cross-section for crystal look
		top_cone.mesh = top_mesh
		top_cone.material_override = crystal_mats[value]
		top_cone.position = Vector3(0, 0.8 * crystal_scale, 0)
		crystal_root.add_child(top_cone)

		# Bottom cone (point down)
		var bottom_cone = MeshInstance3D.new()
		var bottom_mesh = CylinderMesh.new()
		bottom_mesh.top_radius = 0.8 * crystal_scale
		bottom_mesh.bottom_radius = 0.0
		bottom_mesh.height = 1.6 * crystal_scale
		bottom_mesh.radial_segments = 6
		bottom_cone.mesh = bottom_mesh
		bottom_cone.material_override = crystal_mats[value]
		bottom_cone.position = Vector3(0, -0.8 * crystal_scale, 0)
		crystal_root.add_child(bottom_cone)

		# Small inner glow sphere
		var glow = MeshInstance3D.new()
		var glow_mesh = SphereMesh.new()
		glow_mesh.radius = 0.4 * crystal_scale
		glow_mesh.height = 0.8 * crystal_scale
		glow_mesh.radial_segments = 6
		glow_mesh.rings = 4
		glow.mesh = glow_mesh
		var glow_mat = crystal_mats[value].duplicate()
		glow_mat.emission_energy_multiplier = 5.0
		glow.material_override = glow_mat
		crystal_root.add_child(glow)

		# Store spin metadata and base position for animation
		crystal_root.set_meta("spin_speed", 1.5 + float(value) * 0.5)
		crystal_root.set_meta("base_y", crystal_pos.y)

		add_child(crystal_root)
		ring["visual_node"] = crystal_root


func _make_crystal_material(albedo: Color, emission: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


# =========================================================================
#  HAZARD WAVES (sweeping asteroid walls)
# =========================================================================

func _define_hazard_waves() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	var baked_length = curve.get_baked_length()

	var wave_count = 18
	var start = 200.0
	var spacing = (baked_length - 400.0) / float(wave_count)

	for i in range(wave_count):
		var prog = start + float(i) * spacing + rng.randf_range(-25.0, 25.0)
		prog = clampf(prog, 150.0, baked_length - 150.0)

		# Difficulty increases along track
		var track_ratio = prog / baked_length
		var osc_speed = 2.0 + track_ratio * 3.0 + rng.randf_range(-0.5, 0.5)
		var osc_range = 4.0 + track_ratio * 4.0 + rng.randf_range(-1.0, 1.0)
		var gap_hw = 7.5 - track_ratio * 2.0 + rng.randf_range(-0.5, 0.5)
		gap_hw = clampf(gap_hw, 5.0, 8.0)

		# Sweep direction: 0=horizontal, 1=vertical, 2=diagonal
		# More variety as track progresses
		var sweep_type = 0
		var roll = rng.randf()
		if track_ratio > 0.25:
			if roll < 0.35:
				sweep_type = 1  # vertical — duck under / go over
			elif roll < 0.55:
				sweep_type = 2  # diagonal — top-right to bottom-left etc.
		elif track_ratio > 0.15:
			if roll < 0.2:
				sweep_type = 1

		# Diagonal angle (only used for sweep_type 2)
		var diag_angle = rng.randf_range(0.6, 1.2) * (1.0 if rng.randf() > 0.5 else -1.0)

		hazard_wave_data.append({
			"progress": prog,
			"osc_speed": osc_speed,
			"osc_range": osc_range,
			"gap_half_width": gap_hw,
			"sweep_type": sweep_type,
			"diag_angle": diag_angle,
			"spawned": false,
			"passed": false,
			"wall_node": null,
		})


# =========================================================================
#  TRACK RIBBON MESH
# =========================================================================

func _generate_track_ribbon() -> void:
	var c = curve
	if not c or c.get_baked_length() < 10.0:
		return

	var baked_length = c.get_baked_length()
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	var half_width = track_width * 0.5

	for i in range(track_segments + 1):
		var t = float(i) / float(track_segments)
		var dist = clampf(t * baked_length, 0.0, baked_length - 0.1)
		var pos = c.sample_baked(dist)
		var up = c.sample_baked_up_vector(dist)
		var next_dist = clampf(dist + 2.0, 0.0, baked_length - 0.1)
		var next_pos = c.sample_baked(next_dist)
		var fwd = (next_pos - pos)
		if fwd.length() < 0.001:
			fwd = Vector3(0, 0, -1)
		fwd = fwd.normalized()
		var right = fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()
		vertices.append(pos - right * half_width)
		vertices.append(pos + right * half_width)
		normals.append(up)
		normals.append(up)
		uvs.append(Vector2(0.0, t * 20.0))
		uvs.append(Vector2(1.0, t * 20.0))

	for i in range(track_segments):
		var idx = i * 2
		indices.append(idx)
		indices.append(idx + 1)
		indices.append(idx + 2)
		indices.append(idx + 1)
		indices.append(idx + 3)
		indices.append(idx + 2)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.15, 0.4, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.15, 0.5, 1.0)
	mat.emission_energy_multiplier = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, mat)

	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "TrackRibbon"
	add_child(mi)


# =========================================================================
#  EDGE LINES
# =========================================================================

func _generate_edge_lines() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	var half_width = track_width * 0.5

	var edge_mat = StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.3, 0.5, 1.0, 0.8)
	edge_mat.emission_enabled = true
	edge_mat.emission = Color(0.3, 0.5, 1.0, 1.0)
	edge_mat.emission_energy_multiplier = 2.0
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for side in [-1.0, 1.0]:
		var mesh = ArrayMesh.new()
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices = PackedVector3Array()
		for i in range(track_segments + 1):
			var t = float(i) / float(track_segments)
			var dist = clampf(t * baked_length, 0.0, baked_length - 0.1)
			var pos = c.sample_baked(dist)
			var up = c.sample_baked_up_vector(dist)
			var next_dist = clampf(dist + 2.0, 0.0, baked_length - 0.1)
			var next_pos = c.sample_baked(next_dist)
			var fwd = (next_pos - pos)
			if fwd.length() < 0.001:
				fwd = Vector3(0, 0, -1)
			fwd = fwd.normalized()
			var right = fwd.cross(up).normalized()
			vertices.append(pos + right * half_width * side + up * 0.2)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
		mesh.surface_set_material(0, edge_mat)
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = "EdgeLine_" + ("Left" if side < 0 else "Right")
		add_child(mi)


# =========================================================================
#  WIRE TUBE
# =========================================================================

func _generate_wire_tube() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	if baked_length < 20.0:
		return

	var wire_mat = StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.25, 0.45, 0.9, 0.35)
	wire_mat.emission_enabled = true
	wire_mat.emission = Color(0.2, 0.4, 0.8, 1.0)
	wire_mat.emission_energy_multiplier = 1.2
	wire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ring_count = int(baked_length / tube_ring_spacing) + 1
	var rd_list: Array = []

	for i in range(ring_count):
		var dist = clampf(float(i) * tube_ring_spacing, 0.0, baked_length - 0.1)
		var pos = c.sample_baked(dist)
		var up = c.sample_baked_up_vector(dist)
		var next_dist = clampf(dist + 2.0, 0.0, baked_length - 0.1)
		var next_pos = c.sample_baked(next_dist)
		var fwd = (next_pos - pos)
		if fwd.length() < 0.001:
			fwd = Vector3(0, 0, -1)
		fwd = fwd.normalized()
		var right = fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()
		rd_list.append({"pos": pos, "up": up, "right": right})

	# Ring circles
	var ring_verts = PackedVector3Array()
	for rd in rd_list:
		for s in range(tube_ring_sides + 1):
			var angle = float(s % tube_ring_sides) / float(tube_ring_sides) * TAU
			ring_verts.append(rd["pos"] + rd["right"] * cos(angle) * tube_radius + rd["up"] * sin(angle) * tube_radius)

	var ring_mesh = ArrayMesh.new()
	var ring_arrays = []
	ring_arrays.resize(Mesh.ARRAY_MAX)
	var ring_line_verts = PackedVector3Array()
	var vpr = tube_ring_sides + 1
	for ri in range(ring_count):
		var base = ri * vpr
		for s in range(tube_ring_sides):
			ring_line_verts.append(ring_verts[base + s])
			ring_line_verts.append(ring_verts[base + s + 1])
	ring_arrays[Mesh.ARRAY_VERTEX] = ring_line_verts
	ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, ring_arrays)
	ring_mesh.surface_set_material(0, wire_mat)
	var rmi = MeshInstance3D.new()
	rmi.mesh = ring_mesh
	rmi.name = "WireTube_Rings"
	add_child(rmi)

	# Longitudinal wires
	var long_mat = wire_mat.duplicate()
	long_mat.albedo_color = Color(0.2, 0.35, 0.75, 0.2)
	long_mat.emission_energy_multiplier = 0.8
	var long_mesh = ArrayMesh.new()
	var long_arrays = []
	long_arrays.resize(Mesh.ARRAY_MAX)
	var long_verts = PackedVector3Array()
	for l in range(tube_longitude_count):
		var angle = float(l) / float(tube_longitude_count) * TAU
		for ri in range(ring_count - 1):
			var r0 = rd_list[ri]
			var r1 = rd_list[ri + 1]
			long_verts.append(r0["pos"] + r0["right"] * cos(angle) * tube_radius + r0["up"] * sin(angle) * tube_radius)
			long_verts.append(r1["pos"] + r1["right"] * cos(angle) * tube_radius + r1["up"] * sin(angle) * tube_radius)
	long_arrays[Mesh.ARRAY_VERTEX] = long_verts
	long_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, long_arrays)
	long_mesh.surface_set_material(0, long_mat)
	var lmi = MeshInstance3D.new()
	lmi.mesh = long_mesh
	lmi.name = "WireTube_Longitude"
	add_child(lmi)


# =========================================================================
#  GATE MARKERS
# =========================================================================

func _generate_gate_markers() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	var half_width = track_width * 0.55

	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.2, 0.4, 0.8, 0.7)
	post_mat.emission_enabled = true
	post_mat.emission = Color(0.2, 0.4, 0.9, 1.0)
	post_mat.emission_energy_multiplier = 1.5
	post_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	post_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var post_mesh = CylinderMesh.new()
	post_mesh.top_radius = 0.15
	post_mesh.bottom_radius = 0.15
	post_mesh.height = 2.0

	var gate_count = int(baked_length / gate_spacing)
	for i in range(gate_count):
		var dist = float(i) * gate_spacing + gate_spacing * 0.5
		if dist >= baked_length - 10.0:
			break
		var pos = c.sample_baked(dist)
		var up = c.sample_baked_up_vector(dist)
		var next_pos = c.sample_baked(clampf(dist + 2.0, 0.0, baked_length - 0.1))
		var fwd = (next_pos - pos).normalized()
		var right = fwd.cross(up).normalized()

		var left = MeshInstance3D.new()
		left.mesh = post_mesh
		left.material_override = post_mat
		left.position = pos - right * half_width + up * 1.0
		left.name = "GateL_%d" % i
		add_child(left)

		var right_post = MeshInstance3D.new()
		right_post.mesh = post_mesh
		right_post.material_override = post_mat
		right_post.position = pos + right * half_width + up * 1.0
		right_post.name = "GateR_%d" % i
		add_child(right_post)


# =========================================================================
#  BOOST PADS (speed burst on optimal racing lines)
# =========================================================================

func _define_boost_pads() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	# Place boost pads on the inside of curves
	var sample_step = 30.0
	var sample_count = int(baked_length / sample_step)

	for i in range(2, sample_count - 2):
		var prog = float(i) * sample_step
		var pos_here = c.sample_baked(prog)
		var pos_ahead = c.sample_baked(clampf(prog + 40.0, 0.0, baked_length - 1.0))
		var pos_behind = c.sample_baked(clampf(prog - 20.0, 0.0, baked_length - 1.0))

		var dir_fwd = (pos_ahead - pos_here)
		var dir_back = (pos_here - pos_behind)
		if dir_fwd.length() < 0.1 or dir_back.length() < 0.1:
			continue
		dir_fwd = dir_fwd.normalized()
		dir_back = dir_back.normalized()

		var curvature = dir_fwd - dir_back
		var track_up = c.sample_baked_up_vector(prog)
		var track_right = dir_fwd.cross(track_up).normalized()

		var curve_lateral = curvature.dot(track_right)
		var curve_vertical = curvature.dot(track_up)
		var curve_mag = Vector2(curve_lateral, curve_vertical).length()

		# Only place pads where curvature is significant
		if curve_mag < 0.015:
			continue

		# Place pad on the INSIDE of the curve (opposite to curvature direction)
		var pad_x = -curve_lateral / maxf(curve_mag, 0.001) * 0.5  # Normalised offset (-1 to 1)
		var pad_y = -curve_vertical / maxf(curve_mag, 0.001) * 0.3

		# Skip some to avoid overcrowding
		if rng.randf() < 0.55:
			continue

		boost_pad_data.append({
			"progress": prog,
			"offset_x": clampf(pad_x, -0.8, 0.8),
			"offset_y": clampf(pad_y, -0.5, 0.5),
			"boost_amount": 12.0 + curve_mag * 200.0,  # Sharper curve = bigger reward
			"triggered": false,
			"visual_node": null,
		})


func _generate_boost_pad_visuals() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()

	var pad_mat = StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.0, 1.0, 0.5, 0.6)
	pad_mat.emission_enabled = true
	pad_mat.emission = Color(0.0, 1.0, 0.4, 1.0)
	pad_mat.emission_energy_multiplier = 3.0
	pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for pad in boost_pad_data:
		var prog = pad["progress"]
		if prog >= baked_length - 1.0:
			continue

		var pos = c.sample_baked(prog)
		var up = c.sample_baked_up_vector(prog)
		var next = c.sample_baked(clampf(prog + 3.0, 0.0, baked_length - 0.1))
		var fwd = (next - pos)
		if fwd.length() < 0.001:
			fwd = Vector3(0, 0, -1)
		fwd = fwd.normalized()
		var right = fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()

		var max_off = track_width * 0.5
		var pad_pos = pos + right * pad["offset_x"] * max_off + up * pad["offset_y"] * max_off + up * 0.15

		# Chevron shape: flat box angled forward
		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(3.5, 0.08, 5.0)
		mi.mesh = box
		mi.material_override = pad_mat
		mi.position = pad_pos
		if fwd.length() > 0.5:
			mi.look_at(pad_pos + fwd, up)
		mi.name = "BoostPad_%d" % boost_pad_data.find(pad)
		add_child(mi)
		pad["visual_node"] = mi


# =========================================================================
#  SPEED GATES (narrow precision gates for bonus)
# =========================================================================

func _define_speed_gates() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	var rng = RandomNumberGenerator.new()
	rng.seed = 99

	# Place speed gates at intervals, offset from centre
	var gate_count = 12
	var spacing = (baked_length - 400.0) / float(gate_count)

	for i in range(gate_count):
		var prog = 200.0 + float(i) * spacing + rng.randf_range(-30.0, 30.0)
		prog = clampf(prog, 150.0, baked_length - 150.0)

		# Random offset — player needs to steer to hit the gate
		var ox = rng.randf_range(-0.6, 0.6)
		var oy = rng.randf_range(-0.3, 0.3)

		speed_gate_data.append({
			"progress": prog,
			"offset_x": ox,
			"offset_y": oy,
			"gate_half_width": 3.0,  # Narrow!
			"boost_centre": 18.0,    # Big boost for dead-centre
			"boost_edge": 6.0,       # Small boost for edges
			"passed": false,
			"visual_node": null,
		})


func _generate_speed_gate_visuals() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()

	var gate_mat = StandardMaterial3D.new()
	gate_mat.albedo_color = Color(1.0, 0.6, 0.0, 0.8)
	gate_mat.emission_enabled = true
	gate_mat.emission = Color(1.0, 0.5, 0.0, 1.0)
	gate_mat.emission_energy_multiplier = 2.5
	gate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gate_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var post_mesh = CylinderMesh.new()
	post_mesh.top_radius = 0.2
	post_mesh.bottom_radius = 0.2
	post_mesh.height = 5.0
	post_mesh.radial_segments = 6

	for gate in speed_gate_data:
		var prog = gate["progress"]
		if prog >= baked_length - 1.0:
			continue

		var pos = c.sample_baked(prog)
		var up = c.sample_baked_up_vector(prog)
		var next = c.sample_baked(clampf(prog + 3.0, 0.0, baked_length - 0.1))
		var fwd = (next - pos)
		if fwd.length() < 0.001:
			fwd = Vector3(0, 0, -1)
		fwd = fwd.normalized()
		var right = fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()

		var max_off = track_width * 0.5
		var gate_centre = pos + right * gate["offset_x"] * max_off + up * gate["offset_y"] * max_off
		var ghw = gate["gate_half_width"]

		var gate_root = Node3D.new()
		gate_root.position = gate_centre
		gate_root.name = "SpeedGate_%d" % speed_gate_data.find(gate)

		# Left post
		var left_post = MeshInstance3D.new()
		left_post.mesh = post_mesh
		left_post.material_override = gate_mat
		left_post.position = -right * ghw
		gate_root.add_child(left_post)

		# Right post
		var right_post = MeshInstance3D.new()
		right_post.mesh = post_mesh
		right_post.material_override = gate_mat
		right_post.position = right * ghw
		gate_root.add_child(right_post)

		# Top bar connecting them
		var bar = MeshInstance3D.new()
		var bar_mesh = BoxMesh.new()
		bar_mesh.size = Vector3(ghw * 2.0, 0.15, 0.15)
		bar.mesh = bar_mesh
		bar.material_override = gate_mat
		bar.position = up * 2.5
		gate_root.add_child(bar)

		add_child(gate_root)
		gate["visual_node"] = gate_root


# =========================================================================
#  CROSSWIND ZONES (lateral force pushing ship)
# =========================================================================

func _define_crosswinds() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	var rng = RandomNumberGenerator.new()
	rng.seed = 55

	# Place crosswind zones along the track
	var zone_count = 8
	var spacing = (baked_length - 400.0) / float(zone_count)

	for i in range(zone_count):
		var prog_start = 250.0 + float(i) * spacing + rng.randf_range(-40.0, 40.0)
		prog_start = clampf(prog_start, 200.0, baked_length - 300.0)
		var zone_length = rng.randf_range(40.0, 80.0)

		# Wind direction: +1 = push right, -1 = push left
		# Occasionally vertical: +2 = push up, -2 = push down
		var wind_dir_x = rng.randf_range(-1.0, 1.0)
		var wind_dir_y = rng.randf_range(-0.5, 0.5)
		var wind_vec = Vector2(wind_dir_x, wind_dir_y).normalized()
		var wind_strength = rng.randf_range(5.0, 10.0)

		crosswind_data.append({
			"progress_start": prog_start,
			"progress_end": prog_start + zone_length,
			"wind_x": wind_vec.x * wind_strength,
			"wind_y": wind_vec.y * wind_strength,
			"visual_node": null,
		})


func _generate_crosswind_visuals() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()

	var streak_mat = StandardMaterial3D.new()
	streak_mat.albedo_color = Color(0.6, 0.8, 1.0, 0.25)
	streak_mat.emission_enabled = true
	streak_mat.emission = Color(0.5, 0.7, 1.0, 1.0)
	streak_mat.emission_energy_multiplier = 1.5
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for zone in crosswind_data:
		var zone_root = Node3D.new()
		zone_root.name = "Crosswind_%d" % crosswind_data.find(zone)

		# Generate wind streaks (thin elongated boxes showing wind direction)
		var prog_mid = (zone["progress_start"] + zone["progress_end"]) * 0.5
		if prog_mid >= baked_length - 1.0:
			continue

		var pos = c.sample_baked(clampf(prog_mid, 0.0, baked_length - 1.0))
		var up = c.sample_baked_up_vector(clampf(prog_mid, 0.0, baked_length - 1.0))
		var next = c.sample_baked(clampf(prog_mid + 3.0, 0.0, baked_length - 0.1))
		var fwd = (next - pos)
		if fwd.length() < 0.001:
			fwd = Vector3(0, 0, -1)
		fwd = fwd.normalized()
		var right = fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()

		var wind_dir_3d = right * zone["wind_x"] + up * zone["wind_y"]

		var rng = RandomNumberGenerator.new()
		rng.seed = hash(prog_mid)

		for s in range(12):
			var streak = MeshInstance3D.new()
			var smesh = BoxMesh.new()
			smesh.size = Vector3(0.06, 0.06, 6.0 + rng.randf_range(-2.0, 3.0))
			streak.mesh = smesh
			streak.material_override = streak_mat

			var sx = rng.randf_range(-8.0, 8.0)
			var sy = rng.randf_range(-4.0, 4.0)
			var sz = rng.randf_range(-15.0, 15.0)
			streak.position = pos + right * sx + up * sy + fwd * sz

			# Orient streak in wind direction
			if wind_dir_3d.length() > 0.1:
				streak.look_at(streak.position + wind_dir_3d, up)

			zone_root.add_child(streak)

		add_child(zone_root)
		zone["visual_node"] = zone_root


# =========================================================================
#  GRAVITY WELLS (pull ship, slingshot risk/reward)
# =========================================================================

func _define_gravity_wells() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	var rng = RandomNumberGenerator.new()
	rng.seed = 33

	var well_count = 6
	var spacing = (baked_length - 400.0) / float(well_count)

	for i in range(well_count):
		var prog = 300.0 + float(i) * spacing + rng.randf_range(-50.0, 50.0)
		prog = clampf(prog, 200.0, baked_length - 200.0)

		# Place well offset from track centre
		var off_x = rng.randf_range(-1.2, 1.2)
		var off_y = rng.randf_range(-0.6, 0.6)
		# Push wells that are too centred outward
		if absf(off_x) < 0.3 and absf(off_y) < 0.2:
			off_x = 0.8 * signf(off_x + 0.01)

		gravity_well_data.append({
			"progress": prog,
			"offset_x": off_x,
			"offset_y": off_y,
			"pull_strength": rng.randf_range(8.0, 14.0),
			"pull_radius": rng.randf_range(10.0, 16.0),  # How far the pull reaches
			"slingshot_bonus": rng.randf_range(15.0, 25.0),  # Speed boost for close flyby
			"slingshot_radius": 4.0,  # Must get this close for slingshot
			"triggered": false,
			"visual_node": null,
		})


func _generate_gravity_well_visuals() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()

	var well_mat = StandardMaterial3D.new()
	well_mat.albedo_color = Color(0.6, 0.1, 0.8, 0.6)
	well_mat.emission_enabled = true
	well_mat.emission = Color(0.7, 0.15, 0.9, 1.0)
	well_mat.emission_energy_multiplier = 3.5
	well_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	well_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ring_mat = well_mat.duplicate()
	ring_mat.albedo_color = Color(0.5, 0.1, 0.7, 0.3)
	ring_mat.emission_energy_multiplier = 1.5

	for well in gravity_well_data:
		var prog = well["progress"]
		if prog >= baked_length - 1.0:
			continue

		var pos = c.sample_baked(prog)
		var up = c.sample_baked_up_vector(prog)
		var next = c.sample_baked(clampf(prog + 3.0, 0.0, baked_length - 0.1))
		var fwd = (next - pos)
		if fwd.length() < 0.001:
			fwd = Vector3(0, 0, -1)
		fwd = fwd.normalized()
		var right = fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()

		var max_off = track_width * 0.5
		var well_pos = pos + right * well["offset_x"] * max_off + up * well["offset_y"] * max_off

		var well_root = Node3D.new()
		well_root.position = well_pos
		well_root.name = "GravWell_%d" % gravity_well_data.find(well)

		# Core sphere
		var core = MeshInstance3D.new()
		var core_mesh = SphereMesh.new()
		core_mesh.radius = 1.5
		core_mesh.height = 3.0
		core_mesh.radial_segments = 12
		core_mesh.rings = 8
		core.mesh = core_mesh
		core.material_override = well_mat
		well_root.add_child(core)

		# Concentric rings showing pull radius
		for r in range(3):
			var ring_mi = MeshInstance3D.new()
			var torus = TorusMesh.new()
			var ring_radius = 3.0 + float(r) * 3.5
			torus.inner_radius = ring_radius - 0.1
			torus.outer_radius = ring_radius + 0.1
			torus.rings = 16
			torus.ring_segments = 4
			ring_mi.mesh = torus
			ring_mi.material_override = ring_mat
			well_root.add_child(ring_mi)

		# Store spin metadata
		well_root.set_meta("spin_speed", 0.8)

		add_child(well_root)
		well["visual_node"] = well_root
		well["world_pos"] = well_pos
