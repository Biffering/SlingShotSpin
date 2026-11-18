extends CanvasLayer

## On-screen UI: score, bank, active power-ups, shout banners,
## the end-of-run results panel and the upgrade shop. Built entirely in code.

signal launch_pressed
signal shop_pressed
signal buy_pressed(id: String)

const GOLD := Color(1.0, 0.84, 0.25)

var root: Control
var score_label: Label
var bank_label: Label
var status_label: Label
var hint_label: Label
var banner: Label
var banner_tween: Tween
var results: CenterContainer
var results_box: VBoxContainer
var shop: CenterContainer
var shop_list: VBoxContainer
var shop_bank: Label


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var score_caption := _label("SCORE", 18, Color(0.7, 0.75, 0.9))
	score_caption.position = Vector2(26, 18)
	root.add_child(score_caption)

	score_label = _label("0", 52, Color.WHITE)
	score_label.position = Vector2(24, 36)
	score_label.size = Vector2(320, 64)
	score_label.pivot_offset = Vector2(0, 32)
	root.add_child(score_label)

	bank_label = _label("BANK 0", 24, GOLD)
	bank_label.position = Vector2(300, 22)
	bank_label.size = Vector2(394, 36)
	bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(bank_label)

	status_label = _label("", 22, Color(0.85, 0.9, 1.0))
	status_label.position = Vector2(24, 104)
	status_label.size = Vector2(672, 34)
	root.add_child(status_label)

	hint_label = _label("Drag the ball back and let go!", 28, Color(1, 0.85, 0.5))
	hint_label.position = Vector2(0, 950)
	hint_label.size = Vector2(720, 44)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)

	banner = _label("", 62, Color.WHITE)
	banner.position = Vector2(0, 690)
	banner.size = Vector2(720, 110)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.pivot_offset = Vector2(360, 55)
	banner.add_theme_constant_override("outline_size", 14)
	banner.visible = false
	root.add_child(banner)

	# Results panel.
	results = _center_wrap()
	var rpanel := PanelContainer.new()
	rpanel.custom_minimum_size = Vector2(560, 0)
	results.add_child(rpanel)
	results_box = VBoxContainer.new()
	results_box.add_theme_constant_override("separation", 12)
	rpanel.add_child(results_box)
	results.visible = false

	# Shop panel.
	shop = _center_wrap()
	var spanel := PanelContainer.new()
	spanel.custom_minimum_size = Vector2(670, 1120)
	shop.add_child(spanel)
	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", 12)
	spanel.add_child(sbox)
	var title := _label("UPGRADE SHOP", 44, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sbox.add_child(title)
	shop_bank = _label("", 28, Color.WHITE)
	shop_bank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sbox.add_child(shop_bank)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sbox.add_child(scroll)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 10)
	scroll.add_child(shop_list)
	var play_btn := Button.new()
	play_btn.text = "LAUNCH!"
	play_btn.custom_minimum_size = Vector2(0, 84)
	play_btn.add_theme_font_size_override("font_size", 34)
	play_btn.pressed.connect(_on_launch_btn)
	sbox.add_child(play_btn)
	shop.visible = false


# --- Public API -------------------------------------------------------------

func show_play() -> void:
	results.visible = false
	shop.visible = false
	hint_label.visible = true
	status_label.text = ""


func hide_hint() -> void:
	hint_label.visible = false


func set_score(n: int) -> void:
	score_label.text = fmt(n)
	score_label.scale = Vector2(1.12, 1.12)
	var tw := create_tween()
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.12)


func set_bank(n: int) -> void:
	bank_label.text = "BANK  " + fmt(n)


func set_status(text: String) -> void:
	status_label.text = text


func show_banner(text: String, color: Color = Color.WHITE) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.modulate.a = 1.0
	banner.scale = Vector2(0.4, 0.4)
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_interval(0.9)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.35)


func show_results(score: int, bank: int, best: int, new_best: bool) -> void:
	_clear(results_box)
	var title := _label("NEW BEST!" if new_best else "RUN COMPLETE", 46, GOLD if new_best else Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_box.add_child(title)
	var s := _label(fmt(score), 72, Color.WHITE)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_box.add_child(s)
	var earned := _label("+%s added to your bank" % fmt(score), 24, Color(0.6, 1.0, 0.65))
	earned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_box.add_child(earned)
	var info := _label("BANK  %s        BEST  %s" % [fmt(bank), fmt(best)], 24, Color(0.8, 0.85, 1.0))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_box.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	results_box.add_child(row)
	var shop_btn := Button.new()
	shop_btn.text = "UPGRADES"
	shop_btn.custom_minimum_size = Vector2(0, 80)
	shop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_btn.pressed.connect(_on_shop_btn)
	row.add_child(shop_btn)
	var again_btn := Button.new()
	again_btn.text = "LAUNCH AGAIN"
	again_btn.custom_minimum_size = Vector2(0, 80)
	again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again_btn.pressed.connect(_on_launch_btn)
	row.add_child(again_btn)
	results.visible = true
	shop.visible = false
	hint_label.visible = false


func show_shop() -> void:
	results.visible = false
	shop.visible = true
	refresh_shop()


func refresh_shop() -> void:
	shop_bank.text = "Bank:  " + fmt(SaveData.bank) + " points"
	_clear(shop_list)
	for u in SaveData.UPGRADES:
		var id: String = u["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_l := _label("%s   Lv %d/%d" % [u["name"], SaveData.lvl(id), SaveData.max_lvl(id)], 26, GOLD)
		var desc_l := _label(u["desc"], 19, Color(0.8, 0.83, 0.92))
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.custom_minimum_size = Vector2(380, 0)
		info.add_child(name_l)
		info.add_child(desc_l)
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 76)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if SaveData.is_maxed(id):
			btn.text = "MAXED"
			btn.disabled = true
		else:
			var c: int = SaveData.cost(id)
			btn.text = fmt(c)
			btn.disabled = SaveData.bank < c
		btn.pressed.connect(func(): buy_pressed.emit(id))
		row.add_child(btn)
		shop_list.add_child(row)
		shop_list.add_child(HSeparator.new())


func _on_launch_btn() -> void:
	Sfx.play("click")
	launch_pressed.emit()


func _on_shop_btn() -> void:
	Sfx.play("click")
	shop_pressed.emit()


# --- Helpers ----------------------------------------------------------------

static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _center_wrap() -> CenterContainer:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _box(bg: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), border_w: int = 0, margin: float = 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_content_margin_all(margin)
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 24
	th.set_stylebox("normal", "Button", _box(Color(0.95, 0.52, 0.15)))
	th.set_stylebox("hover", "Button", _box(Color(1.0, 0.63, 0.25)))
	th.set_stylebox("pressed", "Button", _box(Color(0.78, 0.4, 0.1)))
	th.set_stylebox("disabled", "Button", _box(Color(0.28, 0.3, 0.4)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.65, 0.67, 0.75))
	th.set_font_size("font_size", "Button", 26)
	th.set_stylebox("panel", "PanelContainer", _box(Color(0.09, 0.1, 0.19, 0.97), 22, Color(0.95, 0.55, 0.15), 3, 28.0))
	return th
