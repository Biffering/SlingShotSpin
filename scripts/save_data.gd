extends Node

## Persistent progress: banked points, best score and upgrade levels.
## Saved to user://save.json so everything carries over between sessions.

const PATH := "user://save.json"

const UPGRADES := [
	{"id": "launch", "name": "Launch Power", "desc": "The slingshot fires the ball harder.", "base": 100, "max": 10},
	{"id": "endurance", "name": "Endurance", "desc": "The ball slows down more gradually, so runs last longer.", "base": 150, "max": 10},
	{"id": "value", "name": "Point Value", "desc": "+15% points from everything you hit.", "base": 200, "max": 10},
	{"id": "smash", "name": "Smash Strength", "desc": "Smash emblems roll higher levels (up to Smash 5).", "base": 175, "max": 8},
	{"id": "luck", "name": "Emblem Luck", "desc": "+1 power-up emblem in the arena each run.", "base": 250, "max": 6},
	{"id": "duration", "name": "Power Duration", "desc": "Speed and Double Points last 15% longer.", "base": 150, "max": 10},
	{"id": "pep", "name": "Pep Talks", "desc": "+1 motivational push when the ball runs out of steam.", "base": 300, "max": 4},
]

var bank: int = 0
var best: int = 0
var runs: int = 0
var levels: Dictionary = {}


func _ready() -> void:
	load_game()


# --- Upgrade bookkeeping -------------------------------------------------

func get_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


func lvl(id: String) -> int:
	return int(levels.get(id, 0))


func max_lvl(id: String) -> int:
	return int(get_def(id).get("max", 0))


func is_maxed(id: String) -> bool:
	return lvl(id) >= max_lvl(id)


func cost(id: String) -> int:
	return int(float(get_def(id).get("base", 100)) * pow(1.55, lvl(id)))


func buy(id: String) -> bool:
	if is_maxed(id) or bank < cost(id):
		return false
	bank -= cost(id)
	levels[id] = lvl(id) + 1
	save_game()
	return true


# --- What each upgrade actually does ---------------------------------------

func launch_speed() -> float:
	return 1500.0 * (1.0 + 0.08 * lvl("launch"))


func ball_damp() -> float:
	return maxf(0.12, 0.45 - 0.03 * lvl("endurance"))


func point_mult() -> float:
	return 1.0 + 0.15 * lvl("value")


func smash_roll() -> int:
	var s: int = lvl("smash")
	var hi: int = clampi(2 + s / 2, 2, 5)
	var lo: int = clampi(1 + s / 4, 1, hi)
	return randi_range(lo, hi)


func emblem_count() -> int:
	return 4 + lvl("luck")


func boost_time(base_seconds: float) -> float:
	return base_seconds * (1.0 + 0.15 * lvl("duration"))


func pep_talks() -> int:
	return 1 + lvl("pep")


# --- Saving -----------------------------------------------------------------

func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify({"bank": bank, "best": best, "runs": runs, "levels": levels}))


func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	bank = int(data.get("bank", 0))
	best = int(data.get("best", 0))
	runs = int(data.get("runs", 0))
	var lv = data.get("levels", {})
	if typeof(lv) == TYPE_DICTIONARY:
		for k in lv.keys():
			levels[str(k)] = int(lv[k])


func reset_progress() -> void:
	bank = 0
	best = 0
	runs = 0
	levels = {}
	save_game()
