class_name Relics
## 遗物数据表。效果分别落在 engine.flags / 遭遇参数 / 视图 / 商店 / 事件。

const DATA := {
	"egg": {"name": "蛛后之卵", "desc": "每局发牌次数 +1", "price": 6},
	"pendant": {"name": "断丝坠子", "desc": "每局撤销次数 +2", "price": 5},
	"eye": {"name": "猎手之眼", "desc": "每局开局翻开 3 张暗牌", "price": 5},
	"nest_charm": {"name": "空巢护符", "desc": "有空列时也可以发牌", "price": 4},
	"gloves": {"name": "八足手套", "desc": "杂色降序序列可整体移动", "price": 7},
	"moonlight": {"name": "月光纱", "desc": "每完成一组序列 +2 蛛丝", "price": 5},
	"molt": {"name": "蜕壳", "desc": "每局第一次撤销免费", "price": 4},
	"wax": {"name": "蜂蜡封印", "desc": "商店价格 -25%", "price": 5},
	"harvest": {"name": "丰收茧", "desc": "每次发牌后随机翻开一张暗牌", "price": 4},
	"bloodstone": {"name": "血月石", "desc": "每次撤销时随机翻开一张暗牌", "price": 4},
	"atlas": {"name": "蛛网地图", "desc": "事件三选一变四选一", "price": 5},
	"loom": {"name": "织者之梭", "desc": "移动 5 张以上同花序列 +1 蛛丝", "price": 4},
	"mimic": {"name": "拟态蝶", "desc": "飞蛾视为蜘蛛（同花判定）", "price": 6},
	"amber": {"name": "琥珀念珠", "desc": "每局目标序列数 -1（最低 1）", "price": 8},
	"beacon": {"name": "蜘蛛信标", "desc": "显示下一次发牌的全部花色", "price": 4},
}


static func random_offers(owned: Array, n: int) -> Array:
	var ids: Array = []
	for k in DATA.keys():
		if not owned.has(k):
			ids.append(k)
	ids.shuffle()
	return ids.slice(0, n)


static func name_of(id: String) -> String:
	return str(DATA[id]["name"]) if DATA.has(id) else id
