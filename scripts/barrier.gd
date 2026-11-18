extends StaticBody2D

## A breakable barrier. Normally the ball bounces off and chips it (1-3 hits).
## With a Smash power-up the ball ploughs straight through and shatters it.

var size := Vector2(100, 24)
var max_hp := 2
var hp := 2
var dead := false
var flash := 0.0
var area: Area2D


func _ready() -> void:
	hp = max_hp
	collision_layer = 4
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.6
	physics_material_override = mat

	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	add_child(cs)

	# Slightly larger sensor so a smashing ball is caught before contact.
	area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var acs := CollisionShape2D.new()
	var ars := RectangleShape2D.new()
	ars.size = size + Vector2(14, 14)
	acs.shape = ars
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_area_body)


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
		queue_redraw()


func on_ball_hit(_ball) -> void:
	if dead:
		return
	hp -= 1
	flash = 1.0
	if hp <= 0:
		_break(false)
	else:
		Sfx.play("barrier_hit", randf_range(0.9, 1.15))
		queue_redraw()


func _on_area_body(body: Node) -> void:
	if dead or not body.is_in_group("ball"):
		return
	if int(body.smash_charges) > 0:
		body.use_smash()
		_break(true)


func _break(smashed: bool) -> void:
	dead = true
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.on_barrier_broken(global_position, smashed, max_hp, _color())
	set_deferred("collision_layer", 0)
	area.set_deferred("monitoring", false)
	queue_free()


func _color() -> Color:
	match max_hp:
		3:
			return Color(0.7, 0.4, 1.0)
		2:
			return Color(0.35, 0.6, 1.0)
	return Color(0.3, 0.85, 0.85)


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	var col: Color = _color().lerp(Color.WHITE, flash * 0.6)
	draw_rect(r, col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), col.lightened(0.3))
	draw_rect(r, col.darkened(0.55), false, 3.0)
	if hp < max_hp:
		var c := Color(0.05, 0.05, 0.1, 0.8)
		draw_line(Vector2(-size.x * 0.15, -size.y * 0.5), Vector2(0, 2), c, 2.0)
		draw_line(Vector2(0, 2), Vector2(size.x * 0.12, size.y * 0.5), c, 2.0)
		draw_line(Vector2(0, 2), Vector2(size.x * 0.25, -3), c, 2.0)
	for i in hp:
		var x: float = (float(i) - float(hp - 1) * 0.5) * 16.0
		draw_circle(Vector2(x, 0), 4.0, Color(1, 1, 1, 0.9))
