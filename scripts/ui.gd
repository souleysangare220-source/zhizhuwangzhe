class_name Ui
extends Object
## UI 工厂：系统字体（中文回退）、主题、Label、Button。


static func make_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei",
		"Noto Sans CJK SC", "WenQuanYi Micro Hei", "sans-serif",
	])
	return f


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = make_font()
	t.default_font_size = 10
	return t


static func label(parent: Control, text: String, pos: Vector2, font_size: int = 10, color: Color = Color(0.87, 0.84, 0.95)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


static func wrap_label(parent: Control, text: String, pos: Vector2, w: int, font_size: int = 9, color: Color = Color(0.75, 0.72, 0.85)) -> Label:
	var l := label(parent, text, pos, font_size, color)
	l.custom_minimum_size = Vector2(w, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(parent: Control, text: String, pos: Vector2, size: Vector2, cb: Callable, font_size: int = 10) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", font_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.17, 0.34)
	sb.border_color = Color(0.55, 0.45, 0.80)
	sb.set_border_width_all(1)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(0.30, 0.24, 0.46)
	sbh.border_color = Color(0.90, 0.80, 1.00)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Color(0.15, 0.12, 0.24)
	b.add_theme_stylebox_override("pressed", sbp)
	var sbd: StyleBoxFlat = sb.duplicate()
	sbd.bg_color = Color(0.16, 0.13, 0.24)
	sbd.border_color = Color(0.30, 0.26, 0.42)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_color", Color(0.92, 0.89, 0.98))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.85, 0.80, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.55))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	b.add_theme_constant_override("outline_size", 1)
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b
