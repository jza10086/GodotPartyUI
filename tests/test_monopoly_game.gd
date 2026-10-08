extends SceneTree

const EVENT_CONTENT := "EventModal/Center/Dialog/Margin/Content"
const INVENTORY_ITEMS := "Inventory/Body/Margin/Scroll/Items"
const RANK_ROWS := "Leaderboard/Body/Margin/Rows"

var checks := 0
var failures := 0
var rolls := 0
var items: Array = []
var choices: Array = []
var dismissals: Array = []
var modal_changes: Array = []

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
	return {
		"money": 12800, "diamonds": 36,
		"leaderboard": [{"id": "p1", "name": "蓝莓", "money": 12800, "diamonds": 36, "is_self": true}],
		"inventory": [
			{"id": "shield", "name": "很长很长的中文道具名用于验证省略与完整提示", "count": 2},
			{"id": "empty", "name": "空道具", "count": 0},
			{"id": "locked", "name": "锁定道具", "count": 1, "enabled": false, "reason": "当前不可用"}
		],
		"roll_enabled": true, "roll_hint": "等待行动"
	}

func event_data(id := "chance") -> Dictionary:
	return {
		"id": id, "title": "随机事件", "body": "来自外部游戏的事件内容。",
		"choices": [
			{"id": "yes", "label": "接受"},
			{"id": "no", "label": "离开"},
			{"id": "locked", "label": "条件不足", "enabled": false}
		]
	}

func run() -> void:
	var scene = load("res://ui/pages/monopoly_game.tscn")
	var page = scene.instantiate()
	check(page.set_snapshot(sample()), "Pre-ready snapshot accepted")
	root.add_child(page)
	await process_frame
	await process_frame
	page.roll_requested.connect(func(): rolls += 1)
	page.item_requested.connect(func(id): items.append(id))
	page.event_choice_requested.connect(func(id, choice): choices.append([id, choice]))
	page.event_dismissed.connect(func(id, reason): dismissals.append([id, reason]))
	page.modal_visibility_changed.connect(func(open): modal_changes.append(open))
	check(page.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Transparent root allows center input through")
	check(not page.has_node("Board") and not page.has_node("Background"), "No board/background in production UI")
	check(not page.has_node("TurnPanel"), "No 2D dice result display")
	check(not page.has_node("Actions") and not page.get_snapshot().has("actions"), "No standalone action UI or snapshot field")
	check(not page.has_signal("action_requested") and not page.has_method("request_action") and not page.has_method("set_actions"), "Standalone action signal and APIs removed")
	check(not page.has_node("Leaderboard/Toggle") and not page.has_method("set_leaderboard_open"), "Leaderboard has no collapse control or API")
	check(page.get_node("Leaderboard/Body").visible, "Leaderboard permanently visible")
	check(not page.get_node("Inventory/Body").visible, "Inventory initially closed")
	check(page.get_node("Wallet/Margin/Values/Money/Value").text == "12,800", "Money formatted")
	check(page.get_node("Wallet/Margin/Values/Diamonds/Value").text == "36", "Diamonds rendered")
	var roll: TextureButton = page.get_node("Roll/Button")
	var inventory_toggle: TextureButton = page.get_node("Inventory/Toggle")
	check(roll != null and roll.texture_normal != null, "Roll uses a textured icon button")
	check(inventory_toggle != null and inventory_toggle.texture_normal != null, "Inventory uses a textured icon button")
	check(roll.focus_mode == Control.FOCUS_ALL and inventory_toggle.focus_mode == Control.FOCUS_ALL, "Icon buttons retain keyboard focus")
	var roll_root: Control = page.get_node("Roll")
	check(is_equal_approx(roll_root.anchor_left, 1.0) and is_equal_approx(roll_root.anchor_right, 1.0) and is_equal_approx(roll_root.anchor_top, 1.0) and is_equal_approx(roll_root.anchor_bottom, 1.0), "Roll anchored at bottom right")
	check(roll.size.x <= 112.0 and roll.size.y <= 112.0, "Roll icon button stays compact")
	var leaderboard: Control = page.get_node("Leaderboard")
	check(is_equal_approx(leaderboard.anchor_left, 1.0) and is_equal_approx(leaderboard.anchor_right, 1.0) and is_equal_approx(leaderboard.anchor_top, 0.5) and is_equal_approx(leaderboard.anchor_bottom, 0.5) and leaderboard.grow_vertical == Control.GROW_DIRECTION_BOTH, "Permanent leaderboard anchored at right center")
	var wallet: Control = page.get_node("Wallet")
	check(is_zero_approx(wallet.anchor_left) and is_zero_approx(wallet.anchor_top), "Compact wallet anchored at top left")
	check(wallet.size.y <= 80.0, "Wallet remains a compact single row")
	check(inventory_toggle.size.x <= 104.0 and inventory_toggle.size.y <= 104.0, "Backpack icon button stays compact")
	var inventory: Control = page.get_node("Inventory")
	check(is_zero_approx(inventory.anchor_left) and is_equal_approx(inventory.anchor_top, 1.0) and is_equal_approx(inventory.anchor_bottom, 1.0), "Inventory anchored at bottom left")
	check(page.get_node(INVENTORY_ITEMS) is HBoxContainer, "Inventory items form one horizontal row")
	var inventory_scroll: ScrollContainer = page.get_node("Inventory/Body/Margin/Scroll")
	check(inventory_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and inventory_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Inventory scrolls horizontally only")
	check(not roll.disabled, "External roll state enables button")
	press(KEY_SPACE)
	check(rolls == 0, "No global Space shortcut")
	page.request_roll()
	page.request_roll()
	check(rolls == 1 and roll.disabled, "Roll latches before callback")
	page.set_wallet(7, 8)
	page.request_roll()
	check(rolls == 1, "Unrelated setter preserves pending roll")
	page.set_roll_enabled(false, "等待其他玩家")
	page.request_roll()
	check(rolls == 1, "Disabled roll guarded")
	page.set_roll_enabled(true)
	page.request_roll()
	check(rolls == 2, "Explicit availability setter rearms roll")
	page.set_inventory_open(true)
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
	var stale_item: Button = page.get_node(INVENTORY_ITEMS).get_child(0)
	page.set_inventory(sample().inventory)
	stale_item.pressed.emit()
	check(items.size() == 2, "Detached inventory button cannot trigger a newer snapshot with the same ID")
	page.get_node(INVENTORY_ITEMS).get_child(0).pressed.emit()
	check(items.size() == 3, "Current inventory button remains usable after snapshot replacement")
	var detached: Dictionary = page.get_snapshot()
	detached.inventory[0].name = "mutated"
	detached.leaderboard[0].money = 0
	check(page.get_snapshot().inventory[0].name != "mutated" and page.get_snapshot().leaderboard[0].money == 12800, "Deep defensive snapshot getter")
	var before: Dictionary = page.get_snapshot()
	var malformed_patches := [
		{"money": -1}, {"diamonds": "36"}, {"roll_enabled": 1}, {"status": 7},
		{"leaderboard": [{"id": "x", "name": "x", "value": "4"}]},
		{"leaderboard": [{"id": "x", "name": "x", "money": -1, "diamonds": 0}]},
		{"leaderboard": [{"id": "x", "name": "x", "money": 1, "diamonds": -1}]},
		{"leaderboard": [{"id": "x", "name": "x", "money": "1", "diamonds": 0}]},
		{"leaderboard": [{"id": "x", "name": "x", "money": 1, "diamonds": 0.5}]},
		{"inventory": [{"id": "x", "name": "x", "count": -1}]},
		{"actions": []}, {"actions": [{"id": "buy", "label": "购买"}]}
	]
	for patch in malformed_patches:
		var bad := sample()
		bad.merge(patch, true)
		check(not page.set_snapshot(bad), "Reject malformed " + str(patch))
		check(page.get_snapshot() == before, "Failure atomic " + str(patch.keys()))
		if patch.has("actions"):
			check("actions" in page.last_error, "Removed actions field reports a clear migration error")
	page.request_item("shield")
	page.request_roll()
	check(items.size() == 3 and rolls == 2, "Rejected snapshots preserve interaction latches")
	var ranks := []
	for i in 8:
		ranks.append({"id": str(i), "name": "很长的中文名字用于完整提示" + str(i), "money": 12800 - i * 100, "diamonds": 36 - i})
	check(page.set_leaderboard(ranks), "Eight rank rows accepted")
	await process_frame
	await process_frame
	var rank_rows: VBoxContainer = page.get_node(RANK_ROWS)
	check(rank_rows.get_child_count() == 8, "Eight rows rendered")
	for i in 8:
		var row = rank_rows.get_child(i)
		check(row.get_node("Margin/Row/Rank").text == "%02d" % (i + 1), "Rank position rendered %d" % i)
		check(row.get_node("Margin/Row/Name").text == ranks[i].name, "External ranking order preserved %d" % i)
		check(row.get_node("Margin/Row/Money/Value").text == "12,%03d" % (800 - i * 100) and row.get_node("Margin/Row/Diamonds/Value").text == str(36 - i), "Rank shows formatted coins and diamonds %d" % i)
	check(rank_rows.get_child(7).get_node("Margin/Row/Name").tooltip_text == ranks[7].name, "Long rank name retains full tooltip")
	var rank_snapshot: Dictionary = page.get_snapshot()
	ranks.append({"id": "9", "name": "nine", "money": 0, "diamonds": 0})
	check(not page.set_leaderboard(ranks) and page.get_snapshot() == rank_snapshot, "Reject ninth rank atomically")
	page.set_inventory_open(false)
	check(not page.get_node("Inventory/Body").visible and page.get_node("Leaderboard/Body").visible, "Closing inventory leaves all rankings visible")
	page.set_inventory_open(true)
	var item: Button = page.get_node(INVENTORY_ITEMS).get_child(0)
	check(sample().inventory[0].name in item.tooltip_text and item.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "Long item name preserved with ellipsis")
	var many_items := []
	for i in 12: many_items.append({"id": "item-%d" % i, "name": "道具 %d" % i, "count": 1})
	check(page.set_inventory(many_items), "Long horizontal inventory accepted")
	await process_frame
	await process_frame
	var inventory_body: Control = page.get_node("Inventory/Body")
	check(inventory_body.global_position.x >= inventory_toggle.get_global_rect().end.x, "Open inventory expands to the right of the backpack")
	check(is_equal_approx(inventory_body.size.x, 760.0) and inventory_scroll.get_h_scroll_bar().max_value > inventory_scroll.get_h_scroll_bar().page, "Long inventory keeps a bounded horizontal scroll area")
	var horizontal_items: HBoxContainer = page.get_node(INVENTORY_ITEMS)
	check(is_equal_approx(horizontal_items.get_child(0).position.y, horizontal_items.get_child(11).position.y), "Long inventory stays in one row")
	page.set_inventory([])
	check(page.get_node(INVENTORY_ITEMS).get_child(0).text == "背包是空的", "Empty inventory state")
	page.set_snapshot(sample())
	roll.grab_focus()
	var art_image := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	art_image.fill(Color(0.4, 0.7, 0.9, 1.0))
	var art: Texture2D = ImageTexture.create_from_image(art_image)
	var illustrated := event_data()
	illustrated.illustration = art
	illustrated.illustration_alt = "一份神秘邀请"
	check(page.show_event(illustrated), "Event with external illustration opens")
	check(page.is_modal_open() and page.get_node("EventModal").visible, "Modal visible")
	var illustration: TextureRect = page.get_node(EVENT_CONTENT + "/Illustration")
	check(illustration.visible and illustration.texture == art, "Optional event illustration rendered")
	check(illustration.tooltip_text == illustrated.illustration_alt, "Event illustration keeps descriptive alternative text")
	var detached_event: Dictionary = page.get_event()
	detached_event.choices[0].label = "mutated"
	check(page.get_event().choices[0].label == "接受" and page.get_event().illustration == art, "Event getter deep-copies containers while preserving the texture resource")
	check(roll.disabled and inventory_toggle.disabled, "Modal disables background controls")
	var counts := [rolls, items.size()]
	page.request_roll()
	page.request_item("shield")
	check(counts == [rolls, items.size()], "Public methods respect modal guard")
	var original_event: Dictionary = page.get_event()
	var original_modal_changes := modal_changes.size()
	for patch in [{"illustration": "res://not-a-texture.png"}, {"illustration": 42}, {"illustration": art_image}, {"illustration_alt": 7}]:
		var bad_event := event_data("bad-art")
		bad_event.merge(patch, true)
		check(not page.show_event(bad_event), "Reject invalid illustration field " + str(patch.keys()))
		check(page.get_event() == original_event and illustration.texture == art and illustration.visible, "Invalid illustration leaves active event and artwork unchanged")
		check(dismissals.is_empty() and modal_changes.size() == original_modal_changes, "Invalid illustration emits no dismissal or modal transition")
	for i in 12:
		press(KEY_TAB, i % 2 == 0)
		check(page.get_node("EventModal").is_ancestor_of(root.gui_get_focus_owner()), "Modal Tab focus trapped %d" % i)
	page.request_event_choice("locked")
	page.request_event_choice("yes")
	page.request_event_choice("no")
	check(choices == [["chance", "yes"]], "Choice request latches with event + choice stable IDs")
	check(page.is_modal_open(), "Choice does not auto-dismiss authoritative event")
	var bad_refresh := event_data()
	bad_refresh.illustration = false
	check(not page.show_event(bad_refresh), "Invalid illustrated refresh rejected")
	page.request_event_choice("no")
	check(choices.size() == 1, "Rejected event refresh preserves choice latch")
	var stale_choice: Button = page.get_node(EVENT_CONTENT + "/ChoicesScroll/Choices").get_child(0)
	check(page.show_event(event_data()), "Same ID refresh allowed")
	check(not illustration.visible and illustration.texture == null and illustration.tooltip_text.is_empty(), "Refresh without illustration clears previous artwork and alt text")
	check(dismissals.is_empty(), "Same ID refresh does not dismiss")
	stale_choice.pressed.emit()
	check(choices.size() == 1, "Detached event choice cannot activate refreshed event")
	page.request_event_choice("no")
	check(choices.size() == 2, "Refresh rearms choices")
	var null_illustration := event_data()
	null_illustration.illustration = null
	check(page.show_event(null_illustration) and not illustration.visible and illustration.texture == null, "Explicit null illustration accepted and hidden")
	page.show_event(event_data("new"))
	check(dismissals == [["chance", "replaced"]], "Replacement reports displaced ID")
	var old: Dictionary = page.get_event()
	var malformed := event_data("bad")
	malformed.choices[0].id = ""
	check(not page.show_event(malformed) and page.get_event() == old, "Malformed event does not replace active event")
	press(KEY_ESCAPE)
	check(not page.is_modal_open(), "Escape closes dismissible event")
	check(root.gui_get_focus_owner() == roll, "Focus restored across replacement")
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
	page.set_inventory(sample().inventory)
	page.request_item("shield")
	check(rolls == counts[0] and items.size() == counts[1], "Hidden HUD rejects interaction requests")
	page.queue_free()
	await process_frame
	var early = scene.instantiate()
	var early_event := event_data("early")
	early_event.illustration = art
	early_event.body = "很长的事件说明，用来验证正文滚动不会撑大弹窗。\n".repeat(80)
	early_event.choices = []
	for i in 32: early_event.choices.append({"id": "choice-%d" % i, "label": "事件选项 %d" % i})
	check(early.show_event(early_event), "Pre-ready illustrated event accepted")
	root.add_child(early)
	await process_frame
	check(early.get_node("EventModal").visible and early.get_node(EVENT_CONTENT + "/Illustration").texture == art, "Pre-ready illustrated event rendered")
	await process_frame
	var dialog: Control = early.get_node("EventModal/Center/Dialog")
	check(dialog.size.x <= 760.0 and dialog.size.y <= 900.0, "Large illustration, long body and 32 choices keep a bounded dialog")
	check(early.get_node(EVENT_CONTENT + "/Illustration").size.y <= 160.0, "External illustration dimensions cannot expand the modal")
	var choice_scroll: ScrollContainer = early.get_node(EVENT_CONTENT + "/ChoicesScroll")
	var body_scroll: ScrollContainer = early.get_node(EVENT_CONTENT + "/BodyScroll")
	check(choice_scroll.get_v_scroll_bar().max_value > choice_scroll.get_v_scroll_bar().page and body_scroll.get_v_scroll_bar().max_value > body_scroll.get_v_scroll_bar().page, "Long body and maximum choices remain independently scrollable")
	early.queue_free()
	var demo = load("res://examples/monopoly_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	check(demo is Node3D and demo.get_node("Overlay") is CanvasLayer, "Demo full-screen 3D with CanvasLayer overlay")
	var demo_hud = demo.get_node("Overlay/HUD")
	check(demo_hud.get_snapshot().leaderboard.size() == 4, "Sample controller initializes four ranks")
	check(not demo_hud.get_snapshot().has("actions") and not demo_hud.get_node("Inventory/Body").visible, "Sample starts with updated schema and closed inventory")
	demo.get_node("Driver").begin(8)
	check(demo_hud.get_snapshot().leaderboard.size() == 8, "Sample eight-player mode")
	check(demo_hud.get_snapshot().leaderboard[7].money is int and demo_hud.get_snapshot().leaderboard[7].diamonds is int, "Sample ranks supply both integer currencies")
	demo.queue_free()
	await process_frame
	print("MONOPOLY HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
