extends SceneTree
var ui: Control
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func press(path: String) -> void: ui.get_node(path).pressed.emit()
func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	ui._unhandled_key_input(event)
func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	check(ui.get_node("Home/Profile").get_global_rect() == Rect2(1400,56,424,96), "Top right profile precise geometry")
	check(ui.get_node("Home/Profile/Name").position.x < ui.get_node("Home/Profile/Avatar").position.x, "Name left avatar right")
	press("Home/Profile")
	check(ui.modal_kind == "Profile", "Profile opens")
	check(ui.get_node("Home/Profile").focus_mode == Control.FOCUS_NONE, "Profile isolates background focus")
	ui.get_node("Modal/Profile/Name").text = "   "
	press("Modal/Profile/Confirm")
	check(ui.modal_kind == "Profile" and ui.player_name == "你", "Blank name rejected")
	ui.get_node("Modal/Profile/Name").text = "取消名字"
	press("Modal/Profile/Cancel")
	check(ui.player_name == "你", "Cancel discards profile draft")
	press("Home/Profile")
	check(ui.get_node("Modal/Profile/Name").text == "你", "Reopen restores committed profile")
	ui.get_node("Modal/Profile/Name").text = "  星野  "
	ui.get_node("Modal/Profile/Name").text_submitted.emit("  星野  ")
	check(ui.player_name == "星野" and ui.modal_kind.is_empty(), "Enter saves trimmed profile")
	check(ui.get_node("Home/Profile/Name").text == "星野", "Home reflects saved name")
	press("Home/Profile")
	ui.get_node("Modal/Profile/Name").text = "另一名字"
	escape()
	check(ui.player_name == "星野" and ui.page == "Home", "Escape cancels profile")
	press("Home/Start")
	check(ui.get_node("Modal/Create/RoomName").text == "我的派对", "Create default name")
	check(ui.get_node("Modal/Create/Password").secret, "Password always masked")
	check(ui.get_node("Modal/Create/Password").get_theme_color("font_placeholder_color").r < 0.5, "Password placeholder readable")
	check(ui.get_node("Modal/Direct/Address").get_theme_color("font_placeholder_color").r < 0.5, "IP placeholder readable")
	check(ui.get_node("Modal/Create/Visibility").item_count == 3, "All visibility choices")
	check(ui.get_node("Modal/Dialog").get_global_rect() == Rect2(520,176,880,684), "Create expanded panel geometry")
	for field in ["Game", "RoomName", "Password", "Visibility", "Confirm", "Cancel"]:
		check(ui.get_node("Modal/Dialog").get_global_rect().encloses(ui.get_node("Modal/Create/" + field).get_global_rect()), "Create control contained: " + field)
	ui.get_node("Modal/Create/RoomName").text = " "
	press("Modal/Create/Confirm")
	check(ui.modal_kind == "Create" and ui.page == "Home", "Blank room rejected")
	ui.get_node("Modal/Create/RoomName").text = "周末同乐"
	ui.get_node("Modal/Create/Password").text = "   "
	press("Modal/Create/Confirm")
	check(ui.modal_kind == "Create", "Whitespace-only password rejected")
	ui.get_node("Modal/Create/Password").text = "test-only-123"
	ui.get_node("Modal/Create/Visibility").select(1)
	ui.select_game(3)
	press("Modal/Create/Confirm")
	check(ui.page == "Lobby" and ui.is_host, "Create submits host lobby")
	check(ui.get_node("Lobby/LobbyTitle").text == "周末同乐", "Room title carried")
	check(ui.room_visibility == 1 and ui.room_has_password, "Visibility and protection state carried")
	check(ui.game_index == 3, "Selected game carried")
	check(ui.get_node("Lobby/LobbySubtitle").text.contains("仅限好友") and ui.get_node("Lobby/LobbySubtitle").text.contains("已设密码"), "Lobby shows safe metadata")
	check(not ui.get_node("Lobby/LobbySubtitle").text.contains("test-only"), "No raw secret in lobby")
	check(ui.get_node("Modal/Create/Password").text.is_empty(), "Raw password cleared after submit")
	check(ui.get_node("Lobby/SlotName0").text == "星野 · 房主", "Profile name in host row")
	press("Lobby/Back")
	press("Home/Start")
	check(ui.get_node("Modal/Create/Visibility").selected == 0 and ui.get_node("Modal/Create/RoomName").text == "我的派对", "New creation resets form")
	ui.get_node("Modal/Create/Password").text = "discard-me"
	press("Modal/Create/Cancel")
	check(ui.get_node("Modal/Create/Password").text.is_empty() and ui.page == "Home", "Cancel clears password")
	press("Home/Start")
	ui.get_node("Modal/Create/Visibility").select(2)
	press("Modal/Create/Confirm")
	check(ui.room_visibility == 2 and not ui.room_has_password, "Invite only permits optional empty password")
	press("Lobby/Back")
	press("Home/Join")
	press("Rooms/Direct")
	check(ui.modal_kind == "Direct" and ui.page == "Rooms", "IP button opens modal over list")
	check(ui.get_node("Rooms/PageBacking").get_global_rect().encloses(ui.get_node("Rooms/Direct").get_global_rect()), "Direct button inside list panel")
	check(absf(ui.get_node("Rooms/Direct").get_global_rect().get_center().y - ui.get_node("Rooms/RoomsTitle").get_global_rect().get_center().y) <= 2.0, "Direct button centered with heading")
	check(ui.get_node("Modal/Direct/Port").text == "7777", "Default port")
	press("Modal/Direct/Confirm")
	check(ui.modal_kind == "Direct", "Empty IP rejected")
	for invalid in ["999.1.1.1", "example.com", "127.0.0.1:7777", "https://127.0.0.1"]:
		ui.get_node("Modal/Direct/Address").text = invalid
		press("Modal/Direct/Confirm")
		check(ui.modal_kind == "Direct", "Invalid endpoint rejected")
	ui.get_node("Modal/Direct/Address").text = "127.0.0.1"
	for invalid in ["", "0", "65536", "abc", "-1", "1.5", "+123"]:
		ui.get_node("Modal/Direct/Port").text = invalid
		press("Modal/Direct/Confirm")
		check(ui.modal_kind == "Direct", "Invalid port rejected")
	ui.get_node("Modal/Direct/Port").text = "7777"
	press("Modal/Direct/Cancel")
	check(ui.page == "Rooms" and ui.modal_kind.is_empty(), "Direct cancel returns list")
	press("Rooms/Direct")
	check(ui.get_node("Modal/Direct/Address").text.is_empty(), "Direct reopen drops draft")
	escape()
	check(ui.page == "Rooms" and ui.modal_kind.is_empty(), "Direct Escape keeps list")
	press("Rooms/Direct")
	ui.get_node("Modal/Direct/Address").text = " 127.0.0.1 "
	ui.get_node("Modal/Direct/Port").text = "1"
	ui.get_node("Modal/Direct/Port").text_submitted.emit("1")
	check(ui.page == "Lobby" and not ui.is_host, "IPv4 mock guest flow by Enter")
	check(ui.get_node("Lobby/LobbySubtitle").text.contains("未建立连接") and ui.get_node("Lobby/LobbySubtitle").text.contains("127.0.0.1:1"), "Explicit mock endpoint and no connection promise")
	check(ui.get_node("Lobby/SlotName1").text == "星野 · 玩家", "Profile name in guest row")
	press("Lobby/Back")
	press("Home/Join")
	press("Rooms/Direct")
	ui.get_node("Modal/Direct/Address").text = "2001:db8::1"
	ui.get_node("Modal/Direct/Port").text = "65535"
	press("Modal/Direct/Confirm")
	check(ui.get_node("Lobby/LobbySubtitle").text.contains("[2001:db8::1]:65535"), "IPv6 and upper port bound")
	press("Lobby/Back")
	ui.submit_direct()
	ui.submit_profile()
	ui.submit_create()
	check(ui.page == "Home" and ui.modal_kind.is_empty(), "Stale submits ignored after navigation")
	check(not ui.valid_display_name("x\ny",12) and not ui.valid_display_name("x".repeat(13),12), "Control characters and overlimit validation")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
