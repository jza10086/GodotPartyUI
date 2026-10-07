extends SceneTree
## Resolver, editable prompt scenes, live InputMap bindings and integrations.
## Run: godot --headless --path . --script res://tests/test_input_prompts.gd
## Source-alpha/layout checks complement, rather than replace, rendered QA.

const Resolver = preload("res://ui/input_prompt_resolver.gd")
const PROMPT_PATH := "res://ui/components/input_prompt.tscn"
const CONFIG_PATH := "res://ui/theme/ui_config.tres"
const TEST_ACTION: StringName = &"_input_prompt_regression_action"
const CONFIG_FIELDS := ["text", "text_hover", "text_disabled", "meta_size", "font"]
var checks := 0
var failures := 0
var config: Resource
var original_config: Dictionary = {}

class InputProbe extends Node:
	var keys: Array[int] = []
	var mouse_buttons: Array[int] = []
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed: keys.append(event.keycode)
		if event is InputEventMouseButton and event.pressed: mouse_buttons.append(event.button_index)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + message)
	else:
		print("PASS ", message)

func settle() -> void:
	for i in range(5): await process_frame

func labels(tokens: Array) -> Array[String]:
	var result: Array[String] = []
	for token in tokens: result.append(str(token.get("label", "")))
	return result

func key_only(tokens: Array) -> Array:
	return tokens.filter(func(token): return not token.get("separator", false))

func assets(tokens: Array) -> Array[String]:
	var result: Array[String] = []
	for token in tokens: result.append(str(token.get("asset", "")))
	return result

func key_event(code: int, physical: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	if physical: event.physical_keycode = code & KEY_CODE_MASK
	else: event.keycode = code & KEY_CODE_MASK
	event.ctrl_pressed = bool(code & KEY_MASK_CTRL)
	event.alt_pressed = bool(code & KEY_MASK_ALT)
	event.shift_pressed = bool(code & KEY_MASK_SHIFT)
	event.meta_pressed = bool(code & KEY_MASK_META)
	return event

func mouse_event(index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	return event

func joy_event(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	return event

func assert_tokens(tokens: Array, context: String, require_asset: bool = false) -> void:
	check(not tokens.is_empty(), context + " resolves a readable token")
	for i in tokens.size():
		var token: Dictionary = tokens[i]
		check(token.get("label") is String and not str(token.get("label", "")).is_empty(), context + " token %d has readable label" % i)
		check(token.get("asset") is String, context + " token %d has stable asset field" % i)
		var asset := str(token.get("asset", ""))
		if token.get("separator", false): continue
		if not asset.is_empty():
			check(Resolver.texture_for(token) is Texture2D, context + " asset ID loads as Texture2D: " + asset)
		elif require_asset:
			check(token.get("texture") is Texture2D, context + " mapped token supplies an icon")

func assert_fallback(binding: Variant, context: String) -> void:
	var resolved: Array = Resolver.tokens(binding)
	assert_tokens(resolved, context)
	for token in resolved:
		check(str(token.get("asset", "")).is_empty() and not token.get("texture") is Texture2D, context + " uses safe text fallback")

func glyphs(prompt: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in prompt.get_node("Keys").get_children():
		if child is Control and child.has_node("Icon") and child.has_node("Fallback"):
			result.append(child)
	return result

func first_icon(prompt: Node) -> TextureRect:
	var items := glyphs(prompt)
	return null if items.is_empty() else items[0].get_node("Icon") as TextureRect

func effective_modulate(control: CanvasItem) -> Color:
	var color := control.self_modulate
	var item: Node = control
	while item is CanvasItem:
		color *= item.modulate
		item = item.get_parent()
	return color

func color_close(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) < 0.005 and absf(actual.g - expected.g) < 0.005 and absf(actual.b - expected.b) < 0.005 and absf(actual.a - expected.a) < 0.005

func map_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for action in InputMap.get_actions():
		var events: Array = []
		for event in InputMap.action_get_events(action): events.append(var_to_str(event))
		result[String(action)] = [InputMap.action_get_deadzone(action), events]
	return result

func spawn_prompt() -> Control:
	var prompt: Control = load(PROMPT_PATH).instantiate()
	root.add_child(prompt)
	return prompt

func verify_passive(node: Node, context: String) -> void:
	if node is Control:
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, context + " ignores pointer input: " + String(node.name))
		check(node.focus_mode == Control.FOCUS_NONE, context + " does not claim keyboard focus: " + String(node.name))
	for child in node.get_children(): verify_passive(child, context)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	config = load(CONFIG_PATH)
	for field in CONFIG_FIELDS: original_config[field] = config.get(field)
	Resolver.clear_registered_icons()
	test_resolver()
	test_asset_crops()
	await test_component()
	await test_action_bindings()
	await test_theme_and_alpha()
	await test_custom_icons()
	await test_serialization()
	await test_input_passthrough()
	await test_main_integration()
	await test_demo_integration()
	for field in original_config: config.set(field, original_config[field])
	Resolver.clear_registered_icons()
	await settle()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_resolver() -> void:
	var mapped: Array[int] = [KEY_TAB, KEY_ENTER, KEY_ESCAPE, KEY_SPACE, KEY_BACKSPACE, KEY_DELETE, KEY_INSERT, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_CTRL, KEY_SHIFT, KEY_ALT]
	for code in range(KEY_A, KEY_Z + 1): mapped.append(code)
	for code in range(KEY_0, KEY_9 + 1): mapped.append(code)
	for code in range(KEY_F1, KEY_F12 + 1): mapped.append(code)
	assert_tokens(Resolver.tokens(KEY_META), "Platform-appropriate Meta key")
	for code in mapped:
		var direct: Array = Resolver.key_tokens(code)
		assert_tokens(direct, "Key " + OS.get_keycode_string(code), true)
		check(direct == Resolver.tokens(code), "Integer resolver delegates consistently: " + OS.get_keycode_string(code))
		check(direct == Resolver.event_tokens(key_event(code)), "Logical key event agrees: " + OS.get_keycode_string(code))
	var aliases := {"Esc":KEY_ESCAPE, "escape":KEY_ESCAPE, "Return":KEY_ENTER, "Ctrl":KEY_CTRL, "Control":KEY_CTRL, "Spacebar":KEY_SPACE, "PgUp":KEY_PAGEUP, "PgDn":KEY_PAGEDOWN, "a":KEY_A, "F12":KEY_F12}
	for alias in aliases:
		check(Resolver.tokens(alias) == Resolver.key_tokens(aliases[alias]), "Alias maps to canonical key: " + alias)
	for code in [KEY_K | KEY_MASK_CTRL, KEY_A | KEY_MASK_ALT | KEY_MASK_SHIFT, KEY_P | KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_SHIFT | KEY_MASK_META]:
		var chord: Array = Resolver.tokens(code)
		assert_tokens(chord, "Packed chord " + OS.get_keycode_string(code))
		check(chord == Resolver.tokens(key_event(code)), "Packed modifier mask agrees with key event")
		check(labels(chord).count(OS.get_keycode_string(code & KEY_CODE_MASK)) == 1, "Chord contains exactly one base-key label")
	check(Resolver.tokens("Ctrl+K") == Resolver.tokens(KEY_K | KEY_MASK_CTRL), "String chord resolves Ctrl+K")
	check(Resolver.tokens("Ctrl + Shift + A") == Resolver.tokens(KEY_A | KEY_MASK_CTRL | KEY_MASK_SHIFT), "String chord trims surrounding spaces")
	check(Resolver.tokens("+") == Resolver.tokens(KEY_PLUS), "Literal plus is a key rather than an empty chord")
	check(Resolver.tokens("Ctrl++") == Resolver.tokens(KEY_PLUS | KEY_MASK_CTRL), "Plus key can follow a modifier in string chord")
	check(Resolver.tokens(KEY_BACKTAB) == Resolver.tokens(KEY_TAB | KEY_MASK_SHIFT), "Backtab resolves to Shift+Tab")
	check(key_only(Resolver.tokens(KEY_CTRL | KEY_MASK_CTRL)).size() == 1, "Modifier key never duplicates itself in a packed event")
	var alternatives: Array = Resolver.tokens([KEY_A, KEY_B])
	check(labels(alternatives).has("A") and labels(alternatives).has("B"), "Array preserves both alternatives")
	check(assets(alternatives).has(assets(Resolver.tokens(KEY_A))[0]) and assets(alternatives).has(assets(Resolver.tokens(KEY_B))[0]), "Array alternatives retain mapped icons")
	check(Resolver.tokens([KEY_W, 0]) == Resolver.tokens(KEY_W), "Empty secondary binding slot adds no redundant unbound alternative")
	check(Resolver.tokens([0, KEY_UP]) == Resolver.tokens(KEY_UP), "Empty primary binding slot does not hide a bound secondary key")
	check(Resolver.tokens([0, 0]) == Resolver.tokens(0), "Completely unbound alternative pair shows one fallback")
	for pair in [[KEY_KP_0, KEY_0], [KEY_KP_1, KEY_1], [KEY_KP_ADD, KEY_PLUS], [KEY_KP_ENTER, KEY_ENTER], [KEY_KP_PERIOD, KEY_PERIOD]]:
		var keypad: Array = Resolver.tokens(pair[0])
		assert_tokens(keypad, "Distinct keypad " + str(pair[0]))
		check(keypad != Resolver.tokens(pair[1]), "Keypad never silently masquerades as main-keyboard equivalent")
	for invalid in [0, -1, 0x7fffffff, "UnknownKeyNotInGodot", "", null, {}, Vector2.ONE]:
		assert_fallback(invalid, "Fallback " + str(invalid))
	check(Resolver.tokens(key_event(KEY_Q, true)) == Resolver.tokens(KEY_Q), "Physical-only key event has a usable key fallback")
	var physical_chord := key_event(KEY_W | KEY_MASK_SHIFT, true)
	check(Resolver.tokens(physical_chord) == Resolver.tokens(KEY_W | KEY_MASK_SHIFT), "Physical key fallback retains modifiers")
	assert_fallback(InputEventKey.new(), "Unbound key event")
	var localized := InputEventKey.new()
	localized.key_label = KEY_Z
	check(Resolver.tokens(localized) == Resolver.tokens(KEY_Z), "Key-label-only event is readable")
	localized.key_label = 0
	localized.unicode = KEY_A
	check(Resolver.tokens(localized) == Resolver.tokens(KEY_A), "Unicode-only event is readable")
	for index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		assert_tokens(Resolver.tokens(mouse_event(index)), "Mouse button " + str(index), true)
	check(Resolver.tokens("LMB") == Resolver.tokens(mouse_event(MOUSE_BUTTON_LEFT)), "LMB alias matches mouse event")
	check(Resolver.tokens("RMB") == Resolver.tokens(mouse_event(MOUSE_BUTTON_RIGHT)), "RMB alias matches mouse event")
	var mouse_chord := mouse_event(MOUSE_BUTTON_LEFT)
	mouse_chord.ctrl_pressed = true
	check(key_only(Resolver.tokens(mouse_chord)).size() == 2 and labels(Resolver.tokens(mouse_chord)).has("Ctrl"), "Mouse chords retain modifier and mouse glyph")
	assert_tokens(Resolver.tokens(mouse_event(MOUSE_BUTTON_XBUTTON1)), "Mouse back button", true)
	assert_fallback(mouse_event(64), "Unmapped mouse button")
	assert_fallback(joy_event(JOY_BUTTON_A), "Controller button without registered artwork")
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = -1.0
	assert_fallback(motion, "Controller axis without registered artwork")
	var negative: Array = Resolver.tokens(motion)
	motion.axis_value = 1.0
	check(labels(negative) != labels(Resolver.tokens(motion)), "Controller axis fallback distinguishes direction")
	assert_fallback(InputEventAction.new(), "Unsupported event type")

func test_asset_crops() -> void:
	var manifest: Dictionary = load("res://assets/input_prompts/manifest.json").data
	check(manifest.size() == 104, "Curated manifest contains all 104 licensed keyboard/mouse assets")
	for id in manifest:
		var texture: Texture2D = Resolver.texture_for({"asset":id, "label":id})
		check(texture is AtlasTexture, "Manifest asset uses alpha-preserving crop: " + id)
		if not texture is AtlasTexture: continue
		var atlas: AtlasTexture = texture
		var source: Image = atlas.atlas.get_image()
		var region := Rect2i(atlas.region)
		check(atlas.atlas.resource_path == "res://assets/input_prompts/" + str(manifest[id].file), "Crop references the authored SVG: " + id)
		check(Rect2i(Vector2i.ZERO, source.get_size()).encloses(region), "Crop stays within source bounds: " + id)
		check(region.encloses(source.get_used_rect()), "Crop preserves all visible edge pixels: " + id)
		var cropped: Image = atlas.get_image()
		check(not cropped.is_empty() and cropped.get_used_rect().has_area(), "Cropped glyph contains visible pixels: " + id)
		check(cropped.get_data() == source.get_region(region).get_data(), "Crop preserves source RGBA exactly: " + id)

func test_component() -> void:
	var before := map_snapshot()
	var prompt := spawn_prompt()
	await settle()
	check(prompt is HBoxContainer, "Prompt root is an editable native HBoxContainer")
	check(prompt.get_script().is_tool(), "Prompt script supports editor preview")
	check(prompt.get_node("Keys") is HBoxContainer and prompt.get_node("Function") is Label, "Prompt keeps separate native key row and function label")
	var exports := {"keycodes":TYPE_PACKED_INT64_ARRAY, "key_separator":TYPE_STRING, "action_name":TYPE_STRING_NAME, "binding_index":TYPE_INT, "function_text":TYPE_STRING, "icon_height":TYPE_FLOAT, "label_variation":TYPE_STRING_NAME, "disabled":TYPE_BOOL, "highlighted":TYPE_BOOL}
	for field in exports:
		var found := false
		for property in prompt.get_property_list():
			if property.name == field:
				found = property.type == exports[field] and bool(property.usage & PROPERTY_USAGE_EDITOR) and bool(property.usage & PROPERTY_USAGE_STORAGE)
		check(found, "Editable serialized property: " + field)
	check(prompt.icon_height == 36.0 and prompt.key_separator == "+" and prompt.binding_index == -1, "Default size, separator and all-events binding index")
	check(prompt.label_variation == &"PartyLabelMeta", "Default function text uses shared metadata hierarchy")
	prompt.configure(KEY_K | KEY_MASK_CTRL, "保存")
	await settle()
	check(prompt.get_tokens() == Resolver.tokens(KEY_K | KEY_MASK_CTRL), "configure exposes resolved chord tokens")
	var snapshot: Array = prompt.get_tokens()
	snapshot[0].label = "External mutation"
	check(prompt.get_tokens() == Resolver.tokens(KEY_K | KEY_MASK_CTRL), "get_tokens is a deep snapshot rather than mutable component state")
	check(prompt.get_node("Function").text == "保存", "configure binds function text")
	var accessible: String = prompt.get_accessible_text()
	check(accessible.contains("Ctrl") and accessible.contains("K") and accessible.contains("保存"), "Accessible text retains key names and function meaning")
	check(glyphs(prompt).size() == 2, "Chord uses one independently editable glyph per key")
	var separators: Array[String] = []
	for child in prompt.get_node("Keys").get_children():
		if child is Label: separators.append(child.text)
	check(separators.has("+"), "Chord renders its separator as a native label")
	for glyph in glyphs(prompt):
		check(not glyph.scene_file_path.is_empty(), "Glyph is scene-backed")
		check(glyph.get_node("Icon").visible and not glyph.get_node("Fallback").visible, "Known key displays icon without duplicate fallback label")
		check(glyph.get_combined_minimum_size().y >= 35.0 and glyph.size.x > 0, "Glyph has useful nonzero minimum geometry")
	verify_passive(prompt, "Standalone prompt")
	var row: HBoxContainer = prompt.get_node("Keys")
	var previous_right := -INF
	for child in row.get_children():
		if not child is Control or not child.visible: continue
		check(child.position.x >= previous_right - 0.5, "Chord children flow left to right without overlap")
		previous_right = child.position.x + child.size.x
	check(prompt.get_node("Function").position.x >= row.position.x + row.size.x, "Function label follows complete key row")
	prompt.keycodes = PackedInt64Array([KEY_CTRL, KEY_K])
	prompt.key_separator = " / "
	prompt.refresh()
	await settle()
	var changed_separator := false
	for child in prompt.get_node("Keys").get_children():
		if child is Label and child.text.contains("/"): changed_separator = true
	check(changed_separator, "Edited separator refreshes displayed label")
	prompt.set_binding("UnknownKeyNotInGodot")
	await settle()
	check(glyphs(prompt).size() == 1, "Unknown binding renders one fallback glyph")
	if not glyphs(prompt).is_empty():
		var fallback := glyphs(prompt)[0]
		check(fallback.get_node("Fallback").visible and not fallback.get_node("Icon").visible, "Unknown binding shows text without broken texture")
		check(not fallback.get_node("Fallback").text.is_empty(), "Unknown binding keeps readable fallback text")
	prompt.configure(null, "未知操作")
	await settle()
	check(prompt.get_tokens() == Resolver.tokens(null), "Explicit null binding uses resolver fallback instead of default Tab")
	check(not prompt.get_accessible_text().contains("Tab"), "Null binding never claims a working Tab shortcut")
	prompt.keycodes = PackedInt64Array([KEY_B])
	prompt.refresh()
	check(prompt.get_tokens() == Resolver.tokens(KEY_B), "Editable keycodes clear explicit null binding mode")
	prompt.set_binding(0)
	await settle()
	check(not prompt.get_accessible_text().is_empty(), "Unbound component remains accessible")
	prompt.set_binding([KEY_A, KEY_B])
	await settle()
	check(prompt.get_accessible_text().contains("A") and prompt.get_accessible_text().contains("B"), "Component renders alternative bindings")
	prompt.keycodes = PackedInt64Array([KEY_F10 | KEY_MASK_ALT])
	prompt.refresh()
	await settle()
	check(prompt.get_tokens() == Resolver.tokens(KEY_F10 | KEY_MASK_ALT), "Editable packed keycodes refresh glyphs")
	prompt.function_text = ""
	prompt.refresh()
	await settle()
	check(not prompt.get_node("Function").visible or prompt.get_node("Function").text.is_empty(), "Empty function text leaves no stale label")
	check(map_snapshot() == before, "Manual prompt configuration does not mutate InputMap")
	prompt.queue_free()
	await settle()

func test_action_bindings() -> void:
	if InputMap.has_action(TEST_ACTION):
		check(false, "Dynamic action fixture collides with an existing application action")
		return
	var prompt := spawn_prompt()
	prompt.action_name = TEST_ACTION
	prompt.function_text = "动态操作"
	prompt.refresh()
	await settle()
	assert_tokens(prompt.get_tokens(), "Missing action fallback")
	check(not InputMap.has_action(TEST_ACTION), "Reading missing action never creates it")
	InputMap.add_action(TEST_ACTION, 0.37)
	InputMap.action_add_event(TEST_ACTION, key_event(KEY_K | KEY_MASK_CTRL))
	InputMap.action_add_event(TEST_ACTION, mouse_event(MOUSE_BUTTON_RIGHT))
	var before := map_snapshot()
	await create_timer(0.25).timeout
	check(labels(prompt.get_tokens()).has("K") and assets(prompt.get_tokens()).has(assets(Resolver.tokens(mouse_event(MOUSE_BUTTON_RIGHT)))[0]), "Action created after prompt refreshes automatically with all events")
	check(prompt.get_accessible_text().contains("动态操作"), "Action prompt retains function text")
	prompt.binding_index = 0
	prompt.refresh()
	check(prompt.get_tokens() == Resolver.tokens(KEY_K | KEY_MASK_CTRL), "Explicit action index selects keyboard chord immediately")
	prompt.binding_index = 1
	prompt.refresh()
	check(prompt.get_tokens() == Resolver.tokens(mouse_event(MOUSE_BUTTON_RIGHT)), "Explicit action index selects mouse event immediately")
	prompt.binding_index = 8
	prompt.refresh()
	assert_tokens(prompt.get_tokens(), "Out-of-range action index fallback")
	check(assets(prompt.get_tokens()).all(func(asset): return asset.is_empty()), "Out-of-range index does not pretend another binding is selected")
	check(map_snapshot() == before, "Action display and binding index never rewrite InputMap or deadzones")
	prompt.binding_index = -1
	InputMap.action_erase_events(TEST_ACTION)
	InputMap.action_add_event(TEST_ACTION, key_event(KEY_F12))
	await create_timer(0.25).timeout
	check(prompt.get_tokens() == Resolver.tokens(KEY_F12), "InputMap rebind automatically replaces old displayed chord")
	prompt.hide()
	InputMap.action_erase_events(TEST_ACTION)
	InputMap.action_add_event(TEST_ACTION, key_event(KEY_F11))
	await create_timer(0.25).timeout
	prompt.show()
	check(prompt.get_tokens() == Resolver.tokens(KEY_F11), "Hidden action prompt stays current when shown again")
	InputMap.action_erase_events(TEST_ACTION)
	prompt.refresh()
	assert_tokens(prompt.get_tokens(), "Empty action fallback")
	check(assets(prompt.get_tokens()).all(func(asset): return asset.is_empty()), "Empty action has no stale mapped icons")
	InputMap.erase_action(TEST_ACTION)
	await create_timer(0.25).timeout
	assert_tokens(prompt.get_tokens(), "Removed action fallback")
	check(not InputMap.has_action(TEST_ACTION), "Polling removed action does not recreate it")
	prompt.queue_free()
	await settle()

func test_theme_and_alpha() -> void:
	var prompt := spawn_prompt()
	prompt.configure(KEY_A, "测试文字")
	await settle()
	var label: Label = prompt.get_node("Function")
	check(label.get_theme_font("font") == config.font and label.get_theme_font_size("font_size") == config.meta_size, "Prompt inherits global font and metadata font size")
	var icon := first_icon(prompt)
	check(icon != null and icon.texture is AtlasTexture, "Glyph crops transparent padding through AtlasTexture")
	if icon == null or not icon.texture is AtlasTexture:
		prompt.queue_free()
		await settle()
		return
	var atlas: AtlasTexture = icon.texture
	var source: Texture2D = atlas.atlas
	check(source.resource_path.ends_with(".svg") and source.resource_path.begins_with("res://assets/input_prompts/"), "Atlas references original imported SVG texture")
	var source_image := source.get_image()
	var original_pixels := source_image.get_data()
	var region := Rect2i(atlas.region)
	var used := source_image.get_used_rect()
	check(region.size.x > 0 and region.size.y > 0 and region.size.x <= source_image.get_width() and region.size.y <= source_image.get_height(), "Atlas region has valid source bounds")
	check(region.encloses(used), "Padding crop never removes visible source pixels")
	check(region.size.x < source_image.get_width() or region.size.y < source_image.get_height(), "Transparent source padding is actually removed")
	var cropped := atlas.get_image()
	var wrong_alpha := 0
	var wrong_rgb := 0
	var transparent := 0
	for y in cropped.get_height():
		for x in cropped.get_width():
			var original := source_image.get_pixel(x + region.position.x, y + region.position.y)
			var actual := cropped.get_pixel(x, y)
			if not is_equal_approx(actual.a, original.a): wrong_alpha += 1
			if actual.a > 0 and (not is_equal_approx(actual.r, original.r) or not is_equal_approx(actual.g, original.g) or not is_equal_approx(actual.b, original.b)): wrong_rgb += 1
			if actual.a == 0: transparent += 1
	check(wrong_alpha == 0 and transparent > 0, "Cropped glyph preserves original SVG alpha including transparent interior")
	check(wrong_rgb == 0, "Atlas does not bake palette colors into source pixels")
	config.text = Color(0.81, 0.19, 0.41, 0.67)
	config.text_hover = Color(0.21, 0.83, 0.42, 0.81)
	config.text_disabled = Color(0.24, 0.38, 0.72, 0.44)
	config.meta_size = 27
	await settle()
	icon = first_icon(prompt)
	check(color_close(effective_modulate(icon), config.text), "Monochrome icon follows live normal theme RGBA")
	check(color_close(label.get_theme_color("font_color") * effective_modulate(label), config.text), "Function label follows live normal theme RGBA")
	check(label.get_theme_font_size("font_size") == 27, "Live metadata size refreshes existing function text")
	var replacement_font := SystemFont.new()
	config.font = replacement_font
	await settle()
	check(label.get_theme_font("font") == replacement_font, "Live font replacement reaches existing prompt")
	prompt.highlighted = true
	await settle()
	check(color_close(effective_modulate(first_icon(prompt)), config.text_hover), "Highlighted icon follows shared hover color")
	prompt.disabled = true
	await settle()
	check(color_close(effective_modulate(first_icon(prompt)), config.text_disabled), "Disabled icon takes precedence over highlight")
	check(color_close(label.get_theme_color("font_color") * effective_modulate(label), config.text_disabled), "Disabled label follows shared disabled RGBA")
	prompt.disabled = false
	prompt.highlighted = false
	prompt.icon_height = 52.0
	await settle()
	check(glyphs(prompt)[0].get_combined_minimum_size().y >= 51.0, "Edited icon height updates glyph minimum height")
	icon = first_icon(prompt)
	check(is_equal_approx(icon.custom_minimum_size.x / icon.custom_minimum_size.y, float(icon.texture.get_width()) / icon.texture.get_height()), "Glyph minimum size preserves cropped artwork aspect ratio")
	check(icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "TextureRect keeps artwork aspect ratio while centered")
	prompt.scale = Vector2(0.75, 0.75)
	await settle()
	check(is_equal_approx(icon.get_global_rect().size.y, icon.size.y * 0.75), "Whole-prompt scaling preserves responsive glyph geometry")
	prompt.scale = Vector2.ONE
	prompt.label_variation = &"PartyLabelBody"
	await settle()
	check(label.theme_type_variation == &"PartyLabelBody" and label.get_theme_font_size("font_size") == config.body_size, "Edited label variation follows shared body hierarchy")
	var local_ink := Color(0.62, 0.22, 0.87, 0.73)
	label.add_theme_color_override("font_color", local_ink)
	check(color_close(effective_modulate(first_icon(prompt)), local_ink), "Static prompt icon immediately follows Function local color override")
	label.add_theme_font_size_override("font_size", 31)
	await settle()
	check(color_close(label.get_theme_color("font_color"), local_ink) and label.get_theme_font_size("font_size") == 31, "Function retains native local theme overrides")
	prompt.highlighted = true
	prompt.disabled = true
	prompt.highlighted = false
	prompt.disabled = false
	await settle()
	check(color_close(label.get_theme_color("font_color"), local_ink) and label.has_theme_color_override("font_color"), "Temporary states restore authored local font color")
	check(color_close(effective_modulate(first_icon(prompt)), local_ink), "Monochrome icon matches restored local label color")
	check(source.get_image().get_data() == original_pixels, "Theme and state updates never alter imported texture alpha or RGB")
	for field in original_config: config.set(field, original_config[field])
	prompt.queue_free()
	await settle()

func test_custom_icons() -> void:
	var pixels := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	pixels.fill_rect(Rect2i(1, 1, 5, 6), Color(1, 0, 0, 0.5))
	pixels.fill_rect(Rect2i(6, 1, 5, 6), Color(0, 0.5, 1, 0.8))
	var texture := ImageTexture.create_from_image(pixels)
	Resolver.register_icon("joypad_button:0", texture)
	var tokens: Array = Resolver.tokens(joy_event(JOY_BUTTON_A))
	assert_tokens(tokens, "Registered controller artwork", true)
	check(tokens.any(func(token): return token.get("texture") == texture), "Controller ID extension resolves the supplied texture")
	var prompt := spawn_prompt()
	prompt.configure(joy_event(JOY_BUTTON_A), "手柄确认")
	await settle()
	var icon := first_icon(prompt)
	check(icon != null and icon.texture != null and icon.visible, "Registered controller icon renders through common component")
	if icon != null:
		var color := effective_modulate(icon)
		check(is_equal_approx(color.r, 1.0) and is_equal_approx(color.g, 1.0) and is_equal_approx(color.b, 1.0), "Multicolor extension icon is not tinted by monochrome palette")
		prompt.highlighted = true
		await settle()
		color = effective_modulate(first_icon(prompt))
		check(is_equal_approx(color.r, 1.0) and is_equal_approx(color.g, 1.0) and is_equal_approx(color.b, 1.0), "Highlight preserves multicolor extension RGB")
	check(texture.get_image().get_data() == pixels.get_data(), "Custom texture pixels and alpha remain unchanged")
	Resolver.clear_registered_icons()
	prompt.refresh()
	await settle()
	assert_fallback(joy_event(JOY_BUTTON_A), "Cleared controller registration")
	check(not glyphs(prompt).is_empty() and glyphs(prompt)[0].get_node("Fallback").visible, "Clearing icon extension restores component text fallback")
	prompt.queue_free()
	await settle()

func test_serialization() -> void:
	var prompt := spawn_prompt()
	prompt.keycodes = PackedInt64Array([KEY_K | KEY_MASK_CTRL])
	prompt.function_text = "保存设置"
	prompt.key_separator = " · "
	prompt.icon_height = 44.0
	prompt.label_variation = &"PartyLabelBody"
	prompt.disabled = true
	prompt.highlighted = true
	prompt.refresh()
	await settle()
	var packed := PackedScene.new()
	check(packed.pack(prompt) == OK, "Configured prompt packs as editable scene")
	var path := "user://input_prompt_test_roundtrip.tscn"
	check(ResourceSaver.save(packed, path) == OK, "Configured prompt saves to temporary scene")
	var restored := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	check(restored != null, "Configured prompt reloads without resource cache")
	if restored != null:
		var copy: Control = restored.instantiate()
		root.add_child(copy)
		await settle()
		for field in ["keycodes", "function_text", "key_separator", "icon_height", "label_variation", "disabled", "highlighted", "action_name", "binding_index"]:
			check(copy.get(field) == prompt.get(field), "Scene round-trip preserves " + field)
		check(copy.get_tokens() == prompt.get_tokens(), "Scene round-trip rebuilds the same resolved glyphs")
		check(copy.get_node("Keys").get_child_count() == prompt.get_node("Keys").get_child_count(), "Scene round-trip never duplicates generated glyphs")
		copy.queue_free()
	prompt.action_name = &"ui_accept"
	prompt.binding_index = 0
	prompt.refresh()
	var action_scene := PackedScene.new()
	check(action_scene.pack(prompt) == OK, "Action-driven prompt packs as scene")
	var action_copy: Control = action_scene.instantiate()
	root.add_child(action_copy)
	await settle()
	check(action_copy.action_name == &"ui_accept" and action_copy.binding_index == 0, "Non-default action name and event index survive serialization")
	check(action_copy.get_tokens() == prompt.get_tokens(), "Serialized action binding reads current InputMap events")
	action_copy.queue_free()
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Temporary scene file is cleaned up")
	prompt.queue_free()
	await settle()

func test_input_passthrough() -> void:
	var prompt := spawn_prompt()
	prompt.configure(KEY_F1, "提示不是按钮")
	prompt.position = Vector2(100, 100)
	var probe := InputProbe.new()
	root.add_child(probe)
	await settle()
	for code in [KEY_TAB, KEY_ENTER, KEY_ESCAPE, KEY_F1, KEY_F10, KEY_F12]:
		var event := key_event(code)
		event.pressed = true
		root.push_input(event, true)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event, true)
		check(probe.keys.has(code), "Prompt never steals unhandled keyboard shortcut " + OS.get_keycode_string(code))
	var click := mouse_event(MOUSE_BUTTON_LEFT)
	click.position = prompt.get_global_rect().get_center()
	click.global_position = click.position
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	check(probe.mouse_buttons.has(MOUSE_BUTTON_LEFT), "Click through visible prompt still reaches unhandled input")
	check(root.gui_get_focus_owner() != prompt, "Informational prompt never takes GUI focus")
	probe.queue_free()
	prompt.queue_free()
	await settle()

func test_main_integration() -> void:
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	var status: Control = ui.get_node("Status")
	var keys: Control = ui.get_node("Status/Keys")
	check(keys is HBoxContainer, "Status shortcuts are an editable horizontal component row")
	var expected := {"Tab":[KEY_TAB, "切换"], "Confirm":[KEY_ENTER, "确认"], "Back":[KEY_ESCAPE, "返回"], "Guide":[KEY_F1, "标尺"]}
	for name in expected:
		check(keys.has_node(NodePath(name)), "Status keeps named prompt " + name)
		if not keys.has_node(NodePath(name)): continue
		var prompt: Control = keys.get_node(NodePath(name))
		check(prompt.scene_file_path == PROMPT_PATH, "Status shortcut uses reusable PackedScene: " + name)
		check(prompt.get_tokens() == Resolver.tokens(expected[name][0]), "Status shortcut maps correct key: " + name)
		check(prompt.get_accessible_text().contains(expected[name][1]), "Status shortcut preserves function meaning: " + name)
		check(prompt.get_global_rect().end.x <= status.get_global_rect().end.x + 0.5, "Status shortcut stays within status width: " + name)
	verify_passive(keys, "Status prompt row")
	for page in ["Home", "Rooms", "Lobby", "Settings"]:
		ui.show_page(page)
		await settle()
		check(status.is_visible_in_tree() and keys.is_visible_in_tree(), "Status prompts remain visible on " + page)
		check(ui.get_node("Status/Engine").text.contains(str(Engine.get_version_info()["string"])), "Actual engine diagnostics preserved on " + page)
		check(ui.get_node("Status/Protocol").text.contains("MOCK"), "Protocol diagnostics retain MOCK qualifier on " + page)
		check(ui.get_node("Status/Scene").text.contains("res://main.tscn") and ui.get_node("Status/Scene").text.contains(page), "Scene diagnostics update on " + page)
		check(keys.get_global_rect().end.y <= ui.get_node("Status/Engine").global_position.y + 0.5, "Prompt row does not overlap engine diagnostics on " + page)
	ui.show_page("Home")
	ui.open_modal("Protocol")
	ui.select_protocol(1)
	await settle()
	check(ui.get_node("Status/Protocol").text.contains(ui.PROTOCOL_NAMES[1]), "Protocol diagnostics continue following selected gameplay mock")
	check(ui.get_node("Status/Scene").text.contains("Protocol"), "Scene diagnostics retain active modal identifier")
	ui.close_modal()
	ui.show_page("Settings")
	var page = ui.get_node("Settings")
	page.get_node("Tabs").current_tab = 3
	await settle()
	check(page.begin_binding_capture("party_demo_move_forward", 0), "Existing key capture still opens with icon prompts")
	await settle()
	var capture: Control = page.get_node("BindingCapture")
	var message: Label = capture.get_node("Panel/Content/Message")
	check(message is Label, "Capture instruction/error message remains a native Label")
	check(not message.text.contains("Esc 取消") and not message.text.contains("Delete / Backspace"), "Capture no longer duplicates shortcut hints as plain text")
	var hint_prompts: Array[Node] = []
	collect_prompts(capture, hint_prompts)
	check(hint_prompts.size() >= 2, "Capture hints use separate reusable prompt children")
	var hint_text := ""
	for prompt in hint_prompts:
		hint_text += prompt.get_accessible_text() + " "
		verify_passive(prompt, "Capture hint")
	check(hint_text.contains("Esc") or hint_text.contains("Escape"), "Capture cancel hint retains readable Escape fallback")
	check(hint_text.contains("Delete") and hint_text.contains("Backspace"), "Capture clear hint displays both supported keys")
	page.cancel_binding_capture()
	check(not page.is_capturing_binding(), "Capture API remains functional after prompt integration")
	ui.queue_free()
	await settle()

func collect_prompts(node: Node, result: Array[Node]) -> void:
	if node.scene_file_path == PROMPT_PATH: result.append(node)
	for child in node.get_children(): collect_prompts(child, result)

func test_demo_integration() -> void:
	var demo = load("res://examples/settings_demo.tscn").instantiate()
	root.add_child(demo)
	await settle()
	var row: Control = demo.get_node("Prompts")
	check(row is HFlowContainer, "Demo uses native wrapping container for real action prompts")
	for name in ["Jump", "Interact", "Back", "Capture"]:
		var prompt: Control = row.get_node(NodePath(name))
		check(prompt.scene_file_path == PROMPT_PATH, "Demo shortcut uses reusable scene: " + name)
		check(prompt.get_global_rect().end.x <= root.size.x and prompt.get_global_rect().end.y <= root.size.y, "Demo shortcut fits design viewport: " + name)
	check(row.get_node("Jump").action_name == &"party_demo_jump" and row.get_node("Interact").action_name == &"party_demo_interact", "Demo glyphs track actual application-owned actions")
	check(row.get_node("Back").get_tokens() == Resolver.tokens(KEY_F10), "Demo return hint keeps F10 binding")
	check(row.get_node("Capture").get_tokens() == Resolver.tokens(KEY_F12), "Demo screenshot hint keeps F12 binding")
	var page = demo.get_node("Settings")
	check(page.set_value("party_demo_jump", [KEY_K | KEY_MASK_CTRL, 0], true), "Demo application callback accepts changed binding")
	await create_timer(0.25).timeout
	check(row.get_node("Jump").get_tokens() == Resolver.tokens(KEY_K | KEY_MASK_CTRL), "Changing demo binding updates prompt through actual InputMap")
	check(demo.callback_count == 1, "Read-only prompt refresh adds no duplicate business callbacks")
	check(page.set_value("party_demo_jump", [0, 0], true), "Demo application callback can unbind action")
	await create_timer(0.25).timeout
	check(row.get_node("Jump").get_tokens() == Resolver.tokens(0), "Unbinding demo action replaces old icon with accessible fallback")
	check(demo.callback_count == 2, "Unbinding applies once while prompt refresh remains silent")
	var modifiers: int = KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_SHIFT
	for mask in [modifiers, modifiers | KEY_MASK_META]:
		check(page.set_value("party_demo_jump", [KEY_SPACE | mask, KEY_J | mask], true), "Demo accepts long primary and secondary jump chords")
		check(page.set_value("party_demo_interact", [KEY_ENTER | mask, KEY_P | mask], true), "Demo accepts long primary and secondary interaction chords")
		await create_timer(0.25).timeout
		await settle()
		for name in ["Jump", "Interact", "Back", "Capture"]:
			var prompt: Control = row.get_node(NodePath(name))
			check(prompt.get_global_rect().end.x <= root.size.x and prompt.get_global_rect().end.y <= root.size.y, "Long rebound demo prompt stays inside viewport: " + name)
		check(demo.get_node("Preview").get_global_rect().end.y <= row.global_position.y - 7.5, "Wrapped hints never cover demo callback feedback")
		check(demo.get_node("Preview").global_position.y >= demo.get_node("Settings/Tabs").get_global_rect().end.y, "Long hint footer and feedback stay below settings content")
	row.size.x = 380.0
	await settle()
	check(row.get_node("Capture").position.y > row.get_node("Jump").position.y, "Narrow native flow wraps prompts rather than overlapping")
	demo.queue_free()
	await settle()
