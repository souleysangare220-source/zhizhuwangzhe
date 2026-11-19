class_name EventScreen
extends Control
## 事件屏：两阶段——选择 → 结果摘要 → 继续。

var data: Dictionary        # 事件数据（title/desc/opts）
var on_choose: Callable     # (effect: Dictionary) -> String 摘要
var on_done: Callable
var result_text := ""
var phase := 1


func _init(p_data: Dictionary, p_choose: Callable, p_done: Callable) -> void:
	data = p_data
	on_choose = p_choose
	on_done = p_done


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(640, 360)
	theme = Ui.make_theme()
	queue_redraw()
	_build()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.08, 0.06, 0.12))
	draw_rect(Rect2(80, 60, 480, 240), Color(0.10, 0.08, 0.19))
	draw_rect(Rect2(80, 60, 480, 240), Color(0.35, 0.28, 0.55), false)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	Ui.label(self, "塔中奇遇", Vector2(10, 6), 9, Color(0.55, 0.50, 0.70))
	Ui.label(self, str(data["title"]), Vector2(100, 76), 14, Color(0.95, 0.92, 1.0))
	Ui.wrap_label(self, str(data["desc"]), Vector2(100, 100), 440, 9)
	if phase == 1:
		var y := 130
		for opt in data["opts"]:
			var effect: Dictionary = opt["effect"]
			Ui.button(self, str(opt["text"]), Vector2(100, y), Vector2(440, 24),
				_choose.bind(effect), 9)
			y += 30
	else:
		Ui.wrap_label(self, result_text, Vector2(100, 130), 440, 10, Color(0.90, 0.85, 0.65))
		Ui.button(self, "继续攀登", Vector2(260, 250), Vector2(120, 24), _continue)


func _choose(effect: Dictionary) -> void:
	if phase != 1:
		return
	phase = 2
	result_text = str(on_choose.call(effect))
	_build()


func _continue() -> void:
	if on_done.is_valid():
		on_done.call()
