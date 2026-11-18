extends Area2D

## A floating power-up emblem that spins in place like a coin.
## The ball collects it by passing through it.
##   speed - lightning bolt: the ball stays fast for a few seconds
##   smash - starburst with pips: ball smashes through 1-5 barriers
##   multi - x2: double points for a few seconds
##   coins - $: instant bonus points

const R := 28.0

var kind := "speed"
var level := 1
var t := 0.0
var base_pos := Vector2.ZERO
var collected := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = R
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)
	t = randf() * TAU
	base_pos = position
	z_index = 5


func _process(delta: float) -> void:
	if collected:
		return
	t += delta
	position = base_pos + Vector2(0, sin(t * 2.0) * 5.0)
	queue_redraw()


func color() -> Color:
	match kind:
		"speed":
			return Color(0.3, 0.9, 1.0)
		"smash":
			return Color(1.0, 0.45, 0.15)
		"multi":
			return Color(1.0, 0.85, 0.2)
	return Color(0.4, 1.0, 0.5)


func _on_body(body: Node) -> void:
	if collected or not body.is_in_group("ball") or body.done:
		return
	collected = true
	set_deferred("monitoring", false)
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.on_emblem(kind, level, global_position, color())
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var col: Color = color()
	var font: Font = ThemeDB.fallback_font
	var pulse: float = 0.5 + 0.5 * sin(t * 5.0)
	draw_circle(Vector2.ZERO, R + 8.0 + pulse * 3.0, Color(col.r, col.g, col.b, 0.16))
	# Orbiting sparkles.
	for i in 8:
		var a: float = t * 1.6 + float(i) * TAU / 8.0
		draw_circle(Vector2.RIGHT.rotated(a) * (R + 6.0), 2.2, Color(col.r, col.g, col.b, 0.8))

	# Coin-style spin: squash horizontally with cos().
	var sx: float = maxf(0.12, absf(cos(t * 2.6)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, 1.0))
	draw_circle(Vector2.ZERO, R, col.darkened(0.6))
	draw_arc(Vector2.ZERO, R - 2.0, 0.0, TAU, 32, col, 4.0)
	match kind:
		"speed":
			var bolt := PackedVector2Array([
				Vector2(-4, -18), Vector2(9, -18), Vector2(2, -4), Vector2(10, -4),
				Vector2(-7, 19), Vector2(-1, 2), Vector2(-9, 2)])
			draw_colored_polygon(bolt, col.lightened(0.3))
		"smash":
			var star := PackedVector2Array()
			for k in 16:
				var rr: float = 18.0 if k % 2 == 0 else 8.0
				star.append(Vector2.UP.rotated(float(k) * TAU / 16.0) * rr)
			draw_colored_polygon(star, col.lightened(0.25))
			draw_string(font, Vector2(-20, 7), str(level), HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color(0.25, 0.05, 0.0))
		"multi":
			draw_string(font, Vector2(-26, 9), "x2", HORIZONTAL_ALIGNMENT_CENTER, 52, 26, col.lightened(0.3))
		_:
			draw_string(font, Vector2(-26, 10), "$", HORIZONTAL_ALIGNMENT_CENTER, 52, 30, col.lightened(0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Smash level pips under the emblem.
	if kind == "smash":
		for i in level:
			var x: float = (float(i) - float(level - 1) * 0.5) * 11.0
			draw_circle(Vector2(x, R + 12.0), 3.5, col)
