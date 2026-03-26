extends Node3D
## Main menu: animated starfield, rotating ship, track selector,
## difficulty selector, best time, START RACE.

var _ship_node: Node3D = null
var _difficulty_buttons: Array = []
var _best_time_label: Label = null
var _title_label: Label = null
var _title_tween: Tween = null
var _track_name_label: Label = null
var _track_subtitle_label: Label = null
var _track_index: int = 0


func _ready() -> void:
	# Reset clear colour for menu
	RenderingServer.set_default_clear_color(Color(0.005, 0.005, 0.02, 1.0))

	# Set initial track index from current selection
	var order = TrackData.TRACK_ORDER
	_track_index = order.find(GameSettings.current_track)
	if _track_index < 0:
		_track_index = 0

	# Build the 3D ship display
	_build_ship()

	# Build 2D UI overlay
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# Starfield background particles
	_build_starfield(ui_layer)

	# Dark gradient overlay so UI text pops over 3D scene
	var gradient_overlay = ColorRect.new()
	gradient_overlay.color = Color(0.0, 0.0, 0.02, 0.4)
	gradient_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	gradient_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(gradient_overlay)

	# Title
	_build_title(ui_layer)

	# Track selector
	_build_track_selector(ui_layer)

	# Difficulty selector
	_build_difficulty_selector(ui_layer)

	# Best time display
	_build_best_time(ui_layer)

	# START RACE button
	_build_start_button(ui_layer)

	# EXIT button
	_build_exit_button(ui_layer)

	# Select current difficulty button
	_update_difficulty_selection()
	_update_track_display()


func _process(delta: float) -> void:
	# Rotate and bob the ship
	if _ship_node:
		_ship_node.rotate_y(0.4 * delta)
		_ship_node.position.y = sin(Time.get_ticks_msec() * 0.001 * 1.2) * 0.15

	# Pulse the title alpha
	if _title_label:
		var t = sin(Time.get_ticks_msec() * 0.001 * 2.0) * 0.15 + 0.85
		_title_label.modulate.a = t


# =========================================================================
#  3D SHIP (reuse the same geometry as main.tscn)
# =========================================================================

func _build_ship() -> void:
	_ship_node = Node3D.new()
	_ship_node.position = Vector3(0, -0.5, 0)

	# Materials
	var mat_red = StandardMaterial3D.new()
	mat_red.albedo_color = Color(0.75, 0.06, 0.06, 1.0)
	mat_red.metallic = 0.7
	mat_red.roughness = 0.2
	mat_red.emission_enabled = true
	mat_red.emission = Color(0.9, 0.08, 0.05, 1.0)
	mat_red.emission_energy_multiplier = 1.2

	var mat_white = StandardMaterial3D.new()
	mat_white.albedo_color = Color(0.92, 0.92, 0.95, 1.0)
	mat_white.metallic = 0.5
	mat_white.roughness = 0.15
	mat_white.emission_enabled = true
	mat_white.emission = Color(0.5, 0.5, 0.55, 1.0)
	mat_white.emission_energy_multiplier = 0.4

	var mat_cockpit = StandardMaterial3D.new()
	mat_cockpit.albedo_color = Color(0.1, 0.12, 0.18, 0.85)
	mat_cockpit.metallic = 0.9
	mat_cockpit.roughness = 0.05
	mat_cockpit.emission_enabled = true
	mat_cockpit.emission = Color(0.15, 0.2, 0.35, 1.0)
	mat_cockpit.emission_energy_multiplier = 0.8
	mat_cockpit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mat_engine = StandardMaterial3D.new()
	mat_engine.albedo_color = Color(0.25, 0.25, 0.28, 1.0)
	mat_engine.metallic = 0.85
	mat_engine.roughness = 0.3
	mat_engine.emission_enabled = true
	mat_engine.emission = Color(0.2, 0.2, 0.25, 1.0)
	mat_engine.emission_energy_multiplier = 0.5

	var mat_exhaust = StandardMaterial3D.new()
	mat_exhaust.albedo_color = Color(0.3, 0.6, 1.0, 0.8)
	mat_exhaust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_exhaust.emission_enabled = true
	mat_exhaust.emission = Color(0.4, 0.7, 1.0, 1.0)
	mat_exhaust.emission_energy_multiplier = 4.0
	mat_exhaust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Fuselage
	var fuse = MeshInstance3D.new()
	var fuse_mesh = BoxMesh.new()
	fuse_mesh.size = Vector3(1.0, 0.5, 3.5)
	fuse.mesh = fuse_mesh
	fuse.material_override = mat_red
	_ship_node.add_child(fuse)

	# Nose cone
	var nose = MeshInstance3D.new()
	var nose_mesh = CylinderMesh.new()
	nose_mesh.top_radius = 0.05
	nose_mesh.bottom_radius = 0.5
	nose_mesh.height = 1.8
	nose_mesh.radial_segments = 8
	nose.mesh = nose_mesh
	nose.material_override = mat_red
	nose.transform = Transform3D(Basis(Vector3(1,0,0), Vector3(0,0,1), Vector3(0,-1,0)), Vector3(0, 0, -2.6))
	_ship_node.add_child(nose)

	# Cockpit
	var cockpit = MeshInstance3D.new()
	var cockpit_mesh = SphereMesh.new()
	cockpit_mesh.radius = 0.45
	cockpit_mesh.height = 0.5
	cockpit_mesh.radial_segments = 10
	cockpit_mesh.rings = 6
	cockpit.mesh = cockpit_mesh
	cockpit.material_override = mat_cockpit
	cockpit.position = Vector3(0, 0.4, -0.6)
	_ship_node.add_child(cockpit)

	# Wing struts
	var strut_mesh = BoxMesh.new()
	strut_mesh.size = Vector3(1.0, 0.06, 0.6)
	for x_pos in [-0.9, 0.9]:
		var strut = MeshInstance3D.new()
		strut.mesh = strut_mesh
		strut.material_override = mat_white
		strut.position = Vector3(x_pos, -0.05, 0.2)
		_ship_node.add_child(strut)

	# Engine nacelles
	var engine_mesh = CylinderMesh.new()
	engine_mesh.top_radius = 0.22
	engine_mesh.bottom_radius = 0.32
	engine_mesh.height = 2.2
	engine_mesh.radial_segments = 10
	for x_pos in [-1.4, 1.4]:
		var eng = MeshInstance3D.new()
		eng.mesh = engine_mesh
		eng.material_override = mat_engine
		eng.transform = Transform3D(Basis(Vector3(1,0,0), Vector3(0,0,1), Vector3(0,-1,0)), Vector3(x_pos, -0.05, 0.3))
		_ship_node.add_child(eng)

	# Exhaust glow
	var exhaust_mesh = SphereMesh.new()
	exhaust_mesh.radius = 0.28
	exhaust_mesh.height = 0.45
	exhaust_mesh.radial_segments = 8
	exhaust_mesh.rings = 4
	for x_pos in [-1.4, 1.4]:
		var exh = MeshInstance3D.new()
		exh.mesh = exhaust_mesh
		exh.material_override = mat_exhaust
		exh.position = Vector3(x_pos, -0.05, 1.4)
		_ship_node.add_child(exh)

	# Racing stripes
	var stripe_mesh = BoxMesh.new()
	stripe_mesh.size = Vector3(0.15, 0.06, 2.8)
	for x_pos in [-1.4, 1.4]:
		var stripe = MeshInstance3D.new()
		stripe.mesh = stripe_mesh
		stripe.material_override = mat_red
		stripe.position = Vector3(x_pos, 0.28, 0.3)
		_ship_node.add_child(stripe)

	# Tail fin
	var fin = MeshInstance3D.new()
	var fin_mesh = BoxMesh.new()
	fin_mesh.size = Vector3(0.06, 0.7, 0.9)
	fin.mesh = fin_mesh
	fin.material_override = mat_white
	fin.position = Vector3(0, 0.55, 1.3)
	_ship_node.add_child(fin)

	add_child(_ship_node)

	# Camera looking at the ship from a front-quarter angle
	var cam = Camera3D.new()
	cam.position = Vector3(3.0, 2.0, -4.0)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	cam.fov = 50.0
	add_child(cam)

	# Directional light
	var light = DirectionalLight3D.new()
	light.transform = Transform3D(Basis(Vector3(1,0,0), Vector3(0,0.866,-0.5), Vector3(0,0.5,0.866)), Vector3.ZERO)
	light.light_color = Color(0.85, 0.85, 1.0, 1.0)
	light.light_energy = 0.8
	add_child(light)

	# Subtle ambient fill from below
	var fill = DirectionalLight3D.new()
	fill.transform = Transform3D(Basis(Vector3(1,0,0), Vector3(0,-0.5,0.866), Vector3(0,-0.866,-0.5)), Vector3.ZERO)
	fill.light_color = Color(0.2, 0.3, 0.6, 1.0)
	fill.light_energy = 0.3
	add_child(fill)


# =========================================================================
#  STARFIELD (GPUParticles2D)
# =========================================================================

func _build_starfield(ui_layer: CanvasLayer) -> void:
	var particles = GPUParticles2D.new()
	particles.amount = 150
	particles.lifetime = 8.0
	particles.speed_scale = 1.0
	particles.position = Vector2(360, 0)

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 5.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3.ZERO
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(400, 10, 0)
	mat.scale_min = 0.5
	mat.scale_max = 2.0
	mat.color = Color(1.0, 1.0, 1.0, 0.7)

	particles.process_material = mat
	particles.emitting = true

	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex = ImageTexture.create_from_image(img)
	particles.texture = tex

	ui_layer.add_child(particles)


# =========================================================================
#  TITLE
# =========================================================================

func _build_title(ui_layer: CanvasLayer) -> void:
	_title_label = Label.new()
	_title_label.text = "SPACE RACER"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 80)
	_title_label.size = Vector2(720, 100)
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1.0))
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_title_label)


# =========================================================================
#  TRACK SELECTOR (< TRACK NAME > with subtitle)
# =========================================================================

func _build_track_selector(ui_layer: CanvasLayer) -> void:
	# Track name
	_track_name_label = Label.new()
	_track_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track_name_label.position = Vector2(80, 200)
	_track_name_label.size = Vector2(560, 50)
	_track_name_label.add_theme_font_size_override("font_size", 30)
	_track_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 0.95))
	_track_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_track_name_label)

	# Track subtitle
	_track_subtitle_label = Label.new()
	_track_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track_subtitle_label.position = Vector2(80, 245)
	_track_subtitle_label.size = Vector2(560, 35)
	_track_subtitle_label.add_theme_font_size_override("font_size", 20)
	_track_subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9, 0.6))
	_track_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_track_subtitle_label)

	# Left arrow button
	var left_btn = Button.new()
	left_btn.text = "<"
	left_btn.position = Vector2(20, 195)
	left_btn.size = Vector2(55, 55)
	_style_arrow_button(left_btn)
	left_btn.pressed.connect(_on_track_prev)
	ui_layer.add_child(left_btn)

	# Right arrow button
	var right_btn = Button.new()
	right_btn.text = ">"
	right_btn.position = Vector2(645, 195)
	right_btn.size = Vector2(55, 55)
	_style_arrow_button(right_btn)
	right_btn.pressed.connect(_on_track_next)
	ui_layer.add_child(right_btn)

	# Track counter (1/4 etc.)
	var counter = Label.new()
	counter.name = "TrackCounter"
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.position = Vector2(80, 275)
	counter.size = Vector2(560, 25)
	counter.add_theme_font_size_override("font_size", 16)
	counter.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7, 0.5))
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(counter)


func _style_arrow_button(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.2, 0.4, 0.6)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_color = Color(0.4, 0.6, 1.0, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.25, 0.35, 0.6, 0.8)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))


func _on_track_prev() -> void:
	_track_index -= 1
	if _track_index < 0:
		_track_index = TrackData.TRACK_ORDER.size() - 1
	_update_track_display()


func _on_track_next() -> void:
	_track_index += 1
	if _track_index >= TrackData.TRACK_ORDER.size():
		_track_index = 0
	_update_track_display()


func _update_track_display() -> void:
	var track_id = TrackData.TRACK_ORDER[_track_index]
	GameSettings.current_track = track_id

	_track_name_label.text = TrackData.get_track_name(track_id)
	_track_subtitle_label.text = TrackData.get_track_subtitle(track_id)

	# Update counter label
	var counter = get_node_or_null("../CanvasLayer/TrackCounter")
	# Walk through all children to find the counter
	for child in get_children():
		if child is CanvasLayer:
			var tc = child.find_child("TrackCounter", false)
			if tc:
				tc.text = "%d / %d" % [_track_index + 1, TrackData.TRACK_ORDER.size()]
				break

	# Refresh best time for new track
	_refresh_best_time()


# =========================================================================
#  DIFFICULTY SELECTOR
# =========================================================================

func _build_difficulty_selector(ui_layer: CanvasLayer) -> void:
	var label = Label.new()
	label.text = "DIFFICULTY"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 820)
	label.size = Vector2(720, 40)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8, 0.7))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(label)

	var names = ["EASY", "NORMAL", "HARD"]
	var colours = [
		Color(0.2, 0.7, 0.3, 0.85),
		Color(0.7, 0.5, 0.1, 0.85),
		Color(0.8, 0.15, 0.1, 0.85),
	]
	var button_width = 180
	var gap = 20
	var total_width = button_width * 3 + gap * 2
	var start_x = (720 - total_width) / 2

	for i in range(3):
		var btn = Button.new()
		btn.text = names[i]
		btn.position = Vector2(start_x + i * (button_width + gap), 865)
		btn.size = Vector2(button_width, 55)

		var style = StyleBoxFlat.new()
		style.bg_color = colours[i]
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.border_color = Color(1.0, 1.0, 1.0, 0.3)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", style)

		var hover = style.duplicate()
		hover.bg_color = colours[i] * 1.3
		hover.bg_color.a = 0.95
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)

		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

		var idx = i
		btn.pressed.connect(func(): _on_difficulty_selected(idx))
		ui_layer.add_child(btn)
		_difficulty_buttons.append(btn)


func _on_difficulty_selected(index: int) -> void:
	GameSettings.current_difficulty = index
	_update_difficulty_selection()


func _update_difficulty_selection() -> void:
	for i in range(_difficulty_buttons.size()):
		var btn = _difficulty_buttons[i] as Button
		if i == GameSettings.current_difficulty:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if style:
				var selected = style.duplicate()
				selected.border_color = Color(1.0, 1.0, 1.0, 0.9)
				selected.border_width_left = 3
				selected.border_width_right = 3
				selected.border_width_top = 3
				selected.border_width_bottom = 3
				btn.add_theme_stylebox_override("normal", selected)
		else:
			btn.modulate = Color(0.6, 0.6, 0.6, 0.7)

	_refresh_best_time()


# =========================================================================
#  BEST TIME
# =========================================================================

func _build_best_time(ui_layer: CanvasLayer) -> void:
	_best_time_label = Label.new()
	_best_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_time_label.position = Vector2(0, 940)
	_best_time_label.size = Vector2(720, 50)
	_best_time_label.add_theme_font_size_override("font_size", 24)
	_best_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_best_time_label)
	_refresh_best_time()


func _refresh_best_time() -> void:
	if not _best_time_label:
		return
	var best = GameSettings.get_best_time()
	if best < 0.0:
		_best_time_label.text = "BEST: ---"
		_best_time_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.6))
	else:
		_best_time_label.text = "BEST: %s" % GameSettings.format_time(best)
		_best_time_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.9))


# =========================================================================
#  START BUTTON
# =========================================================================

func _build_start_button(ui_layer: CanvasLayer) -> void:
	var btn = Button.new()
	btn.text = "START RACE"
	btn.position = Vector2(160, 1050)
	btn.size = Vector2(400, 80)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.65, 0.2, 0.9)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_color = Color(0.3, 1.0, 0.4, 0.7)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.15, 0.8, 0.3, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	btn.pressed.connect(_on_start_pressed)
	ui_layer.add_child(btn)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# =========================================================================
#  EXIT BUTTON
# =========================================================================

func _build_exit_button(ui_layer: CanvasLayer) -> void:
	var btn = Button.new()
	btn.text = "EXIT"
	btn.position = Vector2(270, 1170)
	btn.size = Vector2(180, 50)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.1, 0.1, 0.6)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_color = Color(0.8, 0.3, 0.3, 0.4)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.6, 0.15, 0.15, 0.8)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7, 0.8))

	btn.pressed.connect(_on_exit_pressed)
	ui_layer.add_child(btn)


func _on_exit_pressed() -> void:
	get_tree().quit()
