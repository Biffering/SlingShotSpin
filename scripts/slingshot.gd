extends Node2D

## The slingshot. Press on the ball, drag back, let go.
## Launch direction is opposite the pull; power grows with pull distance.

signal launched

var rest := Vector2(360, 1100)
var ball
var active := true
var dragging := false
var pull := Vector2.ZERO
var max_pull := 150.0
var last_stretch := 0.0
var wobble := 0.0
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	wobble = maxf(0.0, wobble - delta * 2.5)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active or ball == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = get_global_mouse_position()
		if event.pressed:
			if p.distance_to(rest) < 130.0:
				dragging = true
				last_stretch = 0.0
				_update_pull(p)
		elif dragging:
			dragging = false
			_release()
	elif event is InputEventMouseMotion and dragging:
		_update_pull(get_global_mouse_position())


func _update_pull(p: Vector2) -> void:
	var v: Vector2 = p - rest
	v.y = maxf(v.y, 10.0)  # must pull back (downward)
	if v.length() > max_pull:
		v = v.normalized() * max_pull
	v.y = minf(v.y, 135.0)  # keep the ball above the floor
	pull = v
	ball.global_position = rest + pull
	var plen: float = pull.length()
	if plen - last_stretch > 14.0:
		last_stretch = plen
		Sfx.play("stretch", 0.8 + 0.7 * plen / max_pull, -3.0)
	elif plen < last_stretch - 14.0:
		last_stretch = plen


func _release() -> void:
	if pull.length() < 18.0:
		pull = Vector2.ZERO
		ball.global_position = rest
		return
	var power: float = pull.length() / max_pull
	var vel: Vector2 = -pull.normalized() * SaveData.launch_speed() * power
	ball.global_position = rest + pull
	ball.launch(vel)
	active = false
	pull = Vector2.ZERO
	wobble = 1.0
	launched.emit()


func _draw() -> void:
	var fork_c := rest + Vector2(0, 62)
	var fork_l := rest + Vector2(-64, -14)
	var fork_r := rest + Vector2(64, -14)
	var base := rest + Vector2(0, 150)
	var wood := Color(0.55, 0.33, 0.16)
	var band := Color(0.85, 0.25, 0.2)

	# Back band first (behind the frame).
	var pouch: Vector2 = rest + pull
	if active and ball != null:
		pouch = ball.global_position
	if active:
		draw_line(fork_l, pouch, band.darkened(0.2), 7.0)
	# Frame.
	draw_line(base, fork_c, wood, 16.0)
	draw_line(fork_c, fork_l, wood, 13.0)
	draw_line(fork_c, fork_r, wood, 13.0)
	draw_circle(fork_l, 8.0, wood.lightened(0.15))
	draw_circle(fork_r, 8.0, wood.lightened(0.15))
	draw_circle(fork_c, 9.0, wood)
	if active:
		draw_line(fork_r, pouch, band, 7.0)
		draw_arc(pouch, 19.0, PI * 0.15, PI * 0.85, 12, Color(0.35, 0.2, 0.12), 6.0)
	else:
		# Band snaps back and wobbles after launch.
		var mid := (fork_l + fork_r) * 0.5 + Vector2(0, sin(t * 40.0) * 14.0 * wobble)
		draw_polyline(PackedVector2Array([fork_l, mid, fork_r]), band, 6.0)

	# Aim guide while pulling.
	if dragging and pull.length() > 18.0:
		var power: float = pull.length() / max_pull
		var dir: Vector2 = -pull.normalized()
		for i in range(1, 10):
			var d: float = float(i) * (18.0 + 42.0 * power)
			var a: float = 0.85 - float(i) * 0.08
			draw_circle(rest + dir * d, 6.0 - float(i) * 0.45, Color(1, 1, 1, a))
		var pct: String = "%d%%" % int(round(power * 100.0))
		draw_string(ThemeDB.fallback_font, rest + Vector2(-60, 175), pct, HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Color(1, 0.8, 0.3))
