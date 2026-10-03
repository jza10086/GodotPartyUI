extends SceneTree
var checks := 0
var failures := 0
var page: Control
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ", message)
	else: failures += 1; push_error(message)
func content() -> Control: return page.get_node("Tabs/Test/Padding/Content")
func lines(parent: Control, automatic_only: bool = false) -> Array:
	var result: Array = []
	for child in parent.get_children():
		if child is ColorRect and child.visible and (not automatic_only or child.has_meta("automatic_row_divider")): result.append(child)
	return result
func setup(options: Array) -> void:
	check(page.configure([{"id":"Test", "options":options}]), "Configure divider fixture")
func run() -> void:
	page = load("res://settings/settings_page.tscn").instantiate()
	root.add_child(page)
	setup([
		{"id":"a", "type":"select", "items":[{"label":"One", "value":1}]},
		{"id":"b", "type":"toggle", "value":true},
		{"id":"c", "type":"number"},
		{"id":"d", "type":"slider"}
	])
	await process_frame
	check(lines(content()).size() == 3, "Arbitrary schema gets one separator per adjacent row without opt-in")
	for line in lines(content()):
		check(line.size.y == 1 and line.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Separator is one pixel and cannot intercept pointer input")
	check(content().get_child(0) is HBoxContainer and content().get_child(-1) is HBoxContainer, "No leading or trailing separator")
	check(page.get_values().size() == 4, "Generated separators do not enter public values")
	check(page.add_option("Test", {"id":"e", "type":"label", "value":"text"}) and lines(content()).size() == 4, "Runtime insertion also receives default separator")
	setup([
		{"id":"show", "type":"toggle", "value":true},
		{"id":"conditional", "type":"number", "visible_when":{"id":"show", "equals":true}},
		{"id":"last", "type":"number"}
	])
	check(lines(content()).size() == 2, "Visible conditional row has both neighboring lines")
	page.set_value("show", false)
	check(lines(content()).size() == 1, "Hiding middle row leaves exactly one line")
	page.set_value("show", true)
	check(lines(content()).size() == 2, "Showing middle row restores lines")
	setup([
		{"id":"first", "type":"number", "visible_when":{"id":"show", "equals":true}},
		{"id":"show", "type":"toggle", "value":false}
	])
	check(lines(content()).is_empty(), "Hidden first row does not leave leading separator")
	setup([
		{"id":"a", "type":"number"},
		{"id":"manual", "type":"divider"},
		{"id":"b", "type":"toggle"},
		{"id":"note", "type":"note", "text":"Section note"},
		{"id":"action", "type":"action"}
	])
	check(lines(content()).size() == 1 and lines(content(), true).is_empty(), "Explicit divider is not doubled and note boundaries preserve original layout")
	check(page.get_control("manual") == lines(content())[0], "Explicit divider retains ID and original public control")
	setup([
		{"id":"group", "type":"group", "expanded":true, "children":[
			{"id":"one", "type":"number"},
			{"id":"two", "type":"toggle"},
			{"id":"subgroup", "type":"group", "expanded":true, "children":[
				{"id":"three", "type":"number"},
				{"id":"four", "type":"action"}
			]}
		]},
		{"id":"last", "type":"number"}
	])
	var children := content().get_node("groupDetails/Rows")
	check(lines(content()).size() == 1 and lines(children).size() == 2, "Group headers and nested sibling rows receive default separators")
	var nested_line: Control = lines(children.get_node("subgroupDetails/Rows"))[0]
	check(nested_line.is_visible_in_tree(), "Deeply nested group receives a visible separator")
	page.get_control("group").button_pressed = false
	check(not nested_line.is_visible_in_tree(), "Collapsing ancestor hides its separators")
	page.get_control("group").button_pressed = true
	check(nested_line.is_visible_in_tree(), "Reopening ancestor restores separators")
	check(page.add_option("Test", {"id":"five", "type":"label"}, "subgroup"), "Insert nested row dynamically")
	check(lines(content().get_node("groupDetails/Rows/subgroupDetails/Rows")).size() == 2, "Dynamic nested insertion rebuilds correct separators")
	page.clear()
	check(page.get_node("Tabs").get_child_count() == 0, "Clear removes generated separators with their content")
	setup([{"id":"only", "type":"toggle"}])
	check(lines(content()).is_empty(), "Reconfigure after clear leaves no stale separators")
	page.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
