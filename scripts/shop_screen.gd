class_name ShopScreen
extends Control
## 商店：3 遗物 + 2 印记 + 重掷。印记购买后随机落在 3 张牌上。

var run: RunState
var next_suits: Array
var on_done: Callable
var relic_offers: Array = []
var mark_offers: Array = []
var items_box: Control
var silk_label: Label
var msg_label: Label
var reroll_count := 0


func _init(p_run: RunState, p_suits: Array, p_done: Callable) -> void:
	run = p_run
	next_suits = p_suits
	on_done = p_done


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(640, 360)
	theme = Ui.make_theme()
	relic_offers = Relics.random_offers(run.relic_ids, 3)
	mark_offers = Marks.random_offers(2)
	draw.connect(_draw_bg)
	_draw_bg_queue()
	Ui.label(self, "旧货商的角落", Vector2(10, 6), 12, Color(0.95, 0.92, 1.0))
	Ui.label(self, "一只披着斗篷的蜈蚣向你摊开了货箱。", Vector2(10, 22), 8, Color(0.60, 0.56, 0.72))
	silk_label = Ui.label(self, "", Vector2(560, 8), 11, Color(0.98, 0.85, 0.45))
	items_box = Control.new()
	items_box.position = Vector2(0, 40)
	items_box.size = Vector2(640, 280)
	add_child(items_box)
	msg_label = Ui.label(self, "", Vector2(10, 322), 9, Color(0.90, 0.80, 0.55))
	Ui.button(self, "重掷商品（2丝）", Vector2(430, 334), Vector2(100, 22), _on_reroll)
	Ui.button(self, "离开商店", Vector2(538, 334), Vector2(96, 22), _on_leave)
	_refresh()


func _draw_bg_queue() -> void:
	queue_redraw()


func _draw_bg() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.06, 0.12))
	draw_rect(Rect2(0, 32, 640, 286), Color(0.10, 0.08, 0.19))


func _price(base: int) -> int:
	if run.has_relic("wax"):
		return maxi(1, int(round(base * 0.75)))
	return base


func _refresh() -> void:
	for child in items_box.get_children():
		child.queue_free()
	silk_label.text = "丝 %d" % run.silk
	var y := 4
	# 遗物
	for id in relic_offers:
		y = _draw_item_row(str(Relics.DATA[id]["name"]), str(Relics.DATA[id]["desc"]), _price(int(Relics.DATA[id]["price"])), y,
			func() -> void: _buy_relic(str(id)), run.has_relic(str(id)))
	# 印记
	for id in mark_offers:
		y = _draw_item_row(str(Marks.DATA[id]["name"]) + "（随机落在 3 张牌上）", str(Marks.DATA[id]["desc"]), _price(int(Marks.DATA[id]["price"])), y,
			func() -> void: _buy_mark(str(id)), false)


func _draw_item_row(item_name: String, desc: String, price: int, y: int, cb: Callable, owned: bool) -> int:
	Ui.label(items_box, item_name, Vector2(14, y), 11, Color(0.95, 0.92, 1.0))
	Ui.label(items_box, "%d 丝" % price, Vector2(240, y), 10, Color(0.98, 0.85, 0.45))
	Ui.wrap_label(items_box, desc, Vector2(14, y + 15), 440, 8)
	var b := Ui.button(items_box, "已拥有" if owned else "购买", Vector2(538, y + 2), Vector2(90, 20), cb)
	b.disabled = owned or run.silk < price
	return y + 40


func _buy_relic(id: String) -> void:
	var price := _price(int(Relics.DATA[id]["price"]))
	if run.silk < price or run.has_relic(id):
		return
	run.silk -= price
	run.gain_relic(id)
	msg_label.text = "获得遗物：" + str(Relics.DATA[id]["name"])
	_refresh()


func _buy_mark(id: String) -> void:
	var price := _price(int(Marks.DATA[id]["price"]))
	if run.silk < price:
		return
	var applied := run.apply_random_mark(id, 3, next_suits)
	if applied <= 0:
		msg_label.text = "没有可施加印记的牌了。"
		return
	run.silk -= price
	msg_label.text = "%d 张牌获得了%s（印记在牌组重铸时优先保留）" % [applied, str(Marks.DATA[id]["name"])]
	_refresh()


func _on_reroll() -> void:
	if run.silk < 2:
		msg_label.text = "丝不够了。"
		return
	run.silk -= 2
	reroll_count += 1
	relic_offers = Relics.random_offers(run.relic_ids, 3)
	mark_offers = Marks.random_offers(2)
	msg_label.text = ""
	_refresh()


func _on_leave() -> void:
	if on_done.is_valid():
		on_done.call()
