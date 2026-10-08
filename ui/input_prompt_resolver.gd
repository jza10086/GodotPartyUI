@tool
extends RefCounted
## Read-only input presentation. Never edits bindings or InputMap.
## Asset IDs and original alpha bounds are kept separate from key labels/localization.
const ROOT := "res://assets/input_prompts/"
const MANIFEST: Dictionary = preload("res://assets/input_prompts/manifest.json").data
const KEY_ASSETS := {
	KEY_ESCAPE:"escape", KEY_TAB:"tab", KEY_ENTER:"enter", KEY_KP_ENTER:"numpad_enter",
	KEY_BACKSPACE:"backspace", KEY_INSERT:"insert", KEY_DELETE:"delete", KEY_PAUSE:"pause",
	KEY_PRINT:"printscreen", KEY_HOME:"home", KEY_END:"end", KEY_LEFT:"arrow_left",
	KEY_UP:"arrow_up", KEY_RIGHT:"arrow_right", KEY_DOWN:"arrow_down",
	KEY_PAGEUP:"page_up", KEY_PAGEDOWN:"page_down", KEY_SHIFT:"shift", KEY_CTRL:"ctrl",
	KEY_META:"command", KEY_ALT:"alt", KEY_CAPSLOCK:"capslock", KEY_NUMLOCK:"numlock",
	KEY_SCROLLLOCK:"scroll_lock", KEY_SPACE:"space", KEY_EXCLAM:"exclamation",
	KEY_QUOTEDBL:"quote", KEY_APOSTROPHE:"apostrophe", KEY_ASTERISK:"asterisk",
	KEY_PLUS:"plus", KEY_COMMA:"comma", KEY_MINUS:"minus", KEY_PERIOD:"period",
	KEY_SLASH:"slash_forward", KEY_COLON:"colon", KEY_SEMICOLON:"semicolon",
	KEY_LESS:"bracket_less", KEY_EQUAL:"equals", KEY_GREATER:"bracket_greater",
	KEY_QUESTION:"question", KEY_BRACKETLEFT:"bracket_open", KEY_BACKSLASH:"slash_back",
	KEY_BRACKETRIGHT:"bracket_close", KEY_ASCIICIRCUM:"caret", KEY_UNDERSCORE:"underscore",
	KEY_ASCIITILDE:"tilde", KEY_KP_ADD:"numpad_plus"
}
const ALIASES := {
	"esc":KEY_ESCAPE, "escape":KEY_ESCAPE, "return":KEY_ENTER, "enter":KEY_ENTER,
	"spacebar":KEY_SPACE, "space":KEY_SPACE, "control":KEY_CTRL, "ctrl":KEY_CTRL,
	"alt":KEY_ALT, "option":KEY_ALT, "shift":KEY_SHIFT, "meta":KEY_META,
	"cmd":KEY_META, "command":KEY_META, "super":KEY_META, "win":KEY_META,
	"pgup":KEY_PAGEUP, "pageup":KEY_PAGEUP, "page up":KEY_PAGEUP,
	"pgdn":KEY_PAGEDOWN, "pagedown":KEY_PAGEDOWN, "page down":KEY_PAGEDOWN,
	"del":KEY_DELETE, "delete":KEY_DELETE, "ins":KEY_INSERT,
	"left arrow":KEY_LEFT, "right arrow":KEY_RIGHT, "up arrow":KEY_UP, "down arrow":KEY_DOWN
}
static var _textures: Dictionary = {}
static var _registered: Dictionary = {}

static func register_icon(id: String, texture: Texture2D) -> void:
	# Extension icons preserve their authored color; use e.g. joypad_button:0.
	if texture == null: _registered.erase(id)
	else: _registered[id] = texture

static func clear_registered_icons() -> void:
	_registered.clear()

static func glyph(asset: String, label: String) -> Dictionary:
	if _registered.has(asset): return {"asset":asset, "label":label, "texture":_registered[asset], "monochrome":false}
	return {"asset":asset if MANIFEST.has(asset) else "", "label":label, "monochrome":true}

static func texture_for(token: Dictionary) -> Texture2D:
	if token.has("texture"): return token.texture
	var id: String = token.get("asset", "")
	if not MANIFEST.has(id): return null
	if not _textures.has(id):
		var entry: Dictionary = MANIFEST[id]
		var source: Texture2D = load(ROOT + entry.file)
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		var r: Array = entry.region
		var scale_factor := source.get_width() / 64.0
		atlas.region = Rect2(Vector2(float(r[0]), float(r[1])) * scale_factor, Vector2(float(r[2]), float(r[3])) * scale_factor)
		atlas.filter_clip = true
		_textures[id] = atlas
	return _textures[id]

static func _key(code: int) -> Dictionary:
	var label := OS.get_keycode_string(code)
	if label.is_empty(): label = "Key %d" % code
	var asset := ""
	if code >= KEY_A and code <= KEY_Z: asset = "keyboard_" + String.chr(code).to_lower()
	elif code >= KEY_0 and code <= KEY_9: asset = "keyboard_" + String.chr(code)
	elif code >= KEY_F1 and code <= KEY_F12: asset = "keyboard_f%d" % (code - KEY_F1 + 1)
	elif KEY_ASSETS.has(code): asset = "keyboard_" + str(KEY_ASSETS[code])
	if code == KEY_META:
		asset = "keyboard_command" if OS.get_name() == "macOS" else ("keyboard_win" if OS.get_name() == "Windows" else "")
	# Keypad digits/operators have distinct semantics. Do not show a wrong main-key icon.
	return glyph(asset, label)

static func separator(label: String) -> Dictionary:
	return {"separator":true, "label":label, "asset":""}

static func key_tokens(code: int) -> Array[Dictionary]:
	if code == 0: return [glyph("", "未绑定")]
	if code < 0 or code & ~(KEY_CODE_MASK | KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_SHIFT | KEY_MASK_META):
		return [glyph("", "Key %d" % code)]
	var result: Array[Dictionary] = []
	var base: int = code & KEY_CODE_MASK
	if base == KEY_BACKTAB:
		base = KEY_TAB
		code |= KEY_MASK_SHIFT
	for pair in [[KEY_MASK_CTRL, KEY_CTRL], [KEY_MASK_ALT, KEY_ALT], [KEY_MASK_SHIFT, KEY_SHIFT], [KEY_MASK_META, KEY_META]]:
		if code & int(pair[0]) and base != int(pair[1]):
			if not result.is_empty(): result.append(separator("+"))
			result.append(_key(int(pair[1])))
	if not result.is_empty(): result.append(separator("+"))
	result.append(_key(base))
	return result

static func _mouse_label(button: int) -> String:
	return {MOUSE_BUTTON_LEFT:"鼠标左键", MOUSE_BUTTON_RIGHT:"鼠标右键", MOUSE_BUTTON_MIDDLE:"鼠标中键", MOUSE_BUTTON_WHEEL_UP:"滚轮向上", MOUSE_BUTTON_WHEEL_DOWN:"滚轮向下", MOUSE_BUTTON_WHEEL_LEFT:"滚轮向左", MOUSE_BUTTON_WHEEL_RIGHT:"滚轮向右", MOUSE_BUTTON_XBUTTON1:"鼠标后退", MOUSE_BUTTON_XBUTTON2:"鼠标前进"}.get(button, "Mouse %d" % button)

static func event_tokens(event: InputEvent) -> Array[Dictionary]:
	if event is InputEventKey:
		var code: int = event.keycode
		if code == 0 and event.physical_keycode != 0:
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
			if code == 0: code = event.physical_keycode
		if code == 0: code = event.key_label if event.key_label != 0 else event.unicode
		return key_tokens(code | event.get_modifiers_mask())
	if event is InputEventMouseButton:
		var suffix: String = {MOUSE_BUTTON_LEFT:"left", MOUSE_BUTTON_RIGHT:"right", MOUSE_BUTTON_MIDDLE:"scroll", MOUSE_BUTTON_WHEEL_UP:"scroll_up", MOUSE_BUTTON_WHEEL_DOWN:"scroll_down", MOUSE_BUTTON_XBUTTON1:"side_back", MOUSE_BUTTON_XBUTTON2:"side_forward"}.get(event.button_index, "")
		var result: Array[Dictionary] = []
		for pair in [[KEY_MASK_CTRL, KEY_CTRL], [KEY_MASK_ALT, KEY_ALT], [KEY_MASK_SHIFT, KEY_SHIFT], [KEY_MASK_META, KEY_META]]:
			if event.get_modifiers_mask() & int(pair[0]):
				result.append(_key(int(pair[1])))
				result.append(separator("+"))
		result.append(glyph("mouse_" + suffix, _mouse_label(event.button_index)))
		return result
	if event is InputEventJoypadButton:
		return [glyph("joypad_button:%d" % event.button_index, "手柄按钮 %d" % (event.button_index + 1))]
	if event is InputEventJoypadMotion:
		return [glyph("joypad_axis:%d:%s" % [event.axis, "+" if event.axis_value >= 0 else "-"], "手柄轴 %d %s" % [event.axis + 1, "+" if event.axis_value >= 0 else "−"])]
	var fallback := "" if event == null else event.as_text()
	return [glyph("", "未知输入" if fallback.is_empty() else fallback)]

static func _text_tokens(text: String) -> Array[Dictionary]:
	var cleaned := text.strip_edges()
	if cleaned.is_empty(): return key_tokens(0)
	var lower := cleaned.to_lower()
	if lower in ["lmb", "mouse left", "rmb", "mouse right", "mmb", "mouse middle"]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if lower in ["lmb", "mouse left"] else (MOUSE_BUTTON_RIGHT if lower in ["rmb", "mouse right"] else MOUSE_BUTTON_MIDDLE)
		return event_tokens(event)
	# Literal '+' is a key, not an empty two-part chord.
	if cleaned == "+": return key_tokens(KEY_PLUS)
	if cleaned.contains("+"):
		var result: Array[Dictionary] = []
		var parts := cleaned.split("+", false)
		if cleaned.ends_with("+"): parts.append("+")
		for part in parts:
			if not result.is_empty(): result.append(separator("+"))
			result.append_array(_text_tokens(part))
		return result
	var code: int = ALIASES.get(lower, OS.find_keycode_from_string(cleaned))
	# Labels vary across platforms; printable Latin input still maps deterministically.
	if code == 0 and cleaned.length() == 1: code = cleaned.to_upper().unicode_at(0)
	if code != 0: return key_tokens(code)
	return [glyph("", cleaned)]

static func tokens(binding: Variant) -> Array[Dictionary]:
	if binding is int: return key_tokens(binding)
	if binding is String or binding is StringName: return _text_tokens(str(binding))
	if binding is InputEvent: return event_tokens(binding)
	if binding is Array or binding is PackedInt64Array or binding is PackedInt32Array:
		var result: Array[Dictionary] = []
		for item in binding:
			# Settings use zero for an empty primary/secondary slot.
			if item is int and item == 0: continue
			if not result.is_empty(): result.append(separator("/"))
			result.append_array(tokens(item))
		return result if not result.is_empty() else key_tokens(0)
	return [glyph("", "未知输入")]
