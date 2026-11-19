class_name Pixel
extends Object
## 像素绘制基础层：5x7 像素字体、7x7 花色图标、配色。
## 全部程序化绘制，零外部素材。

const GLYPHS := {
	"0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	"/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
}

const ICONS := {
	"spider": [
		".#...#.",
		"#..#..#",
		".#.#.#.",
		"..###..",
		".#####.",
		".#.#.#.",
		"#..#..#",
	],
	"moth": [
		"#..#..#",
		".#.#.#.",
		".#####.",
		"..###..",
		".#####.",
		".#.#.#.",
		"#..#..#",
	],
	"beetle": [
		"..###..",
		".#.#.#.",
		"#######",
		"###.###",
		"###.###",
		"#######",
		".#.#.#.",
	],
	"centipede": [
		"#.....#",
		".#.#.#.",
		"..###..",
		".#####.",
		"..###..",
		".#.#.#.",
		"#.....#",
	],
	"silk": [
		"..###..",
		".#...#.",
		"#..#..#",
		"#.#.#.#",
		"#..#..#",
		".#...#.",
		"..###..",
	],
	"web": [
		"#..#..#",
		".#.#.#.",
		"..###..",
		"###.###",
		"..###..",
		".#.#.#.",
		"#..#..#",
	],
}

const SUIT_ICONS := ["spider", "moth", "beetle", "centipede"]
const SUIT_NAMES := ["蜘蛛", "飞蛾", "甲虫", "蜈蚣"]


static func suit_color(s: int) -> Color:
	match s:
		0: return Color(0.72, 0.60, 1.00)  # 蜘蛛 紫
		1: return Color(1.00, 0.45, 0.45)  # 飞蛾 红
		2: return Color(0.40, 0.72, 1.00)  # 甲虫 蓝
		3: return Color(0.50, 0.95, 0.60)  # 蜈蚣 绿
	return Color.WHITE


static func draw_glyph(ctx: CanvasItem, ch: String, pos: Vector2, scale: int, color: Color) -> void:
	var rows: Array = GLYPHS.get(ch, [])
	if rows.is_empty():
		return
	var x0 := int(pos.x)
	var y0 := int(pos.y)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				ctx.draw_rect(Rect2(x0 + x * scale, y0 + y * scale, scale, scale), color)


static func draw_text(ctx: CanvasItem, text: String, pos: Vector2, scale: int, color: Color, spacing: int = 1) -> void:
	var x := int(pos.x)
	for ch in text:
		draw_glyph(ctx, ch, Vector2(x, pos.y), scale, color)
		x += (5 + spacing) * scale


static func draw_icon(ctx: CanvasItem, icon: String, pos: Vector2, scale: int, color: Color) -> void:
	var rows: Array = ICONS.get(icon, [])
	if rows.is_empty():
		return
	var x0 := int(pos.x)
	var y0 := int(pos.y)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				ctx.draw_rect(Rect2(x0 + x * scale, y0 + y * scale, scale, scale), color)


static func text_width(text: String, scale: int, spacing: int = 1) -> int:
	if text.is_empty():
		return 0
	return text.length() * (5 + spacing) * scale - spacing * scale
