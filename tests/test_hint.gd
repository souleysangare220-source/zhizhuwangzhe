extends SceneTree
## 验证教学气泡：位置同步正确 + 定时自动消失（箭头不残留）

func _init() -> void:
	await create_timer(0.1).timeout
	var fx := FxLayer.new()
	get_root().add_child(fx)
	await create_timer(0.1).timeout
	fx.show_hint("测试气泡", Vector2(320, 100), 0.3)
	var c: Control = fx._hint
	if c == null:
		print("FAIL: _hint 为空")
		quit(1)
		return
	print("气泡位置=", c.position, " 尺寸=", c.size)
	if c.position == Vector2.ZERO:
		print("FAIL: 位置未同步设置（旧 BUG）")
		quit(1)
		return
	print("PASS: 位置同步正确（指向三角会跟随气泡而非挂在原点）")
	await create_timer(0.8).timeout
	var gone: bool = fx._hint == null or not is_instance_valid(fx._hint)
	print("0.8秒后气泡已消失: ", gone)
	if gone:
		print("ALL HINT TESTS PASSED")
		quit(0)
	else:
		print("FAIL: 气泡未自动消失（箭头残留 BUG 仍在）")
		quit(1)
