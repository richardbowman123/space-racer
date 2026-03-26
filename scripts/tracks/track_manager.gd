extends Path3D
## Builds the current track from TrackData: curve geometry, visual elements,
## energy ring positions, and hazard wave definitions.

# Data exposed to GameManager
var ring_data: Array = []
var hazard_wave_data: Array = []
var boost_pad_data: Array = []
var speed_gate_data: Array = []
var crosswind_data: Array = []
var gravity_well_data: Array = []

# Track visual parameters (set from TrackData in _ready)
@export var track_width: float = 14.0
@export var track_segments: int = 200
@export var gate_spacing: float = 60.0

# Wire tube parameters (set from TrackData in _ready)
@export var tube_radius: float = 8.0
@export var tube_ring_sides: int = 12
@export var tube_ring_spacing: float = 15.0
@export var tube_longitude_count: int = 8

# Current track definition and theme
var _track_def: Dictionary = {}
var _theme: Dictionary = {}

var _vortex_node: Node3D = null
var _vortex_rings: Array = []

func _ready() -> void:
	# Load track definition
	var track_id = GameSettings.current_track
	_track_def = TrackData.get_track(track_id)
	_theme = _track_def["theme"]

	# Apply track-specific parameters
	track_width = _track_def.get("track_width", 14.0)
	tube_radius = _track_def.get("tube_radius", 8.0)

	# Set background colour for this track
	RenderingServer.set_default_clear_color(_theme["clear_color"])

	_build_curve()
	_define_rings()
	_define_hazard_waves()
	_generate_track_ribbon()
	_generate_edge_lines()
	_generate_wire_tube()
	_generate_gate_markers()
	_generate_ring_visuals()
	_generate_finish_vortex()


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

	# Spin finish vortex rings at different speeds
	for i in range(_vortex_rings.size()):
		var ring_node = _vortex_rings[i]
		if ring_node and is_instance_valid(ring_node):
			var speed = ring_node.get_meta("spin_speed", 1.0)
			var axis = ring_node.get_meta("spin_axis", Vector3.FORWARD)
			ring_node.rotate(axis, speed * delta)


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

	var points = _track_def["points"]

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
	rng.seed = _track_def.get("ring_seed", 123)
	var baked_length = curve.get_baked_length()

	var ring_spacing = _track_def.get("ring_spacing", 45.0)
	var count = int((baked_length - 200.0) / ring_spacing)

	for i in range(count):
		var prog = 80.0 + float(i) * ring_spacing + rng.randf_range(-10.0, 10.0)
		prog = clampf(prog, 50.0, baked_length - 80.0)

		var ox = rng.randf_range(-0.8, 0.8)
		var oy = rng.randf_range(-0.4, 0.4)

		var difficulty = absf(ox) + absf(oy) * 1.5
		var value = 1
		if difficulty > 0.6:
			value = 2

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

	var heart_mat = _make_crystal_material(Color(0.1, 0.9, 0.2, 0.85), Color(0.05, 0.85, 0.15, 1.0))
	var chevron_mat = _make_crystal_material(Color(0.1, 0.8, 1.0, 0.9), Color(0.05, 0.75, 0.95, 1.0))
	var heart_glow_mat = heart_mat.duplicate()
	heart_glow_mat.emission_energy_multiplier = 5.0
	var chevron_glow_mat = chevron_mat.duplicate()
	chevron_glow_mat.emission_energy_multiplier = 5.0

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

		var max_off = track_width
		var item_pos = pos + right * ring["offset_x"] * max_off + up * ring["offset_y"] * max_off * 0.5

		var item_root = Node3D.new()
		item_root.position = item_pos
		item_root.name = "Pickup_%d" % ring_data.find(ring)

		var value = ring["value"]

		if value == 1:
			var left_bump = MeshInstance3D.new()
			var lb_mesh = SphereMesh.new()
			lb_mesh.radius = 0.5
			lb_mesh.height = 1.0
			lb_mesh.radial_segments = 8
			lb_mesh.rings = 6
			left_bump.mesh = lb_mesh
			left_bump.material_override = heart_mat
			left_bump.position = Vector3(-0.35, 0.3, 0)
			item_root.add_child(left_bump)

			var right_bump = MeshInstance3D.new()
			right_bump.mesh = lb_mesh
			right_bump.material_override = heart_mat
			right_bump.position = Vector3(0.35, 0.3, 0)
			item_root.add_child(right_bump)

			var tip = MeshInstance3D.new()
			var tip_mesh = CylinderMesh.new()
			tip_mesh.top_radius = 0.65
			tip_mesh.bottom_radius = 0.0
			tip_mesh.height = 1.1
			tip_mesh.radial_segments = 8
			tip.mesh = tip_mesh
			tip.material_override = heart_mat
			tip.position = Vector3(0, -0.3, 0)
			item_root.add_child(tip)

			var glow = MeshInstance3D.new()
			var glow_mesh = SphereMesh.new()
			glow_mesh.radius = 0.35
			glow_mesh.height = 0.7
			glow_mesh.radial_segments = 6
			glow_mesh.rings = 4
			glow.mesh = glow_mesh
			glow.material_override = heart_glow_mat
			glow.position = Vector3(0, 0.1, 0)
			item_root.add_child(glow)

		else:
			var arm_mesh = BoxMesh.new()
			arm_mesh.size = Vector3(0.2, 0.2, 1.8)

			var top_arm = MeshInstance3D.new()
			top_arm.mesh = arm_mesh
			top_arm.material_override = chevron_mat
			top_arm.position = Vector3(0, 0.35, -0.3)
			top_arm.rotation_degrees = Vector3(25, 0, 0)
			item_root.add_child(top_arm)

			var bottom_arm = MeshInstance3D.new()
			bottom_arm.mesh = arm_mesh
			bottom_arm.material_override = chevron_mat
			bottom_arm.position = Vector3(0, -0.35, -0.3)
			bottom_arm.rotation_degrees = Vector3(-25, 0, 0)
			item_root.add_child(bottom_arm)

			var top_arm2 = MeshInstance3D.new()
			top_arm2.mesh = arm_mesh
			top_arm2.material_override = chevron_mat
			top_arm2.position = Vector3(0, 0.35, 0.5)
			top_arm2.rotation_degrees = Vector3(25, 0, 0)
			item_root.add_child(top_arm2)

			var bottom_arm2 = MeshInstance3D.new()
			bottom_arm2.mesh = arm_mesh
			bottom_arm2.material_override = chevron_mat
			bottom_arm2.position = Vector3(0, -0.35, 0.5)
			bottom_arm2.rotation_degrees = Vector3(-25, 0, 0)
			item_root.add_child(bottom_arm2)

			var glow = MeshInstance3D.new()
			var glow_mesh = SphereMesh.new()
			glow_mesh.radius = 0.3
			glow_mesh.height = 0.6
			glow_mesh.radial_segments = 6
			glow_mesh.rings = 4
			glow.mesh = glow_mesh
			glow.material_override = chevron_glow_mat
			item_root.add_child(glow)

		item_root.scale = Vector3(3.0, 3.0, 3.0)  # Scaled up for wider tunnels
		item_root.set_meta("spin_speed", 1.5 + float(value) * 0.5)
		item_root.set_meta("base_y", item_pos.y)

		add_child(item_root)
		ring["visual_node"] = item_root


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
	rng.seed = _track_def.get("hazard_seed", 77)
	var baked_length = curve.get_baked_length()

	var wave_count = _track_def.get("hazard_count", 18)
	var start = 200.0
	var spacing = (baked_length - 400.0) / float(wave_count)

	for i in range(wave_count):
		var prog = start + float(i) * spacing + rng.randf_range(-25.0, 25.0)
		prog = clampf(prog, 150.0, baked_length - 150.0)

		var track_ratio = prog / baked_length
		var osc_speed = 2.0 + track_ratio * 3.0 + rng.randf_range(-0.5, 0.5)
		var osc_range = 4.0 + track_ratio * 4.0 + rng.randf_range(-1.0, 1.0)
		var gap_hw = 7.5 - track_ratio * 2.0 + rng.randf_range(-0.5, 0.5)
		gap_hw = clampf(gap_hw, 5.0, 8.0)

		var sweep_type = 0
		var roll = rng.randf()
		if track_ratio > 0.25:
			if roll < 0.35:
				sweep_type = 1
			elif roll < 0.55:
				sweep_type = 2
		elif track_ratio > 0.15:
			if roll < 0.2:
				sweep_type = 1

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
	mat.albedo_color = _theme["ribbon_albedo"]
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = _theme["ribbon_emission"]
	mat.emission_energy_multiplier = _theme["ribbon_emission_energy"]
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
	edge_mat.albedo_color = _theme["edge_albedo"]
	edge_mat.emission_enabled = true
	edge_mat.emission = _theme["edge_emission"]
	edge_mat.emission_energy_multiplier = _theme["edge_emission_energy"]
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
	wire_mat.albedo_color = _theme["wire_albedo"]
	wire_mat.emission_enabled = true
	wire_mat.emission = _theme["wire_emission"]
	wire_mat.emission_energy_multiplier = _theme["wire_emission_energy"]
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
	long_mat.albedo_color = _theme["wire_long_albedo"]
	long_mat.emission_energy_multiplier = _theme["wire_long_emission_energy"]
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
	post_mat.albedo_color = _theme["gate_albedo"]
	post_mat.emission_enabled = true
	post_mat.emission = _theme["gate_emission"]
	post_mat.emission_energy_multiplier = _theme["gate_emission_energy"]
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
#  FINISH VORTEX (spiral portal at the end of the track)
# =========================================================================

func _generate_finish_vortex() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	if baked_length < 50.0:
		return

	var end_prog = baked_length - 10.0
	var end_pos = c.sample_baked(end_prog)
	var end_up = c.sample_baked_up_vector(end_prog)
	var behind = c.sample_baked(clampf(end_prog - 5.0, 0.0, baked_length - 1.0))
	var end_fwd = (end_pos - behind)
	if end_fwd.length() < 0.001:
		end_fwd = Vector3(0, 0, -1)
	end_fwd = end_fwd.normalized()
	var end_right = end_fwd.cross(end_up).normalized()
	end_up = end_right.cross(end_fwd).normalized()

	_vortex_node = Node3D.new()
	_vortex_node.name = "FinishVortex"
	_vortex_node.global_position = end_pos
	add_child(_vortex_node)

	var ring_configs = [
		{"radius": 10.0, "thickness": 0.25, "color": Color(0.0, 0.8, 1.0, 0.7), "energy": 4.0, "speed": 1.8, "tilt": 0.0},
		{"radius": 8.5, "thickness": 0.2, "color": Color(0.2, 0.5, 1.0, 0.65), "energy": 3.5, "speed": -2.5, "tilt": 0.15},
		{"radius": 7.0, "thickness": 0.18, "color": Color(0.4, 0.3, 1.0, 0.6), "energy": 3.0, "speed": 3.2, "tilt": -0.1},
		{"radius": 5.5, "thickness": 0.15, "color": Color(0.6, 0.2, 1.0, 0.55), "energy": 3.5, "speed": -4.0, "tilt": 0.2},
		{"radius": 4.0, "thickness": 0.12, "color": Color(0.8, 0.1, 1.0, 0.5), "energy": 4.0, "speed": 5.0, "tilt": -0.15},
		{"radius": 2.5, "thickness": 0.1, "color": Color(1.0, 0.3, 0.8, 0.6), "energy": 5.0, "speed": -6.5, "tilt": 0.1},
		{"radius": 1.2, "thickness": 0.08, "color": Color(1.0, 0.6, 0.3, 0.7), "energy": 6.0, "speed": 8.0, "tilt": 0.0},
	]

	for cfg in ring_configs:
		var ring_mi = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = cfg["radius"] - cfg["thickness"]
		torus.outer_radius = cfg["radius"] + cfg["thickness"]
		torus.rings = 32
		torus.ring_segments = 12
		ring_mi.mesh = torus

		var mat = StandardMaterial3D.new()
		mat.albedo_color = cfg["color"]
		mat.emission_enabled = true
		mat.emission = Color(cfg["color"].r, cfg["color"].g, cfg["color"].b, 1.0)
		mat.emission_energy_multiplier = cfg["energy"]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mi.material_override = mat

		ring_mi.look_at_from_position(Vector3.ZERO, end_fwd, end_up)
		ring_mi.rotate_object_local(Vector3.RIGHT, cfg["tilt"])

		ring_mi.set_meta("spin_speed", cfg["speed"])
		ring_mi.set_meta("spin_axis", end_fwd)

		_vortex_node.add_child(ring_mi)
		_vortex_rings.append(ring_mi)

	# Bright centre core
	var core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 1.0
	core_mesh.height = 2.0
	core_mesh.radial_segments = 12
	core_mesh.rings = 8
	core.mesh = core_mesh

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.8, 0.9, 1.0, 1.0)
	core_mat.emission_energy_multiplier = 8.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.material_override = core_mat
	_vortex_node.add_child(core)

	# Spiral arms
	var arm_mat = StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.3, 0.6, 1.0, 0.3)
	arm_mat.emission_enabled = true
	arm_mat.emission = Color(0.4, 0.7, 1.0, 1.0)
	arm_mat.emission_energy_multiplier = 2.5
	arm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for arm in range(2):
		var arm_node = Node3D.new()
		arm_node.name = "SpiralArm_%d" % arm
		var base_angle = float(arm) * PI

		for seg in range(16):
			var t = float(seg) / 16.0
			var angle = base_angle + t * TAU * 1.5
			var r = 2.0 + t * 8.0
			var local_pos = end_right * cos(angle) * r + end_up * sin(angle) * r

			var seg_mi = MeshInstance3D.new()
			var seg_mesh = SphereMesh.new()
			seg_mesh.radius = 0.15 + t * 0.25
			seg_mesh.height = 0.8 + t * 1.2
			seg_mesh.radial_segments = 6
			seg_mesh.rings = 4
			seg_mi.mesh = seg_mesh
			seg_mi.material_override = arm_mat
			seg_mi.position = local_pos
			arm_node.add_child(seg_mi)

		arm_node.set_meta("spin_speed", 1.5)
		arm_node.set_meta("spin_axis", end_fwd)
		_vortex_node.add_child(arm_node)
		_vortex_rings.append(arm_node)


# =========================================================================
#  BOOST PADS (speed burst on optimal racing lines) — DISABLED
# =========================================================================

func _define_boost_pads() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

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

		if curve_mag < 0.015:
			continue

		var pad_x = -curve_lateral / maxf(curve_mag, 0.001) * 0.5
		var pad_y = -curve_vertical / maxf(curve_mag, 0.001) * 0.3

		if rng.randf() < 0.55:
			continue

		boost_pad_data.append({
			"progress": prog,
			"offset_x": clampf(pad_x, -0.8, 0.8),
			"offset_y": clampf(pad_y, -0.5, 0.5),
			"boost_amount": 12.0 + curve_mag * 200.0,
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
#  SPEED GATES (narrow precision gates for bonus) — DISABLED
# =========================================================================

func _define_speed_gates() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	var rng = RandomNumberGenerator.new()
	rng.seed = 99

	var gate_count = 12
	var spacing = (baked_length - 400.0) / float(gate_count)

	for i in range(gate_count):
		var prog = 200.0 + float(i) * spacing + rng.randf_range(-30.0, 30.0)
		prog = clampf(prog, 150.0, baked_length - 150.0)

		var ox = rng.randf_range(-0.6, 0.6)
		var oy = rng.randf_range(-0.3, 0.3)

		speed_gate_data.append({
			"progress": prog,
			"offset_x": ox,
			"offset_y": oy,
			"gate_half_width": 3.0,
			"boost_centre": 18.0,
			"boost_edge": 6.0,
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

		var left_post = MeshInstance3D.new()
		left_post.mesh = post_mesh
		left_post.material_override = gate_mat
		left_post.position = -right * ghw
		gate_root.add_child(left_post)

		var right_post = MeshInstance3D.new()
		right_post.mesh = post_mesh
		right_post.material_override = gate_mat
		right_post.position = right * ghw
		gate_root.add_child(right_post)

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
#  CROSSWIND ZONES — DISABLED
# =========================================================================

func _define_crosswinds() -> void:
	var c = curve
	if not c:
		return
	var baked_length = c.get_baked_length()
	var rng = RandomNumberGenerator.new()
	rng.seed = 55

	var zone_count = 8
	var spacing = (baked_length - 400.0) / float(zone_count)

	for i in range(zone_count):
		var prog_start = 250.0 + float(i) * spacing + rng.randf_range(-40.0, 40.0)
		prog_start = clampf(prog_start, 200.0, baked_length - 300.0)
		var zone_length = rng.randf_range(40.0, 80.0)

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


# =========================================================================
#  GRAVITY WELLS — DISABLED
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

		var off_x = rng.randf_range(-1.2, 1.2)
		var off_y = rng.randf_range(-0.6, 0.6)
		if absf(off_x) < 0.3 and absf(off_y) < 0.2:
			off_x = 0.8 * signf(off_x + 0.01)

		gravity_well_data.append({
			"progress": prog,
			"offset_x": off_x,
			"offset_y": off_y,
			"pull_strength": rng.randf_range(8.0, 14.0),
			"pull_radius": rng.randf_range(10.0, 16.0),
			"slingshot_bonus": rng.randf_range(15.0, 25.0),
			"slingshot_radius": 4.0,
			"triggered": false,
			"visual_node": null,
		})
