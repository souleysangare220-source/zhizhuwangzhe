class_name Events
## 塔中奇遇事件池。效果词表：silk / relic / mark / mark_random / cocoon / undo_next / none

const DATA := [
	{
		"title": "缠网的旅人",
		"desc": "一位旅人被困在你的网中，还在哼着走调的歌。",
		"opts": [
			{"text": "割开蛛网放他走（-3 丝，获得随机遗物）", "effect": {"silk": -3, "relic": true}},
			{"text": "静静等着（他睡着了，钱袋掉了出来，+2 丝）", "effect": {"silk": 2}},
			{"text": "现在就吃掉他（+5 丝）", "effect": {"silk": 5}},
		],
	},
	{
		"title": "蛛后低语",
		"desc": "黑暗中传来古老的声音：'把丝给我，我把力量给你。'",
		"opts": [
			{"text": "献上 3 缕蛛丝（获得随机遗物）", "effect": {"silk": -3, "relic": true}},
			{"text": "拒绝（黑暗静了下来）", "effect": {"none": true}},
			{"text": "反问她的问题（3 张牌获得随机印记）", "effect": {"mark_random": 3}},
		],
	},
	{
		"title": "蜕下的旧壳",
		"desc": "你旧日的躯壳挂在墙角，还算完整。",
		"opts": [
			{"text": "穿上它（获得随机遗物）", "effect": {"relic": true}},
			{"text": "修补成茧（3 张牌获得醒牌印）", "effect": {"mark": {"id": "awake", "count": 3}}},
			{"text": "吃掉它（+4 丝）", "effect": {"silk": 4}},
		],
	},
	{
		"title": "月光织机",
		"desc": "月光在塔壁上织出半张网，比你织的更美。你有些恼火。",
		"opts": [
			{"text": "跟着织完（3 张牌获得金线印）", "effect": {"mark": {"id": "gold", "count": 3}}},
			{"text": "在网下入睡（下局撤销 +2）", "effect": {"undo_next": 2}},
			{"text": "拆掉它（+3 丝）", "effect": {"silk": 3}},
		],
	},
	{
		"title": "塔的低语",
		"desc": "诅咒向你展示了一笔交易：让它缠住你的一部分，换取丝线。",
		"opts": [
			{"text": "接受（3 张牌被茧印缠住，+6 丝）", "effect": {"cocoon": 3, "silk": 6}},
			{"text": "抵抗（下局撤销 +1）", "effect": {"undo_next": 1}},
		],
	},
	{
		"title": "旧神残丝",
		"desc": "一根不属于任何猎物的丝，从塔顶一直垂到你面前。",
		"opts": [
			{"text": "收进丝囊（+5 丝）", "effect": {"silk": 5}},
			{"text": "编入命运（获得随机遗物）", "effect": {"relic": true}},
			{"text": "缠在腿上（3 张牌获得洞察印）", "effect": {"mark": {"id": "seer", "count": 3}}},
		],
	},
]

const ATLAS_EXTRA := {"text": "用蛛丝占卜（+2 丝）", "effect": {"silk": 2}}


static func pick(used: Array) -> Dictionary:
	var candidates: Array = []
	for i in DATA.size():
		if not used.has(i):
			candidates.append(i)
	if candidates.is_empty():
		return {}
	var idx: int = candidates[randi() % candidates.size()]
	return {"index": idx, "data": DATA[idx]}
