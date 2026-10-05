extends SceneTree
## 中文 Inspector 代理回归：不改写正式资源；测试文件保存在 user:// 并清理。
## Run: godot --headless --path . --script res://tests/test_config_inspector.gd

const CONFIG = preload("res://ui/theme/ui_config.gd")
const FIELDS := {
	"font": "界面字体",
	"micro_size": "微型提示字号",
	"debug_size": "调试信息字号",
	"meta_size": "标记信息字号",
	"detail_size": "详细信息字号",
	"note_size": "提示与错误字号",
	"secondary_size": "次要说明字号",
	"body_size": "正文字号",
	"player_size": "玩家与表单字号",
	"setting_size": "设置项字号",
	"action_size": "操作与页签字号",
	"section_size": "分区标题字号",
	"subheading_size": "创建房间标题字号",
	"compact_title_size": "紧凑弹窗标题字号",
	"dialog_title_size": "标准弹窗标题字号",
	"display_size": "展示与大厅标题字号",
	"page_title_size": "列表页面标题字号",
	"brand_size": "品牌标题字号",
	"text": "普通文字颜色",
	"text_hover": "悬停文字颜色",
	"text_disabled": "禁用文字颜色",
	"text_on_primary": "深色底文字颜色",
	"error": "错误提示颜色",
	"success": "示例启用反馈颜色",
	"demo_inactive": "示例关闭反馈颜色",
	"info": "示例按键反馈颜色",
	"surface": "普通表面颜色",
	"muted_surface": "弱化表面颜色",
	"primary": "主色背景颜色",
	"hover_surface": "悬停表面颜色",
	"border": "普通边框颜色",
	"hover_border": "悬停边框颜色",
	"focus": "焦点强调颜色",
	"divider": "分隔与层级线颜色",
	"selection": "文本选区颜色",
	"toggle_border": "左右开关边框颜色",
	"toggle_active_text": "左右开关选中文字颜色",
	"page_background": "设置页面背景颜色",
	"menu_backdrop": "主菜单底板颜色",
	"rooms_backdrop": "房间列表底板颜色",
	"lobby_backdrop": "大厅底板颜色",
	"status_backdrop": "状态信息底板颜色",
	"modal_overlay": "普通弹窗遮罩颜色",
	"capture_overlay": "按键录入遮罩颜色",
	"ruler": "布局标尺颜色",
	"display_background": "展示区天空颜色",
	"display_far_left": "展示区远景左侧颜色",
	"display_far_center": "展示区远景中部颜色",
	"display_far_right": "展示区远景右侧颜色",
	"display_near_left": "展示区近景左侧颜色",
	"display_near_right": "展示区近景右侧颜色",
	"display_ground": "展示区地面颜色",
	"display_horizon": "展示区地平线颜色",
	"display_text": "展示区标题颜色",
	"display_caption": "展示区说明颜色",
	"disabled_opacity": "开关禁用透明度",
}
const GROUPS := ["字体与字号", "文字与状态", "表面与控件", "页面与遮罩", "展示占位背景", "开关禁用效果"]
const LEGACY_PATH := "user://config_inspector_legacy.tres"
const SAVED_PATH := "user://config_inspector_saved.tres"
var checks := 0
var failures := 0
var changes := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS ", message)

func changed() -> void:
	changes += 1

func same(a: Variant, b: Variant) -> bool:
	if a is Color and b is Color:
		return a.is_equal_approx(b)
	if a is float and b is float:
		return is_equal_approx(a, b)
	if a is SystemFont and b is SystemFont:
		return a.font_names == b.font_names and a.allow_system_fallback == b.allow_system_fallback
	return a == b

func alternate_value(field: String, iteration: int) -> Variant:
	if field == "font":
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Config Inspector Test %d" % iteration])
		font.allow_system_fallback = false
		return font
	if field.ends_with("_size"):
		return 90 + iteration
	if field == "disabled_opacity":
		return 0.21 + float(iteration) * 0.03
	return Color(0.17 + float(iteration) * 0.01, 0.34, 0.56, 0.23 + float(iteration) * 0.01)

func descriptions() -> Dictionary:
	# Each tooltip must be a ## block immediately preceding its declaration.
	# Godot's --gdscript-docs export and a real Inspector hover are checked separately.
	var result: Dictionary = {}
	var comment := ""
	var declaration := RegEx.new()
	declaration.compile("^@export.* var ([^ :]+)")
	for line in FileAccess.get_file_as_string("res://ui/theme/ui_config.gd").split("\n"):
		if line.begins_with("##"):
			comment += line.trim_prefix("##") + "\n"
		else:
			var match := declaration.search(line)
			if match != null:
				result[match.get_string(1)] = comment
			comment = ""
	return result

func run() -> void:
	var config := CONFIG.new()
	var properties: Dictionary = {}
	var groups: Array[String] = []
	var editable: Array[String] = []
	var stored: Array[String] = []
	for property in config.get_property_list():
		properties[property.name] = property
		if property.usage & PROPERTY_USAGE_GROUP and property.name != "Resource":
			groups.append(property.name)
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			if property.usage & PROPERTY_USAGE_EDITOR:
				editable.append(property.name)
			if property.usage & PROPERTY_USAGE_STORAGE:
				stored.append(property.name)
	check(groups == GROUPS, "All six Inspector groups are Chinese and in order")
	check(editable.size() == FIELDS.size(), "Exactly 56 Chinese settings are editable; no duplicate English rows")
	check(stored.size() == FIELDS.size(), "Exactly 56 canonical fields are stored")
	var docs := descriptions()
	var source := FileAccess.get_file_as_string("res://ui/theme/ui_config.gd")
	check(String(docs.get("micro_size", "")).contains("默认 18") and String(docs.get("micro_size", "")).contains("未设置本地字号覆盖") and not source.contains("这是一段micro_size的注释"), "Micro source documentation explains default, scope and replaces the placeholder")
	check(String(docs.get("微型提示字号", "")).contains("编辑玩家资料"), "Micro tooltip identifies the actual profile hint")
	config.changed.connect(changed)
	var undo := UndoRedo.new()
	for field in FIELDS:
		var label: String = FIELDS[field]
		check(properties.has(field) and properties.has(label), field + " has canonical and Chinese properties")
		if not properties.has(field) or not properties.has(label):
			continue
		var canonical: Dictionary = properties[field]
		var localized: Dictionary = properties[label]
		check(stored.has(field) and not editable.has(field), field + " preserves hidden storage API")
		check(editable.has(label) and not stored.has(label), label + " is an editor-only proxy")
		check(canonical.type == localized.type, label + " preserves the original value type")
		check(same(config.get(field), config.get(label)), label + " reads the canonical default")
		check(same((CONFIG as Script).get_property_default_value(label), (CONFIG as Script).get_property_default_value(field)), label + " native revert default matches canonical default")
		check(String(docs.get(label, "")).length() > 40 and String(docs.get(label, "")).contains(field), label + " has Chinese hover documentation and API link")
		check(String(docs.get(field, "")).length() > 20, field + " retains source documentation")
		if field.ends_with("_size"):
			check(localized.hint == PROPERTY_HINT_RANGE and localized.hint_string == "8,160,1", label + " preserves native integer range")
		elif field == "font":
			check(localized.hint == PROPERTY_HINT_RESOURCE_TYPE and localized.hint_string == "Font", label + " accepts native Font resources")
		elif field == "disabled_opacity":
			check(localized.hint == PROPERTY_HINT_RANGE and localized.hint_string == "0,1,0.01", label + " preserves opacity range and step")
		else:
			check(localized.hint == PROPERTY_HINT_NONE, label + " retains full RGBA editing")
			check(String(docs.get(label, "")).contains("alpha") and String(docs.get(label, "")).contains("0 完全透明"), label + " explains alpha")
		var first: Variant = alternate_value(field, 1)
		var second: Variant = alternate_value(field, 2)
		var before := changes
		config.set(label, first)
		check(same(config.get(field), first), label + " writes the existing API")
		check(changes == before + 1, label + " emits exactly one changed notification")
		before = changes
		config.set(field, second)
		check(same(config.get(label), second), field + " writes remain visible in Chinese")
		check(changes == before + 1, field + " retains exactly one changed notification")
		undo.create_action("Edit " + label)
		undo.add_do_property(config, label, first)
		undo.add_undo_property(config, label, second)
		undo.commit_action()
		check(same(config.get(field), first), label + " applies through native UndoRedo property actions")
		undo.undo()
		check(same(config.get(field), second), label + " undo restores the old value")
		undo.redo()
		check(same(config.get(field), first), label + " redo restores the new value")
		config.set(label, (CONFIG as Script).get_property_default_value(label))
		check(same(config.get(field), (CONFIG as Script).get_property_default_value(field)), label + " restores canonical default through proxy")
		config.set(label, first)
	undo.clear_history()
	undo.free()
	var duplicated := config.duplicate(true)
	for field in FIELDS:
		check(same(duplicated.get(field), config.get(field)) and same(duplicated.get(FIELDS[field]), config.get(field)), field + " survives deep Resource duplication")
	verify_font_forwarding(config)
	verify_legacy_roundtrip()
	config.changed.disconnect(changed)
	for path in [LEGACY_PATH, SAVED_PATH]:
		if FileAccess.file_exists(path):
			check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Temporary resource removed: " + path.get_file())
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func verify_font_forwarding(config: Resource) -> void:
	var old_font: Font = config.font
	config.set("界面字体", null)
	check(config.font == null and config.get("界面字体") == null, "Chinese font field supports clearing")
	var before := changes
	old_font.emit_changed()
	check(changes == before, "Replacing font disconnects its old changed signal")
	var new_font := SystemFont.new()
	config.set("界面字体", new_font)
	before = changes
	new_font.emit_changed()
	check(changes == before + 1, "Nested font changes propagate once through canonical setter")
	config.set("界面字体", new_font)
	before = changes
	new_font.emit_changed()
	check(changes == before + 1, "Reassigning identical font does not duplicate connections")

func verify_legacy_roundtrip() -> void:
	# A pre-localization resource with every English key customized, including Font.
	var text := "[gd_resource type=\"Resource\" load_steps=3 format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"res://ui/theme/ui_config.gd\" id=\"config\"]\n\n"
	text += "[sub_resource type=\"SystemFont\" id=\"legacy_font\"]\nfont_names = PackedStringArray(\"Legacy Config Font\")\nallow_system_fallback = false\n\n"
	text += "[resource]\nscript = ExtResource(\"config\")\nfont = SubResource(\"legacy_font\")\n"
	for field in FIELDS:
		if field != "font":
			text += field + " = " + var_to_str(alternate_value(field, 3)) + "\n"
	var file := FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	check(file != null, "Legacy fixture can be created")
	if file == null:
		return
	file.store_string(text)
	file.close()
	var legacy := ResourceLoader.load(LEGACY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	check(legacy != null, "Existing English-key configuration loads without migration")
	if legacy == null:
		return
	for field in FIELDS:
		var expected: Variant = alternate_value(field, 3)
		if field == "font":
			expected.font_names = PackedStringArray(["Legacy Config Font"])
		check(same(legacy.get(field), expected), field + " preserves non-default legacy value")
		check(same(legacy.get(FIELDS[field]), expected), FIELDS[field] + " displays loaded legacy value")
		legacy.set(FIELDS[field], alternate_value(field, 4))
	check(ResourceSaver.save(legacy, SAVED_PATH) == OK, "Chinese Inspector edits save successfully")
	var saved := FileAccess.get_file_as_string(SAVED_PATH)
	var reloaded := ResourceLoader.load(SAVED_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	check(reloaded != null, "Saved Chinese Inspector edits reload")
	if reloaded == null:
		return
	for field in FIELDS:
		check(saved.contains("\n" + field + " = "), field + " is still the serialized key")
		check(not saved.contains(FIELDS[field] + " = "), FIELDS[field] + " is not serialized as a competing value")
		check(same(reloaded.get(field), alternate_value(field, 4)), field + " reloads the edited value")
		check(same(reloaded.get(FIELDS[field]), alternate_value(field, 4)), FIELDS[field] + " reloads the edited value")
		reloaded.set(field, alternate_value(field, 5))
		check(same(reloaded.get(FIELDS[field]), alternate_value(field, 5)), field + " API remains writable after reload")
