class_name RunState
extends RefCounted
## 一次 Run 的全部持久状态：巢、丝、遗物、印记库、事件记录。
## 印记挂在牌组身份（花色_点数_副本）上，跨遭遇持久；牌组重铸时印记优先保留。

var timeline_idx: int = 0
var silk: int = 3
var relic_ids: Array = []
var mark_store: Dictionary = {}   # "suit_rank_copy" -> mark id
var pending_undo_bonus: int = 0   # 事件给下局的撤销加成
var used_events: Array = []       # 已用过的事件下标
var stats := {"encounters": 0, "sets": 0, "undo_used": 0}


func has_relic(id: String) -> bool:
	return relic_ids.has(id)


func gain_relic(id: String) -> void:
	if not relic_ids.has(id):
		relic_ids.append(id)


func relic_flags() -> Dictionary:
	return {
		"loose_move": has_relic("gloves"),
		"moth_as_spider": has_relic("mimic"),
		"empty_deal": has_relic("nest_charm"),
		"molt": has_relic("molt"),
		"bloodstone": has_relic("bloodstone"),
		"harvest": has_relic("harvest"),
		"eye": has_relic("eye"),
	}


static func _key(s: int, r: int, c: int) -> String:
	return "%d_%d_%d" % [s, r, c]


func _copy_has_mark(s: int, c: int) -> bool:
	for r in range(1, 14):
		if mark_store.has(_key(s, r, c)):
			return true
	return false


## 当前巢的可用身份池（104 张：8 套按花色均分）
func _pool(suits: Array) -> Array:
	var num := suits.size()
	if num <= 0:
		num = 1
		suits = [0]
	var per := int(8 / num)
	var pool: Array = []
	for s in suits:
		var copy_ids: Array = []
		for c in range(8):
			copy_ids.append(c)
		copy_ids.shuffle()
		# 印记优先保留：带印记的副本优先入选
		copy_ids.sort_custom(func(a, b):
			return _copy_has_mark(s, a) and not _copy_has_mark(s, b))
		for c in copy_ids.slice(0, per):
			for r in range(1, 14):
				pool.append([s, r, c])
	return pool


## 构建一次遭遇的牌组：印记必入 + 分层随机填充（保证每花色每点数至少一张）
func build_encounter_cards(suits: Array, count: int) -> Array:
	var pool := _pool(suits)
	var marked: Array = []
	var plain: Array = []
	for idn in pool:
		if mark_store.has(_key(idn[0], idn[1], idn[2])):
			marked.append(idn)
		else:
			plain.append(idn)
	marked.shuffle()
	plain.shuffle()
	var chosen: Array = []
	var rank_count := {}
	for idn in marked:
		if chosen.size() >= count:
			break
		chosen.append(idn)
		var rk: String = "%d_%d" % [idn[0], idn[1]]
		rank_count[rk] = int(rank_count.get(rk, 0)) + 1
	# 分层保底：每个在场花色每个点数至少一张
	var num := suits.size()
	if num <= 0:
		num = 1
	if count >= num * 13:
		for s in suits:
			if chosen.size() >= count:
				break
			for r in range(1, 14):
				var rk: String = "%d_%d" % [s, r]
				if int(rank_count.get(rk, 0)) > 0:
					continue
				for i in range(plain.size()):
					var idn: Array = plain[i]
					if idn[0] == s and idn[1] == r:
						chosen.append(idn)
						rank_count[rk] = 1
						plain.remove_at(i)
						break
	while chosen.size() < count and not plain.is_empty():
		chosen.append(plain.pop_back())
	chosen.shuffle()
	var cards: Array = []
	for idn in chosen:
		var c := Card.new(idn[0], idn[1], idn[2])
		c.mark = str(mark_store.get(_key(idn[0], idn[1], idn[2]), ""))
		cards.append(c)
	return cards


## 给随机若干张牌施加印记，返回实际施加数量
func apply_random_mark(mark_id: String, count: int, suits: Array) -> int:
	var pool := _pool(suits)
	var candidates: Array = []
	for idn in pool:
		if not mark_store.has(_key(idn[0], idn[1], idn[2])):
			candidates.append(idn)
	candidates.shuffle()
	var applied := 0
	for i in range(mini(count, candidates.size())):
		var idn: Array = candidates[i]
		mark_store[_key(idn[0], idn[1], idn[2])] = mark_id
		applied += 1
	return applied
