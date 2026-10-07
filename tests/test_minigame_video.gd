extends SceneTree
## Real Ogg/Theora decode + live grouped movement bindings; no external media.
var checks := 0
var failures := 0
var loops := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ", message)
	else: failures += 1; push_error("FAIL " + message)
func settle() -> void:
	for i in 6: await process_frame
func run() -> void:
	var page: Control = load("res://ui/pages/minigame_loading.tscn").instantiate()
	root.add_child(page)
	await settle()
	var source: VideoStream = load("res://tests/fixtures/minigame_preview.ogv")
	var fallback: Texture2D = load("res://assets/minigames/cloud_hop.svg")
	page.set_preview(fallback, source, "原创测试视频")
	var player: VideoStreamPlayer = page.get_node("%Video")
	player.finished.connect(func(): loops += 1)
	await create_timer(0.25).timeout
	check(player.is_playing() and player.stream_position > 0.05, "Actual Theora decoder advances playback")
	var texture := player.get_video_texture()
	check(texture != null and texture.get_width() == 160 and texture.get_height() == 90, "Actual decoded video frame has original 160×90 dimensions")
	check(texture != null and not texture.get_image().is_empty(), "Actual decoder produced readable frame pixels")
	check(is_zero_approx(player.volume) and player.visible and not page.get_node("%Image").visible, "Real video is visible and fully muted")
	check(is_equal_approx(page.get_node("%VideoFrame").ratio, 160.0 / 90.0), "Real video display preserves decoded aspect ratio")
	await create_timer(1.2).timeout
	check(loops >= 1 and player.is_playing(), "Actual finite Theora stream finishes and loops")
	page.hide()
	check(not player.is_playing(), "Hiding page stops real decoder")
	page.show()
	await create_timer(0.15).timeout
	check(player.is_playing() and player.stream_position > 0.0, "Reopening page restarts real decoder")
	page.set_preview(fallback)
	check(not player.is_playing() and player.stream == null and page.get_node("%Image").visible, "Switch to image releases real stream")
	page.set_preview()
	check(page.get_node("%Placeholder").visible, "Clearing resources shows placeholder")
	var names := PackedStringArray(["_minigame_test_up", "_minigame_test_left", "_minigame_test_down", "_minigame_test_right"])
	var codes := [KEY_W, KEY_A, KEY_S, KEY_D]
	for i in names.size():
		InputMap.add_action(names[i])
		var event := InputEventKey.new()
		event.keycode = codes[i]
		InputMap.action_add_event(names[i], event)
	check(page.configure({"controls":[{"actions":names, "text":"移动"}]}, [], ""), "Page accepts a group of live InputMap actions")
	await settle()
	var prompt: Control = page.get_node("%Controls").get_child(0)
	check(prompt.get_accessible_text().contains("W") and prompt.get_accessible_text().contains("D"), "Movement group shows initial real action bindings")
	InputMap.action_erase_events(names[0])
	var alternate := InputEventKey.new()
	alternate.keycode = KEY_K
	InputMap.action_add_event(names[0], alternate)
	await create_timer(0.25).timeout
	check(prompt.get_tokens()[0].label == "K", "Movement group follows live rebinding without rebuilding page")
	InputMap.action_erase_events(names[1])
	await create_timer(0.25).timeout
	check(prompt.get_accessible_text().contains("未绑定"), "An empty movement direction remains explicit")
	var before: String = page.game_title
	for invalid in [null, "wrong", [], [null], [45], [""]]:
		check(not page.configure({"title":"invalid", "controls":[{"actions":invalid}]}, [], "") and page.game_title == before, "Invalid action group rejected atomically: " + str(invalid))
	check(not page.configure({"title":"invalid", "controls":[{"action":""}]}, [], "") and page.game_title == before, "Empty singular action rejected instead of showing default Tab")
	prompt.set_binding(KEY_SPACE)
	check(prompt.action_names.is_empty() and prompt.get_accessible_text().contains("Space"), "Explicit binding clears grouped action mode")
	for action in names: InputMap.erase_action(action)
	page.queue_free()
	await settle()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
