extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)
func run() -> void:
	var demo = load("res://examples/monopoly_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	var page = demo.get_node("Page")
	var driver = demo.get_node("Driver")
	check(page.get_snapshot().players.size() == 4, "Default demo has four players")
	check(page._tiles().size() == 24, "24 editable perimeter tiles")
	check(page.get_node("EndTurn").disabled, "End-turn unavailable before roll")
	page.request_end_turn()
	check(driver.state.active == 0, "Premature end-turn ignored")
	page.request_item(1)
	check("租金护盾" in driver.state.item_hint, "Item preview updates explanatory copy")
	page.get_node("Item0").grab_focus()
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space)
	check(driver.state.players[0].position == 7 and driver.state.rolled, "Deterministic 3+4 roll moves exactly seven tiles")
	page.request_roll()
	check(driver.roll_cursor == 1, "Repeated roll is guarded")
	check(page.get_node("TurnPanel/Roll").disabled, "Roll button disables after movement")
	page.get_node("EndTurn").grab_focus()
	page.show_property(1)
	check(page.get_node("Modal").visible, "Property popup opens")
	check(page.get_node("Modal/Dialog/Name").text == "蓝湾大道", "Property title matches selected tile")
	check(page.get_node("EndTurn").disabled and page.get_node("Back").disabled, "Modal blocks background controls")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	check(root.gui_get_focus_owner() == page.get_node("Modal/Dialog/Close"), "Tab remains inside modal")
	tab.shift_pressed = true
	root.push_input(tab)
	check(root.gui_get_focus_owner() == page.get_node("Modal/Dialog/Close"), "Shift-Tab remains inside modal")
	page.request_end_turn()
	check(driver.state.active == 0, "Modal prevents turn transition")
	page.show_property(2)
	check(page.get_node("Modal/Dialog/Name").text == "蓝湾大道", "Repeated property open cannot replace active dialog")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	page._unhandled_key_input(esc)
	check(not page.get_node("Modal").visible, "Escape closes modal")
	check(root.gui_get_focus_owner() == page.get_node("EndTurn"), "Closing modal restores prior keyboard focus")
	page.request_end_turn()
	check(driver.state.active == 1 and not driver.state.rolled, "End turn advances player and resets phase")
	page.request_end_turn()
	check(driver.state.active == 1, "Repeated end-turn guarded")
	page.show_property(0)
	check("特殊地块" in page.get_node("Modal/Dialog/District").text, "Special tiles have distinct details")
	page.close_property()
	page.close_property()
	driver.begin(8)
	await process_frame
	await process_frame
	check(page.get_node("Players").get_children().all(func(card): return card.visible), "All eight roster cards visible")
	check(page.get_node("Players/Player8").get_global_rect().end.y <= 1000, "Eight-player roster stays above footer")
	for i in 8:
		page.request_roll()
		page.request_end_turn()
	check(driver.state.active == 0 and driver.state.round == 4, "Full eight-player cycle increments round")
	var snapshot: Dictionary = page.get_snapshot()
	var readonly := snapshot.duplicate(true)
	readonly.can_act = false
	check(page.set_snapshot(readonly), "Read-only snapshot accepted")
	check(page.get_node("TurnPanel/Roll").disabled and page.get_node("Item0").disabled, "Non-active viewer cannot issue turn actions")
	page.request_roll()
	check(driver.roll_cursor == 8, "Read-only roll request ignored")
	var bad := snapshot.duplicate(true)
	bad.players.append(bad.players[0].duplicate())
	check(not page.set_snapshot(bad), "Reject >8 players")
	bad = snapshot.duplicate(true)
	bad.players[1].id = bad.players[0].id
	check(not page.set_snapshot(bad), "Reject duplicate IDs")
	bad = snapshot.duplicate(true)
	bad.players[0].position = 24
	check(not page.set_snapshot(bad), "Reject out-of-range tile")
	bad = snapshot.duplicate(true)
	bad.active = 8
	check(not page.set_snapshot(bad), "Reject invalid current player")
	bad = snapshot.duplicate(true)
	bad.players[0].color = "invalid"
	check(not page.set_snapshot(bad), "Reject non-Color optional color")
	bad = snapshot.duplicate(true)
	bad.can_act = "yes"
	check(not page.set_snapshot(bad), "Reject malformed action flag")
	check(page.get_snapshot() == readonly, "Invalid state does not corrupt last valid snapshot")
	var detached: Dictionary = page.get_snapshot()
	detached.players[0].name = "Mutated"
	check(page.get_snapshot().players[0].name != "Mutated", "Snapshot getter is defensive copy")
	var crowded := snapshot.duplicate(true)
	for player in crowded.players: player.position = 0
	crowded.players[0].name = "很长很长的中文玩家名字用于验证布局"
	page.set_snapshot(crowded)
	check("+6" in page.get_node("Board/Tile00/Tokens").text, "Crowded tile compresses token labels")
	check("P8" in page.get_node("Board/Tile00").tooltip_text, "Crowded tile tooltip preserves full roster")
	check(crowded.players[0].name in page.get_node("Players/Player1/Content/Name").tooltip_text, "Long names preserved in tooltip")
	var early = load("res://ui/pages/monopoly_game.tscn").instantiate()
	check(early.set_snapshot(snapshot), "Snapshot accepted before ready")
	root.add_child(early)
	await process_frame
	check(early.get_node("PlayerCount").text.begins_with("8"), "Pre-ready state rendered on ready")
	early.queue_free()
	demo.queue_free()
	await process_frame
	print("MONOPOLY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
