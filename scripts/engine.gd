class_name SpiderEngine
extends RefCounted
## 蜘蛛纸牌纯逻辑引擎：与渲染完全分离。
## 规则保持原教旨 + 遗物规则钩子（flags）。

var columns: Array = []      # Array of Array[Card]
var stock: Array = []        # 待发牌（按列数分组发牌）
var completed: int = 0
var target: int = 2
var deals_total: int = 3
var deals_used: int = 0
var undo_left: int = 2
var undo_free_used: bool = false
var flags: Dictionary = {}
var finished: String = ""    # "", "win", "dead"
var encounter_name: String = ""

var _history: Array = []


## cfg: {cols, deals, target, undo, flags, name}
func setup(cards: Array, cfg: Dictionary) -> void:
	columns = []
	stock = []
	completed = 0
	finished = ""
	_history = []
	undo_free_used = false
	target = int(cfg.get("target", 2))
	deals_total = int(cfg.get("deals", 3))
	deals_used = 0
	undo_left = int(cfg.get("undo", 2))
	flags = cfg.get("flags", {})
	encounter_name = str(cfg.get("name", ""))
	var cols := int(cfg.get("cols", 8))
	var idx := 0
	for col_i in cols:
		var col: Array = []
		for d in 4:
			if idx >= cards.size():
				break
			var cd: Card = cards[idx]
			cd.face_up = false
			cd.reset_transient()
			idx += 1
			col.append(cd)
		if idx < cards.size():
			var up: Card = cards[idx]
			up.face_up = true
			up.reset_transient()
			idx += 1
			col.append(up)
		columns.append(col)
	while idx < cards.size():
		var s: Card = cards[idx]
		s.face_up = false
		s.reset_transient()
		stock.append(s)
		idx += 1
	# 醒牌印：开局即翻开
	for col in columns:
		for cd in col:
			if cd.mark == "awake":
				cd.face_up = true
	# 新手友好：开局额外翻开 N 张暗牌（优先各列堆顶，均匀分布）
	var reveal := int(cfg.get("reveal", 0))
	for r in reveal:
		var hidden_cols: Array = []
		for ci in columns.size():
			var col: Array = columns[ci]
			for j in range(col.size() - 1, -1, -1):
				if not (col[j] as Card).face_up:
					hidden_cols.append([ci, j])
					break
		if hidden_cols.is_empty():
			break
		var pick: Array = hidden_cols[r % hidden_cols.size()]
		(columns[pick[0]][pick[1]] as Card).face_up = true


func deals_left() -> int:
	var per := columns.size()
	if per <= 0:
		return 0
	return stock.size() / per


## 开局遗物（猎手之眼：翻开 3 张暗牌）
func apply_start_relics() -> Dictionary:
	var ev := _empty_ev()
	if flags.get("eye", false):
		for i in 3:
			_flip_random_hidden(ev)
	return ev


# ---------------- 序列判定 ----------------

func suits_compatible(a: Card, b: Card) -> bool:
	if flags.get("loose_move", false):
		return true
	if a.is_wild() or b.is_wild():
		return true
	var sa := a.suit
	var sb := b.suit
	if flags.get("moth_as_spider", false):
		if sa == Card.Suit.MOTH:
			sa = Card.Suit.SPIDER
		if sb == Card.Suit.MOTH:
			sb = Card.Suit.SPIDER
	return sa == sb


## 从某列顶端可整体移动的最长同花降序序列的起始下标；-1 = 顶端不可移动
func max_run_start(col_idx: int) -> int:
	var col: Array = columns[col_idx]
	if col.is_empty():
		return -1
	var i := col.size() - 1
	var top: Card = col[i]
	if not top.face_up or top.stuck():
		return -1
	while i > 0:
		var under: Card = col[i - 1]
		if not under.face_up or under.stuck():
			break
		if under.rank != col[i].rank + 1:
			break
		if not suits_compatible(under, col[i]):
			break
		i -= 1
	return i


## 该下标的牌是否可作为移动序列的头（maximal run 的任意后缀）
func can_pick(col_idx: int, i: int) -> bool:
	var col: Array = columns[col_idx]
	if i < 0 or i >= col.size():
		return false
	var start := max_run_start(col_idx)
	return start >= 0 and i >= start


func can_drop(head: Card, dst: int) -> bool:
	var col: Array = columns[dst]
	if col.is_empty():
		return true
	var top: Card = col[col.size() - 1]
	return top.rank == head.rank + 1


func can_deal() -> bool:
	if stock.is_empty():
		return false
	if not flags.get("empty_deal", false):
		for col in columns:
			if (col as Array).is_empty():
				return false
	return true


# ---------------- 行动 ----------------

func do_move(src: int, start: int, dst: int) -> Dictionary:
	var ev := _empty_ev()
	_push_history()
	var col: Array = columns[src]
	var run: Array = col.slice(start)
	columns[src] = col.slice(0, start)
	columns[dst].append_array(run)
	ev["moved"] = run
	ev["src"] = src
	ev["dst"] = dst
	# 派发模式：翻牌与完成延迟到 flush_action
	var top_card: Card = null
	var src_col: Array = columns[src]
	if not src_col.is_empty():
		var t: Card = src_col[src_col.size() - 1]
		if not t.face_up:
			top_card = t
	if top_card != null:
		ev["pending_flips"].append(top_card)
	var completed_tail: Array = _peek_complete(dst)
	if not completed_tail.is_empty():
		ev["pending_completed"] = completed_tail
	return ev


func do_deal() -> Dictionary:
	var ev := _empty_ev()
	_push_history()
	var n := columns.size()
	for i in n:
		if stock.is_empty():
			break
		var c: Card = stock.pop_front()
		c.face_up = true
		columns[i].append(c)
		ev["dealt"].append(c)
	deals_used += 1
	# 派发模式：完成判定延迟到 flush_action
	for i in n:
		var tail: Array = _peek_complete(i)
		if not tail.is_empty():
			ev["pending_completed"].append_array(tail)
	if flags.get("harvest", false) and not ev["dealt"].is_empty():
		var hidden: Array = []
		for col in columns:
			for cd in col:
				if not (cd as Card).face_up:
					hidden.append(cd)
		if not hidden.is_empty():
			ev["pending_flips"].append(hidden[randi() % hidden.size()])
	return ev


## 视图动画结束后调用：应用待翻牌、待完成，并结算结束状态
func flush_action(ev: Dictionary) -> void:
	var f := _empty_ev()
	for c in ev.get("pending_flips", []):
		(c as Card).face_up = true
		f["flipped"].append(c)
		if (c as Card).mark == "double":
			undo_left += 1
			f["undo_gain"] += 1
	var completed_cols: Array = ev.get("completed_cols", [])
	if completed_cols.is_empty():
		# 根据 pending_completed 反查所在列
		var seen := {}
		for c in ev.get("pending_completed", []):
			for ci in columns.size():
				if (columns[ci] as Array).has(c) and not seen.has(ci):
					seen[ci] = true
					completed_cols.append(ci)
					break
	for ci in completed_cols:
		_complete_column(ci, f)
	ev["flipped"] = f["flipped"]
	ev["undo_gain"] = f["undo_gain"]
	ev["sets"] = f["sets"]
	ev["silk"] = f["silk"]
	ev["completed_cards"] = f["completed_cards"]
	ev["pending_flips"] = []
	ev["pending_completed"] = []
	_check_end()


## 检查某列尾部是否构成完整 K..A 同花序列（只读，不修改状态）
func _peek_complete(col_idx: int) -> Array:
	var col: Array = columns[col_idx]
	if col.size() < 13:
		return []
	var tail: Array = col.slice(col.size() - 13)
	var suit := -1
	for k in 13:
		var c: Card = tail[k]
		if not c.face_up or c.rank != 13 - k:
			return []
		if c.is_wild():
			continue
		if suit == -1:
			suit = c.suit
		elif c.suit != suit:
			return []
	return tail


func undo() -> bool:
	if _history.is_empty():
		return false
	var free: bool = flags.get("molt", false) and not undo_free_used
	if not free:
		if undo_left <= 0:
			return false
		undo_left -= 1
	else:
		undo_free_used = true
	var snap: Dictionary = _history.pop_back()
	_restore(snap)
	finished = ""
	if flags.get("bloodstone", false):
		var ev := _empty_ev()
		_flip_random_hidden(ev)
	_check_end()
	return true


func any_move() -> bool:
	if can_deal():
		return true
	for i in columns.size():
		var col: Array = columns[i]
		if col.is_empty():
			continue
		var start := max_run_start(i)
		if start < 0:
			continue
		for s in range(start, col.size()):
			var head: Card = col[s]
			for j in columns.size():
				if j == i:
					continue
				var dst: Array = columns[j]
				if dst.is_empty():
					return true
				var top: Card = dst[dst.size() - 1]
				if top.rank == head.rank + 1:
					return true
	return false


# ---------------- 内部 ----------------

func _empty_ev() -> Dictionary:
	return {"moved": [], "flipped": [], "completed_cards": [], "dealt": [], "sets": 0, "silk": 0, "undo_gain": 0,
		"pending_flips": [], "pending_completed": [], "src": -1, "dst": -1}


func _flip_top(col_idx: int, ev: Dictionary) -> void:
	var col: Array = columns[col_idx]
	if col.is_empty():
		return
	var top: Card = col[col.size() - 1]
	if not top.face_up:
		top.face_up = true
		ev["flipped"].append(top)
		if top.mark == "double":
			undo_left += 1
			ev["undo_gain"] += 1


func _flip_random_hidden(ev: Dictionary) -> void:
	var hidden: Array = []
	for col in columns:
		for cd in col:
			if not (cd as Card).face_up:
				hidden.append(cd)
	if hidden.is_empty():
		return
	var c: Card = hidden[randi() % hidden.size()]
	c.face_up = true
	ev["flipped"].append(c)
	if c.mark == "double":
		undo_left += 1
		ev["undo_gain"] += 1


## 检查某列尾部是否有完整 K..A 同花序列（百搭可顶任意花色；茧印可随序列解除）
func _complete_column(col_idx: int, ev: Dictionary) -> void:
	while true:
		var col: Array = columns[col_idx]
		if col.size() < 13:
			return
		var tail: Array = col.slice(col.size() - 13)
		var suit := -1
		var ok := true
		for k in 13:
			var c: Card = tail[k]
			if not c.face_up or c.rank != 13 - k:
				ok = false
				break
			if c.is_wild():
				continue
			if suit == -1:
				suit = c.suit
			elif c.suit != suit:
				ok = false
				break
		if not ok:
			return
		columns[col_idx] = col.slice(0, col.size() - 13)
		completed += 1
		ev["sets"] += 1
		ev["completed_cards"].append_array(tail)
		for c in tail:
			if (c as Card).mark == "gold":
				ev["silk"] += 3
		_flip_top(col_idx, ev)


func _check_end() -> void:
	if completed >= target:
		finished = "win"
	elif not any_move():
		var can_still_undo: bool = undo_left > 0 or (flags.get("molt", false) and not undo_free_used)
		if not can_still_undo:
			finished = "dead"


func _push_history() -> void:
	var cols := []
	for col in columns:
		var arr := []
		for c in col:
			arr.append([c, (c as Card).face_up])
		cols.append(arr)
	_history.append({
		"cols": cols,
		"stock": stock.duplicate(),
		"completed": completed,
		"deals_used": deals_used,
	})


func _restore(snap: Dictionary) -> void:
	columns = []
	for col in snap["cols"]:
		var arr := []
		for pair in col:
			var c: Card = pair[0]
			c.face_up = pair[1]
			arr.append(c)
		columns.append(arr)
	stock = (snap["stock"] as Array).duplicate()
	completed = snap["completed"]
	deals_used = snap["deals_used"]
