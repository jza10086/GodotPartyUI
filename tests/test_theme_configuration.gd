extends SceneTree
## Shared UI palette/typography regressions. All edits are in-memory and restored.
## Run: godot --headless --path . --script res://tests/test_theme_configuration.gd

const CONFIG_PATH := "res://ui/theme/ui_config.tres"
const THEME_PATH := "res://ui/theme/party_theme.tres"
const COLOR_FIELDS := [
	"text", "text_hover", "text_disabled", "text_on_primary", "error", "success", "demo_inactive", "info",
	"surface", "muted_surface", "primary", "hover_surface", "border", "hover_border", "focus", "divider",
	"selection", "toggle_border", "toggle_active_text", "ruler",
	"page_background", "display_background", "menu_backdrop", "rooms_backdrop",
	"lobby_backdrop", "status_backdrop", "modal_overlay", "capture_overlay",
	"display_far_left", "display_far_center", "display_far_right", "display_near_left",
	"display_near_right", "display_ground", "display_horizon", "display_text", "display_caption"
]
const DEFAULT_SIZES := {
	"micro_size":18, "debug_size":19, "meta_size":20, "detail_size":21,
	"note_size":22, "secondary_size":23, "player_size":25,
	"body_size":24, "setting_size":26, "action_size":28, "section_size":30,
	"subheading_size":38, "compact_title_size":40, "dialog_title_size":42, "display_size":48, "page_title_size":58, "brand_size":72
}
const MAIN_BACKGROUNDS := {
	"DisplayBackground/Sky":"display_background",
	"DisplayBackground/FarLeft":"display_far_left", "DisplayBackground/FarCenter":"display_far_center",
	"DisplayBackground/FarRight":"display_far_right", "DisplayBackground/NearLeft":"display_near_left",
	"DisplayBackground/NearRight":"display_near_right", "DisplayBackground/Ground":"display_ground",
	"DisplayBackground/Horizon":"display_horizon", "Home/MenuBacking":"menu_backdrop",
	"Rooms/PageBacking":"rooms_backdrop", "Lobby/PageBacking":"lobby_backdrop",
	"Status/Backing":"status_backdrop", "Settings/Background":"page_background", "Modal/Scrim":"modal_overlay"
}
const MAIN_SIZES := {
	"Home/Title":"brand_size", "Home/Start":"action_size", "Home/Join":"action_size",
	"Rooms/RoomsTitle":"page_title_size", "Rooms/Name0":"section_size",
	"Lobby/LobbyTitle":"display_size", "Lobby/BasicTitle":"section_size",
	"Lobby/Game":"setting_size", "Lobby/GameLabel":"body_size",
	"DisplayBackground/Placeholder":"display_size", "DisplayBackground/Caption":"body_size",
	"Modal/Confirm/Title":"dialog_title_size", "Modal/Protocol/Title":"dialog_title_size",
	"Modal/Advanced/Title":"dialog_title_size", "Settings/Back":"action_size",
	"Modal/Create/Title":"subheading_size", "Modal/Direct/Title":"compact_title_size",
	"Modal/Preset/Title":"compact_title_size", "Modal/Profile/Title":"compact_title_size",
	"Home/Profile/Hint":"micro_size", "Status/Protocol":"debug_size", "Status/Keys":"meta_size",
	"Rooms/Info0":"detail_size", "Guide/Measure":"note_size",
	"Lobby/LobbySubtitle":"secondary_size", "Lobby/PlayerCount":"player_size"
}
const LOCAL_COLOR := Color(0.91, 0.17, 0.43, 0.36)
var failures := 0
var checks := 0
var config: Resource
var shared_theme: Theme
var original: Dictionary = {}
var instances: Array[Node] = []
var standalone_components: Array[Node] = []
var config_changes := 0

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
	for i in range(5):
		await process_frame

func has_property(object: Object, name: String) -> bool:
	for property in object.get_property_list():
		if property.name == name:
			return true
	return false

func spawn(path: String) -> Node:
	var node: Node = load(path).instantiate()
	instances.append(node)
	root.add_child(node)
	return node

func schema() -> Array:
	return [{"id":"theme", "title":"Theme", "options":[
		{"id":"label", "type":"label", "label":"Label", "value":"Value"},
		{"id":"select", "type":"select", "items":[{"label":"One", "value":1}]},
		{"id":"toggle", "type":"toggle", "value":false},
		{"id":"number", "type":"number", "value":4},
		{"id":"slider", "type":"slider", "value":25},
		{"id":"note", "type":"note", "text":"Default note"},
		{"id":"local_note", "type":"note", "text":"Explicit note", "font_size":37},
		{"id":"divider", "type":"divider"},
		{"id":"action", "type":"action", "label":"Action"},
		{"id":"header", "type":"bindings_header"},
		{"id":"group", "type":"group", "label":"Group", "expanded":true, "children":[
			{"id":"binding", "type":"keybinding", "label":"Binding", "value":[KEY_A, 0], "expanded":true, "children":[
				{"id":"child", "type":"keybinding", "label":"Child", "value":[KEY_B, 0]}]}]}]
	}]

func make_page() -> Node:
	var page := spawn("res://settings/settings_page.tscn")
	check(page.configure(schema()), "All schema types configure under shared theme")
	return page

func font_at(control: Control, field: String, context: String) -> void:
	check(control.get_theme_font_size("font_size") == config.get(field), context + " resolves " + field)
	check(control.get_theme_font("font") == config.font, context + " inherits global font")

func color_at(control: Control, color_name: String, field: String, context: String) -> void:
	check(control.get_theme_color(color_name).is_equal_approx(config.get(field)), context + " resolves " + field)

func style_at(control: Control, style_name: String, field: String, context: String) -> void:
	var style := control.get_theme_stylebox(style_name) as StyleBoxFlat
	check(style != null, context + " has editable flat " + style_name + " style")
	if style != null:
		check(style.bg_color.is_equal_approx(config.get(field)), context + " " + style_name + " follows " + field)

func verify_main(main: Node, context: String) -> void:
	check(main.theme == shared_theme, context + " main uses shared Theme resource")
	for path in MAIN_BACKGROUNDS:
		var background: ColorRect = main.get_node(path)
		check(background.color.is_equal_approx(config.get(MAIN_BACKGROUNDS[path])), context + " RGBA background " + path)
	for path in MAIN_SIZES:
		font_at(main.get_node(path), MAIN_SIZES[path], context + " " + path)
	color_at(main.get_node("Home/Join"), "font_color", "text", context + " normal button")
	color_at(main.get_node("Home/Join"), "font_hover_color", "text_hover", context + " hover button")
	color_at(main.get_node("Home/Join"), "font_disabled_color", "text_disabled", context + " disabled button")
	style_at(main.get_node("Home/Join"), "normal", "surface", context + " normal button")
	style_at(main.get_node("Home/Join"), "hover", "hover_surface", context + " hover button")
	style_at(main.get_node("Home/Join"), "disabled", "muted_surface", context + " disabled button")
	var focus_style: StyleBoxFlat = main.get_node("Home/Join").get_theme_stylebox("focus")
	check(focus_style.border_color.is_equal_approx(config.focus), context + " focus border follows RGBA focus")
	var normal_style: StyleBoxFlat = main.get_node("Home/Join").get_theme_stylebox("normal")
	check(normal_style.border_color.is_equal_approx(config.border), context + " card border follows RGBA border")
	var hover_style: StyleBoxFlat = main.get_node("Home/Join").get_theme_stylebox("hover")
	check(hover_style.border_color.is_equal_approx(config.hover_border), context + " hover border follows RGBA")
	style_at(main.get_node("Home/Start"), "normal", "primary", context + " primary button")
	color_at(main.get_node("Home/Start"), "font_color", "text_on_primary", context + " primary button text")
	color_at(main.get_node("Home/Start"), "font_focus_color", "text_on_primary", context + " primary focused text")
	color_at(main.get_node("DisplayBackground/Placeholder"), "font_color", "display_text", context + " display title")
	color_at(main.get_node("Modal/Advanced/Shuffle"), "button_checked_color", "primary", context + " native checked CheckButton")
	color_at(main.get_node("Modal/Advanced/Shuffle"), "button_unchecked_color", "border", context + " native unchecked CheckButton")
	color_at(main.get_node("DisplayBackground/Caption"), "font_color", "display_caption", context + " display caption")
	for modal in ["Create", "Confirm", "Protocol", "Advanced", "Preset", "Direct", "Profile"]:
		style_at(main.get_node("Modal/" + modal + "/Dialog"), "panel", "surface", context + " modal " + modal)
	for modal in ["Create", "Direct", "Profile"]:
		color_at(main.get_node("Modal/" + modal + "/Error"), "font_color", "error", context + " error " + modal)
	style_at(main.get_node("Modal/Preset/Preview"), "panel", "muted_surface", context + " preset preview")
	style_at(main.get_node("Modal/Profile/Avatar"), "panel", "muted_surface", context + " profile avatar")
	style_at(main.get_node("Home/Profile/Avatar"), "panel", "muted_surface", context + " home avatar")
	style_at(main.get_node("Toast"), "panel", "primary", context + " toast")
	style_at(main.get_node("Lobby/SettingsPanel"), "panel", "surface", context + " lobby settings")
	style_at(main.get_node("Lobby/Slot0"), "panel", "surface", context + " occupied lobby slot")
	style_at(main.get_node("Lobby/Slot7"), "panel", "muted_surface", context + " empty lobby slot")

func verify_page(page: Node, context: String) -> void:
	check(page.theme == shared_theme, context + " settings use shared Theme")
	check(page.get_node("Background").color.is_equal_approx(config.page_background), context + " page background RGBA")
	font_at(page.get_node("Back"), "action_size", context + " Back")
	font_at(page.get_node("Tabs"), "action_size", context + " tab captions")
	var content: Node = page.get_node("Tabs/theme/Padding/Content")
	for id in ["label", "select", "toggle", "number", "slider"]:
		font_at(content.get_node(id + "/Label"), "setting_size", context + " " + id + " row label")
	for id in ["label", "select", "number", "action", "group", "binding", "child"]:
		font_at(page.get_control(id), "setting_size", context + " generated " + id)
	font_at(page.get_number_control("number").get_line_edit(), "setting_size", context + " precise integer text")
	font_at(page.get_number_control("slider").get_line_edit(), "setting_size", context + " precise slider text")
	for direction in ["up", "down"]:
		var number: SpinBox = page.get_number_control("number")
		color_at(number, direction + "_icon_modulate", "text", context + " native " + direction + " arrow")
		color_at(number, direction + "_hover_icon_modulate", "text_hover", context + " native " + direction + " hover arrow")
		color_at(number, direction + "_pressed_icon_modulate", "text_hover", context + " native " + direction + " pressed arrow")
		color_at(number, direction + "_disabled_icon_modulate", "text_disabled", context + " native " + direction + " disabled arrow")
		style_at(number, direction + "_background", "surface", context + " native " + direction + " arrow")
		style_at(number, direction + "_background_hovered", "hover_surface", context + " native " + direction + " hover arrow")
		style_at(number, direction + "_background_pressed", "hover_surface", context + " native " + direction + " pressed arrow")
		style_at(number, direction + "_background_disabled", "muted_surface", context + " native " + direction + " disabled arrow")
	font_at(content.get_node("header/Primary"), "body_size", context + " binding header")
	font_at(page.get_control("note"), "secondary_size", context + " default note")
	color_at(page.get_control("label"), "font_color", "text", context + " label text")
	check(page.get_control("local_note").get_theme_font_size("font_size") == 37, context + " explicit schema font_size survives")
	check(page.get_control("local_note").has_theme_font_size_override("font_size"), context + " schema size remains ordinary override")
	var tabs: TabContainer = page.get_node("Tabs")
	style_at(tabs, "panel", "surface", context + " tabs panel")
	style_at(tabs, "tab_selected", "primary", context + " selected tab")
	style_at(tabs, "tab_unselected", "muted_surface", context + " unselected tab")
	color_at(tabs, "font_selected_color", "text_on_primary", context + " selected tab text")
	color_at(tabs, "font_unselected_color", "text", context + " inactive tab text")
	color_at(tabs, "font_hovered_color", "text_hover", context + " hovered tab text")
	var divider: ColorRect = page.get_control("divider")
	check(divider.color.is_equal_approx(config.divider), context + " explicit divider follows RGBA")
	check(content.get_node("AutoDivider_select").color.is_equal_approx(config.divider), context + " automatic divider follows RGBA")
	for path in ["groupDetails/HierarchyLine", "groupDetails/HeaderConnection", "groupDetails/BranchTemplate", "groupDetails/Rows/bindingDetails/HierarchyLine"]:
		check(content.get_node(path).default_color.is_equal_approx(config.divider), context + " hierarchy line " + path)
	var branches: Node = content.get_node("groupDetails/Branches")
	check(branches.get_child_count() > 0, context + " dynamic hierarchy branches exist")
	for branch in branches.get_children():
		check(branch.default_color.is_equal_approx(config.divider), context + " generated branch follows RGBA")
	var toggle: Button = page.get_control("toggle")
	check(toggle.get("use_global_colors") == true, context + " toggle defaults to global colors")
	check(toggle.get_node("Selection").color.is_equal_approx(config.primary), context + " toggle selection follows primary")
	style_at(toggle.get_node("Track"), "panel", "muted_surface", context + " toggle track")
	var track_style: StyleBoxFlat = toggle.get_node("Track").get_theme_stylebox("panel")
	check(track_style.border_color.is_equal_approx(config.toggle_border), context + " toggle border follows RGBA")
	font_at(toggle.get_node("Off"), "setting_size", context + " toggle Off")
	font_at(toggle.get_node("On"), "setting_size", context + " toggle On")
	var popup: PopupMenu = page.get_control("select").get_popup()
	check(popup.get_theme_font("font") == config.font, context + " dropdown popup inherits global font")
	check(popup.get_theme_color("font_color").is_equal_approx(config.text), context + " dropdown popup follows text color")
	check(page.get_control("select").get_theme_constant("modulate_arrow") == 1, context + " dropdown arrow follows interaction-state text tint")
	for item in ["checked", "unchecked", "radio_checked", "radio_unchecked", "checked_disabled", "unchecked_disabled", "radio_checked_disabled", "radio_unchecked_disabled", "submenu", "submenu_mirrored"]:
		var texture := popup.get_theme_icon(item)
		var original_icon := ThemeDB.get_default_theme().get_icon(item, "PopupMenu")
		check(texture.get_size() == original_icon.get_size(), context + " menu icon preserves native geometry: " + item)
		var expected: Color = config.text_disabled if item.ends_with("_disabled") else config.text
		var pixels := texture.get_image()
		var match_count := 0
		var wrong_count := 0
		var maximum_alpha := 0.0
		for y in pixels.get_height():
			for x in pixels.get_width():
				var pixel := pixels.get_pixel(x, y)
				maximum_alpha = maxf(maximum_alpha, pixel.a)
				if pixel.a <= 0: continue
				match_count += 1
				if absf(pixel.r - expected.r) > 0.005 or absf(pixel.g - expected.g) > 0.005 or absf(pixel.b - expected.b) > 0.005 or pixel.a > expected.a + 0.005: wrong_count += 1
		check(match_count > 0 and wrong_count == 0, context + " menu icon follows semantic RGBA: " + item)
		if item.contains("unchecked"):
			var original_pixels := original_icon.get_image()
			var original_alpha := 0.0
			for y in original_pixels.get_height():
				for x in original_pixels.get_width(): original_alpha = maxf(original_alpha, original_pixels.get_pixel(x, y).a)
			check(maximum_alpha >= original_alpha * expected.a * 0.85 - 0.005, context + " unchecked icon keeps native opacity instead of fading twice: " + item)



func verify_component_fonts(node: Node, context: String) -> void:
	if node is Label or node is Button or node is LineEdit or node is SpinBox:
		check(node.get_theme_font("font") == config.font, context + " inherits font: " + str(node.name))
	for child in node.get_children():
		verify_component_fonts(child, context)

func make_standalone_components() -> void:
	var directory := DirAccess.open("res://settings/components")
	for filename in directory.get_files():
		if filename.ends_with(".tscn"):
			standalone_components.append(spawn("res://settings/components/" + filename))

func verify_standalone_components(context: String) -> void:
	for component in standalone_components:
		verify_component_fonts(component, context + " " + component.scene_file_path.get_file())

func verify_demo(demo: Node, context: String) -> void:
	check(demo.theme == shared_theme, context + " standalone demo shares theme")
	font_at(demo.get_node("Preview"), "setting_size", context + " demo preview")
	color_at(demo.get_node("Preview"), "font_color", "text", context + " demo preview text")
	check(not demo.get_node("Preview").has_theme_font_override("font"), context + " demo has no baked font override")
	check(demo.get_node("Settings").theme == shared_theme, context + " demo settings share theme")

func verify_tooltip(tip: Label, context: String) -> void:
	check(tip.theme == shared_theme, context + " independent tooltip has shared Theme")
	font_at(tip, "body_size", context + " tooltip")
	color_at(tip, "font_color", "text", context + " tooltip text")
	check(tip.text == "Theme tooltip", context + " tooltip text survives refresh")

func verify_scene_defaults(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		if not filename.ends_with(".tscn"):
			continue
		var contents := FileAccess.get_file_as_string(path.path_join(filename))
		check(not contents.contains("theme_override_fonts/") and not contents.contains("theme_override_font_sizes/") and not contents.contains("theme_override_colors/"), "Scene text defaults are inherited: " + filename)
	for subdirectory in directory.get_directories():
		verify_scene_defaults(path.path_join(subdirectory))

func verify_checkbutton_icons(button: CheckButton) -> void:
	for icon_name in ["checked", "unchecked"]:
		var texture := button.get_theme_icon(icon_name)
		check(texture != null, "Native CheckButton " + icon_name + " icon exists")
		if texture == null:
			continue
		var pixels := texture.get_image()
		check(pixels != null and not pixels.is_empty(), "Native CheckButton " + icon_name + " icon pixels are readable")
		if pixels == null or pixels.is_empty():
			continue
		var colored_pixels := 0
		var blue_pixels := 0
		for y in range(pixels.get_height()):
			for x in range(pixels.get_width()):
				var pixel := pixels.get_pixel(x, y)
				if pixel.a <= 0.01:
					continue
				if maxf(pixel.r, maxf(pixel.g, pixel.b)) - minf(pixel.r, minf(pixel.g, pixel.b)) > 0.04:
					colored_pixels += 1
				if pixel.b > pixel.r + 0.05 and pixel.b > pixel.g + 0.05:
					blue_pixels += 1
		print("ICON: %s size=%s chromatic_pixels=%d blue_pixels=%d" % [icon_name, str(texture.get_size()), colored_pixels, blue_pixels])
		check(colored_pixels == 0, "Native CheckButton " + icon_name + " icon is neutral before configured tint")

func verify_export_signals() -> void:
	# Isolate setter notifications from the cost of updating all visible scenes.
	for field in original:
		var value: Variant = original[field]
		var replacement: Variant = value
		if value is Color:
			replacement = Color(0.29, 0.53, 0.71, 0.41)
		elif value is int:
			replacement = value + 1
		elif value is float:
			replacement = 0.31
		elif value is Font:
			replacement = SystemFont.new()
			replacement.allow_system_fallback = false
		var before := config_changes
		config.set(field, replacement)
		check(config_changes > before, "Changed signal emitted by exported setter: " + field)
		config.set(field, value)

func roundtrip(node: Node, context: String) -> Node:
	var packed := PackedScene.new()
	check(packed.pack(node) == OK, context + " packs to an in-memory scene")
	var copy: Node = packed.instantiate()
	instances.append(copy)
	root.add_child(copy)
	return copy

func verify_resource_roundtrips(main: Node) -> void:
	var theme_path := "user://theme_configuration_roundtrip_theme.tres"
	var style_path := "user://theme_configuration_roundtrip_style.tres"
	var local_path := "user://theme_configuration_roundtrip_local_style.tres"
	var global_style := shared_theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var local_style := global_style.duplicate() as StyleBoxFlat
	local_style.set("use_global_colors", false)
	local_style.bg_color = LOCAL_COLOR
	local_style.border_color = Color(0.31, 0.71, 0.43, 0.61)
	check(ResourceSaver.save(shared_theme, theme_path) == OK, "Generated Theme saves to temporary resource")
	check(ResourceSaver.save(global_style, style_path) == OK, "Global StyleBox saves to temporary resource")
	check(ResourceSaver.save(local_style, local_path) == OK, "Opted-out StyleBox saves to temporary resource")
	print("SERIALIZED LOCAL STYLE: ", FileAccess.get_file_as_string(local_path).replace("\n", " | "))
	var started := Time.get_ticks_usec()
	config.text = Color(0.24, 0.43, 0.67, 0.39)
	print("TIMING: individual live color setter %d us" % (Time.get_ticks_usec() - started))
	await settle()
	color_at(main.get_node("Home/Join"), "font_color", "text", "Individual live setter")
	started = Time.get_ticks_usec()
	config.body_size += 1
	print("TIMING: individual live size setter %d us" % (Time.get_ticks_usec() - started))
	await settle()
	font_at(main.get_node("Lobby/GameLabel"), "body_size", "Individual live size setter")
	config.surface = Color(0.18, 0.61, 0.38, 0.47)
	await settle()
	var reloaded_theme := ResourceLoader.load(theme_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var reloaded_style := ResourceLoader.load(style_path, "", ResourceLoader.CACHE_MODE_IGNORE) as StyleBoxFlat
	var reloaded_local := ResourceLoader.load(local_path, "", ResourceLoader.CACHE_MODE_IGNORE) as StyleBoxFlat
	# Scripted resources finish applying after deserialized opt-out flags load.
	await settle()
	check(reloaded_theme != null and reloaded_style != null and reloaded_local != null, "Saved Theme and StyleBoxes reload without cache")
	if reloaded_theme != null:
		check(reloaded_theme != shared_theme, "Theme roundtrip creates a fresh resource")
		check(reloaded_theme.get("configuration") == config, "Reloaded Theme uses the shared current config")
		check(reloaded_theme.default_font == config.font, "Reloaded Theme does not freeze saved font")
		check(reloaded_theme.default_font_size == config.body_size, "Reloaded Theme does not freeze saved size")
		check(reloaded_theme.get_color("font_color", "Button").is_equal_approx(config.text), "Reloaded Theme does not freeze generated palette")
	if reloaded_style != null:
		check(reloaded_style.bg_color.is_equal_approx(config.surface), "Reloaded global StyleBox uses current palette")
		check(reloaded_style.border_color.is_equal_approx(config.border), "Reloaded global StyleBox uses current border")
	if reloaded_local != null:
		check(reloaded_local.get("use_global_colors") == false, "Reloaded local StyleBox preserves global opt-out")
		check(reloaded_local.bg_color.is_equal_approx(LOCAL_COLOR), "Reloaded local StyleBox preserves local RGBA")
		check(reloaded_local.border_color.is_equal_approx(local_style.border_color), "Reloaded local StyleBox preserves local border")
	config.primary = Color(0.39, 0.19, 0.54, 0.58)
	await settle()
	if reloaded_theme != null:
		check(reloaded_theme.get_stylebox("normal", "PartyButtonActionPrimary").bg_color.is_equal_approx(config.primary), "Reloaded Theme remains connected to future edits")
	if reloaded_local != null:
		check(reloaded_local.bg_color.is_equal_approx(LOCAL_COLOR), "Reloaded local StyleBox ignores future global edits")
	for path in [theme_path, style_path, local_path]:
		check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Temporary serialization resource removed: " + path.get_file())

func run() -> void:
	config = load(CONFIG_PATH)
	shared_theme = load(THEME_PATH)
	check(config != null and shared_theme != null, "Shared config and Theme resources load")
	if config == null or shared_theme == null:
		quit(1)
		return
	check(config.get_script() != null and config.get_script().is_tool(), "Config previews in the editor through @tool")
	check(shared_theme.get_script() != null and shared_theme.get_script().is_tool(), "Generated Theme previews through @tool")
	for property in config.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and (property.type == TYPE_COLOR or property.type == TYPE_INT or property.type == TYPE_FLOAT or property.name == "font"):
			original[property.name] = config.get(property.name)
	for field in COLOR_FIELDS:
		check(has_property(config, field) and config.get(field) is Color, "Global RGBA field exists: " + field)
	for field in DEFAULT_SIZES:
		check(config.get(field) == DEFAULT_SIZES[field], "Default hierarchy " + field)
	check(config.font is Font, "Default font remains configured")
	config.changed.connect(_config_changed)
	verify_export_signals()
	var main := spawn("res://main.tscn")
	var page := make_page()
	var demo := spawn("res://examples/settings_demo.tscn")
	make_standalone_components()
	await settle()
	var tip: Label = page.get_binding_control("binding", 0)._make_custom_tooltip("Theme tooltip")
	instances.append(tip)
	root.add_child(tip)
	await settle()
	verify_main(main, "Initial")
	verify_checkbutton_icons(main.get_node("Modal/Advanced/Shuffle"))
	verify_page(page, "Initial")
	verify_demo(demo, "Initial")
	verify_tooltip(tip, "Initial")
	verify_standalone_components("Initial")
	verify_scene_defaults("res://ui")
	verify_scene_defaults("res://settings")
	verify_scene_defaults("res://examples")
	var main_text := FileAccess.get_file_as_string("res://main.tscn")
	check(not main_text.contains("theme_override_font_sizes/") and not main_text.contains("theme_override_fonts/") and not main_text.contains("theme_override_colors/"), "Main scene text defaults use shared variations")

	# Node-level overrides are intentional and must outlive config refreshes.
	var local_label: Label = main.get_node("Status/Engine")
	var local_font := SystemFont.new()
	local_label.add_theme_font_override("font", local_font)
	local_label.add_theme_font_size_override("font_size", 47)
	local_label.add_theme_color_override("font_color", LOCAL_COLOR)
	var local_button: Button = main.get_node("Home/Exit")
	var local_style := StyleBoxFlat.new()
	local_style.bg_color = LOCAL_COLOR
	local_button.add_theme_stylebox_override("normal", local_style)
	var local_background: ColorRect = main.get_node("Guide/X96")
	check(has_property(local_background, "use_global_color"), "Background exposes explicit global-color opt-out")
	local_background.set("use_global_color", false)
	local_background.color = LOCAL_COLOR
	var local_line: Line2D = page.get_node("Tabs/theme/Padding/Content/groupDetails/Rows/bindingDetails/HeaderConnection")
	check(has_property(local_line, "use_global_color"), "Hierarchy line exposes global-color opt-out")
	local_line.set("use_global_color", false)
	local_line.default_color = LOCAL_COLOR
	var local_toggle := spawn("res://settings/components/segmented_toggle.tscn")
	local_toggle.set("use_global_colors", false)
	local_toggle.active_text_color = Color(0.80, 0.11, 0.24, 0.67)
	local_toggle.inactive_text_color = Color(0.18, 0.72, 0.29, 0.73)
	local_toggle.focus_color = LOCAL_COLOR
	local_toggle.get_node("Selection").set("use_global_color", false)
	local_toggle.get_node("Selection").color = LOCAL_COLOR
	local_toggle.queue_redraw()
	var label_toggle := spawn("res://settings/components/segmented_toggle.tscn")
	label_toggle.get_node("Off").add_theme_color_override("font_color", LOCAL_COLOR)
	# Scene edits are present before _ready, just like Inspector overrides.
	var local_row: Node = load("res://settings/components/label_row.tscn").instantiate()
	local_row.get_node("Label").add_theme_font_override("font", local_font)
	local_row.get_node("Label").add_theme_font_size_override("font_size", 49)
	local_row.get_node("Label").add_theme_color_override("font_color", LOCAL_COLOR)
	instances.append(local_row)
	root.add_child(local_row)
	var pre_ready_background := ColorRect.new()
	pre_ready_background.set_script(load("res://ui/theme/theme_color_rect.gd"))
	pre_ready_background.set("use_global_color", false)
	pre_ready_background.color = LOCAL_COLOR
	instances.append(pre_ready_background)
	root.add_child(pre_ready_background)
	demo.get_node("Settings").get_control("enabled").button_pressed = false
	check(demo.get_node("Preview").modulate.is_equal_approx(config.demo_inactive), "Demo callback uses configured inactive color")

	# Runtime changes exercise every exported RGBA channel, not just grayscale.
	var replacement_font := SystemFont.new()
	replacement_font.allow_system_fallback = false
	print("PHASE: update global font")
	var font_started := Time.get_ticks_usec()
	config.font = replacement_font
	print("TIMING: individual live font setter %d us" % (Time.get_ticks_usec() - font_started))
	await settle()
	check(main.get_node("Home/Title").get_theme_font("font") == replacement_font, "Individual font setter updates existing UI")
	print("PHASE: update global palette and sizes")
	config.set_block_signals(true)
	var color_index := 0
	for field in COLOR_FIELDS:
		config.set(field, Color(0.12 + color_index * 0.015, 0.70 - color_index * 0.011, 0.31 + color_index * 0.008, 0.53 + color_index * 0.009))
		color_index += 1
	for field in original:
		if field.ends_with("_size"):
			config.set(field, int(original[field]) + 5)
	config.set_block_signals(false)
	config.emit_changed()
	await settle()
	check(config_changes >= COLOR_FIELDS.size() + DEFAULT_SIZES.size() + 1, "Export setters emit changed for color, font and size edits")
	check(shared_theme.default_font == replacement_font, "Shared Theme updates default font in place")
	check(shared_theme.default_font_size == config.body_size, "Shared Theme updates default body size")
	check(shared_theme.configuration == config, "Generated Theme retains the one shared config")
	verify_main(main, "Live")
	verify_page(page, "Live")
	verify_demo(demo, "Live")
	verify_tooltip(tip, "Live")
	verify_standalone_components("Live")
	check(local_label.get_theme_font("font") == local_font, "Local font override survives config change")
	check(local_label.get_theme_font_size("font_size") == 47, "Local font-size override survives config change")
	check(local_label.get_theme_color("font_color").is_equal_approx(LOCAL_COLOR), "Local font-color override survives config change")
	check(local_button.get_theme_stylebox("normal") == local_style and local_style.bg_color.is_equal_approx(LOCAL_COLOR), "Local StyleBox identity and RGBA survive config change")
	check(local_background.color.is_equal_approx(LOCAL_COLOR), "Opted-out background keeps editable ColorRect.color")
	check(local_line.default_color.is_equal_approx(LOCAL_COLOR), "Opted-out line keeps editable Line2D.default_color")
	check(local_toggle.get_node("Selection").color.is_equal_approx(LOCAL_COLOR), "Toggle selection independently preserves local RGBA")
	check(local_toggle.focus_color.is_equal_approx(LOCAL_COLOR), "Toggle retains local focus field")
	check(local_toggle.get_node("Off").get_theme_color("font_color").is_equal_approx(local_toggle.active_text_color), "Opted-out toggle draws local active color")
	check(local_toggle.get_node("On").get_theme_color("font_color").is_equal_approx(local_toggle.inactive_text_color), "Opted-out toggle draws local inactive color")
	check(label_toggle.get_node("Off").get_theme_color("font_color").is_equal_approx(LOCAL_COLOR), "Toggle preserves explicit child-label color override")
	check(local_row.get_node("Label").get_theme_font("font") == local_font, "Pre-ready local font override survives readiness and config update")
	check(local_row.get_node("Label").get_theme_font_size("font_size") == 49, "Pre-ready local font size survives readiness and config update")
	check(local_row.get_node("Label").get_theme_color("font_color").is_equal_approx(LOCAL_COLOR), "Pre-ready local text color survives readiness and config update")
	check(pre_ready_background.color.is_equal_approx(LOCAL_COLOR), "Pre-ready native background color survives opt-out")
	check(demo.get_node("Preview").modulate.is_equal_approx(config.demo_inactive), "Existing demo callback color updates with palette")
	demo.get_node("Settings").get_control("enabled").button_pressed = true
	check(demo.get_node("Preview").modulate.is_equal_approx(config.success), "Demo callback uses configured success RGBA")
	var global_toggle: Button = page.get_control("toggle")
	global_toggle.disabled = true
	global_toggle.queue_redraw()
	config.disabled_opacity = 0.37
	await settle()
	var disabled_active: Color = config.toggle_active_text
	disabled_active.a *= config.disabled_opacity
	var disabled_inactive: Color = config.text
	disabled_inactive.a *= config.disabled_opacity
	check(global_toggle.get_node("Off").get_theme_color("font_color").is_equal_approx(disabled_active), "Disabled toggle multiplies configured active alpha")
	check(global_toggle.get_node("On").get_theme_color("font_color").is_equal_approx(disabled_inactive), "Disabled toggle multiplies configured inactive alpha")
	global_toggle.disabled = false
	label_toggle.button_pressed = true
	label_toggle.sync_visual(false)
	await settle()
	check(label_toggle.get_node("Off").get_theme_color("font_color").is_equal_approx(LOCAL_COLOR), "Toggle state changes preserve local child-label color")

	var saved_toggle := roundtrip(local_toggle, "Local toggle")
	var saved_label_toggle := roundtrip(label_toggle, "Child-overridden toggle")
	var saved_global_toggle := roundtrip(global_toggle, "Global animated toggle")
	var saved_row := roundtrip(local_row, "Locally overridden row")
	var saved_background := roundtrip(pre_ready_background, "Opted-out background")
	await settle()
	check(saved_toggle.get("use_global_colors") == false, "Saved toggle retains global-color opt-out")
	check(saved_toggle.get_node("Off").get_theme_color("font_color").is_equal_approx(local_toggle.active_text_color), "Saved local toggle retains active text RGBA")
	check(saved_toggle.get_node("Selection").color.is_equal_approx(LOCAL_COLOR), "Saved toggle retains local selection color")
	check(saved_label_toggle.get_node("Off").has_theme_color_override("font_color"), "Saved child-label override remains an ordinary Theme Override")
	check(saved_label_toggle.get_node("Off").get_theme_color("font_color").is_equal_approx(LOCAL_COLOR), "Saved child-label override survives readiness")
	check(not saved_global_toggle.get_node("Off").has_theme_color_override("font_color"), "Animated toggle does not serialize generated Theme Overrides")
	check(saved_row.get_node("Label").get_theme_font("font") == local_font, "Saved row retains explicit font resource")
	check(saved_row.get_node("Label").get_theme_font_size("font_size") == 49, "Saved row retains explicit font size")
	check(saved_background.color.is_equal_approx(LOCAL_COLOR), "Saved background retains opted-out native color")
	await verify_resource_roundtrips(main)
	check(saved_global_toggle.get_node("On").get_theme_color("font_color").is_equal_approx(config.text), "Saved global toggle follows next palette edit")
	check(saved_label_toggle.get_node("Off").get_theme_color("font_color").is_equal_approx(LOCAL_COLOR), "Saved explicit toggle text ignores next palette edit")
	check(saved_toggle.get_node("Off").get_theme_color("font_color").is_equal_approx(local_toggle.active_text_color), "Saved local toggle ignores next palette edit")

	check(page.begin_binding_capture("binding", 0), "Capture opens using updated config")
	await settle()
	var capture: Control = page.get_node("BindingCapture")
	check(capture.get_node("Shade").color.is_equal_approx(config.capture_overlay), "New capture overlay inherits RGBA")
	style_at(capture.get_node("Panel"), "panel", "surface", "Capture dialog")
	font_at(capture.get_node("Panel/Content/Title"), "section_size", "Capture title")
	font_at(capture.get_node("Panel/Content/Message"), "body_size", "Capture message")
	config.capture_overlay = Color(0.63, 0.29, 0.18, 0.27)
	await settle()
	check(capture.get_node("Shade").color.is_equal_approx(config.capture_overlay), "Open capture overlay updates live")
	page.cancel_binding_capture()
	await settle()
	check(not page.has_node("BindingCapture"), "Capture cleanly removes theme-bound nodes")

	var new_main := spawn("res://main.tscn")
	var new_page := make_page()
	var new_demo := spawn("res://examples/settings_demo.tscn")
	await settle()
	verify_main(new_main, "New instance")
	verify_page(new_page, "New instance")
	verify_demo(new_demo, "New instance")
	var new_tip: Label = new_page.get_binding_control("binding", 0)._make_custom_tooltip("Theme tooltip")
	instances.append(new_tip)
	root.add_child(new_tip)
	await settle()
	verify_tooltip(new_tip, "New instance")

	# Remove overrides to prove the normal inheritance path resumes immediately.
	local_label.remove_theme_font_override("font")
	local_label.remove_theme_font_size_override("font_size")
	local_label.remove_theme_color_override("font_color")
	local_button.remove_theme_stylebox_override("normal")
	local_background.set("use_global_color", true)
	local_line.set("use_global_color", true)
	await settle()
	check(local_label.get_theme_font("font") == replacement_font, "Removing local font override restores current global font")
	color_at(local_label, "font_color", "text", "Removed color override")
	style_at(local_button, "normal", "surface", "Removed style override")
	check(local_line.default_color.is_equal_approx(config.divider), "Re-enabled global line uses current palette")
	check(local_background.color.is_equal_approx(config.ruler), "Re-enabled background uses current palette")
	local_background.set("color_role", "error")
	check(local_background.color.is_equal_approx(config.error), "Changing a background semantic role applies immediately")
	local_background.set("color_role", "ruler")
	local_line.set("color_role", "focus")
	check(local_line.default_color.is_equal_approx(config.focus), "Changing a line semantic role applies immediately")
	local_line.set("color_role", "divider")

	# Restore the exact shared resources without saving anything to disk.
	config.set_block_signals(true)
	for field in original:
		config.set(field, original[field])
	config.set_block_signals(false)
	config.emit_changed()
	await settle()
	check(config.font == original.font and shared_theme.default_font == original.font, "Original shared font restored")
	for field in COLOR_FIELDS:
		check(config.get(field).is_equal_approx(original[field]), "Original RGBA restored: " + field)
	verify_main(new_main, "Restored")
	verify_page(new_page, "Restored")
	verify_demo(new_demo, "Restored")
	verify_tooltip(new_tip, "Restored")
	verify_standalone_components("Restored")
	config.changed.disconnect(_config_changed)
	for instance in instances:
		if is_instance_valid(instance):
			instance.queue_free()
	await settle()
	var remaining_node_connections := 0
	for connection in config.changed.get_connections():
		if connection.callable.get_object() is Node:
			remaining_node_connections += 1
	check(remaining_node_connections == 0, "Destroyed scenes leave no live config-to-node connections")
	config.emit_changed()
	await settle()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _config_changed() -> void:
	config_changes += 1
