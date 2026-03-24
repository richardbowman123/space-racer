extends Node
class_name GameSettings
## Autoloaded singleton: difficulty parameters, best-time persistence.

enum Difficulty { EASY, NORMAL, HARD }

var current_difficulty: int = Difficulty.NORMAL

const PARAMS := {
	Difficulty.EASY: {
		"base_speed": 55.0,
		"max_speed": 130.0,
		"centrifugal_strength": 25.0,
		"centre_pull": 1.8,
		"max_offset": 16.0,
		"steer_smooth": 18.0,
	},
	Difficulty.NORMAL: {
		"base_speed": 70.0,
		"max_speed": 160.0,
		"centrifugal_strength": 40.0,
		"centre_pull": 1.0,
		"max_offset": 14.0,
		"steer_smooth": 16.0,
	},
	Difficulty.HARD: {
		"base_speed": 85.0,
		"max_speed": 190.0,
		"centrifugal_strength": 55.0,
		"centre_pull": 0.6,
		"max_offset": 12.0,
		"steer_smooth": 14.0,
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
	## Returns best time for current difficulty, or -1.0 if none saved.
	var key = DIFFICULTY_NAMES[current_difficulty]
	return _config.get_value("best_times", key, -1.0)


func save_best_time(time: float) -> void:
	var key = DIFFICULTY_NAMES[current_difficulty]
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
