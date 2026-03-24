extends CanvasLayer
## Racing HUD: speed, progress, race time, countdown, chain counter,
## fire/shield action buttons, ring/hazard feedback, finish screen,
## pause system.

@onready var speed_label: Label = $SpeedLabel
@onready var speed_bar: ProgressBar = $SpeedBar
@onready var progress_label: Label = $ProgressLabel
@onready var time_label: Label = $TimeLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var finish_panel: PanelContainer = $FinishPanel
@onready var finish_time_label: Label = $FinishPanel/FinishTimeLabel
@onready var chain_label: Label = $ChainLabel
@onready var multiplier_label: Label = $MultiplierLabel
@onready var flash_label: Label = $FlashLabel
@onready var drift_label: Label = $DriftLabel
@onready var line_label: Label = $LineLabel
@onready var fire_button: Button = $FireButton
@onready var shield_button: Button = $ShieldButton
@onready var shield_charge_label: Label = $ShieldChargeLabel

# Signals for button presses (game_manager connects to these)
signal fire_pressed
signal shield_pressed
signal restart_pressed
signal menu_pressed

var current_countdown: int = -1
var _is_paused: bool = false

# Pause UI (built in code)
var _pause_button: Button = null
var _pause_overlay: ColorRect = null
var _pause_label: Label = null
var _resume_button: Button = null
var _restart_pause_button: Button = null
var _menu_pause_button: Button = null

# Finish UI buttons (built in code)
var _restart_finish_button: Button = null
var _menu_finish_button: Button = null
var _best_time_label: Label = null


func _ready() -> void:
	# Clear stale exclusion rects from previous scene loads
	TouchInput.clear_exclusion_rects()

	finish_panel.visible = false
	countdown_label.visible = false
	chain_label.visible = false
	multiplier_label.visible = false
	flash_label.visible = false
	drift_label.visible = false
	line_label.visible = false

	# Make all HUD elements transparent to mouse/touch input
	# so clicks pass through to the steering system
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_mouse_ignore_recursive(child)

	# NOW re-enable the action buttons so they intercept touches
	# (must happen AFTER the recursive ignore pass)
	fire_button.mouse_filter = Control.MOUSE_FILTER_STOP
	shield_button.mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect button signals
	fire_button.pressed.connect(_on_fire_pressed)
	shield_button.pressed.connect(_on_shield_pressed)

	# Style the buttons
	_style_action_buttons()

	# Register button areas as exclusion zones for the drag-to-steer system.
	# This prevents clicking a button from also starting a steering drag.
	var fire_rect = Rect2(fire_button.offset_left, fire_button.offset_top,
		fire_button.offset_right - fire_button.offset_left,
		fire_button.offset_bottom - fire_button.offset_top)
	var shield_rect = Rect2(shield_button.offset_left, shield_button.offset_top,
		shield_button.offset_right - shield_button.offset_left,
		shield_button.offset_bottom - shield_button.offset_top)
	TouchInput.add_exclusion_rect(fire_rect)
	TouchInput.add_exclusion_rect(shield_rect)

	# Build pause button and overlay
	_build_pause_button()
	_build_pause_overlay()

	# Build finish panel buttons
	_build_finish_buttons()


func _set_mouse_ignore_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_mouse_ignore_recursive(child)


# =========================================================================
#  PAUSE BUTTON (top-left, small)
# =========================================================================

func _build_pause_button() -> void:
	_pause_button = Button.new()
	_pause_button.text = "| |"
	_pause_button.position = Vector2(20, 60)
	_pause_button.size = Vector2(60, 50)
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	# Must keep processing when paused
	_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_color = Color(0.5, 0.6, 0.8, 0.4)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	_pause_button.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.3, 0.3, 0.5, 0.7)
	_pause_button.add_theme_stylebox_override("hover", hover)
	_pause_button.add_theme_stylebox_override("pressed", hover)

	_pause_button.add_theme_font_size_override("font_size", 20)
	_pause_button.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 0.8))

	_pause_button.pressed.connect(_on_pause_pressed)
	add_child(_pause_button)

	# Register as exclusion zone
	TouchInput.add_exclusion_rect(Rect2(20, 60, 60, 50))


# =========================================================================
#  PAUSE OVERLAY (full screen, only visible when paused)
# =========================================================================

func _build_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.color = Color(0.0, 0.0, 0.05, 0.75)
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.visible = false
	add_child(_pause_overlay)

	# PAUSED label
	_pause_label = Label.new()
	_pause_label.text = "PAUSED"
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.position = Vector2(0, 350)
	_pause_label.size = Vector2(720, 80)
	_pause_label.add_theme_font_size_override("font_size", 56)
	_pause_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	_pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_label.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.add_child(_pause_label)

	# RESUME button
	_resume_button = _create_overlay_button("RESUME", Vector2(210, 500), Color(0.1, 0.6, 0.2, 0.85))
	_resume_button.pressed.connect(_on_resume_pressed)
	_pause_overlay.add_child(_resume_button)

	# RESTART button
	_restart_pause_button = _create_overlay_button("RESTART", Vector2(210, 590), Color(0.7, 0.4, 0.05, 0.85))
	_restart_pause_button.pressed.connect(_on_restart_pressed)
	_pause_overlay.add_child(_restart_pause_button)

	# MENU button
	_menu_pause_button = _create_overlay_button("MENU", Vector2(210, 680), Color(0.15, 0.3, 0.7, 0.85))
	_menu_pause_button.pressed.connect(_on_menu_pressed)
	_pause_overlay.add_child(_menu_pause_button)


func _create_overlay_button(text: String, pos: Vector2, bg_colour: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(300, 70)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var style = StyleBoxFlat.new()
	style.bg_color = bg_colour
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_color = Color(1.0, 1.0, 1.0, 0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = bg_colour * 1.3
	hover.bg_color.a = 0.95
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	return btn


# =========================================================================
#  FINISH PANEL BUTTONS (added inside the existing FinishPanel)
# =========================================================================

func _build_finish_buttons() -> void:
	# Best time label (goes inside the finish panel)
	_best_time_label = Label.new()
	_best_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_time_label.add_theme_font_size_override("font_size", 24)
	_best_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finish_panel.add_child(_best_time_label)

	# We need a VBox inside the finish panel for layout.
	# The panel already has FinishTimeLabel. We'll add buttons below.
	# Since PanelContainer only supports one child, we restructure:
	# Remove FinishTimeLabel from panel, create a VBox, put everything in it.
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS

	# Reparent existing label
	finish_time_label.get_parent().remove_child(finish_time_label)
	vbox.add_child(finish_time_label)

	# Reparent best time label
	_best_time_label.get_parent().remove_child(_best_time_label)
	vbox.add_child(_best_time_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# RESTART button (green)
	_restart_finish_button = Button.new()
	_restart_finish_button.text = "RESTART"
	_restart_finish_button.custom_minimum_size = Vector2(280, 60)
	_restart_finish_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_restart_finish_button.process_mode = Node.PROCESS_MODE_ALWAYS

	var restart_style = StyleBoxFlat.new()
	restart_style.bg_color = Color(0.1, 0.6, 0.2, 0.9)
	restart_style.corner_radius_top_left = 10
	restart_style.corner_radius_top_right = 10
	restart_style.corner_radius_bottom_left = 10
	restart_style.corner_radius_bottom_right = 10
	restart_style.border_color = Color(0.3, 1.0, 0.4, 0.8)
	restart_style.border_width_left = 2
	restart_style.border_width_right = 2
	restart_style.border_width_top = 2
	restart_style.border_width_bottom = 2
	_restart_finish_button.add_theme_stylebox_override("normal", restart_style)
	var restart_hover = restart_style.duplicate()
	restart_hover.bg_color = Color(0.15, 0.75, 0.3, 0.95)
	_restart_finish_button.add_theme_stylebox_override("hover", restart_hover)
	_restart_finish_button.add_theme_stylebox_override("pressed", restart_hover)
	_restart_finish_button.add_theme_font_size_override("font_size", 26)
	_restart_finish_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_restart_finish_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(_restart_finish_button)

	# Small spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer2)

	# MENU button (blue)
	_menu_finish_button = Button.new()
	_menu_finish_button.text = "MENU"
	_menu_finish_button.custom_minimum_size = Vector2(280, 60)
	_menu_finish_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_finish_button.process_mode = Node.PROCESS_MODE_ALWAYS

	var menu_style = StyleBoxFlat.new()
	menu_style.bg_color = Color(0.15, 0.3, 0.7, 0.9)
	menu_style.corner_radius_top_left = 10
	menu_style.corner_radius_top_right = 10
	menu_style.corner_radius_bottom_left = 10
	menu_style.corner_radius_bottom_right = 10
	menu_style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	menu_style.border_width_left = 2
	menu_style.border_width_right = 2
	menu_style.border_width_top = 2
	menu_style.border_width_bottom = 2
	_menu_finish_button.add_theme_stylebox_override("normal", menu_style)
	var menu_hover = menu_style.duplicate()
	menu_hover.bg_color = Color(0.2, 0.4, 0.85, 0.95)
	_menu_finish_button.add_theme_stylebox_override("hover", menu_hover)
	_menu_finish_button.add_theme_stylebox_override("pressed", menu_hover)
	_menu_finish_button.add_theme_font_size_override("font_size", 26)
	_menu_finish_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_menu_finish_button.pressed.connect(_on_menu_pressed)
	vbox.add_child(_menu_finish_button)

	finish_panel.add_child(vbox)


# =========================================================================
#  PAUSE / RESUME
# =========================================================================

func _on_pause_pressed() -> void:
	toggle_pause()


func _on_resume_pressed() -> void:
	toggle_pause()


func toggle_pause() -> void:
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	_pause_overlay.visible = _is_paused
	_pause_button.visible = not _is_paused


func _on_restart_pressed() -> void:
	# Unpause first in case we're paused
	if _is_paused:
		get_tree().paused = false
		_is_paused = false
	restart_pressed.emit()


func _on_menu_pressed() -> void:
	if _is_paused:
		get_tree().paused = false
		_is_paused = false
	menu_pressed.emit()


func hide_pause_button() -> void:
	if _pause_button:
		_pause_button.visible = false


func show_pause_button() -> void:
	if _pause_button and not _is_paused:
		_pause_button.visible = true


func _style_action_buttons() -> void:
	# Fire button: orange/red theme
	var fire_style = StyleBoxFlat.new()
	fire_style.bg_color = Color(0.8, 0.3, 0.05, 0.7)
	fire_style.corner_radius_top_left = 12
	fire_style.corner_radius_top_right = 12
	fire_style.corner_radius_bottom_left = 12
	fire_style.corner_radius_bottom_right = 12
	fire_style.border_color = Color(1.0, 0.5, 0.1, 0.9)
	fire_style.border_width_left = 2
	fire_style.border_width_right = 2
	fire_style.border_width_top = 2
	fire_style.border_width_bottom = 2
	fire_button.add_theme_stylebox_override("normal", fire_style)

	var fire_hover = fire_style.duplicate()
	fire_hover.bg_color = Color(1.0, 0.4, 0.1, 0.85)
	fire_button.add_theme_stylebox_override("hover", fire_hover)
	fire_button.add_theme_stylebox_override("pressed", fire_hover)

	fire_button.add_theme_font_size_override("font_size", 22)
	fire_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))

	# Shield button: blue theme
	var shield_style = StyleBoxFlat.new()
	shield_style.bg_color = Color(0.1, 0.3, 0.7, 0.7)
	shield_style.corner_radius_top_left = 12
	shield_style.corner_radius_top_right = 12
	shield_style.corner_radius_bottom_left = 12
	shield_style.corner_radius_bottom_right = 12
	shield_style.border_color = Color(0.3, 0.6, 1.0, 0.9)
	shield_style.border_width_left = 2
	shield_style.border_width_right = 2
	shield_style.border_width_top = 2
	shield_style.border_width_bottom = 2
	shield_button.add_theme_stylebox_override("normal", shield_style)

	var shield_hover = shield_style.duplicate()
	shield_hover.bg_color = Color(0.15, 0.4, 0.9, 0.85)
	shield_button.add_theme_stylebox_override("hover", shield_hover)
	shield_button.add_theme_stylebox_override("pressed", shield_hover)

	shield_button.add_theme_font_size_override("font_size", 22)
	shield_button.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))


func _on_fire_pressed() -> void:
	fire_pressed.emit()


func _on_shield_pressed() -> void:
	shield_pressed.emit()


# --- Speed ---
func update_speed(speed: float, ratio: float) -> void:
	speed_label.text = "%d" % int(speed)
	speed_bar.value = ratio * 100.0
	if ratio > 0.3:
		var t = clampf((ratio - 0.3) / 0.7, 0.0, 1.0)
		speed_bar.modulate = Color(0.3, 0.7, 1.0, 1.0).lerp(Color(1.0, 0.3, 0.2, 1.0), t)
	else:
		speed_bar.modulate = Color(0.3, 0.7, 1.0, 1.0)


# --- Progress ---
func update_progress(ratio: float) -> void:
	progress_label.text = "%d%%" % int(ratio * 100)


# --- Time ---
func update_time(seconds: float) -> void:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	var ms = int((seconds - floorf(seconds)) * 100)
	time_label.text = "%d:%02d.%02d" % [mins, secs, ms]


# --- Chain ---
func update_chain(chain_count: int, multiplier: float) -> void:
	if chain_count > 0:
		chain_label.visible = true
		chain_label.text = "CHAIN x%d" % chain_count
		multiplier_label.visible = true
		multiplier_label.text = "%.0f%% BOOST" % ((multiplier - 1.0) * 100.0)
		var t = clampf(float(chain_count) / 10.0, 0.0, 1.0)
		var chain_colour = Color(0.2, 1.0, 0.4, 0.9).lerp(Color(1.0, 0.9, 0.1, 1.0), t)
		chain_label.modulate = chain_colour
		multiplier_label.modulate = chain_colour
	else:
		chain_label.visible = false
		multiplier_label.visible = false


# --- Fire cooldown ---
func update_fire_cooldown(ratio: float) -> void:
	# ratio is 0 = ready, 1 = just fired
	if ratio > 0.01:
		fire_button.text = "FIRE\n%.1f" % (ratio * 2.0)  # Show remaining seconds
		fire_button.modulate = Color(0.5, 0.5, 0.5, 0.6)
	else:
		fire_button.text = "FIRE"
		fire_button.modulate = Color(1.0, 1.0, 1.0, 1.0)


# --- Shield charges ---
func update_shield_charges(charges: int, active: bool) -> void:
	shield_charge_label.text = "x%d" % charges

	if active:
		shield_button.text = "SHIELD\nACTIVE"
		shield_button.modulate = Color(0.5, 1.0, 1.5, 1.0)  # Bright glow
	elif charges > 0:
		shield_button.text = "SHIELD"
		shield_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		shield_button.text = "SHIELD"
		shield_button.modulate = Color(0.4, 0.4, 0.4, 0.5)


func show_shield_active(active: bool) -> void:
	# Visual feedback handled by update_shield_charges in the main loop
	pass


# --- Drift charge indicator ---
func update_drift(charge: float, max_charge: float, active: bool) -> void:
	if not active or charge < 1.0:
		drift_label.visible = false
		return

	drift_label.visible = true
	var ratio = charge / maxf(max_charge, 1.0)
	var bars = int(ratio * 10.0)
	drift_label.text = "DRIFT " + "|".repeat(bars)

	# Colour shifts from cyan to white as charge builds
	var t = clampf(ratio, 0.0, 1.0)
	drift_label.modulate = Color(0.2 + t * 0.8, 0.8 + t * 0.2, 1.0, 0.7 + t * 0.3)

	# Pulse scale slightly
	drift_label.scale = Vector2(1.0 + t * 0.15, 1.0 + t * 0.15)


# --- Racing line quality ---
func update_racing_line(bonus: float) -> void:
	# bonus ranges from roughly -0.2 (bad line) to +0.12 (perfect apex)
	if absf(bonus) < 0.01:
		line_label.visible = false
		return

	line_label.visible = true
	if bonus > 0.02:
		# Good line — green, show bonus
		var pct = int(bonus * 100.0)
		line_label.text = "APEX +%d%%" % pct
		var intensity = clampf(bonus / 0.12, 0.0, 1.0)
		line_label.modulate = Color(0.2, 1.0, 0.3, 0.5 + intensity * 0.5)
	else:
		# Bad line — amber/red, show penalty
		var pct = int(absf(bonus) * 100.0)
		line_label.text = "DRAG -%d%%" % pct
		var intensity = clampf(absf(bonus) / 0.15, 0.0, 1.0)
		line_label.modulate = Color(1.0, 0.5 - intensity * 0.3, 0.1, 0.5 + intensity * 0.4)


# --- Ring collection flash ---
func show_ring_collect(chain: int, value: int) -> void:
	if value == 2:
		show_flash("+SURGE!", Color(0.1, 0.85, 1.0, 1.0))
	else:
		show_flash("+BOOST", Color(0.2, 1.0, 0.3, 1.0))


# --- Hazard hit flash ---
func show_hazard_hit() -> void:
	show_flash("HIT!", Color(1.0, 0.2, 0.1, 1.0))
	_flash_screen_red()


# --- Generic flash text ---
func show_flash(text: String, colour: Color) -> void:
	flash_label.visible = true
	flash_label.text = text
	flash_label.modulate = colour
	flash_label.scale = Vector2(1.5, 1.5)

	var tween = create_tween()
	tween.tween_property(flash_label, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): flash_label.visible = false)


# --- Countdown ---
func show_countdown(count: int) -> void:
	current_countdown = count
	countdown_label.visible = true
	countdown_label.text = str(count)
	countdown_label.modulate = Color(1, 1, 1, 1)
	var tween = create_tween()
	countdown_label.scale = Vector2(2.0, 2.0)
	tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Hide pause button during countdown
	hide_pause_button()


func show_countdown_go() -> void:
	current_countdown = 0
	countdown_label.visible = true
	countdown_label.text = "GO!"
	countdown_label.modulate = Color(0.2, 1.0, 0.3, 1.0)
	var tween = create_tween()
	countdown_label.scale = Vector2(2.5, 2.5)
	tween.tween_property(countdown_label, "scale", Vector2(1.5, 1.5), 0.3) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(countdown_label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func():
		countdown_label.visible = false
		show_pause_button()
	)


# --- Screen red flash on hit ---
func _flash_screen_red() -> void:
	# Create a temporary full-screen red overlay that flashes and fades
	var overlay = ColorRect.new()
	overlay.color = Color(1.0, 0.05, 0.0, 0.35)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.0, 0.4) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): overlay.queue_free())


# --- Finish ---
func show_finish(time: float) -> void:
	var mins = int(time) / 60
	var secs = int(time) % 60
	var ms = int((time - floorf(time)) * 100)
	finish_time_label.text = "FINISH!\n%d:%02d.%02d" % [mins, secs, ms]

	# Best time comparison
	var best = GameSettings.get_best_time()
	if best < 0.0:
		_best_time_label.text = "NEW BEST!"
		_best_time_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
	elif time < best:
		_best_time_label.text = "NEW BEST! (was %s)" % GameSettings.format_time(best)
		_best_time_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
	else:
		_best_time_label.text = "BEST: %s" % GameSettings.format_time(best)
		_best_time_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 0.8))

	finish_panel.visible = true
	finish_panel.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(finish_panel, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT)

	# Hide pause button after finish
	hide_pause_button()
