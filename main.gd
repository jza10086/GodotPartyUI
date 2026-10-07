extends Control
## Native Control-only prototype. main.tscn assembles editable ui/ and settings/ scenes.
## This controller only binds events and updates state; visual layouts live in .tscn files.
const DemoBindings = preload("res://settings/demo_bindings.gd")
var page := "Home"
var modal_kind := ""
var previous_focus: Control
var toast_generation := 0
var selected_protocol := 0
const PROTOCOL_NAMES := ["派对示例 A", "派对示例 B"]
var capture_in_progress := false
var is_host := true
var guest_ready := false
var game_index := 0
var selected_game := 0
var selected_input_device := "Default"
var map_index := 0
var rounds_index := 1
var player_name := "你"
var room_visibility := 0
var room_has_password := false
const VISIBILITIES := ["公开", "仅限好友", "仅限邀请"]
const GAMES := ["派对竞赛", "合作挑战", "欢乐乱斗", "障碍冲刺", "节奏接力", "迷宫探险", "糖果争夺", "星空躲避", "平台跳跃", "团队解谜", "海岛寻宝", "极速跑酷"]
const MAPS := ["欢乐广场", "云端乐园", "海岛营地"]
const ROUNDS := [3, 5, 10]

func _ready() -> void:
	if "--minigame-demo" in OS.get_cmdline_user_args() and not get_tree().has_meta("minigame_demo_started"):
		get_tree().set_meta("minigame_demo_started", true)
		get_tree().change_scene_to_file.call_deferred("res://examples/minigame_loading_demo.tscn")
		return
	if "--settings-demo" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://examples/settings_demo.tscn")
		return
	$Home/Start.pressed.connect(func(): select_game(selected_game); open_modal("Create"))
	get_viewport().gui_embed_subwindows = true
	$Modal/Create/Game.pressed.connect(toggle_game_dropdown)
	for i in range(GAMES.size()):
		get_node("Modal/Create/Dropdown/Scroll/Items/Option%d" % i).pressed.connect(select_game.bind(i))
	$Modal/Create/DropdownDismiss.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close_game_dropdown()
	)
	$Modal/Create/Cancel.pressed.connect(close_modal)
	$Modal/Create/Confirm.pressed.connect(submit_create)
	$Home/Profile.pressed.connect(func(): open_modal("Profile"))
	$Rooms/Direct.pressed.connect(func(): open_modal("Direct"))
	$Modal/Profile/Cancel.pressed.connect(close_modal)
	$Modal/Profile/Confirm.pressed.connect(submit_profile)
	$Modal/Profile/Name.text_submitted.connect(func(_text): submit_profile())
	$Modal/Direct/Cancel.pressed.connect(close_modal)
	$Modal/Direct/Confirm.pressed.connect(submit_direct)
	$Modal/Direct/Port.text_submitted.connect(func(_text): submit_direct())
	$Home/Join.pressed.connect(func(): show_page("Rooms"))
	$Home/Protocol.pressed.connect(func(): open_modal("Protocol"))
	$Modal/Protocol/Option0.pressed.connect(func(): select_protocol(0))
	$Modal/Protocol/Option1.pressed.connect(func(): select_protocol(1))
	$Modal/Protocol/Close.pressed.connect(close_modal)
	$Home/Settings.pressed.connect(func(): show_page("Settings"))
	$Settings/Back.pressed.connect(func(): show_page("Home"))
	$Home/Exit.pressed.connect(func(): open_modal("Confirm"))
	$Rooms/Back.pressed.connect(func(): show_page("Home"))
	$Rooms/Join0.pressed.connect(func(): open_lobby("周五快乐局", false))
	$Rooms/Join1.pressed.connect(func(): open_lobby("再来一局", false))
	$Lobby/Back.pressed.connect(func(): show_page("Home"))
	$MinigameDriver.bind_page($Minigame)
	$Minigame.back_requested.connect(func(): show_page("Lobby"))
	$Lobby/Ready.pressed.connect(toggle_ready)
	$Lobby/Game.pressed.connect(func(): game_index = (game_index + 1) % GAMES.size(); update_lobby())
	$Lobby/Map.pressed.connect(func(): map_index = (map_index + 1) % MAPS.size(); update_lobby())
	$Lobby/Rounds.pressed.connect(func(): rounds_index = (rounds_index + 1) % ROUNDS.size(); update_lobby())
	$Lobby/Advanced.pressed.connect(func(): open_modal("Advanced"))
	$Lobby/ImportPreset.pressed.connect(func(): open_preset(true))
	$Lobby/ExportPreset.pressed.connect(func(): open_preset(false))
	$Modal/Advanced/Close.pressed.connect(close_modal)
	$Modal/Preset/Close.pressed.connect(close_modal)
	$Modal/Preset/Apply.pressed.connect(apply_preset)
	$Modal/Confirm/Cancel.pressed.connect(close_modal)
	$Modal/Confirm/Quit.pressed.connect(func(): get_tree().quit())
	build_settings()
	select_protocol(0)
	select_game(0)
	update_status()
	$Home/Start.grab_focus()
	if "--capture-all" in OS.get_cmdline_user_args():
		capture_all.call_deferred()

func show_page(next_page: String) -> void:
	close_modal()
	for key in ["Home", "Rooms", "Lobby", "Settings", "Minigame"]:
		get_node(key).visible = key == next_page
	page = next_page
	if page == "Settings":
		$Settings/Tabs.current_tab = 0
	update_status()
	$Toast.hide()
	var target := {"Home": "Home/Start", "Rooms": "Rooms/Join0", "Lobby": "Lobby/Ready", "Settings": "Settings/Back"}
	$Status.visible = page != "Minigame"
	if page == "Minigame": $Minigame.focus_primary()
	else: get_node(target[page]).grab_focus()

func open_lobby(title: String, hosting: bool) -> void:
	$MinigameDriver.initialized = false
	is_host = hosting
	guest_ready = false
	game_index = selected_game if hosting else 0
	map_index = 0
	rounds_index = 1
	$Lobby/LobbyTitle.text = title
	$Lobby/LobbySubtitle.text = "演示房间 0001 · 你是房主 · 无真实联网" if hosting else "演示房间 0002 · 你已加入 · 无真实联网"
	update_lobby()
	show_page("Lobby")

func update_lobby() -> void:
	$Lobby/RoleBadge.text = "房主视角" if is_host else "玩家视角"
	var names := [player_name + " · 房主", "小林", "阿舟"] if is_host else ["房主 · 星河", player_name + " · 玩家", "小林", "阿舟"]
	for i in range(8):
		get_node("Lobby/SlotName%d" % i).text = names[i] if i < names.size() else "等待加入"
		get_node("Lobby/SlotName%d" % i).tooltip_text = names[i] if i < names.size() else ""
		var state := "已准备" if i < names.size() else "空位"
		if not is_host and i == 1:
			state = "已准备" if guest_ready else "未准备"
		get_node("Lobby/SlotStatus%d" % i).text = state
		get_node("Lobby/Slot%d" % i).add_theme_stylebox_override("panel", $Lobby/SettingsPanel.get_theme_stylebox("panel") if i < names.size() else $Rooms/Join2.get_theme_stylebox("disabled"))
	$Lobby/PlayerCount.text = "%d / 8 人" % names.size()
	$Lobby/Ready.text = "开始游戏" if is_host else ("取消准备" if guest_ready else "准备")
	$Lobby/ReadySummary.text = "已准备 3 / 3 · 空位不影响演示" if is_host else ("已准备 4 / 4 · 等待房主开始" if guest_ready else "已准备 3 / 4 · 请准备")
	$Lobby/Game.text = GAMES[game_index] + ("  →" if is_host else "")
	$Lobby/Map.text = MAPS[map_index] + ("  →" if is_host else "")
	$Lobby/Rounds.text = "%d 回合" % ROUNDS[rounds_index] + ("  →" if is_host else "")
	$Lobby/SettingsAuthority.text = "房主可修改 · 所有设置仅用于界面演示" if is_host else "由房主修改 · 当前玩家仅可查看设置"
	for key in ["Game", "Map", "Rounds", "ImportPreset"]:
		get_node("Lobby/" + key).disabled = not is_host
	for key in ["Shuffle", "Items", "Teams"]:
		get_node("Modal/Advanced/" + key).disabled = not is_host

func valid_display_name(value: String, limit: int) -> bool:
	if value.is_empty() or value.length() > limit:
		return false
	for i in value.length():
		if value.unicode_at(i) < 32 or value.unicode_at(i) == 127:
			return false
	return true

func submit_create() -> void:
	if modal_kind != "Create": return
	var title: String = $Modal/Create/RoomName.text.strip_edges()
	if not valid_display_name(title, 24):
		$Modal/Create/Error.text = "请输入 1–24 字的房间名称"
		$Modal/Create/RoomName.grab_focus()
		return
	var password: String = $Modal/Create/Password.text
	if password.length() > 32 or (not password.is_empty() and password.strip_edges().is_empty()):
		$Modal/Create/Error.text = "密码可留空，或输入最多 32 字的非空白内容"
		$Modal/Create/Password.grab_focus()
		return
	room_visibility = $Modal/Create/Visibility.selected
	# Prototype carries protection state only; do not retain, print or export raw secrets.
	room_has_password = not password.is_empty()
	open_lobby(title, true)
	$Lobby/LobbySubtitle.text = "MOCK · %s · %s · 无真实联网" % [VISIBILITIES[room_visibility], "已设密码" if room_has_password else "无密码"]

func submit_profile() -> void:
	if modal_kind != "Profile": return
	var value: String = $Modal/Profile/Name.text.strip_edges()
	if not valid_display_name(value, 12):
		$Modal/Profile/Error.text = "请输入 1–12 字的玩家名称"
		$Modal/Profile/Name.grab_focus()
		return
	player_name = value
	$Home/Profile/Name.text = value
	update_lobby()
	close_modal()

func submit_direct() -> void:
	if modal_kind != "Direct": return
	var address: String = $Modal/Direct/Address.text.strip_edges()
	var port: String = $Modal/Direct/Port.text.strip_edges()
	if not address.is_valid_ip_address():
		$Modal/Direct/Error.text = "请输入有效的 IPv4 或 IPv6 地址"
		$Modal/Direct/Address.grab_focus()
		return
	var digits := not port.is_empty()
	for i in port.length():
		digits = digits and port.unicode_at(i) >= 48 and port.unicode_at(i) <= 57
	if not digits or port.to_int() < 1 or port.to_int() > 65535:
		$Modal/Direct/Error.text = "端口请输入 1–65535 的整数"
		$Modal/Direct/Port.grab_focus()
		return
	room_visibility = 0
	room_has_password = false
	open_lobby("IP 直连演示", false)
	var endpoint := ("[%s]" % address if address.contains(":") else address) + ":" + str(port.to_int())
	$Lobby/LobbySubtitle.text = "MOCK · %s · 仅模拟加入，未建立连接" % endpoint

func toggle_ready() -> void:
	if is_host:
		$MinigameDriver.begin(player_name)
		show_page("Minigame")
	else:
		guest_ready = not guest_ready
		update_lobby()

func open_preset(importing: bool) -> void:
	$Modal/Preset/Title.text = "导入预设 · 模拟" if importing else "导出预设 · 预览"
	$Modal/Preset/Note.text = "此操作仅预览示例，不读写本地文件。"
	$Modal/Preset/Apply.visible = importing
	$Modal/Preset/Body.text = "预设：轻松派对\n大游戏：合作挑战    地图：云端乐园\n回合：3    人数上限：8" if importing else "当前房间预设\n大游戏：%s    地图：%s\n回合：%d    人数上限：8" % [GAMES[game_index], MAPS[map_index], ROUNDS[rounds_index]]
	open_modal("Preset")

func apply_preset() -> void:
	if not is_host:
		return
	game_index = 1
	map_index = 1
	rounds_index = 0
	update_lobby()
	close_modal()
	show_demo("已应用示例预设 · 未导入本地文件")

func open_modal(kind: String) -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	modal_kind = kind
	update_status()
	$Modal.show()
	$Modal/Profile.visible = kind == "Profile"
	$Modal/Direct.visible = kind == "Direct"
	$Modal/Create.visible = kind == "Create"
	$Modal/Confirm.visible = kind == "Confirm"
	$Modal/Protocol.visible = kind == "Protocol"
	$Modal/Advanced.visible = kind == "Advanced"
	$Modal/Preset.visible = kind == "Preset"
	# Disable background focus as well as pointer interaction while modal is open.
	set_page_focus(false)
	if kind == "Create":
		$Modal/Create/RoomName.text = "我的派对"
		$Modal/Create/Password.clear()
		$Modal/Create/Visibility.select(0)
		$Modal/Create/Error.text = ""
		$Modal/Create/Game.grab_focus()
	elif kind == "Profile":
		$Modal/Profile/Name.text = player_name
		$Modal/Profile/Error.text = ""
		$Modal/Profile/Name.grab_focus()
		$Modal/Profile/Name.select_all()
	elif kind == "Direct":
		$Modal/Direct/Address.clear()
		$Modal/Direct/Port.text = "7777"
		$Modal/Direct/Error.text = ""
		$Modal/Direct/Address.grab_focus()
	elif kind == "Advanced":
		$Modal/Advanced/Close.grab_focus()
	elif kind == "Preset":
		$Modal/Preset/Close.grab_focus()
	elif kind == "Protocol":
		get_node("Modal/Protocol/Option%d" % selected_protocol).grab_focus()
	else:
		$Modal/Confirm/Cancel.grab_focus()

func close_modal() -> void:
	$Modal/Create/Password.clear()
	$Modal/Create/Visibility.get_popup().hide()
	close_game_dropdown()
	$Modal.hide()
	modal_kind = ""
	update_status()
	set_page_focus(true)
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func set_page_focus(enabled: bool) -> void:
	for key in ["Home", "Rooms", "Lobby", "Settings"]:
		for child in get_node(key).get_children():
			if child is BaseButton:
				child.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func select_protocol(index: int) -> void:
	selected_protocol = index
	update_status()
	$Modal/Protocol/Selected.text = "当前选择：" + PROTOCOL_NAMES[index]
	for i in range(PROTOCOL_NAMES.size()):
		get_node("Modal/Protocol/Option%d" % i).text = PROTOCOL_NAMES[i] + ("    / 已选择" if i == index else "")

func update_status() -> void:
	$Status/Engine.text = "GODOT " + str(Engine.get_version_info()["string"])
	$Status/Protocol.text = "PROTOCOL  /  MOCK · " + PROTOCOL_NAMES[selected_protocol]
	var screen_id: String = page + ("/" + ["Voice", "UI", "About", "Bindings"][$Settings/Tabs.current_tab] if page == "Settings" else "") + ("/" + modal_kind if not modal_kind.is_empty() else "")
	$Status/Scene.text = "UI  /  " + scene_file_path + " :: " + screen_id

func select_game(index: int) -> void:
	selected_game = index
	$Modal/Create/Game.text = GAMES[index] + "  ↓"
	close_game_dropdown()

func toggle_game_dropdown() -> void:
	var opening: bool = not $Modal/Create/Dropdown.visible
	$Modal/Create/Dropdown.visible = opening
	$Modal/Create/DropdownDismiss.visible = opening
	if opening:
		get_node("Modal/Create/Dropdown/Scroll/Items/Option%d" % selected_game).grab_focus()

func close_game_dropdown() -> void:
	$Modal/Create/Dropdown.hide()
	$Modal/Create/DropdownDismiss.hide()
	if modal_kind == "Create":
		$Modal/Create/Game.grab_focus()

func build_settings() -> void:
	var schema: Array = JSON.parse_string(FileAccess.get_file_as_string("res://settings/main_settings_schema.json"))
	var devices := [{"label": "系统默认（未启用采集）", "value": "Default"}]
	for device in AudioServer.get_input_device_list():
		if device != "Default": devices.append({"label": "系统设备：" + device, "value": device})
	schema[0].options[0].items = devices
	schema[0].options[0].value = "Default"
	schema[0].options[0].callback = func(value, _id): selected_input_device = value
	schema[0].options[1].text = "已枚举系统设备；仅保存选择，未打开麦克风" if devices.size() > 1 else "未枚举到具体设备；系统默认为占位选项"
	schema[1].options[2].items = [{"label": "全屏显示", "value": 0}, {"label": "窗口化", "value": 1}, {"label": "无边框窗口", "value": 2}]
	schema[1].options[2].value = 1
	schema[1].options[2].callback = func(value, _id): set_display_mode(value)
	for child in schema[1].options[4].children:
		if child.id == "apply_resolution": child.callback = func(_id): apply_resolution()
	schema[2].options[0].value = "GODOT " + str(Engine.get_version_info()["string"])
	# Append after About to retain the existing Voice / UI / About tab indices.
	schema.append(DemoBindings.make_tab(apply_binding))
	if not $Settings.configure(schema):
		push_error($Settings.last_error)
		return
	DemoBindings.apply_defaults($Settings)
	$Settings/Tabs.tab_changed.connect(func(_index): update_status())

func apply_binding(value: Variant, id: String) -> void:
	DemoBindings.apply_value(value, id)
	show_demo("已更新按键：" + id.trim_prefix(DemoBindings.ACTION_PREFIX))

func toggle_window_options(expanded: bool) -> void:
	$Settings.get_control("window_options").button_pressed = expanded
	$Settings._refresh_visibility()

func set_display_mode(index: int) -> void:
	$Settings.set_value("ui.DisplayMode", index)
	if DisplayServer.get_name() == "headless":
		return
	if index == 0:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, index == 2)

func apply_resolution() -> void:
	if $Settings/Tabs/UI/Padding/Content/DisplayRow/DisplayMode.selected != 1:
		return
	# SpinBox applies keyboard edits on Enter/focus exit and snaps to its 1 px step.
	$Settings/Tabs/UI/Padding/Content/WindowDetails/Rows/WidthRow/Width.apply()
	$Settings/Tabs/UI/Padding/Content/WindowDetails/Rows/HeightRow/Height.apply()
	var resolution := Vector2i(int($Settings/Tabs/UI/Padding/Content/WindowDetails/Rows/WidthRow/Width.value), int($Settings/Tabs/UI/Padding/Content/WindowDetails/Rows/HeightRow/Height.value))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(resolution)
	show_demo("已应用窗口分辨率 %d × %d" % [resolution.x, resolution.y])

func show_demo(message: String = "开始游戏流程演示 · 尚未接入真实游戏") -> void:
	$Toast/Text.text = message
	toast_generation += 1
	var current := toast_generation
	$Toast.show()
	await get_tree().create_timer(3.0).timeout
	if current == toast_generation:
		$Toast.hide()

func _input(event: InputEvent) -> void:
	# Compatibility entry point; the reusable settings component owns wheel routing.
	if page == "Settings" and modal_kind.is_empty():
		$Settings.route_scroll_input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		if $Modal/Create/Dropdown.visible:
			close_game_dropdown()
		elif not modal_kind.is_empty():
			close_modal()
		elif page == "Minigame":
			show_page("Lobby")
		elif page != "Home":
			show_page("Home")
		else:
			open_modal("Confirm")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.keycode == KEY_F1:
		$Guide.visible = not $Guide.visible
	elif event is InputEventKey and event.keycode == KEY_F10:
		get_tree().change_scene_to_file("res://examples/settings_demo.tscn")
	elif event is InputEventKey and event.keycode == KEY_F11:
		capture_all()
	elif event is InputEventKey and event.keycode == KEY_F12:
		capture_screen()

func capture_screen(filename: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("Viewport screenshots need an actual display renderer.")
		return
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var name := filename if not filename.is_empty() else page.to_lower() + ("_" + modal_kind.to_lower() if not modal_kind.is_empty() else "")
	var error := get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("SCREENSHOT ", dir.path_join(name + ".png"), " error=", error)

func capture_all() -> void:
	if capture_in_progress:
		return
	capture_in_progress = true
	show_page("Home")
	$Guide.hide()
	await get_tree().process_frame
	await capture_screen("01_main_menu")
	open_modal("Profile")
	await capture_screen("19_player_profile")
	close_modal()
	show_page("Rooms")
	await capture_screen("02_rooms")
	open_modal("Direct")
	$Modal/Direct/Address.text = "127.0.0.1"
	await capture_screen("18_ip_direct")
	close_modal()
	open_lobby("我的派对", true)
	await capture_screen("03_lobby")
	await capture_screen("07_lobby_host")
	open_modal("Advanced")
	await capture_screen("10_lobby_advanced")
	close_modal()
	open_lobby("周五快乐局", false)
	await capture_screen("08_lobby_guest")
	toggle_ready()
	await capture_screen("09_lobby_guest_ready")
	show_page("Home")
	select_game(0)
	open_modal("Create")
	await capture_screen("11_create_game")
	toggle_game_dropdown()
	await get_tree().process_frame
	await get_tree().process_frame
	await capture_screen("15_create_dropdown")
	close_game_dropdown()
	close_modal()
	show_page("Settings")
	await capture_screen("04_settings")
	await capture_screen("12_settings_voice")
	$Settings/Tabs.current_tab = 1
	$Settings/Tabs/UI/Padding/Content/DisplayRow/DisplayMode.select(1)
	$Settings/Tabs/UI/Padding/Content/WindowOptions.show()
	$Settings/Tabs/UI/Padding/Content/WindowOptions.button_pressed = true
	toggle_window_options(true)
	$Settings/Tabs/UI.scroll_vertical = 0
	await get_tree().process_frame
	await get_tree().process_frame
	await capture_screen("13_settings_ui")
	$Settings/Tabs/UI.scroll_vertical = 10000
	await get_tree().process_frame
	await capture_screen("16_settings_ui_scrolled")
	$Settings/Tabs/UI.scroll_vertical = 0
	$Settings/Tabs.current_tab = 2
	await capture_screen("14_settings_about")
	show_page("Home")
	open_modal("Confirm")
	await capture_screen("05_exit")
	close_modal()
	open_modal("Protocol")
	await capture_screen("06_protocol")
	close_modal()
	capture_in_progress = false
