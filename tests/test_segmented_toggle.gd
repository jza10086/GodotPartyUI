extends SceneTree
var failures := 0
var checks := 0
var calls := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("PASS ", message)
func settle() -> void:
	for i in range(4): await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
func click(button: Control, fraction: float) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.global_position + Vector2(button.size.x * fraction, button.size.y / 2)
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
func run() -> void:
	var page = load("res://settings/settings_page.tscn").instantiate()
	root.add_child(page)
	var schema := [{"id":"test", "options":[{"id":"toggle", "type":"toggle", "value":true, "callback":func(_v, _id): calls += 1}]}]
	check(page.configure(schema), "Toggle schema accepts bool")
	await settle()
	var toggle = page.get_control("toggle")
	check(toggle is Button and toggle.toggle_mode, "Button API remains compatible")
	check(toggle.off_text == "关" and toggle.on_text == "开", "Default Off/On caption API remains compatible")
	check(calls == 0 and toggle._slide == 1.0, "Initial true snaps without callback or tween")
	check(toggle.custom_minimum_size == Vector2(226, 72), "Switch reserves a larger click target")
	check(toggle.get_node("Track") is TextureRect and not toggle.has_node("Selection"), "Switch uses one capsule texture instead of segmented rectangles")
	check(toggle.get_node("Track").size == Vector2(102, 62), "Visible switch uses enlarged 51:31 proportions")
	check(toggle.get_node("On").visible and not toggle.get_node("Off").visible, "Only selected caption is visible")
	check(toggle.get_node("On").get_global_rect().end.x < toggle.get_node("Track").global_position.x, "Caption stays outside the capsule")
	click(toggle, 0.75)
	check(page.get_value("toggle") == false and calls == 1, "Click capsule toggles once")
	await create_timer(0.055).timeout
	check(toggle._slide > 0 and toggle._slide < 1, "Circular thumb slides through intermediate positions")
	click(toggle, 0.25)
	check(page.get_value("toggle") == true and calls == 2, "Click external caption toggles too")
	for i in range(8): click(toggle, 0.5)
	check(calls == 10 and page.get_value("toggle") == true, "Rapid clicks each apply once")
	await create_timer(0.25).timeout
	check(is_equal_approx(toggle._slide, 1), "Rapid reversal settles on latest target")
	toggle.grab_focus()
	key(KEY_LEFT)
	check(page.get_value("toggle") == false and calls == 11, "Left arrow selects Off")
	key(KEY_LEFT)
	check(calls == 11, "Repeated selected arrow has no callback")
	key(KEY_RIGHT)
	check(page.get_value("toggle") == true and calls == 12, "Right arrow selects On")
	key(KEY_SPACE)
	check(page.get_value("toggle") == false and calls == 13, "Space toggles once")
	key(KEY_ENTER)
	check(page.get_value("toggle") == true and calls == 14, "Enter toggles once")
	page.set_value("toggle", false)
	check(calls == 14 and not toggle.button_pressed, "Programmatic sync is silent")
	await create_timer(0.25).timeout
	check(is_zero_approx(toggle._slide), "Silent sync also slides to correct target")
	toggle.disabled = true
	click(toggle, 0.5)
	key(KEY_RIGHT)
	check(calls == 14 and page.get_value("toggle") == false, "Disabled control ignores mouse and keyboard")
	toggle.disabled = false
	page.set_value("toggle", true)
	toggle.size.x += 200
	await create_timer(0.25).timeout
	check(is_equal_approx(toggle._slide, 1), "Resize during slide preserves normalized target")
	check(toggle.get_node("Track").size == Vector2(102, 62) and toggle.get_node("Track").texture.get_size() == Vector2(102, 62), "Wider setting row cannot stretch capsule or thumb")
	page.set_value("toggle", false)
	var old = toggle
	check(page.add_tab("extra", "Extra"), "Rebuild during animation succeeds")
	check(not old._tween.is_running(), "Detached control cancels tween immediately")
	old.button_pressed = true
	check(calls == 14 and page.get_value("toggle") == false, "Detached control cannot call application")
	await settle()
	check(not is_instance_valid(old), "Detached animated control is freed")
	schema[0].options[0].off_text = "Off"
	schema[0].options[0].on_text = "On"
	page.configure(schema)
	toggle = page.get_control("toggle")
	check(toggle.off_text == "Off" and toggle.on_text == "On", "Optional external switch captions are supported")
	await settle()
	check(toggle.get_node("On").text == "On" and toggle.get_node("On").visible and not toggle.get_node("Off").visible, "Custom caption is rendered only outside the selected switch")
	page.set_value("toggle", false)
	page.clear()
	await settle()
	check(page.get_values().is_empty() and calls == 14, "Clear during animation has no callback")
	page.queue_free()
	await settle()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
