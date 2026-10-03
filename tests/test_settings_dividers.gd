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
	check(lines(content()).size() == 1 and lines(children).is_empty(), "Top-level group closing boundary remains while nested sibling rows have no long separators")
	var nested_rows: Control = children.get_node("subgroupDetails/Rows")
	check(lines(nested_rows).is_empty(), "Deeply nested ordinary rows use branches without long separators")
	page.get_control("group").button_pressed = false
	check(lines(nested_rows).is_empty(), "Collapsing ancestor leaves nested separators hidden")
	page.get_control("group").button_pressed = true
	check(lines(nested_rows).is_empty(), "Reopening ancestor does not restore ordinary nested separators")
	check(page.add_option("Test", {"id":"five", "type":"label"}, "subgroup"), "Insert nested row dynamically")
	check(lines(content().get_node("groupDetails/Rows/subgroupDetails/Rows")).is_empty(), "Dynamic nested insertion keeps ordinary nested separators hidden")
	setup([
		{"id":"show", "type":"toggle", "value":true},
		{"id":"mixed", "type":"group", "expanded":true, "children":[
			{"id":"pick", "type":"select", "items":[{"label":"One", "value":1}]},
			{"id":"switch", "type":"toggle"},
			{"id":"value", "type":"number", "visible_when":{"id":"show", "equals":true}},
			{"id":"slide", "type":"slider"},
			{"id":"text", "type":"label"},
			{"id":"act", "type":"action"},
			{"id":"keys", "type":"keybinding", "expanded":true, "children":[
				{"id":"key1", "type":"keybinding"}, {"id":"key2", "type":"keybinding"}]},
			{"id":"after_keys", "type":"number"},
			{"id":"manual_nested", "type":"divider"},
			{"id":"last_nested", "type":"number"}]},
		{"id":"after_mixed", "type":"number"}
	])
	var mixed: Control = content().get_node("mixedDetails/Rows")
	check(lines(mixed, true).size() == 1, "Mixed ordinary settings retain only the expanded child closing boundary")
	check(lines(mixed.get_node("keysDetails/Rows")).is_empty(), "Keybinding siblings and ordinary siblings share separator-free folded style")
	check(lines(mixed).has(page.get_control("manual_nested")), "Explicit nested divider remains author-controlled")
	check(mixed.get_node("AutoDivider_after_keys").visible, "Expanded keybinding child retains its closing boundary")
	page.set_expanded("keys", false)
	check(lines(mixed, true).is_empty(), "Collapsed nested group no longer leaves a closing boundary")
	page.set_expanded("keys", true)
	check(lines(mixed, true).size() == 1, "Reopening nested group restores only its closing boundary")
	page.set_value("show", false)
	check(lines(mixed, true).size() == 1 and not mixed.get_node("AutoDivider_value").visible, "Conditional hide does not add sibling separators")
	page.set_value("show", true)
	check(lines(mixed, true).size() == 1 and not mixed.get_node("AutoDivider_value").visible, "Conditional restore does not add sibling separators")
	check(lines(content(), true).size() == 2, "Top-level ordinary and group closing separators are preserved")
	page.set_expanded("mixed", false)
	check(lines(content(), true).size() == 2, "Collapsed top-level group retains ordinary top-level separators")
	page.set_expanded("mixed", true)
	check(page.add_option("Test", {"id":"new_nested", "type":"number"}, "mixed"), "Runtime mixed-group insertion succeeds")
	mixed = content().get_node("mixedDetails/Rows")
	check(not mixed.get_node("AutoDivider_new_nested").visible and lines(mixed, true).size() == 1, "Runtime insertion preserves separator-free ordinary siblings and child closing boundary")
	page.clear()
	check(page.get_node("Tabs").get_child_count() == 0, "Clear removes generated separators with their content")
	setup([{"id":"only", "type":"toggle"}])
	check(lines(content()).is_empty(), "Reconfigure after clear leaves no stale separators")
	page.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
