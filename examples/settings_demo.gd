extends Control
## Run this scene with F6. Actual callback output updates Preview and a read-only row.
const DemoBindings = preload("res://settings/demo_bindings.gd")
var applied: Dictionary = {}
var callback_count := 0

func _ready() -> void:
	var page := $Settings
	var tabs := [{"id": "Demo", "title": "API DEMO", "options": [
		{"id": "summary", "type": "label", "label": "CALLBACK", "value": "Change a value below"},
		{"id": "divider0", "type": "divider"},
		{"id": "mode", "type": "select", "label": "Selection", "items": [{"label": "Window", "value": "window"}, {"label": "Fullscreen", "value": "full"}], "value": "window", "callback": apply_setting},
		{"id": "enabled", "type": "toggle", "label": "Sliding Off / On", "value": true, "callback": apply_setting},
		{"id": "count", "type": "number", "label": "Integer input", "min": 1, "max": 16, "step": 1, "value": 4, "callback": apply_setting},
		{"id": "gain", "type": "slider", "label": "Slider + precise input", "min": 0, "max": 1, "step": 0.01, "value": 0.75, "callback": apply_setting},
		{"id": "advanced", "type": "group", "label": "Window options", "expanded": true, "visible_when": {"id": "mode", "equals": "window"}, "children": [
			{"id": "width", "type": "number", "label": "Window width", "min": 640, "max": 7680, "step": 1, "value": 1280, "callback": apply_setting},
			{"id": "reset", "type": "action", "label": "Reset gain (silent API)", "callback": reset_gain}
		]},
		{"id": "divider1", "type": "divider"},
		{"id": "help", "type": "note", "text": "Callbacks update the preview and print (id, value).\nNo audio capture, networking or disk writes."}
	]}]
	tabs.append(DemoBindings.make_tab(apply_binding))
	if not page.configure(tabs):
		push_error(page.last_error)
		return
	DemoBindings.apply_defaults(page)
	page.get_node("Back").text = "Rebuild / reset demo"
	page.back_requested.connect(func():
		if not page.configure(tabs):
			push_error(page.last_error)
			return
		DemoBindings.apply_defaults(page)
		callback_count = 0
		applied.clear()
		$Preview.text = "Rebuilt: initialization emits no callbacks"
	)

func apply_setting(value: Variant, id: String) -> void:
	applied[id] = value
	callback_count += 1
	var message := "%s = %s  |  callbacks: %d" % [id, str(value), callback_count]
	$Settings.set_value("summary", message)
	$Preview.text = message
	# A concrete visible application, independent from the settings widgets.
	$Preview.modulate = Color(0.2, 0.55, 0.3) if bool($Settings.get_value("enabled")) else Color(0.55, 0.25, 0.25)
	print("APPLIED ", message)

func apply_binding(value: Variant, id: String) -> void:
	DemoBindings.apply_value(value, id)
	apply_setting(value, id)

func reset_gain(_id: String) -> void:
	$Settings.set_value("gain", 0.75)
	$Preview.text = "Gain reset silently; callbacks: %d" % callback_count

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		get_tree().change_scene_to_file("res://main.tscn")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		_capture_demo()
	elif event is InputEventKey and event.pressed and not event.echo:
		var action := DemoBindings.action_for_event(event)
		if not action.is_empty():
			$Preview.text = "INPUT MAP: %s  |  callbacks: %d" % [action, callback_count]
			$Preview.modulate = Color(0.2, 0.4, 0.65)
			get_viewport().set_input_as_handled()

func _capture_demo() -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("17_settings_api_demo.png")
	print("SCREENSHOT ", path, " error=", get_viewport().get_texture().get_image().save_png(path))
