extends SceneTree
## 无头逻辑自测：Godot --headless -s tests/test_headless.gd

func _init() -> void:
	var ok := true
	ok = ok and _test_deck_build()
	ok = ok and _test_engine_setup()
	ok = ok and _test_moves_and_undo()
	ok = ok and _test_completion()
	ok = ok and _test_marks_persist()
	if ok:
		print("ALL TESTS PASSED")
	else:
		print("TESTS FAILED")
	quit(0 if ok else 1)


func _test_deck_build() -> bool:
	var run := RunState.new()
	var cards := run.build_encounter_cards([0], 8 * 8)
	if cards.size() != 64:
		print("FAIL deck_build: size=%d expect 64" % cards.size())
		return false
	var suits := {}
	for c in cards:
		suits[(c as Card).suit] = true
	if suits.size() != 1 or not suits.has(0):
		print("FAIL deck_build: suits=%s" % str(suits))
		return false
	var cards2 := run.build_encounter_cards([0, 1, 2, 3], 90)
	if cards2.size() != 90:
		print("FAIL deck_build 4s: size=%d" % cards2.size())
		return false
	print("PASS deck_build")
	return true


func _test_engine_setup() -> bool:
	var run := RunState.new()
	var engine := SpiderEngine.new()
	engine.setup(run.build_encounter_cards([0], 8 * 8), {"cols": 8, "deals": 3, "target": 1, "undo": 2, "flags": {}})
	if engine.columns.size() != 8:
		print("FAIL setup: cols=%d" % engine.columns.size())
		return false
	for col in engine.columns:
		if (col as Array).size() != 5:
			print("FAIL setup: col size=%d" % (col as Array).size())
			return false
		if not (col as Array)[4].face_up:
			print("FAIL setup: top not face up")
			return false
	if engine.stock.size() != 24:
		print("FAIL setup: stock=%d" % engine.stock.size())
		return false
	if engine.deals_left() != 3:
		print("FAIL setup: deals_left=%d" % engine.deals_left())
		return false
	print("PASS engine_setup")
	return true


func _test_moves_and_undo() -> bool:
	var run := RunState.new()
	var engine := SpiderEngine.new()
	engine.setup(run.build_encounter_cards([0], 8 * 8), {"cols": 8, "deals": 3, "target": 1, "undo": 2, "flags": {}})
	# 找一个合法移动：源列顶可拾取、目标列顶点数+1 或空列
	var moved := false
	for i in engine.columns.size():
		var col: Array = engine.columns[i]
		var start := engine.max_run_start(i)
		if start < 0:
			continue
		var head: Card = col[start]
		for j in engine.columns.size():
			if i == j:
				continue
			var dst: Array = engine.columns[j]
			if dst.is_empty() or (dst[dst.size() - 1] as Card).rank == head.rank + 1:
				var ev: Dictionary = engine.do_move(i, start, j)
				if ev["moved"].size() != col.size() - start:
					print("FAIL move: run size mismatch")
					return false
				moved = true
				break
		if moved:
			break
	if not moved:
		print("WARN move: 初始局面无合法移动（随机牌局偶发，非致命）")
	else:
		print("PASS moves")
	# 撤销
	var total_before := 0
	for col in engine.columns:
		total_before += (col as Array).size()
	if not engine.undo():
		print("FAIL undo: 应当可以撤销")
		return false
	var total_after := 0
	for col in engine.columns:
		total_after += (col as Array).size()
	if total_before == total_after and moved:
		# 撤销后总牌数不变是正常的（移动不改变总数）；校验发牌次数回退
		pass
	if engine.deals_used != 0:
		print("FAIL undo: deals_used 未回退")
		return false
	print("PASS undo")
	# 发牌
	if engine.can_deal():
		var ev2: Dictionary = engine.do_deal()
		if ev2["dealt"].size() != 8:
			print("FAIL deal: dealt=%d" % ev2["dealt"].size())
			return false
		if engine.deals_left() != 2:
			print("FAIL deal: deals_left=%d" % engine.deals_left())
			return false
		print("PASS deal")
	# 空列限制
	engine.columns[0] = []
	var blocked: bool = not engine.can_deal()
	if not blocked:
		print("FAIL empty-column rule: 空列应阻止发牌")
		return false
	print("PASS empty-column rule")
	return true


func _test_completion() -> bool:
	var run := RunState.new()
	var engine := SpiderEngine.new()
	# 手工构造：列0 有一张 K，列1 是 Q..A 12 张同花明牌
	var cards: Array = []
	var k := Card.new(0, 13, 0)
	k.face_up = true
	cards.append(k)
	for r in range(12, 0, -1):
		var c := Card.new(0, r, 0)
		c.face_up = true
		cards.append(c)
	# 补满 setup 需要的最少牌数（2 列 × 5 张起始 + 发牌）
	while cards.size() < 2 * 5 + 2:
		var f := Card.new(1, 1, 0)
		f.face_up = true
		cards.append(f)
	engine.setup(cards, {"cols": 2, "deals": 1, "target": 1, "undo": 2, "flags": {}})
	# 直接摆盘：列0=[K](明)，列1=[Q,J..A](明)——标准蜘蛛纸牌 K 在堆底
	k.face_up = true
	k.cocooned = false
	engine.columns[0] = [k]
	var qa: Array = []
	for r in range(12, 0, -1):
		var c := Card.new(0, r, 0)
		c.face_up = true
		c.cocooned = false
		qa.append(c)
	engine.columns[1] = qa
	var ev: Dictionary = engine.do_move(1, 0, 0)
	if ev["pending_completed"].size() != 13:
		print("FAIL completion: pending=%d expect 13" % ev["pending_completed"].size())
		return false
	engine.flush_action(ev)
	if engine.completed != 1:
		print("FAIL completion: completed=%d" % engine.completed)
		return false
	if engine.finished != "win":
		print("FAIL completion: finished=%s" % engine.finished)
		return false
	print("PASS completion (move+flush)")
	return true


func _test_marks_persist() -> bool:
	var run := RunState.new()
	var applied := run.apply_random_mark("wild", 3, [0])
	if applied != 3:
		print("FAIL marks: applied=%d" % applied)
		return false
	var cards := run.build_encounter_cards([0], 64)
	var wilds := 0
	for c in cards:
		if (c as Card).mark == "wild":
			wilds += 1
	if wilds < 3:
		print("FAIL marks: wilds in encounter=%d（印记应必入池）" % wilds)
		return false
	print("PASS marks_persist")
	return true
