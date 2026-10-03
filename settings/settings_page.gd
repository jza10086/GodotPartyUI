class_name SettingsPage
extends Control
## Reusable runtime-generated settings. See docs/SETTINGS_API.zh-CN.md.
signal setting_changed(id: String, value: Variant)
signal back_requested
var last_error := ""
var _schema: Array = []
var _entries: Dictionary = {}
var _tabs: Dictionary = {}
var _option_lists: Array = []
var _generation := 0

func _ready() -> void:
	$Back.pressed.connect(func(): back_requested.emit())

func configure(tabs: Array) -> bool:
	last_error = ""
	var ids: Dictionary = {}
	var tab_ids: Dictionary = {}
	for tab in tabs:
		if not tab is Dictionary or not _valid_id(tab.get("id", "")) or tab_ids.has(tab.id):
			return _fail("Invalid or duplicate tab id")
		tab_ids[tab.id] = true
		if not tab.get("options", []) is Array: return _fail("Tab options must be an Array")
		if not _validate_options(tab.get("options", []), ids): return false
	for spec in ids.values():
		var condition: Variant = spec.get("visible_when", {})
		if not condition is Dictionary or (not condition.is_empty() and (not ids.has(condition.get("id", "")) or not condition.has("equals"))):
			return _fail("Invalid visible_when reference")
	clear()
	_schema = tabs.duplicate(true)
	for tab in _schema:
		_build_tab(tab)
	_refresh_visibility()
	return true

func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b) and not ((a is int or a is float) and (b is int or b is float)): return false
	return a == b

func _valid_toggle(value: Variant) -> bool:
	return value is bool or ((value is int or value is float) and (value == 0 or value == 1))

func _valid_id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

func _fail(message: String) -> bool:
	last_error = message
	return false

func _validate_options(options: Array, ids: Dictionary) -> bool:
	for spec in options:
		if not spec is Dictionary or not _valid_id(spec.get("id", "")) or ids.has(spec.id):
			return _fail("Invalid or duplicate option id")
		if not spec.get("type", "") is String: return _fail("Option type must be a String")
		var type: String = spec.get("type", "")
		if type not in ["label", "select", "toggle", "number", "slider", "note", "divider", "action", "group"]:
			return _fail("Unknown option type")
		if spec.has("callback") and not spec.callback is Callable:
			return _fail("callback must be a Callable")
		if type in ["number", "slider"]:
			for key in ["min", "max", "step", "value"]:
				if spec.has(key) and (not (spec[key] is float or spec[key] is int) or not is_finite(float(spec[key]))):
					return _fail("Numeric settings require finite numbers")
			if float(spec.get("min", 0)) > float(spec.get("max", 100)) or float(spec.get("step", 1)) <= 0:
				return _fail("Invalid numeric range or step")
		if type == "toggle" and spec.has("value") and not _valid_toggle(spec.value):
			return _fail("Toggle initial value must be bool or 0/1")
		if type == "select":
			var items: Variant = spec.get("items", [])
			if not items is Array or items.is_empty():
				return _fail("select requires nonempty items")
			var seen: Array = []
			for item in items:
				if not item is Dictionary or not item.has("label") or not item.has("value") or item.value in seen:
					return _fail("Invalid or duplicate select item value")
				seen.append(item.value)
			if spec.has("value") and spec.value not in seen:
				return _fail("Initial select value is not in items")
		ids[spec.id] = spec
		if type == "group":
			if spec.has("expanded") and not spec.expanded is bool: return _fail("Group expanded must be bool")
			if not spec.get("children", []) is Array: return _fail("Group children must be an Array")
			if not _validate_options(spec.get("children", []), ids): return false
	return true

func clear() -> void:
	_generation += 1
	_entries.clear()
	_tabs.clear()
	_option_lists.clear()
	_schema.clear()
	for child in $Tabs.get_children():
		$Tabs.remove_child(child)
		child.queue_free()

func add_tab(id: String, title: String) -> bool:
	var next := _schema.duplicate(true)
	_capture_values(next)
	next.append({"id": id, "title": title, "options": []})
	return configure(next)

func add_option(tab_id: String, spec: Dictionary, parent_group: String = "") -> bool:
	var next := _schema.duplicate(true)
	_capture_values(next)
	for tab in next:
		if tab.id == tab_id:
			if not tab.has("options"): tab.options = []
			if parent_group.is_empty():
				tab.options.append(spec)
			elif not _append_group(tab.options, parent_group, spec):
				return _fail("Unknown parent group in tab")
			return configure(next)
	return _fail("Unknown tab id")

func _append_group(options: Array, group_id: String, spec: Dictionary) -> bool:
	for option in options:
		if option.type == "group":
			if option.id == group_id:
				if not option.has("children"): option.children = []
				option.children.append(spec)
				return true
			if _append_group(option.get("children", []), group_id, spec): return true
	return false

func _capture_values(tabs: Array) -> void:
	for tab in tabs: _capture_options(tab.get("options", []))

func _capture_options(options: Array) -> void:
	for spec in options:
		if _entries.has(spec.id):
			if spec.type == "group": spec.expanded = _entries[spec.id].control.button_pressed
			elif _entries[spec.id].has("value"): spec.value = _entries[spec.id].value
		if spec.type == "group": _capture_options(spec.get("children", []))

func get_value(id: String) -> Variant:
	return _entries.get(id, {}).get("value", null)

func get_values() -> Dictionary:
	var values: Dictionary = {}
	for id in _entries:
		if _entries[id].has("value"): values[id] = _entries[id].value
	return values.duplicate(true)

func get_control(id: String) -> Control:
	return _entries.get(id, {}).get("control", null)

func get_number_control(id: String) -> SpinBox:
	return _entries.get(id, {}).get("number", null)

func set_value(id: String, value: Variant, notify: bool = false) -> bool:
	if not _entries.has(id): return _fail("Unknown option id")
	var entry: Dictionary = _entries[id]
	var spec: Dictionary = entry.spec
	match spec.type:
		"number", "slider":
			if not (value is int or value is float) or not is_finite(float(value)): return _fail("Value must be finite numeric")
			value = clampf(snappedf(float(value), float(spec.get("step", 1))), float(spec.get("min", 0)), float(spec.get("max", 100)))
		"toggle":
			if not _valid_toggle(value): return _fail("Toggle requires bool or 0/1")
			value = bool(value)
		"select":
			var found := false
			for item in spec.items:
				if _same(item.value, value): found = true
			if not found: return _fail("Value is not in select items")
		"label": value = str(value)
		_: return _fail("This option has no settable value")
	var changed: bool = not _same(entry.get("value"), value)
	entry.value = value
	_sync(entry)
	_refresh_visibility()
	if notify and changed:
		var callback: Callable = spec.get("callback", Callable())
		# Emit after model and widgets agree; callbacks may rebuild/free this page.
		var generation := _generation
		if callback.is_valid(): callback.call(value, id)
		if is_instance_valid(self) and not is_queued_for_deletion() and generation == _generation: setting_changed.emit(id, value)
	return true

func _sync(entry: Dictionary) -> void:
	var control: Control = entry.control
	match entry.spec.type:
		"label": control.text = str(entry.value)
		"toggle":
			control.set_pressed_no_signal(entry.value)
			control.sync_visual(entry.get("visual_initialized", false))
			entry.visual_initialized = true
		"number", "slider":
			control.set_value_no_signal(entry.value)
			entry.number.set_value_no_signal(entry.value)
		"select":
			for index in range(entry.spec.items.size()):
				if _same(entry.spec.items[index].value, entry.value): control.select(index)

func _changed(value: Variant, id: String, generation: int) -> void:
	if generation == _generation: set_value(id, value, true)

func _selected(index: int, id: String, generation: int) -> void:
	if generation == _generation: set_value(id, _entries[id].spec.items[index].value, true)

func _action(id: String, generation: int) -> void:
	if generation != _generation: return
	var callback: Callable = _entries[id].spec.get("callback", Callable())
	if callback.is_valid(): callback.call(id)

func _expanded(_value: bool, generation: int) -> void:
	if generation == _generation: _refresh_visibility()

func _build_tab(tab: Dictionary) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab.id
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	$Tabs.add_child(scroll)
	$Tabs.set_tab_title(scroll.get_index(), str(tab.get("title", tab.id)))
	var padding := MarginContainer.new()
	padding.name = "Padding"
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: padding.add_theme_constant_override("margin_" + side, 48 if side in ["left", "right"] else 28)
	scroll.add_child(padding)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 16)
	padding.add_child(content)
	_tabs[tab.id] = content
	_build_options(content, tab.get("options", []))

func _divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.color = Color(0.65, 0.65, 0.62)
	divider.custom_minimum_size.y = 1
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider

func _build_options(parent: VBoxContainer, options: Array) -> void:
	var items: Array = []
	for spec in options:
		var divider: ColorRect
		if spec.type not in ["note", "divider"] and not items.is_empty():
			divider = _divider()
			divider.name = "AutoDivider_" + str(spec.id).validate_node_name()
			divider.set_meta("automatic_row_divider", true)
			divider.visible = false
			parent.add_child(divider)
		_build_option(parent, spec)
		items.append({"id": spec.id, "divider": divider})
	_option_lists.append(items)

func _label(text_value: String, font_size: int = 26) -> Label:
	var label := Label.new()
	label.text = text_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _field(control: Control, width: float = 0) -> void:
	control.custom_minimum_size = Vector2(width, 64)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width == 0 else Control.SIZE_FILL
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.add_theme_font_size_override("font_size", 26)

func _build_option(parent: VBoxContainer, source: Dictionary) -> void:
	var spec := source.duplicate(true)
	var id: String = spec.id
	var type: String = spec.type
	var entry := {"spec": spec}
	_entries[id] = entry
	var control: Control
	var root_node: Control
	if type == "divider":
		control = _divider()
	elif type == "note":
		control = _label(str(spec.get("text", "")), int(spec.get("font_size", 23)))
		control.custom_minimum_size.y = spec.get("height", 90)
		(control as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif type in ["action", "group"]:
		var button := Button.new()
		button.text = str(spec.get("label", id))
		_field(button)
		control = button
		if type == "action": button.pressed.connect(_action.bind(id, _generation))
		else:
			button.toggle_mode = true
			button.flat = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_constant_override("h_separation", 14)
			button.set_pressed_no_signal(spec.get("expanded", false))
			button.toggled.connect(_expanded.bind(_generation))
	else:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = spec.get("row_height", 96)
		row.add_theme_constant_override("separation", 24)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		root_node = row
		var label := _label(str(spec.get("label", id)))
		label.name = spec.get("label_name", "Label")
		_field(label, spec.get("label_width", 378))
		row.add_child(label)
		match type:
			"label": control = _label(str(spec.get("value", "")))
			"select":
				var select := OptionButton.new()
				for item in spec.items:
					select.add_item(str(item.label))
					select.set_item_metadata(select.item_count - 1, item.value)
				select.item_selected.connect(_selected.bind(id, _generation))
				control = select
			"toggle":
				var toggle := preload("res://settings/segmented_toggle.gd").new()
				toggle.off_text = str(spec.get("off_text", "关"))
				toggle.on_text = str(spec.get("on_text", "开"))
				toggle.toggle_mode = true
				toggle.toggled.connect(_changed.bind(id, _generation))
				control = toggle
			"number", "slider":
				var spin := SpinBox.new()
				spin.min_value = spec.get("min", 0)
				spin.max_value = spec.get("max", 100)
				spin.step = spec.get("step", 1)
				spin.suffix = spec.get("suffix", "")
				spin.select_all_on_focus = true
				spin.get_line_edit().focus_exited.connect(spin.apply)
				spin.value_changed.connect(_changed.bind(id, _generation))
				entry.number = spin
				control = spin
				if type == "slider":
					var slider := HSlider.new()
					slider.min_value = spin.min_value
					slider.max_value = spin.max_value
					slider.step = spin.step
					slider.scrollable = false
					slider.value_changed.connect(_changed.bind(id, _generation))
					control = slider
		_field(control)
		control.name = spec.get("control_name", "Value")
		row.add_child(control)
		if type == "slider":
			_field(entry.number, 226)
			entry.number.name = spec.get("number_name", "Number")
			row.add_child(entry.number)
	entry.control = control
	if root_node == null: root_node = control
	root_node.name = spec.get("node_name", id.validate_node_name())
	entry.root = root_node
	parent.add_child(root_node)
	if type == "group":
		var margin := MarginContainer.new()
		margin.name = spec.get("details_name", id.validate_node_name() + "Details")
		margin.add_theme_constant_override("margin_left", 40)
		parent.add_child(margin)
		entry.details = margin
		var children := VBoxContainer.new()
		children.name = "Rows"
		children.add_theme_constant_override("separation", 12)
		margin.add_child(children)
		_build_options(children, spec.get("children", []))
	elif type in ["label", "number", "slider", "toggle", "select"]:
		var default: Variant = "" if type == "label" else (false if type == "toggle" else 0)
		if type == "select": default = spec.items[0].value
		set_value(id, spec.get("value", default))

func _refresh_visibility() -> void:
	for entry in _entries.values():
		if not entry.has("root"): continue
		var condition: Dictionary = entry.spec.get("visible_when", {})
		var showing: bool = condition.is_empty() or _same(get_value(str(condition.get("id", ""))), condition.get("equals"))
		entry.root.visible = showing
		if entry.spec.type == "group" and entry.has("details"):
			entry.details.visible = showing and entry.control.button_pressed
			entry.control.icon = preload("res://assets/chevron_down.svg") if entry.control.button_pressed else preload("res://assets/chevron_right.svg")

	# Only separate neighboring visible rows. Notes and explicit dividers are
	# intentional section boundaries; neither receives an extra automatic line.
	for items in _option_lists:
		var previous_row := false
		for item in items:
			var entry: Dictionary = _entries[item.id]
			var showing: bool = entry.root.visible
			var is_row: bool = entry.spec.type not in ["note", "divider"]
			if item.divider != null:
				item.divider.visible = showing and is_row and previous_row
			if showing: previous_row = is_row

func _input(event: InputEvent) -> void:
	route_scroll_input(event)

func route_scroll_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or $Tabs.get_tab_count() == 0: return
	if not event is InputEventMouseButton or not event.pressed or event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return
	for entry in _entries.values():
		if entry.control is OptionButton and entry.control.get_popup().visible: return
	var scroll: ScrollContainer = $Tabs.get_current_tab_control()
	if scroll.get_global_rect().has_point(event.position):
		var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
		scroll.scroll_vertical += int(direction * 64 * maxf(event.factor, 1))
		get_viewport().set_input_as_handled()
