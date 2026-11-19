class_name Card
extends RefCounted
## 一张牌的数据。牌组身份 = 花色_点数_副本 三元组，印记挂在身份上跨遭遇持久。

enum Suit { SPIDER, MOTH, BEETLE, CENTIPEDE }


var suit: int = Suit.SPIDER
var rank: int = 1          # 1=A, 11=J, 12=Q, 13=K
var copy_index: int = 0    # 该花色该点数的第几副（0-7）
var face_up: bool = false
var mark: String = ""      # "", wild, awake, gold, double, seer, cocoon
var cocooned: bool = false # Boss 茧之风暴的局内临时诅咒（不持久）


func _init(p_suit: int = Suit.SPIDER, p_rank: int = 1, p_copy: int = 0) -> void:
	suit = p_suit
	rank = p_rank
	copy_index = p_copy


func rank_label() -> String:
	match rank:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_: return str(rank)


func is_wild() -> bool:
	return mark == "wild"


func stuck() -> bool:
	return mark == "cocoon" or cocooned


func reset_transient() -> void:
	cocooned = false
