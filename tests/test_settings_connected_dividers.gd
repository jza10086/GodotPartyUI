extends SceneTree
var checks := 0
var failures := 0
var page: Control
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ", message)
	else: failures += 1; push_error(message)
func settle() -> void:
	for i in range(8): await process_frame
func content() -> Control: return page.get_node("Tabs/Test/Padding/Content")
func end_global(details: Control) -> Vector2:
	var line: Line2D = details.get_node("HierarchyLine")
	return line.to_global(line.get_point_position(1))
func audit(node: Node, label: String) -> void:
	if node is ColorRect and node.has_node("HierarchyConnection") and node.is_visible_in_tree():
		var connection: ColorRect = node.get_node("HierarchyConnection")
		var rows := node.get_parent()
		var details := rows.get_parent()
		var spine := details.get_node_or_null("HierarchyLine") as Line2D
		if spine != null and rows.name == "Rows":
			var spine_x := spine.to_global(spine.get_point_position(0)).x
			check(connection.visible and is_equal_approx(connection.global_position.x, spine_x), label + ": horizontal ink meets its own spine")
			check(is_equal_approx(connection.get_global_rect().end.x, node.global_position.x), label + ": gutter joins original divider without a gap")
			check(connection.size.y == node.size.y and connection.color == node.color and connection.mouse_filter == Control.MOUSE_FILTER_IGNORE, label + ": thickness, color and pointer passthrough preserved")
		else: check(not connection.visible, label + ": top-level line has no gutter extension")
	for child in node.get_children(): audit(child, label)
func run() -> void:
	page = load("res://settings/settings_page.tscn").instantiate()
	root.add_child(page)
	check(page.configure([{"id":"Test", "options":[
		{"id":"show", "type":"toggle", "value":true},
		{"id":"outer", "type":"group", "expanded":true, "children":[
			{"id":"a", "type":"number"},
			{"id":"conditional", "type":"number", "visible_when":{"id":"show", "equals":true}},
			{"id":"binding", "type":"keybinding", "expanded":true, "children":[
				{"id":"child", "type":"keybinding"},
				{"id":"deep", "type":"group", "expanded":true, "children":[
					{"id":"x", "type":"number"}, {"id":"explicit", "type":"divider"}, {"id":"y", "type":"number"}]}]}]},
		{"id":"after", "type":"number", "visible_when":{"id":"show", "equals":true}}
	]}]), "Configure three-level hierarchy")
	await settle()
	var outer: Control = content().get_node("outerDetails")
	var binding: Control = outer.get_node("Rows/bindingDetails")
	var deep: Control = binding.get_node("Rows/deepDetails")
	var closing: Control = content().get_node("AutoDivider_after")
	var close_y := closing.global_position.y + closing.size.y / 2.0
	for details in [outer, binding, deep]:
		check(is_equal_approx(end_global(details).y, close_y), "Nested final spines reach ancestor closing separator")
	audit(content(), "Expanded")
	page.set_value("show", false)
	await settle()
	check(not closing.visible, "Conditional closing boundary hides")
	for details in [outer, binding, deep]:
		check(is_equal_approx(end_global(details).y, outer.global_position.y + outer.size.y), "No trailing separator: spines stop at parent bottom")
	audit(content(), "Condition hidden")
	page.set_value("show", true)
	page.set_expanded("binding", false)
	await settle()
	check(not binding.get_node("HierarchyLine").is_visible_in_tree(), "Collapse hides spine and all gutter connectors")
	check(is_equal_approx(end_global(outer).y, closing.global_position.y + closing.size.y / 2), "Outer closing connection follows collapsed height")
	page.set_expanded("binding", true)
	await settle()
	# Change the editable scene geometry at runtime: no fixed gutter offsets.
	outer.add_theme_constant_override("margin_left", 68)
	outer.get_node("Rows").add_theme_constant_override("separation", 23)
	outer.get_node("HierarchyLine").set_point_position(0, Vector2(31.5, 0))
	page.scale = Vector2(1.25, 1.25)
	page.size = Vector2(1500, 900)
	await settle()
	audit(content(), "Edited gutter, spacing, window and scale")
	check(is_equal_approx(end_global(deep).y, closing.global_position.y + closing.get_global_rect().size.y / 2), "Scaled ancestor endpoint remains exact")
	var scroll: ScrollContainer = page.get_node("Tabs/Test")
	scroll.scroll_vertical = 200
	await settle()
	audit(content(), "Scrolled")
	check(is_equal_approx(end_global(deep).y, closing.global_position.y + closing.get_global_rect().size.y / 2), "Scrolling keeps all boundary endpoints attached")
	check(page.add_option("Test", {"id":"added", "type":"number"}, "deep"), "Dynamic nested insertion succeeds")
	await settle()
	audit(content(), "Rebuilt")
	check(page.configure([{"id":"Test", "options":[
		{"id":"show", "type":"toggle", "value":true},
		{"id":"outer", "type":"group", "expanded":true, "children":[
			{"id":"inner", "type":"group", "expanded":true, "children":[
				{"id":"only", "type":"number", "visible_when":{"id":"show", "equals":true}}]},
			{"id":"sibling", "type":"number"}]}]}]), "Configure nonfinal nested group")
	await settle()
	var inner: Control = content().get_node("outerDetails/Rows/innerDetails")
	var next_line: Control = content().get_node("outerDetails/Rows/AutoDivider_sibling")
	check(is_equal_approx(end_global(inner).y, next_line.global_position.y + next_line.get_global_rect().size.y / 2), "Nonfinal nested spine ends at its own next separator")
	audit(content(), "Nonfinal nested group")
	page.set_value("show", false)
	await settle()
	check(not inner.get_node("HierarchyLine").visible, "No dangling spine when every child is conditionally hidden")
	page.set_value("show", true)
	await settle()
	check(inner.get_node("HierarchyLine").visible, "Spine reappears with visible children")
	check(is_equal_approx(end_global(inner).y, next_line.global_position.y + next_line.get_global_rect().size.y / 2), "Reappearing spine reconnects to boundary")
	page.clear()
	await settle()
	check(page.get_node("Tabs").get_child_count() == 0, "Clear removes all connection geometry")
	page.queue_free()
	await settle()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
