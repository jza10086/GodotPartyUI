extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("PASS ", message)
func run() -> void:
	var demo = load("res://examples/settings_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	var page = demo.get_node("Settings")
	check(demo.callback_count == 0, "Demo initialization does not apply")
	page.get_control("enabled").button_pressed = false
	check(demo.callback_count == 1 and demo.applied.enabled == false, "Toggle applies bool through external Callable")
	check(demo.get_node("Preview").modulate == load("res://ui/theme/ui_config.tres").demo_inactive, "Callback really changes independent preview using configured inactive color")
	page.get_control("gain").value = 0.31
	check(demo.callback_count == 2 and is_equal_approx(demo.applied.gain, 0.31), "Slider applies one callback")
	check(is_equal_approx(page.get_number_control("gain").value, 0.31), "Slider syncs decimal precise field")
	page.get_control("reset").pressed.emit()
	check(demo.callback_count == 2 and page.get_value("gain") == 0.75, "Action callback calls silent API")
	page.get_control("mode").item_selected.emit(1)
	check(page.get_value("mode") == "full", "Selection returns stable business value")
	check(not page.get_control("advanced").visible, "Conditional group hides on selection change")
	page.get_node("Back").pressed.emit()
	check(demo.callback_count == 0 and page.get_value("enabled") == true, "Back signal rebuilds complete demo without applying")
	var old = page.get_control("gain")
	check(page.add_tab("Extra", "Extra"), "Runtime add tab")
	check(page.add_option("Extra", {"id":"runtime", "type":"toggle", "value":0}), "Runtime add 0/1 control")
	check(page.set_value("runtime", 1) and page.get_value("runtime") == true, "API accepts 1 and returns bool")
	check(page.add_option("Demo", {"id":"nested", "type":"number", "min":-2,"max":2,"value":0}, "advanced"), "Runtime insert in requested group")
	check(page.get_value("gain") == 0.75, "Incremental build preserves existing values")
	check(not page.add_option("Extra", {"id":"gain", "type":"label"}), "Duplicate ID rejected atomically")
	check(page.get_value("nested") == 0, "Invalid build retains previous model")
	# Detached old controls cannot call application code after rebuild.
	old.value = 0.11
	check(demo.callback_count == 0, "Detached control ignores stale callback")
	page.clear()
	check(page.get_values().is_empty() and page.get_node("Tabs").get_tab_count() == 0, "Clear immediately removes all model and tabs")
	demo.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
