class_name TableView
extends Control
## 牌桌视图：像素渲染 + 点击交互 + HUD + 程序化特效。
## 引擎采用"派发模式"：行动先撤销、播放动画，动画结束后再 flush 应用后续状态。

const CW := 40
const CH := 56
const GAP := 4
const TOP_Y := 36
const LIMIT_Y := 328
const DOWN_OFF := 7
const UP_OFF := 14

const BG := Color(0.08, 0.06, 0.12)
const FELT := Color(0.10, 0.08, 0.19)
const FACE := Color(0.90, 0.86, 0.77)
const FACE_WILD := Color(0.86, 0.84, 0.90)
const INK := Color(0.20, 0.16, 0.25)

var engine: SpiderEngine
var run: RunState
var node_info: Dictionary = {}
var on_win: Callable
var on_lose: Callable

var sel_col := -1
var sel_start := -1
var pending_silk := 0
var completed_suits: Array = []
var quit_armed_until := 0
var _ended := false
var _tut_step := 0   # 0=未开始 1=已提示选牌 2=已提示落牌 3=已提示发牌 4=完成

var fx: FxLayer
var _bg_tex: Texture2D
var _back_tex: Texture2D
var _face_tex: Texture2D
var _court_tex: Dictionary = {}   # suit -> Texture2D（J/Q/K 人头插画）
var btn_deal: Button
var btn_undo: Button
var btn_quit: Button
var lbl_title: Label
var lbl_goal: Label
var lbl_deal: Label
var lbl_undo: Label
var lbl_silk: Label
var lbl_rule: Label
var lbl_toast: Label

# 派发模式下的隐藏/动画状态
var _hidden: Dictionary = {}        # Card -> true（动画期间不渲染）
var _flips: Dictionary = {}         # Card -> t (0..1)
var _moves: Array = []              # {card, from, to, t, dur, delay}
var _pending: Array = []            # 待 flush 的行动上下文


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Ui.make_theme()
	# 美术资源（纹理用线性过滤更平滑；程序化绘制不受影响）
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bg_tex = load("res://assets/bg_table.png")
	_back_tex = load("res://assets/card_back.png")
	_face_tex = load("res://assets/card_face.png")
	var court_names := ["court_spider", "court_moth", "court_beetle", "court_centipede"]
	for s in court_names.size():
		var t: Texture2D = load("res://assets/" + court_names[s] + ".png")
		if t != null:
			_court_tex[s] = t
	_build_hud()
	fx = FxLayer.new()
	fx.position = Vector2.ZERO
	fx.size = size
	add_child(fx)
	if not node_info.is_empty():
		lbl_title.text = str(node_info.get("name", ""))
		var rule := str(node_info.get("rule_desc", ""))
		lbl_rule.text = rule
		lbl_rule.visible = rule != ""
		if rule != "":
			_toast("Boss 遭遇：" + str(node_info.get("name", "")))
	_update_hud()
	_tutorial_check()


func _process(delta: float) -> void:
	# 翻牌动画
	for c in _flips.keys():
		_flips[c] = minf(1.0, float(_flips[c]) + delta / 0.18)
	# 移动动画
	for i in range(_moves.size() - 1, -1, -1):
		var m: Dictionary = _moves[i]
		if m["delay"] > 0:
			m["delay"] -= delta
			continue
		m["t"] = minf(1.0, m["t"] + delta / m["dur"])
		if m["t"] >= 1.0:
			_moves.remove_at(i)
	# 所有动画结束 -> flush
	if not _pending.is_empty() and _moves.is_empty() and _flips_done():
		var ctx: Dictionary = _pending.pop_front()
		engine.flush_action(ctx["ev"])
		if ctx["kind"] == "move":
			_finish_move(ctx)
		elif ctx["kind"] == "deal":
			_finish_deal(ctx)
	queue_redraw()


func _flips_done() -> bool:
	for c in _flips.keys():
		if float(_flips[c]) < 1.0:
			return false
	return true


# ---------------- 交互 ----------------

func _gui_input(event: InputEvent) -> void:
	if engine == null or _ended:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			sel_col = -1
			sel_start = -1


func _handle_click(pos: Vector2) -> void:
	if engine.finished != "" or not _pending.is_empty():
		return
	var col_idx := _column_at(pos.x)
	if col_idx < 0 or pos.y < TOP_Y or pos.y > LIMIT_Y + CH:
		sel_col = -1
		sel_start = -1
		return
	var card_idx := _card_at(col_idx, pos)
	# 已有选中序列且点击的是其他列：优先尝试落牌，落不成再改选被点的牌
	if sel_col >= 0 and col_idx != sel_col:
		if card_idx >= 0:
			var head: Card = engine.columns[sel_col][sel_start]
			if engine.can_drop(head, col_idx):
				_try_drop(col_idx)
				return
		else:
			_try_drop(col_idx)
			return
	if card_idx >= 0:
		if sel_col == col_idx and card_idx == sel_start:
			sel_col = -1
			sel_start = -1
		elif engine.can_pick(col_idx, card_idx):
			sel_col = col_idx
			sel_start = card_idx
			if _tut_step == 1:
				_tut_step = 2
				fx.show_hint("再点一列落牌：可放在大 1 点的牌上，或空列", _col_origin(col_idx) + Vector2(CW / 2, 40))
		else:
			_try_drop(col_idx)
	else:
		_try_drop(col_idx)


func _try_drop(dst: int) -> void:
	if sel_col < 0 or sel_start < 0:
		return
	var col: Array = engine.columns[sel_col]
	if sel_start >= col.size():
		return
	var head: Card = col[sel_start]
	if not engine.can_drop(head, dst):
		_toast("无法移动到那里")
		return
	var src := sel_col
	var start := sel_start
	var run_cards: Array = col.slice(start)
	var run_len := run_cards.size()
	var same_suit := true
	for c in run_cards:
		if (c as Card).suit != head.suit:
			same_suit = false
			break
	# 记录动画起始位置
	var from_poss := _stack_positions(src)
	var from_pos: Array = []
	for j in range(start, col.size()):
		from_pos.append(from_poss[j])
	# 引擎派发：移动已生效，翻牌/完成待定
	var ev: Dictionary = engine.do_move(src, start, dst)
	sel_col = -1
	sel_start = -1
	# 设置动画状态
	var dst_top: Vector2 = _stack_positions(dst)[engine.columns[dst].size() - run_cards.size()]
	for k in run_cards.size():
		var c: Card = run_cards[k]
		_hidden[c] = true
		_moves.append({
			"card": c,
			"from": from_pos[k],
			"to": dst_top + Vector2(0, k * UP_OFF),
			"t": 0.0,
			"dur": 0.16 + 0.02 * run_len,
			"delay": k * 0.03,
		})
	for c in ev.get("pending_flips", []):
		_hidden[c] = true
		_flips[c] = 0.0
	for c in ev.get("pending_completed", []):
		_hidden[c] = true
	if run_len >= 5 and same_suit and run.has_relic("loom"):
		pending_silk += 1
		fx.float_text("+1 丝", dst_top + Vector2(CW / 2, -8), Color(0.98, 0.85, 0.45))
	pending_silk += int(ev.get("silk", 0))
	if int(ev.get("undo_gain", 0)) > 0:
		fx.float_text("+1 撤销", dst_top + Vector2(CW / 2, -20), Color(0.4, 0.9, 0.6))
	_pending.append({"ev": ev, "kind": "move", "dst": dst, "src": src, "run_len": run_len})


func _finish_move(ctx: Dictionary) -> void:
	var ev: Dictionary = ctx["ev"]
	var dst: int = ctx["dst"]
	# 动画结束，清除隐藏与移动状态
	for m in _moves:
		pass
	_moves.clear()
	for c in ev.get("moved", []):
		_hidden.erase(c)
	# flush_action 已把 pending_flips 转存到 flipped，这里用 flipped 清理动画状态
	for c in ev.get("flipped", []):
		_hidden.erase(c)
		_flips.erase(c)
	# 消除特效
	var sets: int = int(ev.get("sets", 0))
	if sets > 0:
		var cards: Array = ev.get("completed_cards", [])
		if cards.size() > 0:
			var first: Card = cards[0]
			var suit_of_set := first.suit
			for i in sets:
				completed_suits.append(suit_of_set)
		# 在该列上方爆散
		var center: Vector2 = _col_origin(dst) + Vector2(CW / 2, 30)
		var suit_colors: Array = []
		for c in cards:
			suit_colors.append(Pixel.suit_color((c as Card).suit))
		fx.burst(center, suit_colors, 26, 90.0)
		fx.shake(3.0)
		fx.float_text("织成命运之丝！", center + Vector2(0, -16), Color(1.0, 0.95, 0.6), 13)
		_toast("织成一段命运之丝！")
		for c in cards:
			_hidden.erase(c)
	_after_action(ev)


func _on_deal_pressed() -> void:
	if engine == null or _ended or engine.finished != "" or not _pending.is_empty():
		return
	if not engine.can_deal():
		if engine.stock.is_empty():
			_toast("发牌已用尽")
		else:
			_toast("有空列时不能发牌")
		return
	var ev: Dictionary = engine.do_deal()
	sel_col = -1
	sel_start = -1
	if str(node_info.get("rule", "")) == "cocoon_storm" and not ev["dealt"].is_empty():
		var dealt: Array = ev["dealt"]
		var victim: Card = dealt[randi() % dealt.size()]
		victim.cocooned = true
		_toast("茧之风暴缠住了 " + Pixel.SUIT_NAMES[victim.suit] + victim.rank_label())
	# 发牌飞行动画：从底部牌堆飞向各列
	var dealt_cards: Array = ev.get("dealt", [])
	for i in dealt_cards.size():
		var c: Card = dealt_cards[i]
		_hidden[c] = true
		var col_idx := i % engine.columns.size()
		var to: Vector2 = _stack_positions(col_idx)[engine.columns[col_idx].size() - 1]
		fx.fly_card(c, Vector2(210, 342), to, 0.24 + 0.02 * (i / engine.columns.size()))
	for c in ev.get("pending_flips", []):
		_hidden[c] = true
		_flips[c] = 0.0
	for c in ev.get("pending_completed", []):
		_hidden[c] = true
	_pending.append({"ev": ev, "kind": "deal"})
	if _tut_step == 2:
		_tut_step = 3
		fx.show_hint("没有好棋时就发牌——次数有限，省着用", Vector2(36, 342))


func _finish_deal(ctx: Dictionary) -> void:
	var ev: Dictionary = ctx["ev"]
	fx.clear_flyers()
	for c in ev.get("dealt", []):
		_hidden.erase(c)
	# flush_action 已把 pending_flips 转存到 flipped，这里用 flipped 清理动画状态
	for c in ev.get("flipped", []):
		_hidden.erase(c)
		_flips.erase(c)
	var sets: int = int(ev.get("sets", 0))
	if sets > 0:
		var cards: Array = ev.get("completed_cards", [])
		if cards.size() > 0:
			var suit_of_set := (cards[0] as Card).suit
			for i in sets:
				completed_suits.append(suit_of_set)
		fx.shake(3.0)
		fx.float_text("织成命运之丝！", Vector2(320, 100), Color(1.0, 0.95, 0.6), 13)
		_toast("织成一段命运之丝！")
		for c in cards:
			_hidden.erase(c)
	_after_action(ev)


func _on_undo_pressed() -> void:
	if engine == null or _ended or not _pending.is_empty():
		return
	if engine.finished == "win":
		return
	if not engine.undo():
		_toast("没有可撤销的步数或次数")
		return
	run.stats["undo_used"] = int(run.stats["undo_used"]) + 1
	sel_col = -1
	sel_start = -1
	_hidden.clear()
	_flips.clear()
	_moves.clear()
	fx.clear_flyers()
	fx.float_text("时光回溯", Vector2(320, 90), Color(0.7, 0.8, 1.0), 12)
	_after_action({"moved": [], "flipped": [], "completed_cards": [], "dealt": [], "sets": 0, "silk": 0, "undo_gain": 0})


func _on_quit_pressed() -> void:
	if _ended:
		return
	var now := Time.get_ticks_msec()
	if now < quit_armed_until:
		_lose()
	else:
		quit_armed_until = now + 2000
		_toast("再按一次确认弃局！")


func _after_action(ev: Dictionary) -> void:
	if engine.finished == "win" and not _ended:
		_win()
	elif engine.finished == "dead" and not _ended:
		_lose()
	elif not engine.any_move():
		_toast("无路可走——撤销或弃局！")
	_update_hud()
	queue_redraw()


func _win() -> void:
	_ended = true
	_toast("织网完成！")
	fx.shake(4.0)
	fx.burst(Vector2(320, 160), [Color(1, 0.95, 0.6), Color(0.72, 0.6, 1.0), Color(1, 1, 1)], 40, 110.0)
	var data := {
		"sets": engine.completed,
		"deals_left": engine.deals_left(),
		"pending": pending_silk,
		"boss": str(node_info.get("type", "")) == "boss",
	}
	run.stats["encounters"] = int(run.stats["encounters"]) + 1
	run.stats["sets"] = int(run.stats["sets"]) + engine.completed
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if on_win.is_valid():
			on_win.call(data))


func _lose() -> void:
	_ended = true
	if on_lose.is_valid():
		on_lose.call()


# ---------------- 布局 ----------------

func _col_origin(col_idx: int) -> Vector2:
	var cols := engine.columns.size()
	var total := cols * CW + (cols - 1) * GAP
	var x0 := int((640.0 - total) / 2.0)
	return Vector2(x0 + col_idx * (CW + GAP), TOP_Y)


func _stack_positions(col_idx: int) -> Array:
	var col: Array = engine.columns[col_idx]
	var n := col.size()
	if n == 0:
		return []
	var offs: Array = []
	for i in n:
		offs.append(DOWN_OFF if not col[i].face_up else UP_OFF)
	var total := 0
	for o in offs:
		total += int(o)
	var max_total := LIMIT_Y - TOP_Y - CH
	if total > max_total and total > 0:
		var f := float(max_total) / float(total)
		for i in offs.size():
			offs[i] = maxi(2, int(int(offs[i]) * f))
	# 标准蜘蛛纸牌布局：j=0（堆底，多为暗牌）在视觉顶部，j=n-1（堆顶，面朝上）在视觉底部
	var pos_by_j: Array = []
	pos_by_j.resize(n)
	var y := int(_col_origin(col_idx).y)
	for j in n:
		pos_by_j[j] = Vector2(_col_origin(col_idx).x, y)
		y += int(offs[j])
	return pos_by_j


func _column_at(x: float) -> int:
	if engine == null:
		return -1
	for i in engine.columns.size():
		var o := _col_origin(i)
		if x >= o.x and x <= o.x + CW:
			return i
	return -1


func _card_at(col_idx: int, pos: Vector2) -> int:
	var col: Array = engine.columns[col_idx]
	if col.is_empty():
		return -1
	var poss := _stack_positions(col_idx)
	var n := col.size()
	for j in range(n - 1, -1, -1):
		var vis_h: int = CH if j == n - 1 else int(poss[j + 1].y - poss[j].y)
		if pos.y >= poss[j].y and pos.y < poss[j].y + vis_h:
			return j
	return -1


## 牌当前应渲染的位置（考虑移动动画偏移）
func _card_render_pos(col_idx: int, j: int, card: Card) -> Vector2:
	for m in _moves:
		if m["card"] == card and m["delay"] <= 0:
			var te := 1.0 - pow(1.0 - float(m["t"]), 2.0)
			var p: Vector2 = (m["from"] as Vector2).lerp(m["to"], te)
			p.y -= sin(float(m["t"]) * PI) * 12.0
			return p
	if _moves.any(func(m): return m["card"] == card):
		return _moves.filter(func(m): return m["card"] == card)[0]["from"]
	return _stack_positions(col_idx)[j]


# ---------------- 渲染 ----------------

func _draw() -> void:
	if engine == null:
		return
	# 背景：AI 美术（诅咒之塔内部），牌桌区加暗罩保证牌面可读
	if _bg_tex != null:
		draw_texture_rect(_bg_tex, Rect2(0, 0, 640, 360), false)
		draw_rect(Rect2(0, 32, 640, 298), Color(0.05, 0.04, 0.10, 0.42))
	else:
		draw_rect(Rect2(0, 0, 640, 360), BG)
		draw_rect(Rect2(0, 32, 640, 298), FELT)
	# 漂浮孢子粒子（环境氛围）
	var t := Time.get_ticks_msec() / 1000.0
	for i in 14:
		var sx := fmod(i * 137.5 + t * 12.0, 640.0)
		var sy := fmod(i * 89.3 + sin(t * 0.5 + i) * 8.0, 330.0) + 32.0
		var a2 := 0.10 + 0.08 * sin(t * 1.3 + i * 1.7)
		draw_circle(Vector2(sx, sy), 1.0, Color(0.72, 0.60, 1.0, a2))
	for i in engine.columns.size():
		var o := _col_origin(i)
		draw_rect(Rect2(o, Vector2(CW, CH)), Color(0.14, 0.11, 0.24), false)
	# 选中时可落点提示
	if sel_col >= 0 and sel_start >= 0:
		var col: Array = engine.columns[sel_col]
		if sel_start < col.size():
			var head: Card = col[sel_start]
			for j in engine.columns.size():
				if j == sel_col:
					continue
				if engine.can_drop(head, j):
					var o2 := _col_origin(j)
					draw_rect(Rect2(o2 - Vector2(2, 2), Vector2(CW + 4, CH + 4)), Color(0.8, 0.75, 1.0, 0.30), false)
	# 教学高亮：提示可拾取的序列
	if _tut_step == 0:
		var hint := _first_pickable()
		if not hint.is_empty():
			var poss := _stack_positions(hint[0])
			var glow := 0.25 + 0.15 * sin(Time.get_ticks_msec() / 200.0)
			for j in range(hint[1], engine.columns[hint[0]].size()):
				draw_rect(Rect2(poss[j] - Vector2(1, 1), Vector2(CW + 2, CH + 2)), Color(1.0, 0.95, 0.5, glow), false)
	# 牌
	for i in engine.columns.size():
		var poss := _stack_positions(i)
		var c2: Array = engine.columns[i]
		for j in c2.size():
			var card: Card = c2[j]
			if _hidden.has(card):
				continue
			var pos: Vector2 = poss[j]
			# 移动动画覆盖位置
			for m in _moves:
				if m["card"] == card:
					if m["delay"] > 0:
						pos = m["from"]
					else:
						var te: float = 1.0 - pow(1.0 - float(m["t"]), 2.0)
						pos = (m["from"] as Vector2).lerp(m["to"], te)
						pos.y -= sin(float(m["t"]) * PI) * 12.0
					break
			var flip_t: float = _flips.get(card, 1.0)
			_draw_card(card, pos, i == sel_col and j >= sel_start, flip_t)
	# 底栏：剩余发牌（迷你牌背）
	var dl := engine.deals_left()
	for k in dl:
		var x := 196 + k * 12
		draw_rect(Rect2(x, 342, 10, 14), Color(0.10, 0.08, 0.18))
		draw_rect(Rect2(x, 342, 10, 14), Color(0.55, 0.44, 0.82), false)
	# 蜘蛛信标：预览下次发牌花色
	if run != null and run.has_relic("beacon") and engine.stock.size() > 0:
		var preview: Array = engine.stock.slice(0, engine.columns.size())
		for k in preview.size():
			var c: Card = preview[k]
			Pixel.draw_icon(self, Pixel.SUIT_ICONS[c.suit], Vector2(196 + k * 10, 333), 1, Pixel.suit_color(c.suit))
	# 已完成序列（右下）
	for k in completed_suits.size():
		Pixel.draw_icon(self, Pixel.SUIT_ICONS[completed_suits[k]], Vector2(560 + (k % 6) * 10, 344 + int(k / 6) * 9), 1, Pixel.suit_color(completed_suits[k]))


func _draw_card(c: Card, pos: Vector2, selected: bool, flip_t: float = 1.0) -> void:
	var p := Vector2(int(pos.x), int(pos.y))
	# 翻牌动画：宽度随 t 缩放
	var scale_x := 1.0
	if flip_t < 0.5:
		scale_x = flip_t * 2.0
		_draw_card_back(Rect2(p + Vector2((CW - CW * scale_x) / 2, 0), Vector2(CW * scale_x, CH)), false)
		return
	elif flip_t < 1.0:
		scale_x = (flip_t - 0.5) * 2.0
	var w2 := maxi(1, int(CW * scale_x))
	var px := p + Vector2((CW - w2) / 2, 0)
	var rect := Rect2(px, Vector2(w2, CH))
	if not c.face_up:
		_draw_card_back(rect, c.mark == "seer", Pixel.suit_color(c.suit) if c.mark == "seer" else Color.TRANSPARENT)
		if c.cocooned:
			_draw_cocoon(p)
		if selected:
			_draw_select_glow(rect)
		return
	# ---- 明牌 ----
	var sc := Pixel.suit_color(c.suit)
	# 牌面底色：深底+微妙渐变感（上亮下暗）
	var face_dark := Color(0.16, 0.13, 0.26)
	var face_mid := Color(0.21, 0.17, 0.33)
	if _face_tex != null:
		# AI 美术牌面底模（华丽边框），点数花色仍程序绘制保证可读
		draw_texture_rect(_face_tex, rect, false)
		draw_rect(rect, Color(0.03, 0.03, 0.08, 0.18))
	else:
		draw_rect(Rect2(px, Vector2(w2, CH / 2)), face_mid)
		draw_rect(Rect2(px + Vector2(0, CH / 2), Vector2(w2, CH / 2)), face_dark)
		# 顶部高光条
		draw_rect(Rect2(px + Vector2(1, 1), Vector2(w2 - 2, 2)), Color(1, 1, 1, 0.08))
	# 边框：花色发光 + 印记色
	var border := sc.darkened(0.25)
	if c.is_wild():
		border = Color(0.90, 0.75, 0.30)
	elif c.mark == "gold":
		border = Color(0.95, 0.80, 0.20)
	elif c.mark == "double":
		border = Color(0.30, 0.85, 0.95)
	elif c.mark == "awake":
		border = Color(0.45, 0.95, 0.55)
	draw_rect(Rect2(px, Vector2(w2, CH)), border, false, 2.0)
	if scale_x < 0.8:
		return
	# 顶部条：点数 + 花色图标（左点数右图标）
	draw_rect(Rect2(px + Vector2(2, 2), Vector2(w2 - 4, 13)), Color(0.08, 0.07, 0.13, 0.75))
	Pixel.draw_text(self, c.rank_label(), px + Vector2(4, 4), 1, Color.WHITE)
	Pixel.draw_icon(self, Pixel.SUIT_ICONS[c.suit], px + Vector2(w2 - 16, 4), 1, sc)
	# 中央大图标（J/Q/K 用花色人物插画，数字牌画大花色）
	if c.rank >= 11:
		# 人头牌：中央画框 + AI 人物插画（组件拼装，小丑牌式）
		var panel := Rect2(px + Vector2(6, 18), Vector2(w2 - 12, 26))
		if _court_tex.has(c.suit):
			# 正方形插画填进扁画框：keep_aspect_centered 会等比放大并居中裁掉上下
			draw_texture_rect(_court_tex[c.suit], Rect2(panel.position + Vector2(1, 1), panel.size - Vector2(2, 2)), false, Color(1, 1, 1), true)
		else:
			draw_rect(panel, face_mid)
			Pixel.draw_icon(self, Pixel.SUIT_ICONS[c.suit], px + Vector2(11, 21), 3, sc)
		draw_rect(panel, border, false)
		# 人头字母
		Pixel.draw_text(self, c.rank_label(), px + Vector2(w2 / 2 - 3, 46), 1, sc)
	else:
		# 数字牌：中央大花色图标
		Pixel.draw_icon(self, Pixel.SUIT_ICONS[c.suit], px + Vector2(w2 / 2 - 10, 22), 3, sc)
		# 底部点数
		Pixel.draw_text(self, c.rank_label(), px + Vector2(w2 / 2 - 3, 46), 1, sc.darkened(0.2))
	# 百搭：四角花色
	if c.is_wild():
		for q in 4:
			var qx := 3 if q % 2 == 0 else w2 - 9
			var qy := 17 if q < 2 else CH - 11
			Pixel.draw_icon(self, Pixel.SUIT_ICONS[q], px + Vector2(qx, qy), 1, Pixel.suit_color(q))
	# 印记底标
	if c.mark == "gold":
		draw_rect(Rect2(px + Vector2(3, CH - 8), Vector2(w2 - 6, 5)), Color(0.95, 0.80, 0.20, 0.35))
	elif c.mark == "double":
		draw_rect(Rect2(px + Vector2(3, CH - 8), Vector2(w2 - 6, 5)), Color(0.30, 0.85, 0.95, 0.35))
	if c.cocooned:
		_draw_cocoon(p)
	if selected:
		_draw_select_glow(rect)


func _draw_card_back(rect: Rect2, seer: bool = false, seer_color: Color = Color.TRANSPARENT) -> void:
	var p := rect.position
	var s := rect.size
	if _back_tex != null:
		# AI 美术牌背（蛛网曼陀罗），微暗化让明牌更突出
		draw_texture_rect(_back_tex, rect, false)
		draw_rect(rect, Color(0.02, 0.02, 0.06, 0.25))
	else:
		# 兜底：程序化牌背
		draw_rect(rect, Color(0.10, 0.08, 0.17))
		var cc := p + s / 2
		for a in 6:
			var d := Vector2.RIGHT.rotated(TAU * a / 6.0)
			draw_line(cc, cc + d * s.x * 0.45, Color(0.20, 0.16, 0.32), 1.0)
		for r in [6, 12, 18]:
			draw_arc(cc, r, 0, TAU, 16, Color(0.20, 0.16, 0.32), 1.0)
		draw_rect(rect, Color(0.45, 0.36, 0.70), false, 2.0)
	# seer 印记：顶部花色色条
	if seer:
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(s.x - 4, 4)), seer_color)


func _draw_select_glow(rect: Rect2) -> void:
	var glow := 0.5 + 0.3 * sin(Time.get_ticks_msec() / 120.0)
	draw_rect(Rect2(rect.position - Vector2(2, 2), rect.size + Vector2(4, 4)), Color(1.0, 0.90, 0.40, glow), false, 2.0)
	draw_rect(Rect2(rect.position - Vector2(1, 1), rect.size + Vector2(2, 2)), Color(1.0, 1.0, 1.0, glow * 0.7), false)


func _draw_cocoon(p: Vector2) -> void:
	for k in 3:
		draw_rect(Rect2(p + Vector2(4, 20 + k * 6), Vector2(CW - 8, 2)), Color(0.95, 0.95, 0.90, 0.75))


# ---------------- 教学 ----------------

func _tutorial_check() -> void:
	# 仅巢一第一关启用
	if int(node_info.get("nest", 9)) != 1 or str(node_info.get("name", "")) != "初醒之网":
		_tut_step = 4
		return
	_tut_step = 0
	var hint := _first_pickable()
	if not hint.is_empty():
		_tut_step = 1
		var pos: Vector2 = _stack_positions(hint[0])[hint[1]]
		fx.show_hint("点发光的牌选中一段序列", pos + Vector2(CW / 2, 20), 4.0)


func _first_pickable() -> Array:
	for i in engine.columns.size():
		var st := engine.max_run_start(i)
		if st >= 0:
			var col: Array = engine.columns[i]
			# 找一个有合法落点的序列
			var head: Card = col[st]
			for j in engine.columns.size():
				if j != i and engine.can_drop(head, j):
					return [i, st]
	return []


# ---------------- HUD ----------------

func _update_hud() -> void:
	if engine == null:
		return
	var nest := int(node_info.get("nest", 1))
	lbl_goal.text = "序列 %d/%d" % [engine.completed, engine.target]
	lbl_deal.text = "发牌 %d" % engine.deals_left()
	lbl_undo.text = "撤销 %d" % engine.undo_left
	var silk_txt := "丝 %d" % run.silk
	if pending_silk > 0:
		silk_txt += " (+%d)" % pending_silk
	lbl_silk.text = silk_txt
	lbl_title.text = "巢%s · %s" % [_cn_num(nest), str(node_info.get("name", ""))]
	btn_deal.text = "发牌 (%d)" % engine.deals_left()
	btn_undo.text = "撤销 (%d)" % engine.undo_left
	btn_deal.disabled = not engine.can_deal()


func _cn_num(n: int) -> String:
	match n:
		1: return "一"
		2: return "二"
		3: return "三"
		4: return "四"
		5: return "五"
	return str(n)


func _toast(text: String) -> void:
	lbl_toast.text = text
	lbl_toast.visible = true
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		lbl_toast.visible = false)


func _build_hud() -> void:
	lbl_title = Ui.label(self, "", Vector2(6, 4), 9, Color(0.95, 0.92, 1.0))
	lbl_rule = Ui.label(self, "", Vector2(6, 18), 8, Color(0.95, 0.75, 0.55))
	lbl_goal = Ui.label(self, "", Vector2(300, 6), 10)
	lbl_deal = Ui.label(self, "", Vector2(372, 6), 10)
	lbl_undo = Ui.label(self, "", Vector2(438, 6), 10)
	lbl_silk = Ui.label(self, "", Vector2(510, 6), 10, Color(0.98, 0.85, 0.45))
	lbl_toast = Ui.label(self, "", Vector2(320, 78), 9, Color(1.0, 0.95, 0.7))
	lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_toast.size = Vector2(640, 14)
	lbl_toast.visible = false
	btn_deal = Ui.button(self, "发牌", Vector2(6, 334), Vector2(60, 22), _on_deal_pressed)
	btn_undo = Ui.button(self, "撤销", Vector2(70, 334), Vector2(60, 22), _on_undo_pressed)
	btn_quit = Ui.button(self, "弃局", Vector2(134, 334), Vector2(48, 22), _on_quit_pressed)
