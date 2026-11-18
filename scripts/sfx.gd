extends Node

## Sound manager (autoload "Sfx").
## - play("name") fires a one-shot effect from res://audio/sfx/name.wav
## - start_loop / stop_loop drive the ball-movement sounds while power-ups are active
## - voice("key") plays a recorded voice line from res://audio/voice/ if you add one,
##   otherwise it falls back to a jingle (fanfare, applause, whistle...)

const SFX_DIR := "res://audio/sfx/"
const VOICE_DIR := "res://audio/voice/"

const NAMES := [
	"stretch", "launch", "bounce", "ring_hit", "drum_hit", "jackpot", "barrier_hit",
	"smash", "collect_speed", "collect_smash", "collect_multi", "collect_coins",
	"cheer_small", "cheer_big", "applause", "motivate", "run_end", "buy", "click", "error",
	"loop_speed", "loop_smash", "loop_multi",
]
const LOOPS := ["loop_speed", "loop_smash", "loop_multi"]

## Voice line keys -> jingle used when no recording exists for that key.
const VOICE_FALLBACK := {
	"launch": "",
	"powerup": "",
	"smash": "",
	"combo": "cheer_small",
	"milestone": "cheer_small",
	"jackpot": "applause",
	"motivate": "motivate",
	"best": "cheer_big",
	"end": "run_end",
}

var streams: Dictionary = {}
var pool: Array = []
var loops: Dictionary = {}
var loop_tweens: Dictionary = {}
var last_play: Dictionary = {}
var voices: Dictionary = {}
var voice_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path: String = SFX_DIR + n + ".wav"
		if ResourceLoader.exists(path):
			streams[n] = load(path)
		else:
			push_warning("Missing sound: " + path)

	for i in 24:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		pool.append(pl)

	for n in LOOPS:
		if not streams.has(n):
			continue
		var s = streams[n]
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		var lp := AudioStreamPlayer.new()
		lp.stream = s
		lp.volume_db = -40.0
		add_child(lp)
		loops[n] = lp

	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = 2.0
	add_child(voice_player)
	for key in VOICE_FALLBACK.keys():
		var found: Array = []
		for i in range(1, 10):
			for ext in ["wav", "ogg", "mp3"]:
				var vp: String = "%s%s_%d.%s" % [VOICE_DIR, key, i, ext]
				if ResourceLoader.exists(vp):
					found.append(load(vp))
		voices[key] = found


func play(n: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not streams.has(n):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(last_play.get(n, -1000)) < 35:
		return
	last_play[n] = now
	var target: AudioStreamPlayer = null
	for pl in pool:
		if not pl.playing:
			target = pl
			break
	if target == null:
		target = pool[0]
		pool.push_back(pool.pop_front())
	target.stream = streams[n]
	target.pitch_scale = clampf(pitch, 0.25, 4.0)
	target.volume_db = vol_db
	target.play()


func voice(key: String) -> void:
	var lines: Array = voices.get(key, [])
	if lines.size() > 0:
		voice_player.stream = lines.pick_random()
		voice_player.play()
		return
	var fallback: String = VOICE_FALLBACK.get(key, "")
	if fallback != "":
		play(fallback)


# --- Looping movement sounds -----------------------------------------------

func start_loop(n: String, vol_db: float = -7.0) -> void:
	if not loops.has(n):
		return
	var pl: AudioStreamPlayer = loops[n]
	_kill_tween(n)
	if not pl.playing:
		pl.volume_db = -30.0
		pl.play()
	var tw := create_tween()
	tw.tween_property(pl, "volume_db", vol_db, 0.2)
	loop_tweens[n] = tw


func stop_loop(n: String) -> void:
	if not loops.has(n):
		return
	var pl: AudioStreamPlayer = loops[n]
	if not pl.playing:
		return
	_kill_tween(n)
	var tw := create_tween()
	tw.tween_property(pl, "volume_db", -40.0, 0.3)
	tw.tween_callback(pl.stop)
	loop_tweens[n] = tw


func set_loop_pitch(n: String, pitch: float) -> void:
	if loops.has(n):
		var pl: AudioStreamPlayer = loops[n]
		pl.pitch_scale = clampf(pitch, 0.3, 3.0)


func stop_all_loops() -> void:
	for n in loops.keys():
		stop_loop(n)


func _kill_tween(n: String) -> void:
	if loop_tweens.has(n):
		var tw = loop_tweens[n]
		if tw is Tween and tw.is_valid():
			tw.kill()
		loop_tweens.erase(n)
