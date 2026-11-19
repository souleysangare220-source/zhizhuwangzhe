extends SceneTree
## 交互层回归测试：验证点击落牌路径（修复"卡片移动不了"的回归）
## 修复点：
## 1. _stack_positions 布局方向（j=0 在视觉顶部）
## 2. _handle_click 选中后点击异列可拾取牌 = 优先落牌

func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	quit(1)

func _pass(msg: String) -> void:
	print("PASS ", msg)

func _init() -> void:
	await create_timer(0.05).timeout

	var engine := SpiderEngine.new()
	var run := RunState.new()
	engine.setup(run.build_encounter_cards([0], 8 * 8), {"cols": 8, "deals": 3, "target": 1, "undo": 2, "flags": {}})

	var tv := TableView.new()
	tv.engine = engine
	tv.run = run
	tv.node_info = {"name": "测试", "nest": 1}
	get_root().add_child(tv)
	await create_timer(0.1).timeout

	# 1) _card_at 命中：每列点其堆顶明牌应返回 n-1
	var hit_ok := true
	for col in engine.columns.size():
		var n: int = engine.columns[col].size()
		var poss: Array = tv._stack_positions(col)
		var top: Vector2 = poss[n - 1]
		var idx: int = tv._card_at(col, top + Vector2(5, TableView.CH / 2.0))
		if idx != n - 1:
			hit_ok = false
			printerr("col %d 命中 %d，期望 %d" % [col, idx, n - 1])
			break
	if not hit_ok:
		_fail("card_at_top")
	_pass("card_at_top")

	# 2) 布局方向：j=0 的 y 应小于 j=n-1 的 y（暗牌在视觉上方）
	var dir_ok := true
	for col in engine.columns.size():
		var poss2: Array = tv._stack_positions(col)
		if poss2.size() >= 2 and not (poss2[0].y < poss2[poss2.size() - 1].y):
			dir_ok = false
			break
	if not dir_ok:
		_fail("layout_direction")
	_pass("layout_direction")

	# 3) 选一张明牌 -> 点击异列合法落点 -> 应发生移动
	var moved := false
	for src in engine.columns.size():
		var col: Array = engine.columns[src]
		var start: int = engine.max_run_start(src)
		var head: Card = col[start]
		if not engine.can_pick(src, start):
			continue
		for dst in engine.columns.size():
			if dst == src:
				continue
			if engine.can_drop(head, dst):
				var src_before: int = engine.columns[src].size()
				var dst_before: int = engine.columns[dst].size()
				# 模拟点击：先点源列堆顶选牌
				var p_src: Vector2 = tv._stack_positions(src)[start] + Vector2(5, 5)
				tv._handle_click(p_src)
				if tv.sel_col != src:
					continue
				# 再点目标列（点其堆顶明牌位置，或空列原点）
				var p_dst: Vector2
				if engine.columns[dst].is_empty():
					p_dst = tv._col_origin(dst) + Vector2(5, 5)
				else:
					var nd: int = engine.columns[dst].size()
					p_dst = tv._stack_positions(dst)[nd - 1] + Vector2(5, 5)
				tv._handle_click(p_dst)
				if engine.columns[src].size() < src_before and engine.columns[dst].size() > dst_before:
					moved = true
				break
		if moved:
			break
	if not moved:
		_fail("click_move")
	_pass("click_move")

	# 等移动动画 flush 完毕
	for i in 60:
		if tv._pending.is_empty():
			break
		await create_timer(0.05).timeout

	# 4) 选中后点同一张牌 -> 取消选中
	tv.sel_col = -1
	tv.sel_start = -1
	var picked := false
	for src2 in engine.columns.size():
		var st: int = engine.max_run_start(src2)
		if st >= 0 and engine.can_pick(src2, st):
			tv.sel_col = src2
			tv.sel_start = st
			picked = true
			break
	if not picked:
		_fail("reselect_setup")
	var p_same: Vector2 = tv._stack_positions(tv.sel_col)[tv.sel_start] + Vector2(5, 5)
	tv._handle_click(p_same)
	if tv.sel_col != -1:
		_fail("deselect_toggle")
	_pass("deselect_toggle")

	print("ALL INTERACTION TESTS PASSED")
	quit(0)
