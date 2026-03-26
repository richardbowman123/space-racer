extends Node
## Autoloaded singleton: difficulty parameters, track selection, best-time persistence.

enum Difficulty { EASY, NORMAL, HARD }

var current_difficulty: int = Difficulty.NORMAL
var current_track: String = "kessel_stretch"

const PARAMS := {
	Difficulty.EASY: {
		"base_speed": 45.0,
		"max_speed": 180.0,
		"max_offset": 16.0,
		"steer_smooth": 14.0,
	},
	Difficulty.NORMAL: {
		"base_speed": 50.0,
		"max_speed": 220.0,
		"max_offset": 14.0,
		"steer_smooth": 12.0,
	},
	Difficulty.HARD: {
		"base_speed": 60.0,
		"max_speed": 260.0,
		"max_offset": 12.0,
		"steer_smooth": 10.0,
	},
}

const DIFFICULTY_NAMES := {
	Difficulty.EASY: "EASY",
	Difficulty.NORMAL: "NORMAL",
	Difficulty.HARD: "HARD",
}

var _config_path := "user://space_racer_settings.cfg"
var _config := ConfigFile.new()


func _ready() -> void:
	_config.load(_config_path)


func get_params() -> Dictionary:
	return PARAMS[current_difficulty]


func get_best_time() -> float:
	## Returns best time for current track + difficulty, or -1.0 if none saved.
	var key = current_track + "_" + DIFFICULTY_NAMES[current_difficulty]
	return _config.get_value("best_times", key, -1.0)


func save_best_time(time: float) -> void:
	var key = current_track + "_" + DIFFICULTY_NAMES[current_difficulty]
	var existing = _config.get_value("best_times", key, -1.0)
	if existing < 0.0 or time < existing:
		_config.set_value("best_times", key, time)
		_config.save(_config_path)


func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "---"
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	var ms = int((seconds - floorf(seconds)) * 100)
	return "%d:%02d.%02d" % [mins, secs, ms]
