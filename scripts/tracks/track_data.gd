class_name TrackData
## Static track definitions: curve points, theme colours, parameters.
## Each track is a dictionary with name, subtitle, points, theme, and tuning values.

const TRACK_ORDER := ["kessel_stretch", "neon_city", "coral_nebula", "graveyard_shift"]

static func get_track(track_id: String) -> Dictionary:
	return TRACKS[track_id]

static func get_track_name(track_id: String) -> String:
	return TRACKS[track_id]["name"]

static func get_track_subtitle(track_id: String) -> String:
	return TRACKS[track_id]["subtitle"]


# =========================================================================
#  TRACK DEFINITIONS
# =========================================================================

const TRACKS := {

	# -----------------------------------------------------------------
	#  THE KESSEL STRETCH — the original test track
	# -----------------------------------------------------------------
	"kessel_stretch": {
		"name": "THE KESSEL STRETCH",
		"subtitle": "Tunnel Run",
		"track_width": 42.0,
		"tube_radius": 24.0,
		"ring_spacing": 45.0,
		"hazard_count": 18,
		"ring_seed": 123,
		"hazard_seed": 77,
		"theme": {
			"ribbon_albedo": Color(0.08, 0.15, 0.4, 0.3),
			"ribbon_emission": Color(0.08, 0.15, 0.5, 1.0),
			"ribbon_emission_energy": 0.5,
			"edge_albedo": Color(0.3, 0.5, 1.0, 0.8),
			"edge_emission": Color(0.3, 0.5, 1.0, 1.0),
			"edge_emission_energy": 2.0,
			"wire_albedo": Color(0.25, 0.45, 0.9, 0.35),
			"wire_emission": Color(0.2, 0.4, 0.8, 1.0),
			"wire_emission_energy": 1.2,
			"wire_long_albedo": Color(0.2, 0.35, 0.75, 0.2),
			"wire_long_emission_energy": 0.8,
			"gate_albedo": Color(0.2, 0.4, 0.8, 0.7),
			"gate_emission": Color(0.2, 0.4, 0.9, 1.0),
			"gate_emission_energy": 1.5,
			"clear_color": Color(0.005, 0.005, 0.02, 1.0),
		},
		"points": [
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
			# Corkscrew 1: right-hand descending spiral (2 revolutions)
			{"pos": Vector3(20, -35, -2140), "tilt": 1.57},
			{"pos": Vector3(0, -55, -2180), "tilt": 3.14},
			{"pos": Vector3(-20, -45, -2220), "tilt": 4.71},
			{"pos": Vector3(0, -30, -2260), "tilt": 6.28},
			{"pos": Vector3(20, -40, -2300), "tilt": 7.85},
			{"pos": Vector3(0, -60, -2340), "tilt": 9.42},
			{"pos": Vector3(-20, -50, -2380), "tilt": 10.99},
			{"pos": Vector3(0, -35, -2420), "tilt": 12.57},
			# Transition
			{"pos": Vector3(0, -35, -2460), "tilt": 12.57},
			# Corkscrew 2: left-hand spiral, unwinding (2 revolutions)
			{"pos": Vector3(-20, -45, -2500), "tilt": 10.99},
			{"pos": Vector3(0, -60, -2540), "tilt": 9.42},
			{"pos": Vector3(20, -50, -2580), "tilt": 7.85},
			{"pos": Vector3(0, -35, -2620), "tilt": 6.28},
			{"pos": Vector3(-20, -45, -2660), "tilt": 4.71},
			{"pos": Vector3(0, -60, -2700), "tilt": 3.14},
			{"pos": Vector3(20, -50, -2740), "tilt": 1.57},
			{"pos": Vector3(0, -35, -2780), "tilt": 0.0},
			# Home straight
			{"pos": Vector3(0, -30, -2840), "tilt": 0.0},
			{"pos": Vector3(0, -25, -2940), "tilt": 0.0},
		],
	},

	# -----------------------------------------------------------------
	#  NEON CITY — tight, bright, cyberpunk street racing
	# -----------------------------------------------------------------
	"neon_city": {
		"name": "NEON CITY",
		"subtitle": "Orbital Station",
		"track_width": 36.0,
		"tube_radius": 21.0,
		"ring_spacing": 35.0,
		"hazard_count": 22,
		"ring_seed": 456,
		"hazard_seed": 88,
		"theme": {
			"ribbon_albedo": Color(0.4, 0.05, 0.3, 0.35),
			"ribbon_emission": Color(0.5, 0.05, 0.35, 1.0),
			"ribbon_emission_energy": 0.7,
			"edge_albedo": Color(0.0, 1.0, 0.8, 0.9),
			"edge_emission": Color(0.0, 1.0, 0.85, 1.0),
			"edge_emission_energy": 2.5,
			"wire_albedo": Color(0.9, 0.3, 0.5, 0.3),
			"wire_emission": Color(0.85, 0.25, 0.45, 1.0),
			"wire_emission_energy": 1.5,
			"wire_long_albedo": Color(0.7, 0.2, 0.4, 0.15),
			"wire_long_emission_energy": 0.9,
			"gate_albedo": Color(0.0, 1.0, 0.3, 0.8),
			"gate_emission": Color(0.0, 1.0, 0.35, 1.0),
			"gate_emission_energy": 2.0,
			"clear_color": Color(0.02, 0.005, 0.03, 1.0),
		},
		"points": [
			# Start — gentle intro into the city
			{"pos": Vector3(0, 0, 0), "tilt": 0.0},
			{"pos": Vector3(0, 0, -80), "tilt": 0.0},
			# Sharp right — entering the station
			{"pos": Vector3(45, 0, -160), "tilt": 0.35},
			{"pos": Vector3(60, 0, -260), "tilt": 0.0},
			# Sharp left — market corridor
			{"pos": Vector3(-10, 0, -380), "tilt": -0.4},
			{"pos": Vector3(-30, 5, -460), "tilt": 0.0},
			# Rise up to the rooftops
			{"pos": Vector3(0, 25, -560), "tilt": 0.15},
			{"pos": Vector3(0, 40, -700), "tilt": 0.0},
			# THE BIG DROP — ventilation shaft plunge
			{"pos": Vector3(0, 35, -760), "tilt": 0.0},
			{"pos": Vector3(0, -40, -840), "tilt": 0.0},
			{"pos": Vector3(0, -100, -920), "tilt": 0.0},
			{"pos": Vector3(0, -130, -980), "tilt": 0.0},
			# Pull out of the drop, sweeping right
			{"pos": Vector3(25, -125, -1060), "tilt": 0.4},
			{"pos": Vector3(0, -120, -1140), "tilt": 0.0},
			# Tight S-curves — market corridors
			{"pos": Vector3(-35, -115, -1220), "tilt": -0.35},
			{"pos": Vector3(30, -110, -1300), "tilt": 0.35},
			{"pos": Vector3(-30, -108, -1380), "tilt": -0.35},
			{"pos": Vector3(25, -105, -1460), "tilt": 0.3},
			# Right-angle sequence — station corridors
			{"pos": Vector3(55, -102, -1540), "tilt": 0.5},
			{"pos": Vector3(55, -100, -1640), "tilt": 0.0},
			{"pos": Vector3(-25, -100, -1720), "tilt": -0.5},
			{"pos": Vector3(-25, -98, -1800), "tilt": 0.0},
			{"pos": Vector3(35, -95, -1880), "tilt": 0.4},
			# Speed straight — neon billboard canyon
			{"pos": Vector3(0, -92, -1960), "tilt": 0.0},
			{"pos": Vector3(0, -88, -2140), "tilt": 0.0},
			# Final chicane
			{"pos": Vector3(-25, -86, -2200), "tilt": -0.2},
			{"pos": Vector3(20, -84, -2260), "tilt": 0.2},
			{"pos": Vector3(-15, -83, -2320), "tilt": -0.15},
			# Finish
			{"pos": Vector3(0, -82, -2380), "tilt": 0.0},
			{"pos": Vector3(0, -80, -2460), "tilt": 0.0},
		],
	},

	# -----------------------------------------------------------------
	#  CORAL NEBULA — wide, flowing, beautiful
	# -----------------------------------------------------------------
	"coral_nebula": {
		"name": "CORAL NEBULA",
		"subtitle": "The Scenic Route",
		"track_width": 48.0,
		"tube_radius": 30.0,
		"ring_spacing": 55.0,
		"hazard_count": 12,
		"ring_seed": 789,
		"hazard_seed": 66,
		"theme": {
			"ribbon_albedo": Color(0.3, 0.08, 0.2, 0.25),
			"ribbon_emission": Color(0.35, 0.08, 0.25, 1.0),
			"ribbon_emission_energy": 0.4,
			"edge_albedo": Color(0.2, 0.8, 0.7, 0.7),
			"edge_emission": Color(0.2, 0.85, 0.75, 1.0),
			"edge_emission_energy": 1.8,
			"wire_albedo": Color(0.5, 0.3, 0.7, 0.25),
			"wire_emission": Color(0.45, 0.25, 0.65, 1.0),
			"wire_emission_energy": 1.0,
			"wire_long_albedo": Color(0.4, 0.2, 0.55, 0.12),
			"wire_long_emission_energy": 0.6,
			"gate_albedo": Color(0.9, 0.3, 0.5, 0.6),
			"gate_emission": Color(0.85, 0.3, 0.5, 1.0),
			"gate_emission_energy": 1.2,
			"clear_color": Color(0.01, 0.005, 0.02, 1.0),
		},
		"points": [
			# Gentle start
			{"pos": Vector3(0, 0, 0), "tilt": 0.0},
			{"pos": Vector3(0, 0, -120), "tilt": 0.0},
			# Wide right sweep — entering the nebula
			{"pos": Vector3(30, 5, -280), "tilt": 0.1},
			{"pos": Vector3(50, 10, -440), "tilt": 0.15},
			{"pos": Vector3(30, 5, -600), "tilt": 0.05},
			# Gentle left sweep with rise
			{"pos": Vector3(-20, 15, -760), "tilt": -0.1},
			{"pos": Vector3(-40, 25, -920), "tilt": -0.12},
			{"pos": Vector3(-15, 30, -1080), "tilt": -0.05},
			# Undulating descent through gas clouds
			{"pos": Vector3(10, 20, -1240), "tilt": 0.08},
			{"pos": Vector3(0, 5, -1400), "tilt": 0.0},
			{"pos": Vector3(-10, -10, -1560), "tilt": -0.06},
			{"pos": Vector3(0, -20, -1720), "tilt": 0.04},
			# Wide graceful spiral (1.5 turns, gentle banking)
			{"pos": Vector3(25, -25, -1820), "tilt": 0.6},
			{"pos": Vector3(0, -40, -1920), "tilt": 1.2},
			{"pos": Vector3(-25, -35, -2020), "tilt": 1.8},
			{"pos": Vector3(0, -25, -2120), "tilt": 2.4},
			{"pos": Vector3(25, -30, -2220), "tilt": 3.0},
			{"pos": Vector3(0, -45, -2320), "tilt": 3.6},
			{"pos": Vector3(-25, -40, -2420), "tilt": 4.2},
			{"pos": Vector3(0, -30, -2520), "tilt": 4.71},
			# Unwind gracefully
			{"pos": Vector3(0, -30, -2620), "tilt": 3.14},
			{"pos": Vector3(0, -28, -2720), "tilt": 1.57},
			{"pos": Vector3(0, -25, -2820), "tilt": 0.0},
			# Final flowing curves
			{"pos": Vector3(20, -22, -2920), "tilt": 0.08},
			{"pos": Vector3(-15, -20, -3060), "tilt": -0.06},
			{"pos": Vector3(0, -18, -3200), "tilt": 0.0},
			# Home straight
			{"pos": Vector3(0, -15, -3300), "tilt": 0.0},
			{"pos": Vector3(0, -12, -3400), "tilt": 0.0},
		],
	},

	# -----------------------------------------------------------------
	#  THE GRAVEYARD SHIFT — dark, atmospheric, tense
	# -----------------------------------------------------------------
	"graveyard_shift": {
		"name": "THE GRAVEYARD SHIFT",
		"subtitle": "Ship Graveyard",
		"track_width": 42.0,
		"tube_radius": 24.0,
		"ring_spacing": 50.0,
		"hazard_count": 20,
		"ring_seed": 321,
		"hazard_seed": 44,
		"theme": {
			"ribbon_albedo": Color(0.08, 0.12, 0.08, 0.2),
			"ribbon_emission": Color(0.06, 0.12, 0.06, 1.0),
			"ribbon_emission_energy": 0.3,
			"edge_albedo": Color(0.7, 0.4, 0.1, 0.5),
			"edge_emission": Color(0.7, 0.4, 0.1, 1.0),
			"edge_emission_energy": 1.4,
			"wire_albedo": Color(0.2, 0.25, 0.2, 0.15),
			"wire_emission": Color(0.15, 0.2, 0.15, 1.0),
			"wire_emission_energy": 0.6,
			"wire_long_albedo": Color(0.12, 0.15, 0.12, 0.08),
			"wire_long_emission_energy": 0.3,
			"gate_albedo": Color(0.6, 0.35, 0.1, 0.5),
			"gate_emission": Color(0.6, 0.35, 0.1, 1.0),
			"gate_emission_energy": 1.0,
			"clear_color": Color(0.005, 0.008, 0.005, 1.0),
		},
		"points": [
			# Slow start — drifting into the graveyard
			{"pos": Vector3(0, 0, 0), "tilt": 0.0},
			{"pos": Vector3(0, 0, -100), "tilt": 0.0},
			# Long eerie straight (builds tension — nothing happens)
			{"pos": Vector3(0, -2, -300), "tilt": 0.0},
			{"pos": Vector3(0, -5, -500), "tilt": 0.0},
			# SUDDEN sharp left — debris field entry
			{"pos": Vector3(-40, -8, -600), "tilt": -0.3},
			{"pos": Vector3(-50, -10, -680), "tilt": -0.2},
			# Quick right correction
			{"pos": Vector3(10, -8, -780), "tilt": 0.25},
			{"pos": Vector3(30, -5, -860), "tilt": 0.15},
			# Tight weaving section (through wreckage)
			{"pos": Vector3(-25, -10, -940), "tilt": -0.3},
			{"pos": Vector3(20, -15, -1020), "tilt": 0.35},
			{"pos": Vector3(-30, -20, -1100), "tilt": -0.4},
			{"pos": Vector3(25, -18, -1180), "tilt": 0.3},
			{"pos": Vector3(0, -15, -1260), "tilt": 0.0},
			# Second long straight (inside a dead ship's corridor)
			{"pos": Vector3(0, -15, -1400), "tilt": 0.0},
			{"pos": Vector3(5, -12, -1600), "tilt": 0.0},
			# Descending banking turns (around a wrecked capital ship)
			{"pos": Vector3(35, -25, -1700), "tilt": 0.25},
			{"pos": Vector3(50, -40, -1800), "tilt": 0.35},
			{"pos": Vector3(30, -55, -1900), "tilt": 0.15},
			{"pos": Vector3(-10, -65, -2000), "tilt": -0.2},
			{"pos": Vector3(-35, -60, -2100), "tilt": -0.3},
			{"pos": Vector3(-15, -50, -2200), "tilt": -0.1},
			# Corkscrew through debris (1 revolution)
			{"pos": Vector3(20, -55, -2280), "tilt": 1.57},
			{"pos": Vector3(0, -70, -2360), "tilt": 3.14},
			{"pos": Vector3(-20, -60, -2440), "tilt": 4.71},
			{"pos": Vector3(0, -50, -2520), "tilt": 6.28},
			# Unwind
			{"pos": Vector3(0, -48, -2580), "tilt": 4.71},
			{"pos": Vector3(0, -46, -2640), "tilt": 3.14},
			{"pos": Vector3(0, -44, -2700), "tilt": 1.57},
			{"pos": Vector3(0, -42, -2740), "tilt": 0.0},
			# Home straight — escape the graveyard
			{"pos": Vector3(0, -40, -2800), "tilt": 0.0},
			{"pos": Vector3(0, -38, -2880), "tilt": 0.0},
		],
	},
}
