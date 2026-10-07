extends SceneTree
## Isolated presentation/API and mock-host integration regressions.
## Run: godot --headless --path . --script res://tests/test_minigame_loading.gd
## Video lifecycle uses a scripted stream, not a decoder or external media file.
const PAGE_PATH := "res://ui/pages/minigame_loading.tscn"
const DRIVER_PATH := "res://examples/minigame_demo_driver.gd"
const CONFIG_PATH := "res://ui/theme/ui_config.tres"
var checks := 0
var failures := 0
var ready_events: Array = []
var state_events: Array = []
var callbacks: Array = []
var all_ready_events := 0
var back_events := 0

class StubPlayback extends VideoStreamPlayback:
	var playing := false
	var paused := false
	var position := 0.0
	var play_calls := 0
	var stop_calls := 0
	var texture: Texture2D
	func _init() -> void:
		var frame := Image.create_empty(16, 9, false, Image.FORMAT_RGBA8)
		frame.fill(Color.CORNFLOWER_BLUE)
		texture = ImageTexture.create_from_image(frame)
	func _play() -> void:
		playing = true
		play_calls += 1
	func _stop() -> void:
		playing = false
		position = 0.0
		stop_calls += 1
	func _is_playing() -> bool: return playing
	func _set_paused(value: bool) -> void: paused = value
	func _is_paused() -> bool: return paused
	func _get_length() -> float: return 60.0
	func _get_playback_position() -> float: return position
	func _seek(value: float) -> void: position = value
	func _set_audio_track(_index: int) -> void: pass
	func _get_texture() -> Texture2D: return texture
	func _update(delta: float) -> void:
		if playing and not paused: position += delta
	func _get_channels() -> int: return 0
	func _get_mix_rate() -> int: return 44100

class StubStream extends VideoStream:
	var playback: StubPlayback
	var valid_frame := true
	func _instantiate_playback() -> VideoStreamPlayback:
		playback = StubPlayback.new()
		if not valid_frame: playback.texture = null
		return playback

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)

func settle() -> void:
	for i in range(6): await process_frame

func two_players() -> Array:
	return [{"id":"local", "name":"本机名字", "state":"loading", "progress":12}, {"id":"peer", "name":"另一玩家", "state":"not_ready"}]

func make_page() -> Control:
	return load(PAGE_PATH).instantiate()

func watch(page: Control) -> void:
	page.ready_changed.connect(func(id, ready): ready_events.append([id, ready]))
	page.player_state_changed.connect(func(id, state): state_events.append([id, state]))
	page.all_ready.connect(func(): all_ready_events += 1)
	page.back_requested.connect(func(): back_events += 1)

func user_callback(ready: bool, id: String) -> void:
	callbacks.append([ready, id])

func text_of(node: Node) -> String:
	var result := ""
	if node is Label or node is Button: result += node.text + "\n"
	for child in node.get_children(): result += text_of(child)
	return result

func run() -> void:
	if "--minigame-demo" in OS.get_cmdline_user_args():
		await test_command_line_return()
		print("RESULT: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	var page := make_page()
	watch(page)
	var players := two_players()
	players[0]["metadata"] = {"score":3}
	var game := {"title":"测试小游戏", "subtitle":"可配置说明", "round":"第 02 回合 / 05", "rules":["规则甲", "规则乙"], "controls":[{"keys":[KEY_W, KEY_A, KEY_S, KEY_D], "separator":" ", "text":"移动"}, {"binding":KEY_SPACE, "text":"跳跃"}]}
	check(page.configure(game, players, "local", user_callback), "Public configuration is safe before entering the tree")
	check(ready_events.is_empty() and state_events.is_empty() and callbacks.is_empty() and all_ready_events == 0, "Initialization is silent for signals and callback")
	players[0].name = "外部修改"
	players[0].metadata.score = 9
	game.rules[0] = "外部规则"
	game.controls[0].text = "外部按键"
	root.add_child(page)
	await settle()
	check(page.get_player("local").name == "本机名字" and page.get_player("local").metadata.score == 3, "Configuration deep-copies incoming player dictionaries")
	check(page.get_node("%GameTitle").text == "测试小游戏" and page.get_node("%Subtitle").text == "可配置说明", "Game title and description render")
	check(page.get_node("%Round").text == "第 02 回合 / 05", "Configured round renders")
	check(page.get_node("%Rules").get_child_count() == 2 and text_of(page.get_node("%Rules")).contains("规则甲"), "Rules are editable scene instances and defensively copied")
	check(page.get_node("%Controls").get_child_count() == 2 and page.get_node("%Controls").get_child(0).function_text == "移动", "Control descriptions are defensively copied")
	check(page.get_node("%Controls").get_child(0).get_accessible_text().contains("W") and page.get_node("%Controls").get_child(1).get_accessible_text().contains("Space"), "Control hints expose semantic key names")
	check(page.get_node("%Players").get_child_count() == 8, "Exactly eight editable player cards exist")
	for i in range(8):
		check(page.get_node("%Players").get_child(i).scene_file_path.ends_with("minigame_player_card.tscn"), "Player card %d retains its reusable PackedScene" % (i + 1))
	var first: Control = page.get_node("%Players").get_child(0)
	var second: Control = page.get_node("%Players").get_child(1)
	check(first.get_node("%Name").text == "本机名字" and first.get_node("%LocalTag").text == "本机", "Local identity is explicitly labeled")
	check(first.get_node("%State").text.contains("加载中") and first.get_node("%State").text.contains("12%"), "Loading uses words and numeric progress, not color alone")
	check(second.get_node("%State").text.contains("未准备"), "Loaded but unready state is explicit")
	check(page.get_node("%Players").get_child(7).get_node("%State").text.contains("空位"), "Unoccupied seats are explicit")
	check(first.accessibility_name.contains("本机") and first.accessibility_name.contains("加载中"), "Player accessible name includes identity and status")
	check(page.get_node("%ReadyCount").text.contains("已准备 0 / 2") and page.get_node("%ReadyCount").text.contains("已加载 1 / 2"), "Summary counts connected players, excluding six empty seats")
	check(page.get_node("%Ready").disabled and page.get_node("%ReadyPrompt").disabled, "Readiness action and hint disabled while loading")
	page.focus_primary()
	check(root.gui_get_focus_owner() == page.get_node("%Back"), "Loading fallback focus lands on Back")
	page.toggle_local_ready()
	check(callbacks.is_empty() and ready_events.is_empty() and page.get_player("local").state == "loading", "Loading player cannot ready through user API")
	var snapshot: Array = page.get_players()
	snapshot[0].name = "损坏副本"
	snapshot[0].metadata.score = 22
	snapshot.clear()
	var one_copy: Dictionary = page.get_player("local")
	one_copy.metadata.score = 33
	check(page.get_players().size() == 2 and page.get_player("local").metadata.score == 3, "Both roster getters return defensive nested copies")
	check(page.get_player("unknown").is_empty(), "Missing player lookup returns an empty dictionary")
	test_validation(page)
	test_readiness(page)
	await test_preview(page)
	await test_theme(page)
	await test_layout(page)
	page.queue_free()
	await settle()
	await test_demo_driver()
	await test_main_integration()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_validation(page: Control) -> void:
	var before: Array = page.get_players()
	var before_title: String = page.game_title
	var before_rules: Array = page.rule_lines.duplicate()
	var bad_players: Array = [
		[{"id":"same"}, {"id":"same"}], [{"name":"Missing id"}], ["invalid"],
		[{"id":"bad", "state":"connected"}], [{"id":"bad", "avatar":"not a texture"}],
		[{"id":"bad", "progress":"50"}], [{"id":null}], [{"id":"  "}], [{"id":7}],
		[{"id":"nan", "progress":NAN}], [{"id":"infinity", "progress":INF}], [{"id":"negative-infinity", "progress":-INF}],
	]
	var too_many: Array = []
	for i in range(9): too_many.append({"id":str(i)})
	bad_players.append(too_many)
	for i in range(bad_players.size()):
		check(not page.configure({"title":"必须保留原题", "rules":["错误替换"]}, bad_players[i], "replacement"), "Malformed roster rejected atomically: %d" % i)
		check(page.get_players() == before and page.game_title == before_title and page.rule_lines == before_rules and page.get_local_player_id() == "local", "Rejected roster preserves content, players, and local identity: %d" % i)
		check(not page.last_error.is_empty(), "Rejected roster gives an actionable error: %d" % i)
		check(not page.set_players(bad_players[i], "replacement") and page.get_players() == before, "set_players also preserves roster on invalid input: %d" % i)
	for invalid in [{"image":"wrong"}, {"video":"wrong"}, {"rules":44}, {"controls":{}}, {"controls":["wrong"]},
		{"controls":[{"action":45}]}, {"controls":[{"keys":"WASD"}]}, {"controls":[{"keys":[1, "A"]}]},
		{"controls":[{"keys":[1.5]}]}, {"controls":[{"separator":4}]}, {"controls":[{"binding_index":-2}]},
		{"controls":[{"binding_index":33}]}, {"controls":[{"binding_index":1.5}]}]:
		invalid["title"] = "必须保留原题"
		check(not page.configure(invalid, [{"id":"replacement"}], "replacement") and page.get_players() == before and page.game_title == before_title, "Invalid game content leaves configuration unchanged: " + str(invalid.keys()))
	check(not page.set_player_state("unknown", "ready") and page.get_players() == before, "Unknown player update is rejected without mutation")
	check(not page.set_player_state("local", "invalid") and page.get_players() == before, "Unknown state update is rejected without mutation")
	for invalid in [NAN, INF, -INF]:
		check(not page.set_player_state("local", "loading", invalid) and page.get_players() == before, "Non-finite incremental progress is rejected without mutation: " + str(invalid))
	check(callbacks.is_empty() and ready_events.is_empty() and state_events.is_empty() and all_ready_events == 0, "Rejected operations emit no events or callbacks")
	check(page.set_players([{"id":"local", "state":"loading", "progress":-50}, {"id":"peer", "state":"loading", "progress":500}], "local"), "Valid replacement roster succeeds")
	check(page.get_player("local").progress == 0 and page.get_player("peer").progress == 99 and page.last_error.is_empty(), "Loading progress normalizes to 0–99 and successful replacement clears error")

func test_readiness(page: Control) -> void:
	check(page.set_local_loaded(true), "Loader can mark the local player loaded")
	check(page.get_player("local").state == "not_ready" and not page.get_node("%Ready").disabled and page.get_node("%Ready").text == "准备", "Loaded local remains unready until user confirms")
	check(callbacks.is_empty() and ready_events.is_empty(), "External loader update does not call user callback")
	var state_count := state_events.size()
	check(page.set_local_loaded(true) and state_events.size() == state_count, "Repeated local-load completion is a no-op")
	page.focus_primary()
	check(root.gui_get_focus_owner() == page.get_node("%Ready"), "Loaded local receives Ready focus")
	page.get_node("%Ready").pressed.emit()
	check(page.get_player("local").state == "ready" and page.get_node("%Ready").text == "取消准备", "Ready button enters cancelable ready state")
	check(callbacks == [[true, "local"]] and ready_events == [["local", true]], "User callback has (ready, id) order and signal has (id, ready) order")
	check(page.get_node("%Players").get_child(0).get_node("%State").text.contains("已准备"), "Ready player card has a semantic status word")
	state_count = state_events.size()
	check(page.set_local_loaded(true) and page.get_player("local").state == "ready" and state_events.size() == state_count, "Repeated load completion preserves already-ready state")
	page.get_node("%Ready").pressed.emit()
	check(page.get_player("local").state == "not_ready" and callbacks == [[true, "local"], [false, "local"]], "Second user press cancels readiness exactly once")
	page.hide()
	page.toggle_local_ready()
	check(callbacks.size() == 2 and page.get_player("local").state == "not_ready", "Hidden page cannot mutate readiness through user API")
	page.show()
	check(page.set_player_state("peer", "ready") and callbacks.size() == 2 and ready_events.size() == 2, "Programmatic peer changes do not impersonate user confirmation")
	check(page.set_player_state("local", "ready") and all_ready_events == 1, "All-ready emits on the first false-to-true edge")
	check(page.is_everyone_ready() and page.get_node("%Summary").text.contains("全部准备完成"), "All-ready state includes summary")
	state_count = state_events.size()
	page.set_player_state("local", "ready")
	page.set_players(page.get_players())
	check(all_ready_events == 1 and state_events.size() == state_count, "Repeated ready state and identical roster do not repeat edge or state signals")
	page.set_player_state("local", "not_ready")
	page.set_player_state("local", "ready")
	check(all_ready_events == 2, "A new false-to-true readiness edge emits again")
	page.set_players([])
	check(not page.is_everyone_ready() and page.get_node("%Ready").disabled and all_ready_events == 2, "Empty roster is not all-ready and disables local action")
	page.toggle_local_ready()
	check(callbacks.size() == 2, "Absent local player cannot send readiness callback")
	page.set_players([{"id":"peer", "state":"ready"}], "missing-local")
	check(page.is_everyone_ready() and all_ready_events == 3 and page.get_node("%Ready").disabled, "Empty seats do not block connected-player readiness; absent local remains disabled")
	check(page.configure({}, [{"id":"local", "state":"ready"}], "local", user_callback), "Already-ready roster can be configured")
	check(all_ready_events == 3 and callbacks.size() == 2, "Already-ready configure initializes edge latch silently")
	page.set_players(page.get_players())
	check(all_ready_events == 3, "Reapplying configured all-ready roster stays silent")
	page.set_local_loaded(false, 26)
	check(page.get_player("local").state == "loading" and page.get_node("%Ready").disabled and page.get_node("%Ready").text.contains("26%"), "Loader can reset ready local to disabled loading")
	state_count = state_events.size()
	page.set_player_state("local", "loading", 40)
	check(state_events.size() == state_count and page.get_player("local").progress == 40, "Progress-only update does not emit a state transition")
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	page._unhandled_key_input(event)
	check(back_events == 1, "Cancel input emits one back request")
	page.hide()
	page._unhandled_key_input(event)
	check(back_events == 1, "Hidden page ignores cancel input")
	page.show()
	page.get_node("%Back").pressed.emit()
	check(back_events == 2, "Back button emits one back request")

func test_preview(page: Control) -> void:
	var image: Texture2D = page.preview_image
	var video: VideoStreamPlayer = page.get_node("%Video")
	check(image != null and page.get_node("%Image").visible and not video.visible and not page.get_node("%Placeholder").visible, "Default original image is available with no video dependency")
	page.set_preview(null, null)
	check(page.get_node("%Placeholder").visible and not page.get_node("%Image").visible and not video.visible and video.stream == null, "Null preview shows readable placeholder and clears stream")
	check(page.get_node("%MediaCaption").text.contains("暂无演示资源"), "Missing media explains what the user can do")
	page.set_preview(image, null, "图片说明")
	check(page.get_node("%Image").texture == image and page.get_node("%Image").visible and page.get_node("%MediaCaption").text == "图片说明", "Image and custom caption can be replaced at runtime")
	var stream := StubStream.new()
	page.set_preview(image, stream)
	await settle()
	check(video.stream == stream and video.visible and not page.get_node("%Image").visible and not page.get_node("%Placeholder").visible, "Video takes precedence over image and placeholder")
	check(video.is_playing() and is_zero_approx(video.volume) and page.get_node("%MediaCaption").text.contains("静音"), "Visible preview starts muted with video-specific caption")
	check(is_equal_approx(page.get_node("%VideoFrame").ratio, 16.0 / 9.0), "Video aspect ratio follows decoded frame without cropping")
	var playback: StubPlayback = stream.playback
	var plays := playback.play_calls
	page.set_preview(image, stream, "更新字幕")
	check(stream.playback == playback and playback.play_calls == plays and page.get_node("%MediaCaption").text == "更新字幕", "Caption-only update does not restart an unchanged stream")
	page.hide()
	check(not video.is_playing() and not playback.playing, "Hiding the page stops media playback")
	plays = playback.play_calls
	video.finished.emit()
	check(playback.play_calls == plays, "Finished callback cannot restart hidden playback")
	page.show()
	check(video.is_playing() and playback.play_calls > plays, "Showing the page resumes configured muted video")
	plays = playback.play_calls
	playback.playing = false
	video.finished.emit()
	check(playback.play_calls == plays + 1 and video.is_playing(), "Finished video loops only while page is visible")
	var alternate := StubStream.new()
	page.set_preview(null, alternate, "第二段")
	check(not playback.playing and video.stream == alternate and video.is_playing(), "Replacing video stops previous playback and starts replacement")
	var alternate_playback: StubPlayback = alternate.playback
	page.set_preview(image)
	check(not alternate_playback.playing and video.stream == null and page.get_node("%Image").visible, "Switching video to image releases active video playback")
	var broken := StubStream.new()
	broken.valid_frame = false
	page.set_preview(image, broken)
	page._process(2.1)
	check(not video.is_playing() and not video.visible and page.get_node("%Image").visible and page.get_node("%MediaCaption").text.contains("视频暂不可用"), "Stream with no decoded frame falls back to image after bounded wait")
	var failed_plays := broken.playback.play_calls
	video.finished.emit()
	page.hide()
	page.show()
	check(broken.playback.play_calls == failed_plays and not video.is_playing(), "Failed video cannot restart through looping or visibility changes")
	page.set_preview(null, broken)
	page._process(2.1)
	check(page.get_node("%Placeholder").visible and not video.visible and page.get_node("%MediaCaption").text.contains("请先阅读游戏规则"), "Unavailable video with no image falls back to readable placeholder")
	page.set_preview(null, stream)
	playback = stream.playback
	check(video.is_playing() and video.visible, "Valid replacement recovers from failed preview state")
	root.remove_child(page)
	check(not playback.playing, "Removing the page from the tree stops playback")
	root.add_child(page)
	await settle()
	check(video.is_playing(), "Reattaching a page safely resumes its configured stream")
	page.set_preview(image)
	await settle()

func test_theme(page: Control) -> void:
	var config: Resource = load(CONFIG_PATH)
	var original: Dictionary = {}
	for field in ["font", "display_size", "body_size", "micro_size", "success", "info", "text_disabled", "page_background"]: original[field] = config.get(field)
	var shared: Theme = load("res://ui/theme/party_theme.tres")
	check(page.theme == shared and page.get_node("%Players").get_child(0).theme == shared, "Page and reusable cards share the application Theme resource")
	check(page.get_node("%GameTitle").get_theme_font("font") == config.font, "Game title inherits configured font")
	check(page.get_node("%GameTitle").get_theme_font_size("font_size") == config.display_size, "Game title inherits semantic title size")
	var replacement := SystemFont.new()
	replacement.allow_system_fallback = false
	config.set_block_signals(true)
	config.font = replacement
	config.display_size = 63
	config.body_size = 27
	config.micro_size = 19
	config.success = Color(0.31, 0.67, 0.28, 0.76)
	config.info = Color(0.18, 0.31, 0.68, 0.72)
	config.text_disabled = Color(0.37, 0.39, 0.42, 0.74)
	config.page_background = Color(0.72, 0.77, 0.85, 0.82)
	config.set_block_signals(false)
	config.emit_changed()
	page.set_players([{"id":"local", "state":"ready"}, {"id":"loading", "state":"loading"}, {"id":"waiting", "state":"not_ready"}], "local")
	await settle()
	check(page.get_node("%GameTitle").get_theme_font("font") == replacement and page.get_node("%GameTitle").get_theme_font_size("font_size") == 63, "Live shared font and title-size changes reach existing minigame page")
	check(page.get_node("%Rules").get_child(0).get_node("Text").get_theme_font_size("font_size") == 27, "Generated rules inherit live shared body size")
	check(page.get_node("%Controls").get_child(0).get_node("Function").get_theme_font("font") == replacement, "Generated key descriptions inherit live shared font")
	check(page.get_node("Background").color.is_equal_approx(config.page_background), "Minigame background follows live semantic RGBA")
	for i in range(3):
		var card: Node = page.get_node("%Players").get_child(i)
		var expected: Color = [config.success, config.info, config.text_disabled][i]
		check(card.get_node("%State").get_theme_color("font_color").is_equal_approx(expected) and card.get_node("%StatusLine").color.is_equal_approx(expected), "Player semantic text and line track shared RGBA: " + str(i))
	config.set_block_signals(true)
	for field in original: config.set(field, original[field])
	config.set_block_signals(false)
	config.emit_changed()
	await settle()
	check(page.get_node("%GameTitle").get_theme_font("font") == original.font, "Original shared font restored without writing resources")

func test_layout(page: Control) -> void:
	# Standalone page dimensions deliberately exercise both layout branches, even
	# though the application normally scales its 1920x1080 logical viewport.
	page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for dimensions in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(1920, 1080)]:
		page.size = dimensions
		await settle()
		var narrow: bool = dimensions.x < 1350
		check(page.get_node("%Body").vertical == narrow and page.get_node("%Players").columns == (4 if narrow else 8), "Responsive body/roster reflow at " + str(dimensions))
		var rect := page.get_global_rect()
		for target in ["%Ready", "%Back", "Padding/Stack/Scroll"]:
			var control: Control = page.get_node(target)
			check(rect.grow(1).encloses(control.get_global_rect()), "Viewport contains persistent control %s at %s" % [target, dimensions])
		check(not page.get_node("%Ready").get_global_rect().intersects(page.get_node("%Back").get_global_rect()), "Persistent actions never overlap at " + str(dimensions))
		var scroll: ScrollContainer = page.get_node("Padding/Stack/Scroll")
		check(scroll.get_global_rect().end.y <= page.get_node("%Ready").global_position.y, "Scrollable content stays above persistent actions at " + str(dimensions))
		var cards: GridContainer = page.get_node("%Players")
		for i in range(8):
			check(cards.get_global_rect().grow(1).encloses(cards.get_child(i).get_global_rect()), "Roster contains card %d at %s" % [i + 1, dimensions])
		check(page.get_node("%Body").size.x <= scroll.size.x + 1, "Content remains horizontally scroll-free at " + str(dimensions))

func test_demo_driver() -> void:
	var page := make_page()
	root.add_child(page)
	var driver: Node = load(DRIVER_PATH).new()
	root.add_child(driver)
	driver.set_process(false)
	driver.bind_page(page)
	driver.begin("演示玩家")
	await settle()
	check(page.get_players().size() == 8 and page.get_player("local").name == "演示玩家", "Separate mock host supplies eight named players")
	check(page.get_node("%DemoBar").visible and text_of(page.get_node("%DemoBar")).contains("无真实联网"), "Mock controls clearly disclose no real networking")
	check(page.get_player("local").state == "loading" and page.get_player("p2").state == "ready" and page.get_player("p3").state == "not_ready", "Initial demo displays all three occupied states")
	driver._process(1.0)
	check(page.get_player("local").progress > 12 and page.get_player("local").state == "loading", "Mock host owns simulated local loading progress")
	page.hide()
	var progress: float = page.get_player("local").progress
	driver._process(100.0)
	check(page.get_player("local").progress == progress, "Mock simulation pauses while screen is hidden")
	page.show()
	driver._process(2.0)
	check(page.get_player("local").state == "not_ready" and not page.get_node("%Ready").disabled, "Mock loading completion enables readiness without auto-readying")
	page.get_node("%CompleteLoad").pressed.emit()
	var loading_count := 0
	for player in page.get_players():
		if player.state == "loading": loading_count += 1
	check(loading_count == 0, "Complete-load demo action completes all loading players")
	page.get_node("%ReadyPeers").pressed.emit()
	check(not page.is_everyone_ready() and page.get_player("local").state == "not_ready", "Ready-peers demo action does not ready local player")
	page.get_node("%Ready").pressed.emit()
	check(page.is_everyone_ready(), "Eight-person mock flow reaches all-ready through explicit user action")
	page.get_node("%ResetDemo").pressed.emit()
	check(page.get_player("local").state == "loading" and page.get_player("local").progress == 12 and page.get_player("p3").state == "not_ready", "Reset demo restores mixed readiness and loading state")
	check(page.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Mock screen remains on offline multiplayer peer")
	page.queue_free()
	driver.queue_free()
	await settle()

func room_state(ui: Control) -> Dictionary:
	return {"title":ui.get_node("Lobby/LobbyTitle").text, "subtitle":ui.get_node("Lobby/LobbySubtitle").text, "host":ui.is_host, "guest_ready":ui.guest_ready, "game":ui.game_index, "map":ui.map_index, "rounds":ui.rounds_index, "name":ui.player_name, "visibility":ui.room_visibility, "password":ui.room_has_password, "protocol":ui.selected_protocol}

func test_main_integration() -> void:
	var ui: Control = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	ui.player_name = "房主星野"
	ui.selected_game = 3
	ui.room_visibility = 2
	ui.room_has_password = true
	ui.select_protocol(1)
	ui.open_lobby("保留房间", true)
	ui.map_index = 2
	ui.rounds_index = 2
	ui.update_lobby()
	var before := room_state(ui)
	var page: Control = ui.get_node("Minigame")
	ui.get_node("Lobby/Ready").pressed.emit()
	check(ui.page == "Minigame" and page.is_visible_in_tree() and not ui.get_node("Lobby").visible, "Host Start opens integrated minigame loading screen")
	check(page.get_player("local").name == "房主星野" and page.get_players().size() == 8, "Integrated mock receives current profile name")
	check(not ui.get_node("Status").visible, "Legacy status strip is hidden on minigame screen")
	check(room_state(ui) == before and ui.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Starting preview preserves room state without network connection")
	page.get_node("%Back").pressed.emit()
	check(ui.page == "Lobby" and room_state(ui) == before and ui.get_node("Status").visible, "Back returns to lobby with complete room state retained")
	ui.get_node("Lobby/Ready").pressed.emit()
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	page._unhandled_key_input(event)
	check(ui.page == "Lobby" and room_state(ui) == before, "Minigame Escape returns to lobby without resetting room")
	ui.open_lobby("访客房间", false)
	ui.get_node("Lobby/Ready").pressed.emit()
	check(ui.page == "Lobby" and ui.guest_ready, "Guest readiness remains lobby-only and cannot act as host Start")
	ui.get_node("Lobby/Ready").pressed.emit()
	check(ui.page == "Lobby" and not ui.guest_ready, "Guest can still cancel readiness in existing lobby")
	ui.queue_free()
	await settle()

func test_command_line_return() -> void:
	var ui: Control = load("res://main.tscn").instantiate()
	root.add_child(ui)
	current_scene = ui
	await settle()
	check(current_scene != null and current_scene.scene_file_path == "res://examples/minigame_loading_demo.tscn", "Command-line demo flag opens standalone minigame scene")
	check(has_meta("minigame_demo_started"), "Command-line entry flag is consumed once per SceneTree")
	var page: Control = current_scene.get_node("Page")
	check(page.get_players().size() == 8 and page.get_node("%Back").text == "← 返回主菜单", "Standalone entry has eight players and correct return label")
	page.get_node("%Back").pressed.emit()
	await settle()
	check(current_scene.scene_file_path == "res://main.tscn" and current_scene.page == "Home", "Standalone return reaches main menu without re-entering command-line demo")
	await settle()
	check(current_scene.scene_file_path == "res://main.tscn", "Consumed command-line flag cannot produce a return loop")
	current_scene.queue_free()
	await settle()
