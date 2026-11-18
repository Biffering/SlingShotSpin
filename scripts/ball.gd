extends RigidBody2D

## The ball. Sits in the slingshot (frozen) until launched, then bounces around
## on its own. Carries the active power-ups and their movement sounds.

signal stopped

const RADIUS := 15.0
const MAX_SPEED := 2600.0
const BOOST_MIN_SPEED := 950.0

var in_play := false
var done := false
var has_pending := false
var pending_velocity := Vector2.ZERO
var base_damp := 0.45

var speed_time := 0.0
var multi_time := 0.0
var smash_charges := 0

var slow_timer := 0.0
var bounce_cd := 0.0
var t := 0.0
var trail: Line2D


func _ready() -> void:
	add_to_group("ball")
	gravity_scale = 0.0
	collision_layer = 2
	collision_mask = 1 | 4  # world + barriers
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	base_damp = SaveData.ball_damp()
	linear_damp = base_damp
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 1.5

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.8
	mat.friction = 0.15
	physics_material_override = mat

	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	cs.shape = circle
	add_child(cs)

	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	body_entered.connect(_on_body_entered)

	trail = Line2D.new()
	trail.top_level = true
	trail.z_index = -1
	trail.width = RADIUS * 1.7
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	trail.width_curve = curve
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55)])
	trail.gradient = g
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(trail)


func launch(vel: Vector2) -> void:
	freeze = false
	pending_velocity = vel
	has_pending = true
	in_play = true


func nudge(impulse: Vector2) -> void:
	apply_central_impulse(impulse)
	slow_timer = 0.0


func finish() -> void:
	done = true
	in_play = false
	Sfx.stop_all_loops()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if has_pending:
		state.linear_velocity = pending_velocity
		has_pending = false
		return
	var v: Vector2 = state.linear_velocity
	var s: float = v.length()
	if s > MAX_SPEED:
		v = v / s * MAX_SPEED
	elif speed_time > 0.0 and s > 1.0 and s < BOOST_MIN_SPEED:
		v = v / s * BOOST_MIN_SPEED
	state.linear_velocity = v


func _physics_process(delta: float) -> void:
	if not in_play or done:
		return
	bounce_cd -= delta

	if speed_time > 0.0:
		speed_time -= delta
		if speed_time <= 0.0:
			speed_time = 0.0
			linear_damp = base_damp
			Sfx.stop_loop("loop_speed")
	if multi_time > 0.0:
		multi_time -= delta
		if multi_time <= 0.0:
			multi_time = 0.0
			Sfx.stop_loop("loop_multi")

	var s: float = linear_velocity.length()
	# Movement sounds follow the ball's speed while power-ups are active.
	if speed_time > 0.0:
		Sfx.set_loop_pitch("loop_speed", clampf(0.7 + s / 1800.0, 0.6, 2.0))
	if smash_charges > 0:
		Sfx.set_loop_pitch("loop_smash", clampf(0.8 + s / 2500.0, 0.7, 1.6))
	if multi_time > 0.0:
		Sfx.set_loop_pitch("loop_multi", clampf(0.9 + s / 4000.0, 0.85, 1.4))

	if s < 22.0:
		slow_timer += delta
		if slow_timer > 0.9:
			done = true
			stopped.emit()
	else:
		slow_timer = 0.0


func apply_powerup(kind: String, level: int) -> void:
	match kind:
		"speed":
			speed_time = SaveData.boost_time(4.0)
			linear_damp = 0.0
			Sfx.start_loop("loop_speed")
		"smash":
			smash_charges = mini(smash_charges + level, 9)
			set_deferred("collision_mask", 1)  # pass through barriers
			Sfx.start_loop("loop_smash", -5.0)
		"multi":
			multi_time = SaveData.boost_time(8.0)
			Sfx.start_loop("loop_multi", -10.0)


func use_smash() -> void:
	smash_charges -= 1
	if smash_charges <= 0:
		smash_charges = 0
		set_deferred("collision_mask", 1 | 4)
		Sfx.stop_loop("loop_smash")


func _on_body_entered(body: Node) -> void:
	if body.has_method("on_ball_hit"):
		body.on_ball_hit(self)
	elif bounce_cd <= 0.0:
		bounce_cd = 0.05
		var s: float = linear_velocity.length()
		Sfx.play("bounce", randf_range(0.9, 1.1), linear_to_db(clampf(s / 1200.0, 0.15, 1.0)))


func _process(delta: float) -> void:
	t += delta
	if in_play and not done:
		trail.add_point(global_position)
		while trail.get_point_count() > 22:
			trail.remove_point(0)
	elif trail.get_point_count() > 0 and done:
		trail.remove_point(0)

	var c := Color(1, 1, 1)
	if smash_charges > 0:
		c = Color(1.0, 0.45, 0.1)
	elif speed_time > 0.0:
		c = Color(0.3, 0.9, 1.0)
	elif multi_time > 0.0:
		c = Color(1.0, 0.85, 0.2)
	trail.modulate = c
	queue_redraw()


func _draw() -> void:
	var col := Color(0.95, 0.96, 1.0)
	if smash_charges > 0:
		var p: float = 0.5 + 0.5 * sin(t * 18.0)
		draw_circle(Vector2.ZERO, RADIUS + 9.0 + p * 3.0, Color(1, 0.35, 0.1, 0.35))
		draw_circle(Vector2.ZERO, RADIUS + 4.0, Color(1, 0.6, 0.15, 0.6))
		col = Color(1.0, 0.86, 0.72)
	if speed_time > 0.0:
		draw_circle(Vector2.ZERO, RADIUS + 7.0, Color(0.3, 0.9, 1.0, 0.35))
	if multi_time > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 32, Color(1, 0.85, 0.2), 3.0)
	draw_circle(Vector2.ZERO, RADIUS, col)
	# Stripe that rotates with the ball so you can see it spin.
	draw_line(Vector2(-RADIUS * 0.8, 0), Vector2(RADIUS * 0.8, 0), Color(0.55, 0.6, 0.8), 3.0)
	# Highlight stays put while the ball spins.
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	draw_circle(Vector2(-5, -5), 4.5, Color(1, 1, 1, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
