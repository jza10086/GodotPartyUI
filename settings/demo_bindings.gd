extends RefCounted
## Application-owned example: the reusable SettingsPage never changes InputMap.
const ACTION_PREFIX := "party_demo_"

static func make_tab(callback: Callable) -> Dictionary:
	return {"id": "Bindings", "title": "按键绑定", "options": [
		{"id": "bindings.header", "type": "bindings_header"},
		{"id": "bindings.help", "type": "note", "text": "点击主按键或次要按键进行录入；支持组合键，取消和清空快捷键见录入面板。"},
		{"id": "bindings.movement", "type": "group", "label": "移动", "expanded": true, "children": [
			binding("move_forward", "向前移动", [KEY_W, KEY_UP], callback),
			binding("move_back", "向后移动", [KEY_S, KEY_DOWN], callback),
			binding("move_left", "向左移动", [KEY_A, KEY_LEFT], callback),
			binding("move_right", "向右移动", [KEY_D, KEY_RIGHT], callback),
			binding("jump", "跳跃", [KEY_SPACE, 0], callback, [
				binding("air_dash", "空中冲刺", [KEY_Q, 0], callback),
				{"id": "bindings.jump.note", "type": "note", "text": "展开功能行可配置相关子操作；折叠不会删除绑定。"}
			]),
			binding("sprint", "冲刺", [KEY_R, 0], callback),
			binding("crouch", "蹲下", [KEY_C, 0], callback)
		]},
		{"id": "bindings.interaction", "type": "group", "label": "交互与道具", "expanded": true, "children": [
			binding("interact", "交互", [KEY_E, 0], callback),
			binding("use_item", "使用道具", [KEY_F, 0], callback),
			binding("previous_item", "上一个道具", [KEY_BRACKETLEFT, 0], callback),
			binding("next_item", "下一个道具", [KEY_BRACKETRIGHT, 0], callback),
			binding("map", "地图", [KEY_M, 0], callback),
			binding("scoreboard", "计分板", [KEY_G, 0], callback),
			binding("ping", "标记位置", [KEY_V, 0], callback)
		]},
		{"id": "bindings.footer", "type": "note", "text": "真实更新当前会话的 party_demo_* InputMap 动作；不修改 ui_*，不写入磁盘。独立示例可预览动作触发与实时按键图标。"}
	]}

static func binding(action: String, label_text: String, keys: Array, callback: Callable, children: Array = []) -> Dictionary:
	var spec := {"id": ACTION_PREFIX + action, "type": "keybinding", "label": label_text, "value": keys, "callback": callback, "conflict_scope": "global"}
	if not children.is_empty():
		spec.children = children
		spec.expanded = false
	return spec

static func apply_value(value: Variant, id: String) -> void:
	# Restrict this example to its own actions, even if called with another setting.
	if not id.begins_with(ACTION_PREFIX) or not value is Array:
		return
	if not InputMap.has_action(id):
		InputMap.add_action(id)
	InputMap.action_erase_events(id)
	for packed_key in value:
		var key := int(packed_key)
		if key == 0:
			continue
		var event := InputEventKey.new()
		event.keycode = key & KEY_CODE_MASK
		event.shift_pressed = bool(key & KEY_MASK_SHIFT)
		event.ctrl_pressed = bool(key & KEY_MASK_CTRL)
		event.alt_pressed = bool(key & KEY_MASK_ALT)
		event.meta_pressed = bool(key & KEY_MASK_META)
		InputMap.action_add_event(id, event)

static func apply_defaults(page: Node) -> void:
	# configure() is silent: initialization applies values deliberately, outside callbacks.
	for id in page.get_values():
		if str(id).begins_with(ACTION_PREFIX):
			apply_value(page.get_value(id), id)

static func action_for_event(event: InputEvent) -> String:
	for action in InputMap.get_actions():
		if str(action).begins_with(ACTION_PREFIX) and event.is_action_pressed(action, false, true):
			return str(action)
	return ""
