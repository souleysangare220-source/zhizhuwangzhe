class_name Marks
## 卡牌印记数据表。cocoon 为诅咒印记，不可购买。

const DATA := {
	"wild": {"name": "百搭印", "desc": "该牌可与任意花色连成序列", "price": 6},
	"awake": {"name": "醒牌印", "desc": "该牌开局即翻开", "price": 4},
	"gold": {"name": "金线印", "desc": "该牌随序列消除时 +3 蛛丝", "price": 3},
	"double": {"name": "复眼印", "desc": "翻开该牌时 +1 撤销", "price": 4},
	"seer": {"name": "洞察印", "desc": "该牌背面时显示花色", "price": 3},
	"cocoon": {"name": "茧印", "desc": "诅咒：该牌不可移动，只能随序列消除解除", "price": 0},
}


static func purchasable_ids() -> Array:
	var ids: Array = []
	for k in DATA.keys():
		if k != "cocoon":
			ids.append(k)
	return ids


static func random_offers(n: int) -> Array:
	var ids := purchasable_ids()
	ids.shuffle()
	return ids.slice(0, n)


static func name_of(id: String) -> String:
	return str(DATA[id]["name"]) if DATA.has(id) else id
