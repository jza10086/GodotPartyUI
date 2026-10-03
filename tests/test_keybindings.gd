extends SceneTree
const Keys = preload("res://settings/key_binding.gd")
var failures := 0
var checks := 0
var calls: Array = []
var signals: Array = []
var conflicts: Array = []
class ShortcutProbe extends Node:
	var keys: Array = []
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed: keys.append(event.keycode)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL " + title)
	else: print("PASS ", title)
func settle() -> void:
	for i in range(5): await process_frame
func record(value: Variant, id: String) -> void:
	calls.append([id, value])
func send_key(code: int, pressed: bool = true, echo: bool = false) -> void:
	var event := Keys.event(code)
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	var page = load("res://settings/settings_page.tscn").instantiate()
	root.add_child(page)
	var probe := ShortcutProbe.new()
	root.add_child(probe)
	var schema := [{"id":"Keys", "title":"按键绑定", "options":[
		{"id":"header", "type":"bindings_header"},
		{"id":"walk", "type":"keybinding", "label":"向前", "value":[KEY_W, KEY_UP], "callback":record},
		{"id":"group", "type":"group", "label":"移动", "expanded":true, "children":[
			{"id":"jump", "type":"keybinding", "label":"跳跃", "value":[KEY_SPACE, 0], "callback":record, "children":[
				{"id":"dash", "type":"keybinding", "label":"空中冲刺", "value":[KEY_Q, 0], "callback":record}
			]},
			{"id":"map", "type":"keybinding", "label":"地图", "value":[KEY_M, 0], "callback":record}
		]}
	]}, {"id":"Other", "title":"其他", "options":[]}]
	check(page.configure(schema), "Programmatic headers, groups, binding rows and children")
	page.setting_changed.connect(func(id, value): signals.append([id, value]))
	page.binding_conflict.connect(func(id, slot, other): conflicts.append([id, slot, other]))
	await settle()
	check(calls.is_empty() and signals.is_empty(), "Initialization remains silent")
	check(page.get_value("walk") == [KEY_W, KEY_UP], "Two slots returned in primary secondary order")
	check(page.get_binding_control("walk", 0).text == "W", "Primary key label")
	check(page.get_binding_control("walk", 1).text == "Up", "Secondary key label")
	check(page.get_binding_control("jump", 1).text == "未绑定", "Unbound slot label")
	check(page.get_control("walk") == page.get_binding_control("walk", 0), "get_control compatibility returns primary")
	check(page.get_binding_control("walk", 2) == null, "Invalid slot safely rejected")
	var snapshot: Array = page.get_value("walk")
	snapshot[0] = KEY_X
	check(page.get_value("walk")[0] == KEY_W, "get_value snapshot cannot mutate internal pair")
	var all: Dictionary = page.get_values()
	all.walk[0] = KEY_X
	check(page.get_value("walk")[0] == KEY_W, "get_values deep copy")
	check(page.set_value("walk", [KEY_X | KEY_MASK_CTRL, KEY_UP]), "Silent programmatic chord update")
	check(calls.is_empty() and signals.is_empty(), "Silent set_value emits nothing")
	check(page.get_binding_control("walk", 0).text.contains("Ctrl"), "Chord display includes modifier")
	check(page.set_value("walk", [KEY_X | KEY_MASK_CTRL, KEY_UP], true) and calls.is_empty(), "Unchanged pair does not apply again")
	check(page.set_value("walk", [KEY_W, KEY_UP], true) and calls.size() == 1 and signals.size() == 1, "Changed pair invokes exactly one callback and signal")
	check(calls[-1] == ["walk", [KEY_W, KEY_UP]], "Callable gets full ordered pair and stable ID")
	for invalid in [[KEY_W], [KEY_W, KEY_W], [-1,0], [KEY_ESCAPE,0], [KEY_SHIFT,0], [KEY_DELETE,0], [KEY_BACKSPACE,0], ["W",0], [1.0,0]]:
		check(not page.set_value("walk", invalid), "Invalid pair rejected: " + str(invalid))
	check(page.get_value("walk") == [KEY_W, KEY_UP], "Invalid changes preserve model")
	check(not page.set_value("walk", [KEY_SPACE,0]), "Cross-row conflict rejected by API")
	check(not page.set_value("walk", [KEY_Q,0]), "Collapsed child's binding still participates in conflicts")
	var bad := schema.duplicate(true)
	bad[0].options[1].value = [KEY_SPACE,0]
	check(not page.configure(bad) and page.get_value("walk") == [KEY_W,KEY_UP], "Duplicate schema rejected atomically")
	check(page.add_option("Other", {"id":"separate", "type":"keybinding", "value":[KEY_W,0], "conflict_scope":"menu"}), "Separate explicit conflict scope allows same key")
	check(page.set_expanded("jump", true), "Binding item children expand by API")
	await settle()
	check(page.get_control("dash").is_visible_in_tree(), "Expanded binding shows child action")
	var header: HBoxContainer = page.get_control("header").get_parent()
	for id in ["walk", "jump", "dash", "map"]:
		var a: Button = page.get_binding_control(id, 0)
		var b: Button = page.get_binding_control(id, 1)
		check(absf(a.global_position.x - header.get_node("Primary").global_position.x) < 1.0, "Primary column aligned through hierarchy: " + id)
		check(absf(b.global_position.x - header.get_node("Secondary").global_position.x) < 1.0, "Secondary column aligned through hierarchy: " + id)
		check(absf(a.size.x - b.size.x) < 1.0, "Equal key column widths: " + id)
		check(absf(a.get_global_rect().get_center().y - b.get_global_rect().get_center().y) < 1.0, "Aligned row midlines: " + id)
	check(page.set_expanded("jump", false) and not page.get_control("dash").is_visible_in_tree(), "Collapse hides descendants")
	check(page.get_value("dash") == [KEY_Q,0], "Collapse preserves child value")
	check(not page.begin_binding_capture("dash", 0), "Hidden capture target rejected")
	check(page.begin_binding_capture("walk", 1), "Begin secondary capture")
	check(page.has_node("BindingCapture"), "Visible capture overlay created")
	await send_key(KEY_SHIFT)
	check(page.is_capturing_binding() and page.get_value("walk")[1] == KEY_UP, "Modifier alone waits without applying")
	await send_key(KEY_SHIFT, false)
	var before := calls.size()
	await send_key(KEY_K | KEY_MASK_CTRL | KEY_MASK_SHIFT)
	check(page.get_value("walk") == [KEY_W, KEY_K | KEY_MASK_CTRL | KEY_MASK_SHIFT], "Captures exact multi-modifier chord")
	check(not page.is_capturing_binding() and calls.size() == before + 1, "Capture closes and applies once")
	await send_key(KEY_K | KEY_MASK_CTRL | KEY_MASK_SHIFT, true, true)
	await send_key(KEY_K | KEY_MASK_CTRL | KEY_MASK_SHIFT, false)
	check(probe.keys.is_empty(), "Captured down, repeat and release do not reach app shortcuts")
	page.begin_binding_capture("walk", 0)
	await send_key(KEY_SPACE)
	check(page.is_capturing_binding() and page.get_value("walk")[0] == KEY_W, "Conflict leaves capture open and existing binding intact")
	check(conflicts[-1] == ["walk",0,"jump"] and page._capture_message.text.contains("跳跃"), "Conflict identifies existing action, never overwrites")
	await send_key(KEY_SPACE, false)
	await send_key(KEY_K | KEY_MASK_CTRL | KEY_MASK_SHIFT)
	check(page.is_capturing_binding() and conflicts[-1][2] == "walk", "Same-action duplicate shortcut rejected")
	await send_key(KEY_K | KEY_MASK_CTRL | KEY_MASK_SHIFT, false)
	await send_key(KEY_ESCAPE)
	check(not page.is_capturing_binding() and page.get_value("walk")[0] == KEY_W, "Escape cancels without changing binding")
	await send_key(KEY_ESCAPE, false)
	check(probe.keys.is_empty(), "Cancel Escape does not reach page back shortcut")
	page.begin_binding_capture("walk", 1)
	await send_key(KEY_DELETE)
	await send_key(KEY_DELETE, false)
	check(page.get_value("walk")[1] == 0 and not page.is_capturing_binding(), "Delete clears only selected slot")
	page.begin_binding_capture("walk", 0)
	await send_key(KEY_F10)
	await send_key(KEY_F10, false)
	check(page.get_value("walk")[0] == KEY_F10 and probe.keys.is_empty(), "F10 binds without triggering demo navigation")
	page.begin_binding_capture("walk", 0)
	await send_key(KEY_F12)
	await send_key(KEY_F12, false)
	check(page.get_value("walk")[0] == KEY_F12 and probe.keys.is_empty(), "F12 binds without triggering screenshots")
	page.begin_binding_capture("walk", 0)
	page.cancel_binding_capture()
	check(not page.is_capturing_binding() and not page.has_node("BindingCapture"), "Explicit cancel removes overlay immediately")
	page.begin_binding_capture("walk", 0)
	page.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not page.is_capturing_binding(), "Window focus loss cancels capture")
	page.begin_binding_capture("walk", 0)
	page.hide()
	check(not page.is_capturing_binding(), "Leaving settings cancels capture")
	page.show()
	page.begin_binding_capture("walk", 0)
	page.get_node("Tabs").current_tab = 1
	check(not page.is_capturing_binding(), "Changing tab cancels capture")
	page.get_node("Tabs").current_tab = 0
	page.set_expanded("jump", true)
	page.begin_binding_capture("dash", 0)
	page.set_expanded("group", false)
	check(not page.is_capturing_binding(), "Collapsing ancestor cancels child capture")
	page.set_expanded("group", true)
	page.set_expanded("jump", true)
	var old_button: Button = page.get_binding_control("walk", 0)
	check(page.add_option("Keys", {"id":"extra", "type":"keybinding", "value":[KEY_Z,0]}, "jump"), "Dynamically append binding under expandable binding item")
	check(page.get_expander("jump").button_pressed and page.get_value("walk")[0] == KEY_F12, "Rebuild preserves expansion and edited values")
	old_button.pressed.emit()
	check(not page.is_capturing_binding(), "Detached button cannot start stale capture")
	page.begin_binding_capture("walk", 0)
	page.clear()
	check(not page.is_capturing_binding() and page.get_values().is_empty(), "Clear cancels capture and removes model")
	page.queue_free()
	probe.queue_free()
	await settle()
	await test_main()
	await test_callback_rebuild()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_main() -> void:
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.show_page("Settings")
	var page = ui.get_node("Settings")
	var tabs: TabContainer = page.get_node("Tabs")
	check(tabs.get_tab_count() == 4 and tabs.get_tab_title(3) == "按键绑定", "Main settings includes fourth keybindings tab")
	tabs.current_tab = 3
	await settle()
	var scroll: ScrollContainer = tabs.get_current_tab_control()
	var initial_height: float = scroll.get_v_scroll_bar().max_value
	check(initial_height > scroll.get_v_scroll_bar().page, "Binding page naturally overflows and scrolls")
	var top := tabs.global_position.y
	var back_y: float = page.get_node("Back").global_position.y
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = page.get_binding_control("party_demo_move_forward",0).get_global_rect().get_center()
	page.route_scroll_input(wheel)
	await settle()
	check(scroll.scroll_vertical > 0, "Wheel over binding button scrolls the content")
	check(top == tabs.global_position.y and back_y == page.get_node("Back").global_position.y, "Tabs and back remain fixed while scrolling")
	page.set_expanded("bindings.movement", false)
	page.set_expanded("bindings.interaction", false)
	await settle()
	check(scroll.get_v_scroll_bar().max_value < initial_height, "Collapsing groups recomputes natural content height")
	check(not page.get_control("party_demo_move_forward").is_visible_in_tree(), "Group hides entire keybinding row")
	var navigation_before := InputMap.action_get_events("ui_accept")
	check(InputMap.has_action("party_demo_move_forward") and InputMap.action_get_events("party_demo_move_forward").size() == 2, "Main explicitly initializes actual two-event InputMap action")
	check(page.set_value("party_demo_move_forward",[KEY_K | KEY_MASK_CTRL, KEY_UP],true), "Main binding callback accepts chord")
	var events := InputMap.action_get_events("party_demo_move_forward")
	check(events.size() == 2 and events[0].keycode == KEY_K and events[0].ctrl_pressed, "Real application callback updates InputMap with modifiers")
	check(InputMap.action_get_events("ui_accept") == navigation_before, "Framework navigation InputMap untouched")
	page.set_expanded("bindings.movement", true)
	await settle()
	page.begin_binding_capture("party_demo_move_forward",0)
	await send_key(KEY_ESCAPE)
	await send_key(KEY_ESCAPE,false)
	check(ui.page == "Settings", "Real main Escape capture cancel does not navigate away")
	ui.queue_free()
	await settle()

func test_callback_rebuild() -> void:
	var page = load("res://settings/settings_page.tscn").instantiate()
	root.add_child(page)
	page.configure([{"id":"Keys", "options":[{"id":"key", "type":"keybinding", "value":[KEY_W,0], "callback":func(_value,_id): page.configure([{"id":"New","options":[]}])}]}])
	await settle()
	page.begin_binding_capture("key",0)
	await send_key(KEY_K)
	await send_key(KEY_K,false)
	check(page.get_node("Tabs").get_tab_count() == 1 and page.get_node("Tabs").get_child(0).name == "New" and not page.is_capturing_binding(), "Application callback may rebuild page during capture commit")
	page.queue_free()
	await settle()
