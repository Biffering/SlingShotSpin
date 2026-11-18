extends AnimatableBody2D

## The big spinning cylinder. Its wall is split into sections, each worth points.
## Three sections are open gaps, so the ball can fly in, ricochet around inside
## (hitting sections from the inside too) and fly back out.
## The glowing core in the middle is the jackpot.

const SLOTS := 12
const GAP_SLOTS := [0, 4, 8]
const CORE_RADIUS := 34.0
const VALUE_POOL := [10, 10, 25, 25, 25, 50, 50, 100, 250]

var radius := 175.0
var thickness := 24.0
var spin := 0.75
var values: Array = []
var flash: Array = []
var hit_cd: Array = []
var core_cd := 0.0
var core_flash := 0.0
var t := 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.6
	mat.friction = 0.3
	physics_material_override = mat

	var pool: Array = VALUE_POOL.duplicate()
	pool.shuffle()
	var step: float = TAU / SLOTS
	for i in SLOTS:
		flash.append(0.0)
		hit_cd.append(0.0)
		if i in GAP_SLOTS:
			values.append(0)
			continue
		values.append(pool.pop_back())
		var poly := CollisionPolygon2D.new()
		poly.polygon = _arc_poly(i * step + 0.015, (i + 1) * step - 0.015, radius - thickness * 0.5, radius + thickness * 0.5, 10)
		add_child(poly)

	var core := Area2D.new()
	core.collision_layer = 0
	core.collision_mask = 2
	core.monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = CORE_RADIUS
	cs.shape = c
	core.add_child(cs)
	add_child(core)
	core.body_entered.connect(_on_core)


func _physics_process(delta: float) -> void:
	rotation += spin * delta
	core_cd -= delta
	for i in SLOTS:
		hit_cd[i] = float(hit_cd[i]) - delta


func _process(delta: float) -> void:
	t += delta
	for i in SLOTS:
		flash[i] = maxf(0.0, float(flash[i]) - delta * 3.0)
	core_flash = maxf(0.0, core_flash - delta * 2.0)
	queue_redraw()


func on_ball_hit(ball) -> void:
	var rel: Vector2 = ball.global_position - global_position
	var local: Vector2 = rel.rotated(-rotation)
	var step: float = TAU / SLOTS
	var f: float = fposmod(local.angle(), TAU) / step
	var slot: int = int(f) % SLOTS
	if int(values[slot]) == 0:
		# Hit the edge of a gap: count it for the neighbouring section.
		var dir: int = 1 if fposmod(f, 1.0) > 0.5 else -1
		slot = (slot + dir + SLOTS) % SLOTS
		if int(values[slot]) == 0:
			return
	if float(hit_cd[slot]) > 0.0:
		return
	hit_cd[slot] = 0.12
	flash[slot] = 1.0

	var v: int = int(values[slot])
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.add_points(v, ball.global_position, value_color(v))
	Sfx.play("ring_hit", clampf(1.35 - float(v) / 400.0, 0.7, 1.4))

	# Kick the ball: away from the wall, plus a shove in the spin direction.
	var dist: float = maxf(rel.length(), 1.0)
	var n: Vector2 = rel / dist
	if dist < radius:
		n = -n
	var tangent: Vector2 = Vector2(-rel.y, rel.x).normalized() * signf(spin)
	ball.apply_central_impulse(n * 160.0 + tangent * absf(spin) * radius * 0.6)


func _on_core(body: Node) -> void:
	if not body.is_in_group("ball") or core_cd > 0.0:
		return
	core_cd = 1.5
	core_flash = 1.0
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.on_jackpot(global_position)


static func value_color(v: int) -> Color:
	if v >= 250:
		return Color(0.95, 0.3, 0.95)
	if v >= 100:
		return Color(1.0, 0.5, 0.15)
	if v >= 50:
		return Color(1.0, 0.85, 0.2)
	if v >= 25:
		return Color(0.35, 0.9, 0.45)
	return Color(0.35, 0.6, 1.0)


func _arc_poly(a0: float, a1: float, r0: float, r1: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in steps + 1:
		var a: float = lerpf(a0, a1, float(k) / steps)
		pts.append(Vector2.RIGHT.rotated(a) * r1)
	for k in steps + 1:
		var a: float = lerpf(a1, a0, float(k) / steps)
		pts.append(Vector2.RIGHT.rotated(a) * r0)
	return pts


func _draw() -> void:
	var step: float = TAU / SLOTS
	var font: Font = ThemeDB.fallback_font
	# Floor of the cylinder.
	draw_circle(Vector2.ZERO, radius - thickness * 0.5, Color(0.09, 0.11, 0.21))
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 64, Color(1, 1, 1, 0.06), 2.0)
	draw_arc(Vector2.ZERO, radius * 0.35, 0.0, TAU, 48, Color(1, 1, 1, 0.06), 2.0)

	for i in SLOTS:
		var v: int = int(values[i])
		if v == 0:
			continue
		var col: Color = value_color(v).lerp(Color.WHITE, float(flash[i]) * 0.7)
		var pts := _arc_poly(i * step + 0.015, (i + 1) * step - 0.015, radius - thickness * 0.5, radius + thickness * 0.5, 10)
		draw_colored_polygon(pts, col)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, col.darkened(0.5), 2.0)
		var mid: float = (i + 0.5) * step
		draw_set_transform(Vector2.RIGHT.rotated(mid) * radius, mid + PI * 0.5, Vector2.ONE)
		draw_string(font, Vector2(-30, 6), str(v), HORIZONTAL_ALIGNMENT_CENTER, 60, 17, Color(0.05, 0.05, 0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Jackpot core.
	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	draw_circle(Vector2.ZERO, CORE_RADIUS + 4.0 + pulse * 4.0, Color(1, 0.75, 0.1, 0.18 + core_flash * 0.5))
	draw_circle(Vector2.ZERO, CORE_RADIUS - 8.0, Color(1, 0.8, 0.2).lerp(Color.WHITE, core_flash))
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	draw_string(font, Vector2(-40, 7), "300", HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Color(0.3, 0.15, 0.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
