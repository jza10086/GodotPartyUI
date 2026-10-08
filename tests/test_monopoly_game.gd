extends SceneTree
var checks := 0
var failures := 0
var rolls := 0
var items: Array = []
var actions: Array = []
var choices: Array = []
var dismissals: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)
func press(key: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.shift_pressed = shift
	root.push_input(event)
	var release := InputEventKey.new()
	release.keycode = key
	root.push_input(release)
func sample() -> Dictionary:
	return {"money": 12800, "diamonds": 36, "leaderboard": [{"id": "p1", "name": "蓝莓", "value": "12800", "is_self": true}], "inventory": [{"id": "shield", "name": "很长很长的中文道具名用于验证省略与完整提示", "count": 2}, {"id": "empty", "name": "空道具", "count": 0}, {"id": "locked", "name": "锁定道具", "count": 1, "enabled": false, "reason": "当前不可用"}], "actions": [{"id": "buy", "label": "购买"}, {"id": "skip", "label": "跳过", "enabled": false}], "roll_enabled": true, "roll_hint": "等待行动"}
func event_data(id := "chance") -> Dictionary:
	return {"id": id, "title": "随机事件", "body": "来自外部游戏的事件内容。", "choices": [{"id": "yes", "label": "接受"}, {"id": "no", "label": "离开"}, {"id": "locked", "label": "条件不足", "enabled": false}]}
func run() -> void:
	var scene = load("res://ui/pages/monopoly_game.tscn")
	var page = scene.instantiate()
	check(page.set_snapshot(sample()), "Pre-ready snapshot accepted")
	root.add_child(page)
	await process_frame
	await process_frame
	page.roll_requested.connect(func(): rolls += 1)
	page.item_requested.connect(func(id): items.append(id))
	page.action_requested.connect(func(id): actions.append(id))
	page.event_choice_requested.connect(func(id, choice): choices.append([id, choice]))
	page.event_dismissed.connect(func(id, reason): dismissals.append([id, reason]))
	check(page.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Transparent root allows center input through")
	check(not page.has_node("Board") and not page.has_node("Background"), "No board/background in production UI")
	check(not page.has_node("TurnPanel"), "No 2D dice display")
	check(page.get_node("Wallet/Margin/Values/Money/Value").text == "12,800", "Money formatted")
	check(page.get_node("Wallet/Margin/Values/Diamonds/Value").text == "36", "Diamonds rendered")
	check(page.get_node("Actions/Roll").disabled == false, "External roll state enables button")
	press(KEY_SPACE)
	check(rolls == 0, "No global Space shortcut")
	page.request_roll()
	page.request_roll()
	check(rolls == 1 and page.get_node("Actions/Roll").disabled, "Roll latches before callback")
	page.set_wallet(7, 8)
	page.request_roll()
	check(rolls == 1, "Unrelated setter preserves pending roll")
	page.set_roll_enabled(false, "等待其他玩家")
	page.request_roll()
	check(rolls == 1, "Disabled roll guarded")
	page.set_roll_enabled(true)
	page.request_roll()
	check(rolls == 2, "Explicit availability setter rearms roll")
	for id in ["missing", "empty", "locked"]: page.request_item(id)
	check(items.is_empty(), "Unavailable/missing/zero-count items guarded")
	page.request_item("shield")
	page.request_item("shield")
	check(items == ["shield"], "Stable item ID emitted once")
	page.set_status("新状态")
	page.request_item("shield")
	check(items.size() == 1, "Status update preserves item latch")
	page.set_inventory(sample().inventory)
	page.request_item("shield")
	check(items.size() == 2, "Inventory setter rearms item")
	check(page.get_snapshot().inventory[0].count == 2, "UI never consumes inventory")
	page.request_action("skip")
	page.request_action("buy")
	page.request_action("buy")
	check(actions == ["buy"], "Action availability and one-shot ID")
	page.set_actions(sample().actions)
	page.request_action("buy")
	check(actions.size() == 2, "Action setter rearms")
	var detached: Dictionary = page.get_snapshot()
	detached.inventory[0].name = "mutated"
	check(page.get_snapshot().inventory[0].name != "mutated", "Deep defensive getter")
	var before: Dictionary = page.get_snapshot()
	for patch in [{"money": -1}, {"diamonds": "36"}, {"roll_enabled": 1}, {"status": 7}, {"leaderboard": [{"id": "x", "name": "x", "value": 4}]}, {"inventory": [{"id": "x", "name": "x", "count": -1}]}, {"actions": [{"id": "", "label": "x"}]}, {"actions": [{"id": "x", "label": "x"}, {"id": "x", "label": "x"}]}]:
		var bad := sample()
		bad.merge(patch, true)
		check(not page.set_snapshot(bad), "Reject malformed " + str(patch.keys()))
		check(page.get_snapshot() == before, "Failure atomic " + str(patch.keys()))
	var ranks := []
	for i in 8: ranks.append({"id": str(i), "name": "很长的中文名字用于完整提示" + str(i), "value": str(100-i)})
	check(page.set_leaderboard(ranks), "Eight rank rows accepted")
	await process_frame
	await process_frame
	check(page.get_node("Leaderboard/Body/Margin/Rows").get_child_count() == 8, "Eight rows rendered")
	check(page.get_node("Leaderboard/Body/Margin/Rows").get_child(7).get_node("Margin/Row/Name").text == ranks[7].name, "External ranking order preserved")
	ranks.append({"id": "9", "name": "nine", "value": "0"})
	check(not page.set_leaderboard(ranks), "Reject ninth rank atomically")
	page.set_leaderboard_open(false)
	check(not page.get_node("Leaderboard/Body").visible, "Leaderboard collapses")
	page.set_leaderboard_open(true)
	page.set_inventory_open(false)
	check(not page.get_node("Inventory/Body").visible, "Inventory collapses")
	page.set_inventory_open(true)
	var item = page.get_node("Inventory/Body/Margin/Scroll/Items").get_child(0)
	check(sample().inventory[0].name in item.tooltip_text and item.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "Long item name preserved with ellipsis")
	page.set_inventory([])
	check(page.get_node("Inventory/Body/Margin/Scroll/Items").get_child(0).text == "背包是空的", "Empty inventory state")
	page.set_snapshot(sample())
	page.get_node("Actions/Roll").grab_focus()
	check(page.show_event(event_data()), "Event opens")
	check(page.is_modal_open() and page.get_node("EventModal").visible, "Modal visible")
	check(page.get_node("Actions/Roll").disabled and page.get_node("Inventory/Toggle").disabled, "Modal disables background controls")
	var counts := [rolls, items.size(), actions.size()]
	page.request_roll()
	page.request_item("shield")
	page.request_action("buy")
	check(counts == [rolls, items.size(), actions.size()], "Public methods respect modal guard")
	for i in 12:
		press(KEY_TAB, i % 2 == 0)
		check(page.get_node("EventModal").is_ancestor_of(root.gui_get_focus_owner()), "Modal Tab focus trapped %d" % i)
	page.request_event_choice("locked")
	page.request_event_choice("yes")
	page.request_event_choice("no")
	check(choices == [["chance", "yes"]], "Choice request latches with event + choice stable IDs")
	check(page.is_modal_open(), "Choice does not auto-dismiss authoritative event")
	check(page.show_event(event_data()), "Same ID refresh allowed")
	check(dismissals.is_empty(), "Same ID refresh does not dismiss")
	page.request_event_choice("no")
	check(choices.size() == 2, "Refresh rearms choices")
	page.show_event(event_data("new"))
	check(dismissals == [["chance", "replaced"]], "Replacement reports displaced ID")
	var old: Dictionary = page.get_event()
	var malformed := event_data("bad")
	malformed.choices[0].id = ""
	check(not page.show_event(malformed) and page.get_event() == old, "Malformed event does not replace active event")
	press(KEY_ESCAPE)
	check(not page.is_modal_open(), "Escape closes dismissible event")
	check(root.gui_get_focus_owner() == page.get_node("Actions/Roll"), "Focus restored across replacement")
	var n := dismissals.size()
	page.close_event()
	check(dismissals.size() == n, "Repeated close silent")
	var locked := event_data("forced")
	locked.dismissible = false
	page.show_event(locked)
	press(KEY_ESCAPE)
	check(page.is_modal_open() and not page.close_event(), "Non-dismissible event ignores Escape/close")
	check(not page.dismiss_event("wrong"), "Stale authoritative dismiss ignored")
	check(page.dismiss_event("forced"), "Controller closes matching forced event")
	var reenter := func(id, _reason):
		if id == "first": page.show_event(event_data("callback"))
	page.event_dismissed.connect(reenter)
	page.show_event(event_data("first"))
	page.show_event(event_data("second"))
	check(page.get_event().id == "callback", "Replacement reentrant callback not overwritten")
	page.close_event()
	page.event_dismissed.disconnect(reenter)
	page.hide()
	page.set_roll_enabled(true)
	page.request_roll()
	check(rolls == counts[0], "Hidden HUD rejects interaction requests")
	page.queue_free()
	await process_frame
	var early = scene.instantiate()
	early.show_event(event_data("early"))
	root.add_child(early)
	await process_frame
	check(early.get_node("EventModal").visible, "Pre-ready event rendered")
	early.queue_free()
	var demo = load("res://examples/monopoly_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	check(demo is Node3D and demo.get_node("Overlay") is CanvasLayer, "Demo full-screen 3D with CanvasLayer overlay")
	check(demo.get_node("Overlay/HUD").get_snapshot().leaderboard.size() == 4, "Sample controller initializes four ranks")
	demo.get_node("Driver").begin(8)
	check(demo.get_node("Overlay/HUD").get_snapshot().leaderboard.size() == 8, "Sample eight-player mode")
	demo.queue_free()
	await process_frame
	print("MONOPOLY HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
