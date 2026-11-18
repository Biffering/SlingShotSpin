extends AnimatableBody2D

## A small, fast-spinning bumper drum. Each slice is worth points,
## and it kicks the ball away hard.

const SECTIONS := 6

var radius := 46.0
var spin := 2.2
var values: Array = [10, 20, 10, 30, 10, 50]
var flash: Array = []
var hit_cd := 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.9
	mat.friction = 0.4
	physics_material_override = mat
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	values.shuffle()
	for i in SECTIONS:
		flash.append(0.0)


func _physics_process(delta: float) -> void:
	rotation += spin * delta
	hit_cd -= delta


func _process(delta: float) -> void:
	for i in SECTIONS:
		flash[i] = maxf(0.0, float(flash[i]) - delta * 3.0)
	queue_redraw()


func on_ball_hit(ball) -> void:
	if hit_cd > 0.0:
		return
	hit_cd = 0.08
	var rel: Vector2 = ball.global_position - global_position
	var local: Vector2 = rel.rotated(-rotation)
	var idx: int = int(fposmod(local.angle(), TAU) / (TAU / SECTIONS)) % SECTIONS
	flash[idx] = 1.0
	var v: int = int(values[idx])
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.add_points(v, ball.global_position, _color(v))
	Sfx.play("drum_hit", 0.8 + float(v) / 60.0)
	var n: Vector2 = rel.normalized()
	var tangent: Vector2 = Vector2(-n.y, n.x) * signf(spin)
	ball.apply_central_impulse(n * 380.0 + tangent * absf(spin) * radius * 0.8)


func _color(v: int) -> Color:
	if v >= 50:
		return Color(1.0, 0.45, 0.3)
	if v >= 30:
		return Color(1.0, 0.8, 0.25)
	if v >= 20:
		return Color(0.4, 0.95, 0.6)
	return Color(0.45, 0.7, 1.0)


func _draw() -> void:
	var step: float = TAU / SECTIONS
	var font: Font = ThemeDB.fallback_font
	for i in SECTIONS:
		var pts := PackedVector2Array([Vector2.ZERO])
		for k in 9:
			var a: float = float(i) * step + step * float(k) / 8.0
			pts.append(Vector2.RIGHT.rotated(a) * radius)
		var col: Color = _color(int(values[i])).lerp(Color.WHITE, float(flash[i]) * 0.7)
		draw_colored_polygon(pts, col)
		var mid: float = (float(i) + 0.5) * step
		draw_set_transform(Vector2.RIGHT.rotated(mid) * radius * 0.64, mid + PI * 0.5, Vector2.ONE)
		draw_string(font, Vector2(-20, 6), str(values[i]), HORIZONTAL_ALIGNMENT_CENTER, 40, 15, Color(0.05, 0.05, 0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in SECTIONS:
		var a2: float = float(i) * step
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(a2) * radius, Color(0, 0, 0, 0.35), 2.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 4.0)
	draw_circle(Vector2.ZERO, 9.0, Color(0.15, 0.15, 0.25))
