extends SceneTree
## Native hover/state regressions. Uses real input, not emitted button signals.
## Run: godot --headless --path . --script res://tests/test_hover_states.gd
## Headless state/theme assertions do not replace rendered visual inspection.

const THEME_PATH := "res://ui/theme/party_theme.tres"
const CONFIG_PATH := "res://ui/theme/ui_config.tres"
const OUTSIDE := Vector2(20, 1020)
const COLORS := ["surface", "hover_surface", "muted_surface", "border", "hover_border", "text", "text_hover", "text_disabled", "focus", "primary"]
const LOCAL_COLOR := Color(0.81, 0.16, 0.47, 0.38)
var checks := 0
var failures := 0
var config: Resource
var shared_theme: Theme
var original: Dictionary = {}
var native_toggles := 0
var option_selections := 0
var setting_changes := 0
var setting_callbacks := 0

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

func move_to(position: Vector2, viewport: Viewport = root) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(viewport.position) + position if viewport is PopupMenu else position
	event.global_position = event.position
	event.relative = Vector2(1, 1)
	# PopupMenu ignores stationary mouse events and handles window input before
	# Viewport input. Route through the embedder, not popup.push_input().
	event.velocity = Vector2(60, 60)
	root.push_input(event, true)

func mouse_button(position: Vector2, pressed: bool, viewport: Viewport = root) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(viewport.position) + position if viewport is PopupMenu else position
	event.global_position = event.position
	event.pressed = pressed
	root.push_input(event, true)

func click(position: Vector2, viewport: Viewport = root) -> void:
	move_to(position, viewport)
	mouse_button(position, true, viewport)
	mouse_button(position, false, viewport)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func style(control: Node, state: String, fill: String, border: String, context: String) -> void:
	var box := control.get_theme_stylebox(state) as StyleBoxFlat
	check(box != null, context + " has a flat " + state + " style")
	if box != null:
		check(box.bg_color.is_equal_approx(config.get(fill)), context + " " + state + " uses full " + fill + " RGBA")
		check(box.border_color.is_equal_approx(config.get(border)), context + " " + state + " uses full " + border + " RGBA")

func verify_native_theme(control: BaseButton, is_check: bool, context: String) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var resting: bool = state == "normal" or (is_check and state == "pressed")
		var fill := "muted_surface" if state == "disabled" else ("surface" if resting else "hover_surface")
		var border := "border" if resting or state == "disabled" else "hover_border"
		style(control, state, fill, border, context)
		var item: String = "font_color" if state == "normal" else "font_" + state + "_color"
		var field := "text_disabled" if state == "disabled" else ("text" if resting else "text_hover")
		check(control.get_theme_color(item).is_equal_approx(config.get(field)), context + " " + item + " follows " + field)
		item = "icon_normal_color" if state == "normal" else "icon_" + state + "_color"
		check(control.get_theme_color(item).is_equal_approx(config.get(field)), context + " " + item + " follows " + field)
	var focus := control.get_theme_stylebox("focus") as StyleBoxFlat
	check(focus != null and focus.border_color.is_equal_approx(config.focus) and focus.bg_color.a == 0, context + " preserves separate transparent focus border")
	check(control.get_theme_color("font_focus_color").is_equal_approx(config.text), context + " focused text keeps normal RGBA")
	if is_check:
		check(control.get_theme_stylebox("pressed") == control.get_theme_stylebox("normal"), context + " checked idle row shares normal style")
		check(control.get_theme_stylebox("hover_pressed") == control.get_theme_stylebox("hover"), context + " checked hover row shares hover style")

func verify_popup_theme(popup: PopupMenu, context: String) -> void:
	style(popup, "panel", "surface", "border", context)
	style(popup, "hover", "hover_surface", "hover_border", context)
	check(popup.get_theme_font("font") == config.font, context + " popup inherits shared font")
	for item in ["font_color", "font_hover_color", "font_disabled_color"]:
		var field := "text" if item == "font_color" else ("text_hover" if item == "font_hover_color" else "text_disabled")
		check(popup.get_theme_color(item).is_equal_approx(config.get(field)), context + " " + item + " follows " + field)
	for item in ["radio_checked", "radio_unchecked", "radio_checked_disabled", "radio_unchecked_disabled"]:
		var icon := popup.get_theme_icon(item)
		var native := ThemeDB.get_default_theme().get_icon(item, "PopupMenu")
		check(icon != null and icon.get_size() == native.get_size(), context + " popup " + item + " preserves native icon geometry")
		var pixels := icon.get_image()
		var maximum_alpha := 0.0
		for y in pixels.get_height():
			for x in pixels.get_width(): maximum_alpha = maxf(maximum_alpha, pixels.get_pixel(x, y).a)
		var tint: Color = config.text_disabled if item.ends_with("_disabled") else config.text
		check(maximum_alpha > 0 and maximum_alpha <= tint.a + 0.005, context + " popup " + item + " remains visible within semantic alpha")

func exercise_native_check(control: BaseButton, context: String) -> void:
	var old_rect := control.get_global_rect()
	var old_minimum := control.get_combined_minimum_size()
	var start_signals := native_toggles
	control.toggled.connect(func(_value): native_toggles += 1)
	for selected in [false, true]:
		control.set_pressed_no_signal(selected)
		move_to(OUTSIDE)
		await settle()
		check(control.get_draw_mode() == (BaseButton.DRAW_PRESSED if selected else BaseButton.DRAW_NORMAL), context + " idle draw mode, selected=" + str(selected))
		move_to(center(control))
		await settle()
		check(control.get_draw_mode() == (BaseButton.DRAW_HOVER_PRESSED if selected else BaseButton.DRAW_HOVER), context + " real mouse enters, selected=" + str(selected))
		move_to(OUTSIDE)
		await settle()
		check(not control.is_hovered() and control.button_pressed == selected, context + " mouse leave retains only value, selected=" + str(selected))
	check(native_toggles == start_signals, context + " hover and silent setup emit no toggled signal")
	click(center(control))
	check(not control.button_pressed and native_toggles == start_signals + 1, context + " real click changes value once")
	move_to(OUTSIDE)
	control.grab_focus()
	key(KEY_SPACE)
	check(control.has_focus() and control.button_pressed and native_toggles == start_signals + 2, context + " keyboard focus and Space toggle once")
	for i in range(4):
		click(center(control))
		check(control.get_draw_mode() == (BaseButton.DRAW_HOVER_PRESSED if control.button_pressed else BaseButton.DRAW_HOVER), context + " rapid click release restores hover %d" % i)
		move_to(OUTSIDE)
		check(control.get_draw_mode() == (BaseButton.DRAW_PRESSED if control.button_pressed else BaseButton.DRAW_NORMAL), context + " rapid mouse leave restores idle %d" % i)
	check(control.button_pressed and native_toggles == start_signals + 6, context + " four rapid toggles each emit once")
	control.disabled = true
	click(center(control))
	key(KEY_SPACE)
	check(control.get_draw_mode() == BaseButton.DRAW_DISABLED and control.button_pressed and native_toggles == start_signals + 6, context + " disabled mouse/keyboard preserve value and signals")
	control.disabled = false
	control.release_focus()
	move_to(OUTSIDE)
	await settle()
	check(control.get_global_rect() == old_rect and control.get_combined_minimum_size() == old_minimum, context + " all states preserve control geometry")

func popup_row_center(popup: PopupMenu, index: int) -> Vector2:
	# This fixture has same-font, one-line items and no icons larger than the font.
	var panel := popup.get_theme_stylebox("panel")
	var height := popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size")) + popup.get_theme_constant("v_separation")
	return Vector2(popup.size.x / 2.0, panel.get_content_margin(SIDE_TOP) + height * (index + 0.5))

func exercise_option(option: OptionButton, page: Node) -> void:
	var popup := option.get_popup()
	var old_rect := option.get_global_rect()
	var old_minimum := option.get_combined_minimum_size()
	move_to(OUTSIDE)
	await settle()
	check(option.get_draw_mode() == BaseButton.DRAW_NORMAL, "Voice dropdown begins in normal state")
	move_to(center(option))
	await settle()
	check(option.get_draw_mode() == BaseButton.DRAW_HOVER, "Voice dropdown receives native hover input")
	check(option.get_theme_stylebox("hover") != option.get_theme_stylebox("normal"), "Voice dropdown hover is distinct from its normal card")
	move_to(OUTSIDE)
	check(option.get_draw_mode() == BaseButton.DRAW_NORMAL and option.selected == 0, "Voice dropdown leaves hover without changing selection")
	check(option_selections == 0 and setting_changes == 0 and setting_callbacks == 0, "Dropdown hover emits no selection, settings signal or callback")
	option.grab_focus()
	check(option.has_focus(), "Dropdown accepts keyboard focus")
	click(center(option))
	await settle()
	check(popup.visible, "Actual mouse click opens native PopupMenu")
	if popup.visible:
		check(popup.is_item_checked(0) and not popup.is_item_checked(2), "Popup preserves selected radio item before hover")
		move_to(popup_row_center(popup, 2), popup)
		await settle()
		check(popup.get_focused_item() == 2, "Native popup pointer hover focuses enabled item")
		check(option.selected == 0 and page.get_value("voice.Device") == "Default" and option_selections == 0, "Popup hover does not select or emit")
		click(popup_row_center(popup, 1), popup)
		await settle()
		check(popup.visible and option.selected == 0 and option_selections == 0, "Disabled popup item cannot be selected by mouse")
		click(popup_row_center(popup, 2), popup)
		await settle()
		check(not popup.visible and option.selected == 2 and page.get_value("voice.Device") == "Other", "Enabled popup item selects native value and closes menu")
		check(option_selections == 1 and setting_changes == 1 and setting_callbacks == 1, "Popup selection emits each business notification exactly once")
	option.grab_focus()
	move_to(OUTSIDE)
	key(KEY_SPACE)
	await settle()
	check(popup.visible, "Space reopens focused dropdown")
	if popup.visible:
		check(popup.is_item_checked(2) and not popup.is_item_checked(0), "Reopened popup retains selected radio item")
		key(KEY_UP)
		check(popup.get_focused_item() == 0, "Popup Up skips disabled item to first enabled row")
		key(KEY_DOWN)
		check(popup.get_focused_item() == 2, "Popup keyboard traversal skips disabled item")
		key(KEY_ESCAPE)
		await settle()
		check(not popup.visible and option.selected == 2 and option_selections == 1, "Escape dismisses popup without another selection")
	option.disabled = true
	click(center(option))
	key(KEY_SPACE)
	await settle()
	check(not popup.visible and option.get_draw_mode() == BaseButton.DRAW_DISABLED and option_selections == 1, "Disabled dropdown cannot reopen or emit selection")
	option.disabled = false
	option.release_focus()
	move_to(OUTSIDE)
	await settle()
	check(option.get_global_rect() == old_rect and option.get_combined_minimum_size() == old_minimum, "Dropdown hover, popup and disabled states preserve geometry")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.gui_embed_subwindows = true
	config = load(CONFIG_PATH)
	shared_theme = load(THEME_PATH)
	for field in COLORS: original[field] = config.get(field)
	var advanced: Control = load("res://ui/dialogs/advanced_dialog.tscn").instantiate()
	root.add_child(advanced)
	var checkbox := CheckBox.new()
	checkbox.text = "Native checkbox"
	checkbox.theme = shared_theme
	checkbox.position = Vector2(600, 180)
	checkbox.size = Vector2(720, 56)
	root.add_child(checkbox)
	await settle()
	var shuffle: CheckButton = advanced.get_node("Shuffle")
	check(shuffle.button_pressed and advanced.get_node("Items").button_pressed and not advanced.get_node("Teams").button_pressed, "Advanced scene preserves authored checked values")
	check(shuffle.position == Vector2(600, 450) and shuffle.size == Vector2(720, 56), "Advanced toggle row preserves authored bounds")
	for control in [shuffle, advanced.get_node("Items"), advanced.get_node("Teams"), checkbox]:
		verify_native_theme(control, true, str(control.name))
	await exercise_native_check(shuffle, "Advanced CheckButton")
	await exercise_native_check(checkbox, "Native CheckBox")
	advanced.hide()
	checkbox.hide()
	var page: Control = load("res://settings/settings_page.tscn").instantiate()
	root.add_child(page)
	var voice: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://settings/main_settings_schema.json"))[0]
	voice.options[0].items = [{"label":"System default", "value":"Default"}, {"label":"Unavailable device", "value":"Unavailable"}, {"label":"Other device", "value":"Other"}]
	voice.options[0].value = "Default"
	voice.options[0].callback = func(_value, _id): setting_callbacks += 1
	check(page.configure([voice]), "Authored Voice settings schema configures with deterministic device fixtures")
	page.setting_changed.connect(func(_id, _value): setting_changes += 1)
	var option: OptionButton = page.get_control("voice.Device")
	option.item_selected.connect(func(_index): option_selections += 1)
	option.set_item_disabled(1, true)
	await settle()
	check(option == page.get_node("Tabs/Voice/Padding/Content/DeviceRow/Device"), "Tests use actual Voice dropdown component and theme variation")
	verify_native_theme(option, false, "Voice OptionButton")
	verify_popup_theme(option.get_popup(), "Voice")
	check(option.get_theme_constant("modulate_arrow") == 1, "Dropdown arrow follows interaction text tint")
	await exercise_option(option, page)
	# A runtime palette update must affect existing and new instances, including alpha.
	var geometry := option.get_global_rect()
	config.set_block_signals(true)
	for i in COLORS.size(): config.set(COLORS[i], Color(0.09 + i * 0.06, 0.81 - i * 0.04, 0.23 + i * 0.03, 0.32 + i * 0.04))
	config.set_block_signals(false)
	config.emit_changed()
	await settle()
	verify_native_theme(shuffle, true, "Custom RGBA existing CheckButton")
	verify_native_theme(checkbox, true, "Custom RGBA existing CheckBox")
	verify_native_theme(option, false, "Custom RGBA existing OptionButton")
	verify_popup_theme(option.get_popup(), "Custom RGBA")
	var fresh := OptionButton.new()
	fresh.theme = shared_theme
	fresh.add_item("New instance")
	fresh.position = Vector2(20, 20)
	root.add_child(fresh)
	verify_native_theme(fresh, false, "Custom RGBA new OptionButton")
	check(option.get_global_rect() == geometry, "Palette refresh preserves existing dropdown bounds")
	check(option_selections == 1 and setting_changes == 1 and setting_callbacks == 1, "Palette refresh emits no extra business notifications")
	# Native local overrides continue to outrank shared defaults after later edits.
	var local_style := StyleBoxFlat.new()
	local_style.bg_color = LOCAL_COLOR
	local_style.border_color = LOCAL_COLOR
	for control in [shuffle, checkbox, option, option.get_popup()]:
		control.add_theme_stylebox_override("hover", local_style)
		control.add_theme_color_override("font_hover_color", LOCAL_COLOR)
	config.hover_surface = Color(0.05, 0.39, 0.91, 0.24)
	config.hover_border = Color(0.82, 0.14, 0.06, 0.63)
	config.text_hover = Color(0.62, 0.08, 0.95, 0.47)
	await settle()
	for control in [shuffle, checkbox, option, option.get_popup()]:
		check(control.get_theme_stylebox("hover") == local_style and local_style.bg_color == LOCAL_COLOR, str(control.name) + " retains local hover style after shared change")
		check(control.get_theme_color("font_hover_color") == LOCAL_COLOR, str(control.name) + " retains local hover text RGBA after shared change")
		control.remove_theme_stylebox_override("hover")
		control.remove_theme_color_override("font_hover_color")
		style(control, "hover", "hover_surface", "hover_border", str(control.name) + " restored global hover")
	# Segmented settings toggles intentionally keep their own transparent root styles.
	var segmented: Button = load("res://settings/components/segmented_toggle.tscn").instantiate()
	root.add_child(segmented)
	await settle()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		check(segmented.has_theme_stylebox_override(state) and segmented.get_theme_stylebox(state) is StyleBoxEmpty, "Segmented toggle retains local transparent " + state + " style")
	check(segmented.get_node("Selection").color.is_equal_approx(config.primary), "Segmented selected segment still follows shared primary")
	check(option_selections == 1 and setting_changes == 1 and setting_callbacks == 1, "Local override changes emit no extra business notifications")
	config.set_block_signals(true)
	for field in original: config.set(field, original[field])
	config.set_block_signals(false)
	config.emit_changed()
	for node in [segmented, fresh, page, checkbox, advanced]: node.queue_free()
	await settle()
	for field in original: check(config.get(field) == original[field], "Restored original " + field)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
