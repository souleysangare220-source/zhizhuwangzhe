class_name Encounters
## Demo 时间线：3 巢 16 节点（10 遭遇 + 3 商店 + 3 事件 + 1 Boss）。
## suits: [0]=蜘蛛 [1]=飞蛾 [2]=甲虫 [3]=蜈蚣
## reveal: 开局额外翻开的暗牌数（新手友好度调节阀）

const NEST_NAMES := ["巢一 · 塔底", "巢二 · 塔腰", "巢三 · 塔顶"]


static func timeline() -> Array:
	return [
		# ---- 巢一：仅蜘蛛（热身层，轻松过关）----
		{"type": "enc", "nest": 1, "name": "初醒之网", "desc": "塔底的第一张网。", "cols": 8, "deals": 4, "target": 1, "suits": [0], "reveal": 2},
		{"type": "enc", "nest": 1, "name": "尘封的巢房", "desc": "旧日的猎物只剩下骨头。", "cols": 8, "deals": 4, "target": 1, "suits": [0], "reveal": 1},
		{"type": "enc", "nest": 1, "name": "旧猎场", "desc": "这里的网，是你上一次失败时留下的。", "cols": 9, "deals": 4, "target": 2, "suits": [0], "reveal": 1},
		{"type": "shop", "nest": 1},
		{"type": "event", "nest": 1},
		# ---- 巢二：蜘蛛 + 飞蛾 ----
		{"type": "enc", "nest": 2, "name": "蛾群的低语", "desc": "飞蛾扑向你的网，它们不怕你。", "cols": 8, "deals": 4, "target": 2, "suits": [0, 1], "reveal": 1},
		{"type": "enc", "nest": 2, "name": "双影走廊", "desc": "墙上同时映出两种影子。", "cols": 9, "deals": 4, "target": 2, "suits": [0, 1]},
		{"type": "enc", "nest": 2, "name": "扑火之夜", "desc": "整座塔都在发光，像一盏灯。", "cols": 9, "deals": 4, "target": 3, "suits": [0, 1]},
		{"type": "shop", "nest": 2},
		{"type": "event", "nest": 2},
		# ---- 巢三：四花色 ----
		{"type": "enc", "nest": 3, "name": "万虫朝圣 · 上", "desc": "所有被诅咒的生物都在向上爬。", "cols": 9, "deals": 4, "target": 2, "suits": [0, 1, 2, 3]},
		{"type": "enc", "nest": 3, "name": "万虫朝圣 · 下", "desc": "它们让开了路——不是因为敬畏。", "cols": 10, "deals": 4, "target": 2, "suits": [0, 1, 2, 3]},
		{"type": "enc", "nest": 3, "name": "王座前厅", "desc": "王座上没有人，只有一面镜子。", "cols": 10, "deals": 4, "target": 3, "suits": [0, 1, 2, 3]},
		{"type": "shop", "nest": 3},
		{"type": "event", "nest": 3},
		{"type": "boss", "nest": 3, "name": "诅咒之源", "desc": "镜子里的那个你，织得比你更快。", "cols": 10, "deals": 4, "target": 2, "suits": [0, 1, 2, 3],
			"rule": "cocoon_storm", "rule_desc": "茧之风暴：每次发牌，随机一张新牌被茧印缠住（不可移动）"},
	]
