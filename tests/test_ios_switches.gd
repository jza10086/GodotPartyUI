extends SceneTree
## Pixel geometry, native input/animation, live RGBA, and serialized overrides.
## Run: godot --headless --path . --script res://tests/test_ios_switches.gd
## Pixel-source checks complement, rather than replace, rendered visual QA.

const Graphics = preload("res://ui/theme/switch_graphics.gd")
const NativeSwitch = preload("res://ui/theme/ios_check_button.gd")
const ICONS := ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored", "unchecked_mirrored", "checked_disabled_mirrored", "unchecked_disabled_mirrored"]
const FIELDS := ["toggle_off", "toggle_on", "toggle_thumb", "toggle_border", "disabled_opacity"]
const OUTSIDE := Vector2(30, 1030)
var checks := 0
var failures := 0
var calls := 0
var config: Resource
var shared_theme: Theme
var original: Dictionary = {}
var copies: Array[Node] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS ", message)

func settle() -> void:
	for i in range(4): await process_frame

func colors_close(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= 0.005 and absf(actual.g - expected.g) <= 0.005 and absf(actual.b - expected.b) <= 0.005 and absf(actual.a - expected.a) <= 0.005

func move_to(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2.ONE
	root.push_input(event, true)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	move_to(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func native_image(button: CheckButton, icon_name: String) -> Image:
	# The dummy headless renderer keeps ImageTexture creation pixels after
	# update(). Inspect the exact uploaded CPU source only on that backend.
	# Rendered runs continue to inspect actual texture readback.
	if DisplayServer.get_name() == "headless":
		var key := "disabled" if icon_name.contains("disabled") else "normal"
		if icon_name.ends_with("mirrored"): key = "disabled_mirrored" if key == "disabled" else "mirrored"
		return button._frame_images[key]
	return button.get_theme_icon(icon_name).get_image()

func custom_image(button: Button) -> Image:
	return button._frame_image if DisplayServer.get_name() == "headless" else button.get_node("Track").texture.get_image()

func verify_capsule(pixels: Image, selected: bool, mirrored: bool, context: String) -> void:
	check(pixels.get_size() == Vector2i(102, 62), context + " uses enlarged 102x62 (51:31) geometry")
	var right := selected != mirrored
	var track: Color = config.toggle_on if selected else config.toggle_off
	check(colors_close(pixels.get_pixel(20 if right else 81, 31), track), context + " track is filled with correct off/on color")
	check(colors_close(pixels.get_pixel(71 if right else 31, 31), Color.WHITE), context + " white thumb reaches the correct endpoint")
	check(pixels.get_pixel(0, 0).a == 0 and pixels.get_pixel(101, 0).a == 0 and pixels.get_pixel(0, 61).a == 0 and pixels.get_pixel(101, 61).a == 0, context + " capsule corners are transparent")
	check(pixels.get_pixel(50, 3).a > 0.99 and pixels.get_pixel(50, 58).a > 0.99 and pixels.get_pixel(2, 31).a > 0.99 and pixels.get_pixel(99, 31).a > 0.99, context + " track stays solid rather than a hollow outline")
	var minimum := Vector2i(102, 62)
	var maximum := Vector2i(-1, -1)
	var count := 0
	var coverage := 0
	for y in pixels.get_height():
		for x in pixels.get_width():
			var pixel := pixels.get_pixel(x, y)
			if pixel.a > 0.99: coverage += 1
			if pixel.r > 0.99 and pixel.g > 0.99 and pixel.b > 0.99 and pixel.a > 0.99:
				minimum = Vector2i(mini(minimum.x, x), mini(minimum.y, y))
				maximum = Vector2i(maxi(maximum.x, x), maxi(maximum.y, y))
				count += 1
	var bounds := maximum - minimum + Vector2i.ONE
	check(bounds == Vector2i(54, 54) and minimum.x == (44 if right else 4) and minimum.y == 4, context + " thumb is a large circular 54x54 shape with 4px inset")
	check(count > 2100 and count < 2400, context + " circular thumb cannot regress to a rectangular segment")
	check(coverage > 5300 and coverage < 5600, context + " capsule silhouette retains rounded ends")

func verify_dimmed(normal: Image, dimmed: Image, opacity: float, context: String) -> void:
	var wrong_rgb := 0
	var wrong_alpha := 0
	for y in normal.get_height():
		for x in normal.get_width():
			var a := normal.get_pixel(x, y)
			var b := dimmed.get_pixel(x, y)
			if a.a <= 0: continue
			if absf(a.r - b.r) > 0.005 or absf(a.g - b.g) > 0.005 or absf(a.b - b.b) > 0.005: wrong_rgb += 1
			if absf(a.a * opacity - b.a) > 0.005: wrong_alpha += 1
	check(wrong_rgb == 0, context + " disabled preserves RGB including the white thumb")
	check(wrong_alpha == 0, context + " disabled multiplies every coverage alpha exactly once")

func verify_mirror(normal: Image, mirrored: Image, context: String) -> void:
	var mismatches := 0
	for y in normal.get_height():
		for x in normal.get_width():
			if not colors_close(normal.get_pixel(x, y), mirrored.get_pixel(normal.get_width() - x - 1, y)): mismatches += 1
	check(mismatches == 0, context + " RTL mirrors the whole indicator without changing colors")

func verify_current_rgba(button: CheckButton, selected: bool, off: Color, on: Color, thumb: Color, context: String) -> void:
	var image := native_image(button, "checked" if selected else "unchecked")
	var track := on if selected else off
	var expected_thumb := track.blend(Color(0, 0, 0, 0.12 * thumb.a)).blend(thumb)
	check(colors_close(image.get_pixel(20 if selected else 81, 31), track), context + " live track keeps full local/config RGBA")
	check(colors_close(image.get_pixel(71 if selected else 31, 31), expected_thumb), context + " live thumb keeps independent local/config RGBA")

func save_reload(node: Node, filename: String) -> Node:
	var packed := PackedScene.new()
	check(packed.pack(node) == OK, filename + " packs")
	var path := "user://ios_switch_" + filename + ".tscn"
	check(ResourceSaver.save(packed, path) == OK, filename + " saves to temporary scene")
	var contents := FileAccess.get_file_as_string(path)
	# Godot synthetic theme properties cannot suppress STORAGE via script.
	# Generated icons serialize as small marker resources with no image bytes;
	# the one explicit user ImageTexture in this fixture must retain its image.
	var authored_images := 1 if filename == "override" else 0
	check(contents.count("[sub_resource type=\"Image\"") == authored_images and contents.count("PackedByteArray(") == authored_images, filename + " stores only authored image data, never generated runtime snapshots")
	var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	check(reloaded != null, filename + " reloads without cache")
	if reloaded == null: return null
	var copy := reloaded.instantiate()
	copy.position = Vector2(30, 850)
	root.add_child(copy)
	copies.append(copy)
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, filename + " temporary file removed")
	return copy

func run() -> void:
	root.size = Vector2i(1920, 1080)
	config = load("res://ui/theme/ui_config.tres")
	shared_theme = load("res://ui/theme/party_theme.tres")
	for field in FIELDS: original[field] = config.get(field)
	check(config.toggle_off.r > 0.55 and absf(config.toggle_off.r - config.toggle_off.g) < 0.03 and absf(config.toggle_off.g - config.toggle_off.b) < 0.03, "Default off is visibly neutral gray")
	check(config.toggle_on.b > config.toggle_on.g and config.toggle_on.g > config.toggle_on.r, "Default on is Godot blue")
	check(config.toggle_thumb == Color.WHITE, "Default thumb is white")
	for selected in [false, true]:
		var name := "checked" if selected else "unchecked"
		var normal := shared_theme.get_icon(name, "CheckButton").get_image()
		var mirrored := shared_theme.get_icon(name + "_mirrored", "CheckButton").get_image()
		verify_capsule(normal, selected, false, "Theme " + name)
		verify_capsule(mirrored, selected, true, "Theme " + name + " mirrored")
		verify_mirror(normal, mirrored, "Theme " + name)
		verify_dimmed(normal, shared_theme.get_icon(name + "_disabled", "CheckButton").get_image(), config.disabled_opacity, "Theme " + name)
		verify_dimmed(mirrored, shared_theme.get_icon(name + "_disabled_mirrored", "CheckButton").get_image(), config.disabled_opacity, "Theme " + name + " mirrored")
	var midpoint := Graphics.image(0.5, Vector2i(102, 62), config.toggle_off, config.toggle_on, config.toggle_thumb, config.toggle_border)
	check(colors_close(midpoint.get_pixel(51, 31), Color.WHITE), "Animation midpoint puts round white thumb in the center")
	check(colors_close(midpoint.get_pixel(20, 31), config.toggle_off.lerp(config.toggle_on, 0.5)), "Animation interpolates full track color with thumb movement")
	var advanced: Control = load("res://ui/dialogs/advanced_dialog.tscn").instantiate()
	root.add_child(advanced)
	await settle()
	var button: CheckButton = advanced.get_node("Shuffle")
	button.toggled.connect(func(_value): calls += 1)
	check(button.get_script() == NativeSwitch and button.button_pressed and is_equal_approx(button._slide, 1.0), "Advanced authored native switch initializes On without animation")
	for name in ["Shuffle", "Items", "Teams"]:
		var row: CheckButton = advanced.get_node(name)
		check(row.size == Vector2(720, 78) and row.get_theme_icon("checked").get_size() == Vector2(102, 62), name + " fits enlarged indicator in 78px row")
		check(row.get_global_rect().end.y <= advanced.get_node("Close").get_global_rect().position.y, name + " stays clear of the Complete button")
	check(button.get_theme_color("button_checked_color") == Color.WHITE and button.get_theme_color("button_unchecked_color") == Color.WHITE, "Native modulation preserves multicolor icon and white thumb")
	verify_capsule(native_image(button, "checked"), true, false, "Advanced initial On")
	click(button)
	check(not button.button_pressed and calls == 1, "Real native click changes value exactly once")
	await create_timer(0.055).timeout
	check(button._slide > 0 and button._slide < 1, "Native thumb moves through a real intermediate frame")
	var intermediate: Image = native_image(button, "unchecked")
	var white_min := 102
	var white_max := -1
	for x in intermediate.get_width():
		if colors_close(intermediate.get_pixel(x, 31), Color.WHITE):
			white_min = mini(white_min, x)
			white_max = maxi(white_max, x)
	check(absf((white_min + white_max + 1) * 0.5 - (31 + 40 * button._slide)) <= 1, "Native intermediate bitmap moves the actual thumb center with animation")
	click(button)
	check(button.button_pressed and calls == 2, "Mid-animation reversal changes value once")
	for i in range(8): click(button)
	check(button.button_pressed and calls == 10, "Rapid native reversals emit one callback per click")
	await create_timer(0.26).timeout
	check(is_equal_approx(button._slide, 1), "Native interrupted animation settles on latest value")
	verify_capsule(native_image(button, "checked"), true, false, "Advanced after rapid reversal")
	button.set_pressed_no_signal(false)
	await settle()
	check(calls == 10 and is_zero_approx(button._slide), "Native silent model sync snaps without business callback")
	move_to(OUTSIDE)
	button.grab_focus()
	key(KEY_SPACE)
	check(button.has_focus() and button.button_pressed and calls == 11, "Native focus and Space toggle exactly once")
	button.size.x += 160
	await create_timer(0.26).timeout
	check(button.get_theme_icon("checked").get_size() == Vector2(102, 62) and is_equal_approx(button._slide, 1), "Row resize during animation keeps circular geometry and target")
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus")
	check(focus.bg_color.a == 0 and focus.border_color == config.focus, "Keyboard focus remains a separate transparent outline")
	button.disabled = true
	click(button)
	key(KEY_SPACE)
	check(button.button_pressed and calls == 11 and button.get_draw_mode() == BaseButton.DRAW_DISABLED, "Disabled native switch blocks mouse and keyboard")
	verify_dimmed(native_image(button, "checked"), native_image(button, "checked_disabled"), config.disabled_opacity, "Disabled live native switch")
	button.disabled = false
	button.release_focus()
	move_to(OUTSIDE)
	await settle()
	check(button.get_draw_mode() == BaseButton.DRAW_PRESSED and button.get_theme_stylebox("pressed") == button.get_theme_stylebox("normal"), "Checked idle native row keeps normal background")
	move_to(button.get_global_rect().get_center())
	await settle()
	check(button.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED and button.get_theme_stylebox("hover_pressed") == button.get_theme_stylebox("hover"), "Checked native row highlights only on hover")
	# The historical settings Button API must also survive same-instance reentry.
	var custom: Button = load("res://settings/components/segmented_toggle.tscn").instantiate()
	custom.position = Vector2(40, 40)
	root.add_child(custom)
	copies.append(custom)
	var custom_calls := [0]
	custom.toggled.connect(func(_value): custom_calls[0] += 1)
	await settle()
	verify_capsule(custom_image(custom), false, false, "Settings initial Off")
	custom.button_pressed = true
	await create_timer(0.055).timeout
	check(custom._slide > 0 and custom._slide < 1 and custom_calls[0] == 1, "Settings switch begins actual animation before reentry")
	var custom_tween: Tween = custom._tween
	root.remove_child(custom)
	check(not custom_tween.is_running() and not config.changed.is_connected(custom.queue_redraw), "Detached settings switch cancels animation and config hook")
	root.add_child(custom)
	await settle()
	check(is_equal_approx(custom._slide, 1) and custom_calls[0] == 1 and config.changed.is_connected(custom.queue_redraw), "Same settings switch reenters snapped to value without duplicate callback")
	custom.set_pressed_no_signal(false)
	await settle()
	check(is_zero_approx(custom._slide) and custom_calls[0] == 1, "Direct silent settings Button sync updates graphics without callback")
	custom.layout_direction = Control.LAYOUT_DIRECTION_RTL
	await settle()
	verify_capsule(custom_image(custom), false, true, "Settings RTL Off")
	var track_rect: Rect2 = custom.get_node("Track").get_global_rect()
	var caption_rect: Rect2 = custom.get_node("Off").get_global_rect()
	check(not track_rect.intersects(caption_rect), "RTL caption remains outside the switch capsule")
	custom.grab_focus()
	key(KEY_LEFT)
	check(custom.button_pressed and custom_calls[0] == 2, "RTL Left selects On at the physical left endpoint once")
	await create_timer(0.26).timeout
	verify_capsule(custom_image(custom), true, true, "Settings RTL On")
	key(KEY_RIGHT)
	check(not custom.button_pressed and custom_calls[0] == 3, "RTL Right selects Off at the physical right endpoint once")
	await create_timer(0.26).timeout
	custom.layout_direction = Control.LAYOUT_DIRECTION_LTR
	custom.release_focus()
	await settle()
	config.set_block_signals(true)
	config.toggle_off = Color(0.22, 0.31, 0.40, 0.43)
	config.toggle_on = Color(0.11, 0.49, 0.82, 0.67)
	config.toggle_thumb = Color(0.89, 0.93, 0.98, 0.58)
	config.toggle_border = Color(0.31, 0.54, 0.69, 0.27)
	config.disabled_opacity = 0.37
	config.set_block_signals(false)
	config.emit_changed()
	await settle()
	verify_current_rgba(button, true, config.toggle_off, config.toggle_on, config.toggle_thumb, "Existing native switch")
	check(colors_close(custom_image(custom).get_pixel(81, 31), config.toggle_off) and custom_calls[0] == 3, "Reentered settings switch follows later global RGBA without callback")
	verify_dimmed(native_image(button, "checked"), native_image(button, "checked_disabled"), config.disabled_opacity, "Custom RGBA native switch")
	check(calls == 11, "Palette edits never emit toggled callbacks")
	var saved_global := save_reload(button, "global") as CheckButton
	await settle()
	if saved_global != null:
		verify_current_rgba(saved_global, true, config.toggle_off, config.toggle_on, config.toggle_thumb, "Saved global native switch")
	var local := NativeSwitch.new()
	local.theme = shared_theme
	local.text = "Local native switch"
	local.position = Vector2(40, 850)
	local.size = Vector2(500, 78)
	local.use_global_colors = false
	local.off_color = Color(0.69, 0.27, 0.43, 0.38)
	local.on_color = Color(0.17, 0.65, 0.41, 0.64)
	local.thumb_color = Color(0.88, 0.76, 0.50, 0.77)
	local.border_color = Color(0.16, 0.21, 0.34, 0.46)
	local.disabled_opacity = 0.29
	root.add_child(local)
	copies.append(local)
	await settle()
	verify_current_rgba(local, false, local.off_color, local.on_color, local.thumb_color, "Opted-out native switch")
	var saved_local := save_reload(local, "local") as CheckButton
	await settle()
	if saved_local != null:
		check(not saved_local.use_global_colors and saved_local.off_color == local.off_color and saved_local.on_color == local.on_color and saved_local.thumb_color == local.thumb_color and saved_local.border_color == local.border_color, "Saved native opt-out preserves every editable local color")
		verify_current_rgba(saved_local, false, local.off_color, local.on_color, local.thumb_color, "Saved local native switch")
	var custom_pixels := Image.create(102, 62, false, Image.FORMAT_RGBA8)
	custom_pixels.fill(Color(0.77, 0.19, 0.40, 0.63))
	var custom_icon := ImageTexture.create_from_image(custom_pixels)
	local.add_theme_icon_override("checked", custom_icon)
	local.add_theme_color_override("button_checked_color", Color(0.67, 0.84, 0.38, 0.72))
	var custom_style := StyleBoxFlat.new()
	custom_style.bg_color = Color(0.58, 0.21, 0.75, 0.39)
	local.add_theme_stylebox_override("hover", custom_style)
	var saved_override := save_reload(local, "override") as CheckButton
	await settle()
	config.toggle_off = Color(0.37, 0.44, 0.52, 0.52)
	config.toggle_on = Color(0.17, 0.39, 0.71, 0.74)
	await settle()
	verify_current_rgba(button, true, config.toggle_off, config.toggle_on, config.toggle_thumb, "Existing native after later palette edit")
	if saved_global != null: verify_current_rgba(saved_global, true, config.toggle_off, config.toggle_on, config.toggle_thumb, "Saved global after later palette edit")
	if saved_local != null: verify_current_rgba(saved_local, false, local.off_color, local.on_color, local.thumb_color, "Saved local after later palette edit")
	check(local.get_theme_icon("checked") == custom_icon and local.get_theme_stylebox("hover") == custom_style, "Explicit native icon/style overrides survive global changes")
	if saved_override != null:
		check(saved_override.has_theme_icon_override("checked") and colors_close(saved_override.get_theme_icon("checked").get_image().get_pixel(31, 31), custom_pixels.get_pixel(31, 31)), "Explicit native icon override survives scene save/reload")
		check(saved_override.get_theme_color("button_checked_color") == local.get_theme_color("button_checked_color") and saved_override.get_theme_stylebox("hover").bg_color == custom_style.bg_color, "Explicit native modulation/style overrides survive scene save/reload")
		verify_dimmed(native_image(saved_override, "unchecked"), native_image(saved_override, "unchecked_disabled"), local.disabled_opacity, "Saved local native disabled alpha")
	# Removing an animating native control must not leave a tween or config hook.
	var detached := NativeSwitch.new()
	detached.theme = shared_theme
	root.add_child(detached)
	detached.button_pressed = true
	var tween: Tween = detached._tween
	root.remove_child(detached)
	check(tween != null and not tween.is_running(), "Detaching native switch immediately cancels its animation")
	check(not config.changed.is_connected(detached._refresh_graphics), "Detaching native switch disconnects global config")
	detached.free()
	config.set_block_signals(true)
	for field in original: config.set(field, original[field])
	config.set_block_signals(false)
	config.emit_changed()
	for copy in copies:
		if is_instance_valid(copy): copy.queue_free()
	advanced.queue_free()
	await settle()
	for field in original: check(config.get(field) == original[field], "Restored " + field)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
