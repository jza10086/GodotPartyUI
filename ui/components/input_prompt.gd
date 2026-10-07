@tool
extends HBoxContainer
## Icon(s) + function text, editable in scenes and read-only with respect to input.
## Explicit refresh() is immediate; InputMap changes are detected within 0.2s.
const Resolver = preload("res://ui/input_prompt_resolver.gd")
const GLYPH = preload("res://ui/components/input_glyph.tscn")
@export var keycodes := PackedInt64Array([KEY_TAB]):
	set(value):
		keycodes = value
		_binding = null
		_has_binding = false
		_queue_refresh()
@export var key_separator := "+":
	set(value):
		key_separator = value
		_queue_refresh()
@export var action_name: StringName = &"":
	set(value):
		action_name = value
		_queue_refresh()
## Optional grouped actions (for example four movement directions). Each resolves
## live from InputMap; binding_index selects one binding per action.
@export var action_names := PackedStringArray():
	set(value):
		action_names = value
		_queue_refresh()
@export_range(-1, 32, 1) var binding_index := -1:
	set(value):
		binding_index = value
		_queue_refresh()
@export var function_text := "切换":
	set(value):
		function_text = value
		_queue_refresh()
@export_range(16, 128, 1) var icon_height := 36.0:
	set(value):
		icon_height = value
		_queue_refresh()
@export var label_variation: StringName = &"PartyLabelMeta":
	set(value):
		label_variation = value
		_queue_refresh()
@export var disabled := false:
	set(value):
		disabled = value
		_update_visuals()
@export var highlighted := false:
	set(value):
		highlighted = value
		_update_visuals()
var _binding: Variant = null
var _has_binding := false
var _updating_visuals := false
var _tokens: Array[Dictionary] = []
var _elapsed := 0.0
var _queued := false
var _built := false

func _ready() -> void:
	$Function.theme_changed.connect(_on_function_theme_changed)
	refresh()

func _queue_refresh() -> void:
	if not is_node_ready() or _queued: return
	_queued = true
	refresh.call_deferred()

func configure(binding: Variant, description: String) -> void:
	function_text = description
	set_binding(binding)

func set_binding(binding: Variant) -> void:
	action_name = &""
	action_names = PackedStringArray()
	_binding = binding.duplicate() if binding is Array else binding
	_has_binding = true
	refresh()

func _resolve() -> Array[Dictionary]:
	if not action_names.is_empty():
		var grouped: Array[Dictionary] = []
		for action in action_names:
			if not grouped.is_empty(): grouped.append(Resolver.separator(key_separator))
			if not InputMap.has_action(action):
				grouped.append_array(Resolver.key_tokens(0))
				continue
			var events := InputMap.action_get_events(action)
			if binding_index >= 0:
				grouped.append_array(Resolver.event_tokens(events[binding_index]) if binding_index < events.size() else Resolver.key_tokens(0))
			else: grouped.append_array(Resolver.tokens(events))
		return grouped
	if not action_name.is_empty():
		if not InputMap.has_action(action_name): return Resolver.key_tokens(0)
		var events := InputMap.action_get_events(action_name)
		if binding_index >= 0:
			return Resolver.event_tokens(events[binding_index]) if binding_index < events.size() else Resolver.key_tokens(0)
		return Resolver.tokens(events)
	if _has_binding: return Resolver.tokens(_binding)
	var resolved: Array[Dictionary] = []
	for code in keycodes:
		if not resolved.is_empty(): resolved.append(Resolver.separator(key_separator))
		resolved.append_array(Resolver.key_tokens(code))
	return resolved if not resolved.is_empty() else Resolver.key_tokens(0)

func get_tokens() -> Array[Dictionary]:
	return _tokens.duplicate(true)

func get_accessible_text() -> String:
	var labels: PackedStringArray = []
	for token in _tokens: labels.append(token.label)
	return " ".join(labels) + (" · " + function_text if not function_text.is_empty() else "")

func refresh() -> void:
	_queued = false
	if not is_node_ready(): return
	var next := _resolve()
	if not _built or next != _tokens:
		for child in $Keys.get_children():
			$Keys.remove_child(child)
			child.queue_free()
		_tokens = next
		for token in _tokens:
			if token.get("separator", false):
				var label := Label.new()
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				label.text = token.label
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				$Keys.add_child(label)
			else:
				var glyph := GLYPH.instantiate()
				$Keys.add_child(glyph)
				var texture := Resolver.texture_for(token)
				glyph.set_meta("monochrome", token.get("monochrome", true))
				glyph.get_node("Icon").texture = texture
				glyph.get_node("Icon").visible = texture != null
				glyph.get_node("Fallback").visible = texture == null
				glyph.get_node("Fallback").text = "[" + str(token.label) + "]"
		_built = true
	$Function.text = function_text
	$Function.visible = not function_text.is_empty()
	tooltip_text = get_accessible_text()
	accessibility_name = tooltip_text
	_update_visuals()
	set_process(not Engine.is_editor_hint() and (not action_name.is_empty() or not action_names.is_empty()))

func _on_function_theme_changed() -> void:
	# Local Label overrides do not notify ancestor Controls. Keep the icon's
	# monochrome tint synchronized without waiting for a binding/state change.
	_update_visuals()

func _update_visuals() -> void:
	if not is_node_ready() or _updating_visuals: return
	_updating_visuals = true
	$Function.theme_type_variation = label_variation
	# Normal text inherits the shared Theme and any local override. State color is
	# a Label-only override; icons retain their original alpha and asset colors.
	for label in _labels():
		label.theme_type_variation = label_variation
		if disabled or highlighted:
			if not label.has_meta("prompt_state_color"):
				label.set_meta("prompt_state_color", {"present":label.has_theme_color_override("font_color"), "color":label.get_theme_color("font_color")})
			label.add_theme_color_override("font_color", get_theme_color("font_disabled_color" if disabled else "font_hover_color", "Label"))
		elif label.has_meta("prompt_state_color"):
			var previous: Dictionary = label.get_meta("prompt_state_color")
			if previous.present: label.add_theme_color_override("font_color", previous.color)
			else: label.remove_theme_color_override("font_color")
			label.remove_meta("prompt_state_color")
	var ink: Color = $Function.get_theme_color("font_color")
	for child in $Keys.get_children():
		if child is Label: continue
		var icon: TextureRect = child.get_node("Icon")
		if icon.texture != null:
			icon.custom_minimum_size = Vector2(icon_height * icon.texture.get_width() / maxf(1.0, icon.texture.get_height()), icon_height)
			icon.self_modulate = ink if child.get_meta("monochrome", true) else Color(1, 1, 1, 0.55 if disabled else 1.0)

	_updating_visuals = false

func _labels() -> Array[Label]:
	var labels: Array[Label] = [$Function]
	for child in $Keys.get_children():
		labels.append(child if child is Label else child.get_node("Fallback"))
	return labels

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.2:
		_elapsed = 0.0
		refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready(): _queue_refresh()
