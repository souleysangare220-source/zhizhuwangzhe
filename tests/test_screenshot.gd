extends SceneTree
## 截图验证：godot --path demo -s tests/test_screenshot.gd

var main: Node


func _initialize() -> void:
	_run()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("res://tests/shots/%s.png" % name)
	print("SHOT ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/shots")
	main = preload("res://scripts/main.gd").new()
	get_root().add_child(main)
	await process_frame
	await _shot("01_title")
	main._start_run()
	await process_frame
	await _shot("02_tower")
	main._enter_node()  # 第一个遭遇
	await process_frame
	await process_frame
	await process_frame
	await _shot("03_table")
	main._encounter_won({"sets": 1, "deals_left": 2, "pending": 2, "boss": false})
	await process_frame
	await _shot("04_reward")
	main._reward_continue(false)
	await process_frame
	main.run.timeline_idx = 3  # 跳到商店
	main._enter_node()
	await process_frame
	await process_frame
	await _shot("05_shop")
	main._node_done()
	main.run.timeline_idx = 4  # 事件
	main._enter_node()
	await process_frame
	await process_frame
	await _shot("06_event")
	print("SCREENSHOTS DONE")
	quit(0)
