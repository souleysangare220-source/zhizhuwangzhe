extends SceneTree
## 整机冒烟测试（需带渲染运行）：godot --path demo -s tests/test_smoke.gd

var main: Node


func _initialize() -> void:
	_run_smoke()


func _run_smoke() -> void:
	main = preload("res://scripts/main.gd").new()
	get_root().add_child(main)
	await process_frame
	await process_frame
	if main.screen == null:
		print("SMOKE FAIL: 标题屏未构建")
		quit(1)
		return
	main._start_run()
	await process_frame
	await process_frame
	var guard := 0
	var errors := 0
	while main.run != null and main.run.timeline_idx < main._timeline().size() and guard < 300:
		guard += 1
		var node: Dictionary = main._timeline()[main.run.timeline_idx]
		match str(node.get("type", "")):
			"enc", "boss":
				main._enter_node()
				await process_frame
				await process_frame
				var tv: Control = main.screen
				if tv == null or not (tv is TableView):
					print("SMOKE FAIL: 牌桌未构建于节点 %d" % main.run.timeline_idx)
					errors += 1
					break
				main._encounter_won({"sets": 2, "deals_left": 1, "pending": 1, "boss": str(node.get("type", "")) == "boss"})
				await process_frame
				await process_frame
				if str(node.get("type", "")) == "boss":
					break  # Boss 胜利直接进结局画面，不走 _node_done
				main._reward_continue(false)
			"shop":
				main._enter_node()
				await process_frame
				await process_frame
				if not (main.screen is ShopScreen):
					print("SMOKE FAIL: 商店未构建")
					errors += 1
					break
				main._node_done()
			"event":
				main._enter_node()
				await process_frame
				await process_frame
				var summary: String = main._apply_event_effect({"silk": 2, "relic": true})
				if summary.is_empty():
					print("SMOKE FAIL: 事件效果摘要为空")
					errors += 1
				main._node_done()
			_:
				main._node_done()
		await process_frame
	await process_frame
	await process_frame
	if main.screen != null:
		print("SMOKE OK: Boss 胜利后到达结局画面（%d 步，丝=%d，遗物=%d）" % [guard, main.run.silk, main.run.relic_ids.size()])
		quit(0 if errors == 0 else 1)
	else:
		print("SMOKE FAIL: 时间线未走完 idx=%d" % (main.run.timeline_idx if main.run != null else -1))
		quit(1)
