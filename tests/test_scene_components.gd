extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("PASS ", message)
func settle() -> void:
	for i in range(5): await process_frame
func run() -> void:
	var directory := DirAccess.open("res://settings/components")
	for filename in directory.get_files():
		if not filename.ends_with(".tscn"): continue
		var component: Control = load("res://settings/components/" + filename).instantiate()
		root.add_child(component)
		await settle()
		check(component.scene_file_path.ends_with(filename), "Standalone editable component: " + filename)
		component.queue_free()
		await settle()
	var page = load("res://settings/settings_page.tscn").instantiate()
	root.add_child(page)
	var options := [
		{"id":"static", "type":"label", "value":"Value"},
		{"id":"choice", "type":"select", "items":[{"label":"One", "value":1}]},
		{"id":"toggle", "type":"toggle"},
		{"id":"number", "type":"number"},
		{"id":"slider", "type":"slider"},
		{"id":"note", "type":"note", "text":"Note"},
		{"id":"divider", "type":"divider"},
		{"id":"action", "type":"action"},
		{"id":"header", "type":"bindings_header"},
		{"id":"group", "type":"group", "expanded":true, "children":[
			{"id":"binding", "type":"keybinding", "children":[
				{"id":"child", "type":"keybinding"}]}]}]
	check(page.configure([{"id":"test", "title":"Test", "options":options}]), "All schema types instantiate scenes")
	await settle()
	var content = page.get_node("Tabs/test/Padding/Content")
	check(page.get_node("Tabs/test").scene_file_path.ends_with("tab_content.tscn"), "Tab is scene-backed")
	for spec in options:
		check(not content.get_node(spec.id).scene_file_path.is_empty(), "Schema row uses PackedScene: " + spec.id)
	var row_template = load("res://settings/components/number_row.tscn").instantiate()
	check(content.get_node("number").custom_minimum_size == row_template.custom_minimum_size, "Row height comes from scene")
	check(page.get_number_control("number").custom_minimum_size == row_template.get_node("Value").custom_minimum_size, "Field dimensions come from scene")
	row_template.free()
	var details = content.get_node("groupDetails")
	var line: Line2D = details.get_node("HierarchyLine")
	check(line.width == 1 and line.get_point_position(1).y == details.size.y, "Expanded hierarchy line spans children")
	var old_height: float = details.size.y
	page.set_expanded("binding", true)
	await settle()
	check(details.size.y > old_height and line.get_point_position(1).y == details.size.y, "Hierarchy line follows nested expansion")
	check(details.get_node("Rows/bindingDetails/HierarchyLine").is_visible_in_tree(), "Nested children have their own line")
	page.set_expanded("group", false)
	await settle()
	check(not line.is_visible_in_tree(), "Collapsed hierarchy line disappears with children")
	page.set_expanded("group", true)
	await settle()
	var button = page.get_binding_control("binding", 0)
	var tip = button._make_custom_tooltip("A tooltip")
	check(tip.scene_file_path.ends_with("tooltip.tscn") and tip.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and tip.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "Tooltip is scene-backed and centered")
	check(tip.text == "A tooltip", "Tooltip text is bound without changing scene layout")
	tip.free()
	check(page.begin_binding_capture("binding", 0), "Capture opens after scene refactor")
	check(page.get_node("BindingCapture").scene_file_path.ends_with("binding_capture.tscn"), "Capture overlay is scene-backed")
	page.get_node("BindingCapture/Panel/Content/Actions/Cancel").pressed.emit()
	check(not page.is_capturing_binding(), "Scene cancel signal wired")
	var tabs: TabContainer = page.get_node("Tabs")
	var hover := tabs.get_theme_stylebox("tab_hovered")
	var normal := tabs.get_theme_stylebox("tab_unselected")
	check(tabs.get_theme_color("font_hovered_color").get_luminance() < 0.2, "Unselected hover text stays dark on light background")
	check(tabs.get_theme_color("font_selected_color").get_luminance() > 0.8, "Selected tab retains light text on dark background")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		check(hover.get_content_margin(side) == normal.get_content_margin(side), "Hover tab preserves text center and margins: " + str(side))
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var dialog: Panel = main.get_node("Modal/Create/Dialog")
	dialog.position += Vector2(7, 9)
	dialog.size += Vector2(20, 30)
	var edited_rect := dialog.get_rect()
	main.open_modal("Create")
	check(dialog.get_rect() == edited_rect, "Opening modal preserves edited scene panel geometry")
	for name in ["Create", "Confirm", "Protocol", "Advanced", "Preset", "Direct", "Profile"]:
		check(main.has_node("Modal/" + name + "/Dialog"), "Dialog scene owns its editable background: " + name)
	main.queue_free()
	page.queue_free()
	await settle()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
