extends Node
## 主状态机：标题 → 塔 → 遭遇/商店/事件 → 奖励 → 胜利/失败。

var run: RunState
var screen: Control


func _ready() -> void:
	randomize()
	_show_title()


func _set_screen(c: Control) -> void:
	if screen != null:
		screen.queue_free()
	screen = c
	c.position = Vector2.ZERO
	c.size = Vector2(640, 360)
	add_child(c)


# ---------------- 标题 / 帮助 ----------------

func _show_title() -> void:
	var c := Control.new()
	c.theme = Ui.make_theme()
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var art: Texture2D = load("res://assets/title_art.png")
	c.draw.connect(func() -> void:
		if art != null:
			c.draw_texture_rect(art, Rect2(0, 0, 640, 360), false)
			# 标题区暗带，保证文字可读
			c.draw_rect(Rect2(0, 38, 640, 92), Color(0.03, 0.02, 0.07, 0.55))
		else:
			c.draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.06, 0.12)))
	var t1 := Ui.label(c, "织 网 者", Vector2(320, 46), 34, Color(0.97, 0.94, 1.0))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.9))
	t1.add_theme_constant_override("outline_size", 5)
	var t2 := Ui.label(c, "诅 咒 之 塔", Vector2(320, 100), 14, Color(0.85, 0.75, 1.0))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.9))
	t2.add_theme_constant_override("outline_size", 3)
	Ui.label(c, "蜘蛛纸牌 × 肉鸽构筑 · DEMO v0.2", Vector2(320, 250), 9, Color(0.85, 0.80, 0.95)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(c, "最熟悉的纸牌，最没见过的打法。", Vector2(320, 268), 9, Color(0.85, 0.80, 0.95)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.button(c, "开始织网", Vector2(270, 292), Vector2(100, 26), _start_run, 12)
	Ui.button(c, "玩法说明", Vector2(270, 324), Vector2(100, 20), _show_help, 9)
	_set_screen(c)


func _show_help() -> void:
	var c := Control.new()
	c.theme = Ui.make_theme()
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.06, 0.12)))
	Ui.label(c, "玩法说明", Vector2(10, 6), 12)
	var lines := [
		"你是被诅咒变成蜘蛛的织女阿剌克涅，要织出完美的网爬出诅咒之塔。",
		"",
		"【牌桌】经典的蜘蛛纸牌：",
		"· 同花色降序序列可整体移动；落点为任意花色大 1 点的牌或空列。",
		"· K 到 A 的完整同花色序列自动消除，消除够目标组数即过关。",
		"· 每列初始 4 暗 1 明；发牌给每列追加 1 张明牌，有空列时不能发牌。",
		"",
		"【肉鸽】",
		"· 过关判定是资源制：发牌次数有限，用尽且无路可走即失败。",
		"· 一败即溃：任何一局失败，整次攀登从头再来。",
		"· 撤销是稀缺资源（每局 2 次），遗物和事件可以增加。",
		"· 局间在商店购买遗物与印记；印记永久刻在你的牌上。",
		"· 塔层越高花色越多：巢一仅蜘蛛，巢二加飞蛾，巢三四花色全开。",
		"",
		"【操作】左键点选一段序列，再点目标列落下；右键取消选择。",
		"花色颜色：紫=蜘蛛 红=飞蛾 蓝=甲虫 绿=蜈蚣。",
	]
	var y := 26
	for line in lines:
		Ui.label(c, str(line), Vector2(14, y), 9)
		y += 14
	Ui.button(c, "返回", Vector2(560, 334), Vector2(70, 20), _show_title, 9)
	_set_screen(c)


# ---------------- Run 流程 ----------------

func _start_run() -> void:
	run = RunState.new()
	_show_tower()


func _timeline() -> Array:
	return Encounters.timeline()


func _show_tower() -> void:
	var c := Control.new()
	c.theme = Ui.make_theme()
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var art: Texture2D = load("res://assets/bg_table.png")
	c.draw.connect(func() -> void:
		if art != null:
			c.draw_texture_rect(art, Rect2(0, 0, 640, 360), false)
			# 整体压暗，保证节点列表可读
			c.draw_rect(Rect2(0, 0, 640, 360), Color(0.03, 0.02, 0.07, 0.62))
		else:
			c.draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.06, 0.12))
		c.draw_rect(Rect2(310, 0, 20, 360), Color(0.12, 0.09, 0.20, 0.7)))
	var tl := _timeline()
	var node: Dictionary = tl[run.timeline_idx]
	var nest := int(node.get("nest", 1))
	Ui.label(c, "诅咒之塔", Vector2(320, 6), 14, Color(0.95, 0.92, 1.0)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(c, "巢%s · 塔层 %d / %d" % [_cn(nest), run.timeline_idx + 1, tl.size()], Vector2(320, 26), 9, Color(0.65, 0.60, 0.80)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 塔层进度（自上而下显示，塔顶在上方）
	var y := 48
	var shown: Array = []
	for i in range(tl.size() - 1, -1, -1):
		shown.append(i)
	for i in shown:
		var n: Dictionary = tl[i]
		var done: bool = i < run.timeline_idx
		var cur: bool = i == run.timeline_idx
		var col := Color(0.40, 0.36, 0.52)
		if done:
			col = Color(0.30, 0.27, 0.42)
		elif cur:
			col = Color(0.98, 0.85, 0.45)
		var txt := _node_label(n)
		if done:
			txt = "· " + txt
		elif cur:
			txt = "> " + txt
		else:
			txt = "  " + txt
		var l := Ui.label(c, txt, Vector2(340, y), 9, col)
		if cur:
			l.add_theme_font_size_override("font_size", 10)
		y += 15
	# 左侧：状态
	Ui.label(c, "丝 %d" % run.silk, Vector2(16, 48), 12, Color(0.98, 0.85, 0.45))
	Ui.label(c, "遗物", Vector2(16, 70), 10, Color(0.75, 0.70, 0.90))
	var ry := 86
	if run.relic_ids.is_empty():
		Ui.label(c, "（暂无）", Vector2(16, ry), 9, Color(0.45, 0.42, 0.55))
	for rid in run.relic_ids:
		Ui.label(c, "· " + str(Relics.DATA[rid]["name"]), Vector2(16, ry), 9, Color(0.85, 0.80, 1.0))
		ry += 13
	var next_n: Dictionary = tl[run.timeline_idx]
	Ui.wrap_label(c, "%s\n%s" % [str(next_n.get("name", "")), str(next_n.get("desc", ""))], Vector2(16, 240), 260, 8)
	var btn_txt := "迎战诅咒之源" if str(next_n.get("type", "")) == "boss" else "继续攀登"
	Ui.button(c, btn_txt, Vector2(16, 320), Vector2(120, 26), _enter_node, 12)
	_set_screen(c)


func _node_label(n: Dictionary) -> String:
	match str(n.get("type", "")):
		"enc": return "遭遇 · " + str(n.get("name", ""))
		"boss": return "BOSS · " + str(n.get("name", ""))
		"shop": return "商店"
		"event": return "奇遇"
	return "？"


func _cn(n: int) -> String:
	match n:
		1: return "一"
		2: return "二"
		3: return "三"
		4: return "四"
		5: return "五"
	return str(n)


func _enter_node() -> void:
	var node: Dictionary = _timeline()[run.timeline_idx]
	match str(node.get("type", "")):
		"enc", "boss":
			_start_encounter(node)
		"shop":
			_show_shop(node)
		"event":
			_show_event(node)
		_:
			_node_done()


# ---------------- 遭遇战 ----------------

func _start_encounter(node: Dictionary) -> void:
	var deals := int(node.get("deals", 3)) + (1 if run.has_relic("egg") else 0)
	var cols := int(node.get("cols", 8))
	var undo := 2 + (2 if run.has_relic("pendant") else 0) + run.pending_undo_bonus
	run.pending_undo_bonus = 0
	var target := int(node.get("target", 2))
	if run.has_relic("amber"):
		target = maxi(1, target - 1)
	var suits: Array = node.get("suits", [0])
	var cards := run.build_encounter_cards(suits, cols * (5 + deals))
	var engine := SpiderEngine.new()
	engine.setup(cards, {
		"cols": cols, "deals": deals, "target": target, "undo": undo,
		"flags": run.relic_flags(), "name": str(node.get("name", "")),
		"reveal": int(node.get("reveal", 0)),
	})
	engine.apply_start_relics()
	var tv := TableView.new()
	tv.engine = engine
	tv.run = run
	tv.node_info = node
	tv.on_win = _encounter_won
	tv.on_lose = _encounter_lost
	_set_screen(tv)


func _encounter_won(data: Dictionary) -> void:
	var sets: int = data["sets"]
	var deals_left: int = data["deals_left"]
	var pending: int = data["pending"]
	var base := sets * 3
	var moon := 0
	if run.has_relic("moonlight"):
		moon = sets * 2
	var unused := deals_left * 2
	var boss_bonus := 0
	var is_boss: bool = data.get("boss", false)
	if is_boss:
		boss_bonus = 10
	var total := base + moon + unused + pending + boss_bonus
	run.silk += total
	var c := Control.new()
	c.theme = Ui.make_theme()
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(0, 0, 640, 360), Color(0.05, 0.04, 0.09))
		c.draw_rect(Rect2(140, 70, 360, 220), Color(0.10, 0.08, 0.19))
		c.draw_rect(Rect2(140, 70, 360, 220), Color(0.45, 0.38, 0.70), false))
	Ui.label(c, "织网完成", Vector2(320, 86), 16, Color(0.95, 0.92, 1.0)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lines := [
		"完成序列 × %d        + %d 丝" % [sets, base],
	]
	if moon > 0:
		lines.append("月光纱加成        + %d 丝" % moon)
	lines.append("剩余发牌 × %d        + %d 丝" % [deals_left, unused])
	if pending > 0:
		lines.append("印记与遗物收益    + %d 丝" % pending)
	if boss_bonus > 0:
		lines.append("诅咒之源战利品    + %d 丝" % boss_bonus)
	lines.append("")
	lines.append("共获得 %d 缕蛛丝" % total)
	var y := 116
	for line in lines:
		Ui.label(c, str(line), Vector2(180, y), 10, Color(0.90, 0.87, 1.0))
		y += 17
	Ui.button(c, "继续", Vector2(270, 244), Vector2(100, 24), _reward_continue.bind(is_boss), 11)
	_set_screen(c)


func _reward_continue(is_boss: bool) -> void:
	if is_boss:
		_show_victory()
	else:
		_node_done()


func _encounter_lost() -> void:
	var c := Control.new()
	c.theme = Ui.make_theme()
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(0, 0, 640, 360), Color(0.10, 0.03, 0.05)))
	Ui.label(c, "丝线断裂", Vector2(320, 120), 22, Color(1.0, 0.45, 0.45)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(c, "塔吞掉了你织到一半的网。但织女的手，还记得每一次落牌。", Vector2(320, 160), 10, Color(0.75, 0.65, 0.70)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(c, "本次攀登：%d 个遭遇 · %d 组序列 · %d 次撤销" % [int(run.stats["encounters"]), int(run.stats["sets"]), int(run.stats["undo_used"])], Vector2(320, 180), 9, Color(0.55, 0.48, 0.58)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.button(c, "从头再来", Vector2(270, 220), Vector2(100, 24), _start_run, 11)
	Ui.button(c, "回到标题", Vector2(270, 250), Vector2(100, 20), _show_title, 9)
	_set_screen(c)


# ---------------- 商店 / 事件 ----------------

func _next_encounter_suits() -> Array:
	var tl := _timeline()
	for i in range(run.timeline_idx, tl.size()):
		var n: Dictionary = tl[i]
		var t := str(n.get("type", ""))
		if t == "enc" or t == "boss":
			return n.get("suits", [0])
	return [0]


func _show_shop(_node: Dictionary) -> void:
	var s := ShopScreen.new(run, _next_encounter_suits(), _node_done)
	_set_screen(s)


func _show_event(_node: Dictionary) -> void:
	var picked: Dictionary = Events.pick(run.used_events)
	if picked.is_empty():
		_node_done()
		return
	run.used_events.append(int(picked["index"]))
	var data: Dictionary = picked["data"]
	if run.has_relic("atlas"):
		var opts: Array = data["opts"].duplicate()
		opts.append(Events.ATLAS_EXTRA.duplicate())
		data = data.duplicate()
		data["opts"] = opts
	var e := EventScreen.new(data, _apply_event_effect, _node_done)
	_set_screen(e)


func _apply_event_effect(effect: Dictionary) -> String:
	var parts: Array = []
	var silk: int = int(effect.get("silk", 0))
	if silk != 0:
		run.silk = maxi(0, run.silk + silk)
		if silk > 0:
			parts.append("获得 %d 缕蛛丝。" % silk)
		else:
			parts.append("失去了 %d 缕蛛丝。" % -silk)
	if effect.get("relic", false):
		var offers := Relics.random_offers(run.relic_ids, 1)
		if offers.is_empty():
			parts.append("旧货商已经没有新货了，退给你 3 缕蛛丝。")
			run.silk += 3
		else:
			var rid := str(offers[0])
			run.gain_relic(rid)
			parts.append("获得遗物「%s」：%s" % [str(Relics.DATA[rid]["name"]), str(Relics.DATA[rid]["desc"])])
	if effect.has("mark"):
		var m: Dictionary = effect["mark"]
		var applied := run.apply_random_mark(str(m["id"]), int(m["count"]), _next_encounter_suits())
		parts.append("%d 张牌获得%s。" % [applied, str(Marks.DATA[m["id"]]["name"])])
	if effect.has("mark_random"):
		var ids := Marks.purchasable_ids()
		var mid := str(ids[randi() % ids.size()])
		var applied2 := run.apply_random_mark(mid, int(effect["mark_random"]), _next_encounter_suits())
		parts.append("%d 张牌获得%s。" % [applied2, str(Marks.DATA[mid]["name"])])
	if effect.has("cocoon"):
		var cursed := run.apply_random_mark("cocoon", int(effect["cocoon"]), _next_encounter_suits())
		parts.append("%d 张牌被茧印缠住——它们无法移动，只能随序列消除解除。" % cursed)
	var un: int = int(effect.get("undo_next", 0))
	if un > 0:
		run.pending_undo_bonus += un
		parts.append("下一局撤销次数 +%d。" % un)
	if parts.is_empty():
		parts.append("什么也没有发生。塔在静静地看着你。")
	return " ".join(PackedStringArray(parts))


# ---------------- 流程推进 / 结局 ----------------

func _node_done() -> void:
	run.timeline_idx += 1
	if run.timeline_idx >= _timeline().size():
		_show_victory()
	else:
		_show_tower()


func _show_victory() -> void:
	var c := Control.new()
	c.theme = Ui.make_theme()
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.05, 0.11))
		for r in [40, 70, 100]:
			c.draw_arc(Vector2(320, 140), r, 0, TAU, 40, Color(0.30, 0.24, 0.48), 1)
		Pixel.draw_icon(c, "web", Vector2(310, 130), 3, Color(0.72, 0.60, 1.0)))
	Ui.label(c, "你爬出了诅咒之塔", Vector2(320, 70), 18, Color(0.95, 0.92, 1.0)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(c, "镜中的影子消散了。网还在——这一次，它是你自己的。", Vector2(320, 210), 10, Color(0.75, 0.72, 0.88)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(c, "本次攀登：%d 个遭遇 · %d 组序列 · %d 次撤销 · 遗物 %d 件" % [
		int(run.stats["encounters"]), int(run.stats["sets"]), int(run.stats["undo_used"]), run.relic_ids.size()],
		Vector2(320, 236), 9, Color(0.60, 0.56, 0.75)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(c, "DEMO 到此为止。正式版：巢四巢五、每日挑战、局外成长。", Vector2(320, 256), 8, Color(0.45, 0.42, 0.58)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.button(c, "再来一次", Vector2(270, 290), Vector2(100, 24), _start_run, 11)
	Ui.button(c, "回到标题", Vector2(270, 320), Vector2(100, 20), _show_title, 9)
	_set_screen(c)
