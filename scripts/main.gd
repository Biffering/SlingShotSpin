extends Node2D

## Slingshot Spin - main game flow.
## Builds the arena, runs one launch, tallies points, then opens results / the shop.

const BallScript := preload("res://scripts/ball.gd")
const SlingScript := preload("res://scripts/slingshot.gd")
const RingScript := preload("res://scripts/ring_drum.gd")
const SpinnerScript := preload("res://scripts/spinner.gd")
const BarrierScript := preload("res://scripts/barrier.gd")
const EmblemScript := preload("res://scripts/emblem.gd")
const HudScript := preload("res://scripts/hud.gd")

const W := 720.0
const H := 1280.0
const BORDER := 16.0
const REST := Vector2(360, 1100)
const RING_CENTER := Vector2(360, 470)
const RING_R := 175.0
const MAX_RUN_TIME := 60.0
const BARRIER_COUNT := 9
const MILESTONES := [500, 1000, 2500, 5000, 10000, 25000, 50000, 100000]
const GOLD := Color(1.0, 0.84, 0.25)

const LAUNCH_LINES := ["GO BALL GO!", "FLY, LITTLE BALL!", "LET'S GOOO!", "SEND IT!"]
const PEP_LINES := ["COME ON, BALL!", "DON'T QUIT NOW!", "ONE MORE PUSH!", "YOU GOT THIS, BALL!", "KEEP ROLLING!"]
const SMASH_LINES := ["SMASHING!", "CRUSHED IT!", "BOOM!", "NOTHING CAN STOP YOU!"]
const COMBO_LINES := {6: "NICE COMBO!", 12: "AWESOME!", 20: "UNSTOPPABLE!", 32: "LEGENDARY!!"}

enum State { AIM, FLYING, RESULTS, SHOP }

var state: int = State.AIM
var level: Node2D
var ball
var slingshot
var hud
var cam: Camera2D
var corners: Array = []

var score := 0
var run_time := 0.0
var combo := 0
var last_score_time := -10.0
var clock := 0.0
var pep_left := 0
var pep_cd := 0.0
var milestone_idx := 0
var smash_banner_cd := 0.0
var shake := 0.0


func _ready() -> void:
	add_to_group("game")
	randomize()

	cam = Camera2D.new()
	cam.position = Vector2(W * 0.5, H * 0.5)
	add_child(cam)
	cam.make_current()

	_build_walls()

	hud = HudScript.new()
	add_child(hud)
	hud.launch_pressed.connect(start_run)
	hud.shop_pressed.connect(open_shop)
	hud.buy_pressed.connect(_on_buy)

	start_run()


# --- Run lifecycle ------------------------------------------------------------

func start_run() -> void:
	if level:
		level.queue_free()
	Sfx.stop_all_loops()
	level = Node2D.new()
	add_child(level)

	score = 0
	run_time = 0.0
	combo = 0
	milestone_idx = 0
	pep_left = SaveData.pep_talks()
	pep_cd = 0.0
	smash_banner_cd = 0.0

	_build_level()

	slingshot = SlingScript.new()
	slingshot.rest = REST
	level.add_child(slingshot)

	ball = BallScript.new()
	ball.position = REST
	level.add_child(ball)
	ball.stopped.connect(_end_run)

	slingshot.ball = ball
	slingshot.launched.connect(_on_launched)

	state = State.AIM
	hud.show_play()
	hud.set_score(0)
	hud.set_bank(SaveData.bank)


func _on_launched() -> void:
	state = State.FLYING
	hud.hide_hint()
	Sfx.play("launch")
	hud.show_banner(LAUNCH_LINES.pick_random(), Color(0.5, 1.0, 0.6))
	Sfx.voice("launch")


func _end_run() -> void:
	if state != State.FLYING:
		return
	state = State.RESULTS
	ball.finish()
	hud.set_status("")

	var new_best: bool = score > SaveData.best and score > 0
	SaveData.bank += score
	SaveData.runs += 1
	if new_best:
		SaveData.best = score
	SaveData.save_game()
	hud.set_bank(SaveData.bank)

	await get_tree().create_timer(0.7).timeout
	if state != State.RESULTS:
		return
	if new_best:
		hud.show_banner("NEW BEST!", GOLD)
		Sfx.voice("best")
		Sfx.play("applause", 1.0, -3.0)
	else:
		hud.show_banner("WHAT A SHOT!" if score >= 2000 else "NICE RUN!", Color.WHITE)
		Sfx.voice("end")
	hud.show_results(score, SaveData.bank, SaveData.best, new_best)


func open_shop() -> void:
	state = State.SHOP
	hud.show_shop()


func _on_buy(id: String) -> void:
	if SaveData.buy(id):
		Sfx.play("buy")
		hud.show_banner("UPGRADED!", GOLD)
	else:
		Sfx.play("error")
	hud.set_bank(SaveData.bank)
	hud.refresh_shop()


# --- Per-frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	clock += delta
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 40.0)
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	else:
		cam.offset = Vector2.ZERO

	if state == State.FLYING and ball:
		var parts := PackedStringArray()
		if ball.speed_time > 0.0:
			parts.append("SPEED %.1fs" % ball.speed_time)
		if ball.smash_charges > 0:
			parts.append("SMASH x%d" % ball.smash_charges)
		if ball.multi_time > 0.0:
			parts.append("x2 POINTS %.1fs" % ball.multi_time)
		parts.append("PEP TALKS %d" % pep_left)
		hud.set_status("   |   ".join(parts))


func _physics_process(delta: float) -> void:
	if state != State.FLYING or ball == null:
		return
	run_time += delta
	pep_cd -= delta
	smash_banner_cd -= delta

	var spd: float = ball.linear_velocity.length()
	# When the ball runs out of steam, cheer it on and give it a push.
	if run_time > 1.5 and spd < 230.0 and spd > 5.0 and pep_left > 0 and pep_cd <= 0.0:
		_pep_talk(spd)

	if run_time >= MAX_RUN_TIME:
		_end_run()
	elif not Rect2(-100, -100, W + 200, H + 200).has_point(ball.global_position):
		_end_run()


func _pep_talk(spd: float) -> void:
	pep_left -= 1
	pep_cd = 3.0
	hud.show_banner(PEP_LINES.pick_random(), Color(0.55, 0.9, 1.0))
	Sfx.voice("motivate")
	var dir: Vector2 = ball.linear_velocity.normalized() if spd > 20.0 else Vector2.UP.rotated(randf_range(-0.6, 0.6))
	ball.nudge(dir * 520.0)
	spawn_burst(ball.global_position, Color(0.55, 0.9, 1.0), 18, 220.0, 0.45, 0.0)


# --- Scoring (called by drums, barriers, emblems) -------------------------------

func add_points(base: int, pos: Vector2, color: Color = Color.WHITE) -> void:
	if state != State.FLYING:
		return
	var mult: float = SaveData.point_mult()
	var doubled: bool = ball.multi_time > 0.0
	if doubled:
		mult *= 2.0
	var pts: int = maxi(1, int(round(float(base) * mult)))
	score += pts
	hud.set_score(score)
	popup_text(("+%d x2" if doubled else "+%d") % pts, pos, GOLD if doubled else color)

	if clock - last_score_time < 1.3:
		combo += 1
	else:
		combo = 1
	last_score_time = clock

	if COMBO_LINES.has(combo):
		hud.show_banner(COMBO_LINES[combo], GOLD)
		Sfx.voice("combo")
		if combo >= 20:
			Sfx.play("applause", 1.0, -4.0)
	elif milestone_idx < MILESTONES.size() and score >= int(MILESTONES[milestone_idx]):
		while milestone_idx < MILESTONES.size() and score >= int(MILESTONES[milestone_idx]):
			milestone_idx += 1
		hud.show_banner("%s POINTS!" % hud.fmt(int(MILESTONES[milestone_idx - 1])), GOLD)
		Sfx.voice("milestone")


func on_emblem(kind: String, lvl: int, pos: Vector2, color: Color) -> void:
	if state != State.FLYING:
		return
	match kind:
		"speed":
			ball.apply_powerup("speed", lvl)
			Sfx.play("collect_speed")
			hud.show_banner("SPEED BOOST!", color)
		"smash":
			ball.apply_powerup("smash", lvl)
			Sfx.play("collect_smash")
			hud.show_banner("SMASH x%d!" % lvl, color)
		"multi":
			ball.apply_powerup("multi", lvl)
			Sfx.play("collect_multi")
			hud.show_banner("DOUBLE POINTS!", color)
		_:
			Sfx.play("collect_coins")
			hud.show_banner("BONUS!", color)
			add_points(150, pos, color)
	Sfx.voice("powerup")
	spawn_burst(pos, color, 26, 280.0, 0.5, 0.0)


func on_barrier_broken(pos: Vector2, smashed: bool, max_hp: int, color: Color) -> void:
	var base: int = 40 * max_hp
	if smashed:
		base = int(base * 1.5)
	add_points(base, pos, color)
	Sfx.play("smash", randf_range(0.9, 1.1))
	shake = maxf(shake, 12.0 if smashed else 7.0)
	spawn_burst(pos, color, 30, 420.0, 0.7, 600.0)
	spawn_burst(pos, Color(1, 0.9, 0.6), 12, 250.0, 0.35, 0.0)
	if smashed and smash_banner_cd <= 0.0:
		smash_banner_cd = 1.2
		hud.show_banner(SMASH_LINES.pick_random(), Color(1.0, 0.5, 0.2))
		Sfx.voice("smash")


func on_jackpot(pos: Vector2) -> void:
	if state != State.FLYING:
		return
	add_points(300, pos, GOLD)
	Sfx.play("jackpot")
	Sfx.voice("jackpot")
	hud.show_banner("JACKPOT!!", GOLD)
	shake = maxf(shake, 10.0)
	spawn_burst(pos, GOLD, 40, 360.0, 0.7, 0.0)


# --- Effects --------------------------------------------------------------------

func popup_text(text: String, pos: Vector2, color: Color, size: int = 28) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(160, 40)
	l.position = pos - Vector2(80, 34)
	l.z_index = 20
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.55).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func spawn_burst(pos: Vector2, color: Color, amount: int, speed: float, life: float, grav: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, grav)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = color
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.z_index = 15
	level.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


# --- Arena building ------------------------------------------------------------

func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.75
	mat.friction = 0.05
	walls.physics_material_override = mat
	_add_rect(walls, Rect2(-100, -100, W + 200, 100 + BORDER))
	_add_rect(walls, Rect2(-100, H - BORDER, W + 200, 100 + BORDER))
	_add_rect(walls, Rect2(-100, -100, 100 + BORDER, H + 200))
	_add_rect(walls, Rect2(W - BORDER, -100, 100 + BORDER, H + 200))

	# Angled corner pieces so the ball never gets stuck in a corner.
	var s := 70.0
	corners = [
		PackedVector2Array([Vector2(BORDER, BORDER), Vector2(BORDER + s, BORDER), Vector2(BORDER, BORDER + s)]),
		PackedVector2Array([Vector2(W - BORDER, BORDER), Vector2(W - BORDER, BORDER + s), Vector2(W - BORDER - s, BORDER)]),
		PackedVector2Array([Vector2(BORDER, H - BORDER), Vector2(BORDER, H - BORDER - s), Vector2(BORDER + s, H - BORDER)]),
		PackedVector2Array([Vector2(W - BORDER, H - BORDER), Vector2(W - BORDER - s, H - BORDER), Vector2(W - BORDER, H - BORDER - s)]),
	]
	for c in corners:
		var cp := CollisionPolygon2D.new()
		cp.polygon = c
		walls.add_child(cp)
	add_child(walls)
	queue_redraw()


func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)


func _build_level() -> void:
	var ring = RingScript.new()
	ring.position = RING_CENTER
	ring.spin = 0.75 * (1.0 if randf() < 0.5 else -1.0)
	level.add_child(ring)

	var spin_spots: Array = [Vector2(130, 830), Vector2(590, 830), Vector2(360, 150)]
	for sp in spin_spots:
		var s = SpinnerScript.new()
		s.position = sp
		s.spin = randf_range(1.8, 2.8) * (1.0 if randf() < 0.5 else -1.0)
		level.add_child(s)

	# Barriers.
	var placed: Array = []
	var tries := 0
	while placed.size() < BARRIER_COUNT and tries < 600:
		tries += 1
		var p := Vector2(randf_range(80.0, W - 80.0), randf_range(240.0, 980.0))
		if p.distance_to(RING_CENTER) < RING_R + 75.0:
			continue
		if _near(p, spin_spots, 115.0) or _near(p, placed, 120.0):
			continue
		if p.y > 900.0 and absf(p.x - REST.x) < 140.0:
			continue
		var b = BarrierScript.new()
		b.position = p
		b.rotation = randf_range(-0.5, 0.5)
		b.max_hp = randi_range(1, 3)
		b.size = Vector2(randf_range(80.0, 120.0), 24.0)
		level.add_child(b)
		placed.append(p)

	# Power-up emblems.
	var count: int = SaveData.emblem_count()
	var spots: Array = []
	if randf() < 0.6:
		spots.append(RING_CENTER + Vector2.RIGHT.rotated(randf() * TAU) * 100.0)
	tries = 0
	while spots.size() < count and tries < 800:
		tries += 1
		var p := Vector2(randf_range(70.0, W - 70.0), randf_range(80.0, 960.0))
		if p.distance_to(RING_CENTER) < RING_R + 60.0:
			continue
		if _near(p, spin_spots, 95.0) or _near(p, placed, 75.0) or _near(p, spots, 100.0):
			continue
		if p.y > 880.0 and absf(p.x - REST.x) < 110.0:
			continue
		spots.append(p)
	for sp in spots:
		var e = EmblemScript.new()
		e.position = sp
		e.kind = _roll_kind()
		if e.kind == "smash":
			e.level = SaveData.smash_roll()
		level.add_child(e)


func _roll_kind() -> String:
	var r := randf()
	if r < 0.35:
		return "smash"
	if r < 0.65:
		return "speed"
	if r < 0.85:
		return "multi"
	return "coins"


func _near(p: Vector2, list: Array, dist: float) -> bool:
	for q in list:
		if p.distance_to(q) < dist:
			return true
	return false


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.07, 0.13))
	var dot := Color(1, 1, 1, 0.05)
	for x in range(40, int(W), 40):
		for y in range(40, int(H), 40):
			draw_circle(Vector2(x, y), 1.5, dot)
	# Launch zone.
	draw_rect(Rect2(BORDER, 1000, W - BORDER * 2.0, H - 1000 - BORDER), Color(1, 0.6, 0.2, 0.05))
	draw_line(Vector2(BORDER, 1000), Vector2(W - BORDER, 1000), Color(1, 0.6, 0.2, 0.25), 2.0)
	for c in corners:
		draw_colored_polygon(c, Color(0.27, 0.32, 0.55))
	draw_rect(Rect2(BORDER * 0.5, BORDER * 0.5, W - BORDER, H - BORDER), Color(0.45, 0.55, 1.0, 0.8), false, BORDER)
