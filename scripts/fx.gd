class_name FxLayer
extends Control
## 局内特效层：覆盖在牌桌上方，纯程序化像素特效。
## 提供：粒子爆散、浮字、发牌飞行、屏幕震动、提示气泡。
## 所有特效对象自管理生命周期，update 由 _process 驱动。

var _parts: Array = []   # {pos, vel, life, max_life, color, size, gravity}
var _floats: Array = []  # {text, pos, life, max_life, color, size}
var _flyers: Array = []  # {card, from, to, t, dur, arc}
var _shake := 0.0
var _hint: Control = null
var _hint_seq := 0
var _font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Ui.make_font()
	set_process(true)


func _process(delta: float) -> void:
	# 粒子
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		p["life"] -= delta
		if p["life"] <= 0:
			_parts.remove_at(i)
			continue
		p["pos"] += p["vel"] * delta
		p["vel"] = p["vel"] + Vector2(0, p["gravity"]) * delta
	# 浮字
	for i in range(_floats.size() - 1, -1, -1):
		var f: Dictionary = _floats[i]
		f["life"] -= delta
		if f["life"] <= 0:
			_floats.remove_at(i)
			continue
		f["pos"] += Vector2(0, -22) * delta
	# 飞行牌
	for i in range(_flyers.size() - 1, -1, -1):
		var fl: Dictionary = _flyers[i]
		fl["t"] += delta / fl["dur"]
		if fl["t"] >= 1.0:
			_flyers.remove_at(i)
	# 震动衰减
	if _shake > 0:
		_shake = maxf(0.0, _shake - delta * 14.0)
		position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		if _shake == 0:
			position = Vector2.ZERO
	queue_redraw()


func shake(amount: float = 3.0) -> void:
	_shake = maxf(_shake, amount)


func burst(center: Vector2, colors: Array, count: int = 14, power: float = 60.0) -> void:
	for i in count:
		var ang := randf() * TAU
		var spd := randf_range(power * 0.4, power)
		_parts.append({
			"pos": center,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": randf_range(0.35, 0.7),
			"max_life": 0.7,
			"color": colors[randi() % colors.size()],
			"size": randi_range(1, 2),
			"gravity": 120.0,
		})
	queue_redraw()


func float_text(text: String, pos: Vector2, color: Color = Color(1.0, 0.92, 0.5), size: int = 11) -> void:
	_floats.append({"text": text, "pos": pos, "life": 1.1, "max_life": 1.1, "color": color, "size": size})
	queue_redraw()


func fly_card(card: Card, from: Vector2, to: Vector2, dur: float = 0.28) -> void:
	_flyers.append({"card": card, "from": from, "to": to, "t": 0.0, "dur": dur, "arc": randf_range(14, 26)})
	queue_redraw()


func clear_flyers() -> void:
	_flyers.clear()


## 教学气泡提示（自动消失）。anchor 为指向点。
## 注意：Label 不会撑开父 Control，resized 信号永不触发——必须同步手动定位，
## 且定时器必须在任何 await 之前创建（曾经的 BUG：await 卡死导致箭头永久残留）。
func show_hint(text: String, anchor: Vector2, dur: float = 3.2) -> void:
	hide_hint()
	_hint_seq += 1
	var my_seq := _hint_seq
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("anchor", anchor)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.85))
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.15))
	lbl.add_theme_constant_override("outline_size", 3)
	c.add_child(lbl)
	add_child(c)
	# 同步定位：按 Label 最小尺寸计算气泡位置
	var w := lbl.get_minimum_size().x + 12
	var h := lbl.get_minimum_size().y + 8
	c.size = Vector2(w, h)
	c.position = Vector2(clampf(anchor.x - w / 2.0, 4, 640.0 - w - 4), maxf(4.0, anchor.y - 30))
	lbl.position = Vector2(6, 4)
	_hint = c
	# 立即创建定时器（带令牌校验：新气泡不会被子弹的旧定时器提前隐藏）
	get_tree().create_timer(dur).timeout.connect(func() -> void:
		if _hint == c and _hint_seq == my_seq:
			hide_hint())


func hide_hint() -> void:
	if _hint != null and is_instance_valid(_hint):
		_hint.queue_free()
	_hint = null


func _draw() -> void:
	# 飞行牌（先画，在粒子下层）
	for fl in _flyers:
		var t: float = fl["t"]
		var te := 1.0 - pow(1.0 - t, 2.0)  # ease-out
		var from: Vector2 = fl["from"]
		var to: Vector2 = fl["to"]
		var pos: Vector2 = from.lerp(to, te)
		pos.y -= sin(t * PI) * fl["arc"]
		var sc := 1.0 + sin(t * PI) * 0.12
		_draw_fly_card(fl["card"], pos, sc)
	# 粒子
	for p in _parts:
		var a: float = p["life"] / p["max_life"]
		var col: Color = p["color"]
		col.a = a
		var s: int = p["size"]
		draw_rect(Rect2(p["pos"], Vector2(s, s)), col)
	# 浮字
	for f in _floats:
		var a2: float = clampf(f["life"] / f["max_life"] * 1.6, 0.0, 1.0)
		var col2: Color = f["color"]
		col2.a = a2
		draw_string(_font, f["pos"], f["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, f["size"], col2)
	# 提示气泡底板
	if _hint != null and is_instance_valid(_hint):
		var lbl: Label = _hint.get_child(0)
		var size: Vector2 = lbl.get_minimum_size() + Vector2(12, 8)
		var pos: Vector2 = _hint.position - Vector2(6, 4)
		draw_rect(Rect2(pos, size), Color(0.12, 0.10, 0.20, 0.92))
		draw_rect(Rect2(pos, size), Color(0.80, 0.70, 0.40), false)
		var anchor: Vector2 = _hint.get_meta("anchor")
		# 小三角指向
		draw_colored_polygon(PackedVector2Array([
			Vector2(anchor.x - 4, pos.y + size.y),
			Vector2(anchor.x + 4, pos.y + size.y),
			anchor,
		]), Color(0.12, 0.10, 0.20, 0.92))


func _draw_fly_card(card: Card, pos: Vector2, scale_f: float) -> void:
	var cw: float = 40 * scale_f
	var ch: float = 56 * scale_f
	var p := Vector2(int(pos.x), int(pos.y))
	if not card.face_up:
		draw_rect(Rect2(p, Vector2(cw, ch)), Color(0.10, 0.08, 0.17))
		draw_rect(Rect2(p, Vector2(cw, ch)), Color(0.45, 0.36, 0.70), false)
		return
	# 暗色牌面（与牌桌明牌一致）
	draw_rect(Rect2(p, Vector2(cw, ch)), Color(0.19, 0.16, 0.30))
	draw_rect(Rect2(p, Vector2(cw, ch)), Pixel.suit_color(card.suit).darkened(0.25), false)
	var sc := Pixel.suit_color(card.suit)
	draw_string(_font, p + Vector2(3, 12), card.rank_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.95, 1.0))
	Pixel.draw_icon(self, Pixel.SUIT_ICONS[card.suit], p + Vector2(cw - 17, 3), 2, sc)
