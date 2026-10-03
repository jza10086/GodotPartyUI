extends SceneTree
# Independent black-box API regression tests. Run with --headless --script.
var failures := 0
var checks := 0
var calls: Array = []
var events: Array = []
var panel: Control
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS ", title)
	else:
		failures += 1
		push_error("FAIL " + title)
func changed(value: Variant, id: String) -> void:
	calls.append([id, value])
func settle() -> void:
	for i in range(4): await process_frame
func schema() -> Array:
	return [{"id":"basic", "title":"Basic", "options":[
		{"id":"choice", "type":"select", "label":"Choice", "items":[{"label":"Ten", "value":10}, {"label":"Forty", "value":40}], "value":40, "callback":changed},
		{"id":"toggle", "type":"toggle", "label":"Toggle", "value":false, "callback":changed},
		{"id":"number", "type":"number", "label":"Count", "min":0, "max":100, "step":1, "value":20, "callback":changed},
		{"id":"slider", "type":"slider", "label":"Scale", "min":0, "max":1, "step":0.1, "value":0.4, "callback":changed},
		{"id":"group", "type":"group", "label":"Children", "expanded":true, "visible_when":{"id":"toggle", "equals":true}, "children":[{"id":"child", "type":"number", "label":"Child", "value":7, "min":1, "max":20, "callback":changed}]}
	]}]
func run() -> void:
	panel = load("res://settings/settings_page.tscn").instantiate()
	root.add_child(panel)
	panel.setting_changed.connect(func(id, value): events.append([id,value]))
	check(panel.configure(schema()), "Configure valid five-type schema")
	await settle()
	check(calls.is_empty() and events.is_empty(), "Initialization never applies or emits changes")
	check(panel.get_value("choice") == 40, "Select initial underlying value, not index")
	check(panel.get_value("toggle") == false, "Toggle initial value")
	check(panel.get_value("child") == 7, "Stable nested child ID lookup")
	check(panel.set_value("number", 25), "Silent set accepted")
	check(panel.get_value("number") == 25 and calls.is_empty() and events.is_empty(), "Silent set updates model with zero notifications")
	check(panel.set_value("number", 25, true), "Same-value notified set accepted")
	check(calls.is_empty() and events.is_empty(), "Same normalized value applies zero times")
	panel.set_value("number", 25.6, true)
	check(panel.get_value("number") == 26, "Programmatic number rounds")
	check(calls.size() == 1 and events.size() == 1 and calls[-1][0] == "number" and calls[-1][1] == 26, "Changed value applies exactly once")
	panel.set_value("number", 999, true)
	check(panel.get_value("number") == 100 and calls.size() == 2, "Programmatic number upper clamps")
	panel.set_value("number", -99, true)
	check(panel.get_value("number") == 0 and calls.size() == 3, "Programmatic number lower clamps")
	var toggle: BaseButton = panel.get_control("toggle")
	toggle.button_pressed = true
	check(panel.get_value("toggle") == true and calls.size() == 4, "Toggle applies exactly once")
	check(typeof(calls[-1][1]) == TYPE_BOOL, "Toggle callback payload is bool")
	var choice: OptionButton = panel.get_control("choice")
	choice.select(0)
	choice.item_selected.emit(0)
	check(panel.get_value("choice") == 10 and calls.size() == 5 and calls[-1] == ["choice",10], "Dropdown passes selected underlying value exactly once")
	var number: SpinBox = panel.get_control("number")
	number.get_line_edit().text = "80.6"
	number.apply()
	check(panel.get_value("number") == 81 and calls.size() == 6, "Keyboard decimal commit rounds and applies once")
	number.get_line_edit().text = "invalid"
	number.apply()
	check(panel.get_value("number") == 81 and calls.size() == 6, "Invalid text preserves value without apply")
	number.get_line_edit().grab_focus()
	number.get_line_edit().text = "42.2"
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	await settle()
	check(panel.get_value("number") == 42 and calls.size() == 7, "Actual Enter key commits exactly once")
	number.get_line_edit().grab_focus()
	number.get_line_edit().text = "43.7"
	toggle.grab_focus()
	await settle()
	check(panel.get_value("number") == 44 and calls.size() == 8, "Focus loss commits exactly once")
	var previous_calls := calls.size()
	var old_number := number
	check(panel.configure(schema()), "Repeated configure works")
	old_number.value_changed.emit(3)
	check(panel.get_value("number") == 20 and calls.size() == previous_calls, "Same-frame obsolete control cannot apply after rebuild")
	await settle()
	check(not is_instance_valid(old_number), "Obsolete control gets released")
	check(panel.set_value("number", 22,true), "New control accepts value")
	check(calls.size() == previous_calls + 1, "Rebuild has only one active callback")
	check(not panel.set_value("missing", 3), "Unknown stable ID rejected")
	check(not panel.set_value("choice", 11), "Unknown dropdown value rejected")
	check(panel.get_value("choice") == 40, "Invalid dropdown set preserves current value")
	var bad := schema()
	bad[0].options.append({"id":"number", "type":"number", "label":"Duplicate"})
	check(not panel.configure(bad), "Duplicate option IDs rejected")
	check(panel.get_value("number") == 22, "Invalid configure preserves existing model atomically")
	panel.set_value("toggle", 1)
	check(panel.get_value("toggle") == true, "Toggle accepts numeric one")
	panel.set_value("toggle", 0)
	check(panel.get_value("toggle") == false, "Toggle accepts numeric zero")
	check(not panel.set_value("toggle", "invalid"), "Toggle rejects string without runtime error")
	check(not panel.set_value("choice", "invalid"), "Select rejects incompatible type without runtime error")
	check(not panel.set_value("toggle", 2), "Toggle rejects nonbinary integer")
	check(not panel.set_value("number", NAN) and not panel.set_value("number", INF), "Numeric rejects nonfinite values")
	var invalid_toggle := schema()
	invalid_toggle[0].options[1].value = "invalid"
	check(not panel.configure(invalid_toggle), "Invalid initial toggle rejected atomically")
	check(panel.get_value("number") == 22, "Invalid initial value preserves prior configuration")
	panel.set_value("slider", 0.46, true)
	check(is_equal_approx(panel.get_value("slider"), 0.5), "Fractional slider snaps correctly")
	var slider: HSlider = panel.get_control("slider")
	var slider_number: SpinBox = panel.get_number_control("slider")
	previous_calls = calls.size()
	slider.value = 0.7
	check(is_equal_approx(slider_number.value, 0.7) and calls.size() == previous_calls + 1, "Slider syncs number with one callback")
	slider_number.value = 0.2
	check(is_equal_approx(slider.value, 0.2) and calls.size() == previous_calls + 2, "Paired numeric syncs slider with one callback")
	check(panel.add_tab("extra", "Extra"), "Incremental tab accepted")
	check(panel.get_value("number") == 22 and is_equal_approx(panel.get_value("slider"), 0.2), "Incremental tab preserves current edits")
	check(panel.add_option("basic", {"id":"new_child", "type":"toggle", "label":"New"}, "group"), "Incremental nested child accepted")
	check(panel.get_value("new_child") == false, "Incremental child initialized")
	check(panel.configure([{"id":"empty", "title":"Empty"}]), "Tab without options accepted")
	check(panel.add_option("empty", {"id":"added", "type":"number", "value":3}), "Add option to initially empty tab")
	check(panel.get_value("added") == 3, "Added option initializes through API")
	var reentry := [{"id":"r", "options":[{"id":"r_value", "type":"toggle", "callback":func(_value, _id): panel.configure(schema())}]}]
	check(panel.configure(reentry), "Configure reentrant callback")
	previous_calls = events.size()
	panel.get_control("r_value").button_pressed = true
	check(panel.get_value("number") == 20 and panel.get_control("r_value") == null, "Callback safely rebuilds component")
	check(events.size() == previous_calls, "Rebuild suppresses obsolete change signal")
	previous_calls = calls.size()
	panel.clear()
	await settle()
	check(panel.get_values().is_empty(), "Clear removes all values")
	check(calls.size() == previous_calls, "Clear never applies")
	panel.queue_free()
	await settle()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
