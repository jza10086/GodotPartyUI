extends SceneTree
# Headless geometry regression for the annotated folding-tree connectors.
# Run: godot --headless --path . --script tests/test_settings_connected_dividers.gd
var checks := 0
var failures := 0
var page: Control
const EPSILON := 0.06

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)

func near(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= EPSILON

func settle() -> void:
	for _frame in range(8):
		await process_frame

func content() -> Control:
	return page.get_node("Tabs/Test/Padding/Content")

func setup(options: Array, label: String) -> void:
	check(page.configure([{"id":"Test", "options":options}]), label)

func spine(details: Control) -> Line2D:
	return details.get_node("HierarchyLine")

func point_global(line: Line2D, index: int) -> Vector2:
	return line.to_global(line.get_point_position(index))

func end_global(details: Control) -> Vector2:
	return point_global(spine(details), 1)

func middle_y(control: Control) -> float:
	return (control.get_global_transform() * Vector2(0, control.size.y / 2.0)).y

func bottom_y(control: Control) -> float:
	return (control.get_global_transform() * Vector2(0, control.size.y)).y

func is_details(node: Node) -> bool:
	return node is Control and node.has_node("HierarchyLine") and node.has_node("Rows")

func visible_rows(details: Control) -> Array:
	# Independent expected list, rather than using the implementation as its oracle.
	var result: Array = []
	for child in details.get_node("Rows").get_children():
		if child is Control and child.visible and not child is ColorRect and not is_details(child):
			result.append(child)
	return result

func expected_closing_details(details: Control) -> Control:
	var children: Array = details.get_node("Rows").get_children()
	children.reverse()
	for child in children:
		if not child is Control or not child.visible:
			continue
		if is_details(child) and not visible_rows(child).is_empty():
			return expected_closing_details(child)
		break
	return details

func assert_closing(divider: Control, expected_details: Control, label: String) -> void:
	var stroke := divider.get_node_or_null("Stroke") as ColorRect
	check(stroke != null, label + ": divider has a separate Stroke")
	if stroke == null:
		return
	var expected_x: float = divider.global_position.x if expected_details == null else point_global(spine(expected_details), 0).x
	check(near(stroke.global_position.x, expected_x), label + ": closing ink starts exactly at the expected spine")
	check(near(stroke.get_global_rect().end.x, divider.get_global_rect().end.x), label + ": right edge is preserved")

func audit_details(details: Control, label: String) -> void:
	var expected := visible_rows(details)
	var line := spine(details)
	var template := details.get_node_or_null("BranchTemplate") as Line2D
	var header_line := details.get_node_or_null("HeaderConnection") as Line2D
	var branches := details.get_node_or_null("Branches")
	check(details.has_method("get_visible_rows"), label + ": visible-row API exists")
	if details.has_method("get_visible_rows"):
		check(details.get_visible_rows() == expected, label + ": visible-row API excludes dividers and nested Details")
	check(template != null and not template.visible, label + ": editable branch template remains hidden")
	check(branches != null, label + ": branches have their own container")
	if branches == null or template == null:
		return
	check(line.visible == not expected.is_empty(), label + ": spine visibility matches real children")
	check(header_line != null, label + ": header connection is a scene-editable Line2D")
	if header_line != null:
		check(header_line.visible == not expected.is_empty(), label + ": header connection visibility matches real children")
	var visible_branches := 0
	for branch in branches.get_children():
		if branch is CanvasItem and branch.visible:
			visible_branches += 1
	check(visible_branches == expected.size(), label + ": one visible branch per child, including notes")
	if expected.is_empty():
		return
	check(line.get_point_count() == 2, label + ": spine has exactly two endpoints")
	if line.get_point_count() != 2:
		return
	check(near(point_global(line, 0).x, point_global(line, 1).x), label + ": spine stays vertical")
	var header: Button = details.get("header_control")
	check(header != null, label + ": parent expander is assigned")
	if header != null and header.icon != null:
		var icon_size := header.icon.get_size()
		var expected_start := header.get_global_transform() * Vector2(0, header.size.y / 2.0 + icon_size.y)
		check(near(point_global(line, 0).y, expected_start.y), label + ": spine begins below its parent arrow")
		if header_line != null:
			check(header_line.get_point_count() == 2, label + ": header connection has exactly two endpoints")
			if header_line.get_point_count() == 2:
				var icon_x := header.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT) + icon_size.x / 2.0
				var expected_icon := header.get_global_transform() * Vector2(icon_x, header.size.y / 2.0)
				check(point_global(header_line, 0).distance_to(expected_icon) <= EPSILON, label + ": connection begins at the actual arrow center")
				check(point_global(header_line, 1).distance_to(point_global(line, 0)) <= EPSILON, label + ": header connection ends exactly on the spine")
		check(point_global(line, 0).y < details.global_position.y, label + ": no gap between arrow and details")
	for row in expected:
		var branch := branches.get_node_or_null(NodePath(row.name)) as Line2D
		check(branch != null, label + ": branch exists for " + str(row.name))
		if branch == null:
			continue
		check(branch.visible and branch.get_point_count() == 2, label + ": " + str(row.name) + " branch is a visible two-point line")
		if branch.get_point_count() != 2:
			continue
		var start := point_global(branch, 0)
		var finish := point_global(branch, 1)
		check(near(start.x, point_global(line, 0).x) and near(finish.x, row.global_position.x), label + ": " + str(row.name) + " branch joins spine to content edge")
		check(near(start.y, middle_y(row)) and near(finish.y, middle_y(row)), label + ": " + str(row.name) + " branch uses the actual row center")
		check(branch.width == template.width and branch.default_color == template.default_color, label + ": " + str(row.name) + " uses editable template styling")
	check(details.has_method("closing_spine_global"), label + ": closing-spine API exists")
	if details.has_method("closing_spine_global"):
		var closing: Vector2 = details.closing_spine_global()
		check(near(closing.x, point_global(spine(expected_closing_details(details)), 0).x), label + ": closing-spine API resolves the deepest final visible child")

func audit_divider(divider: ColorRect, label: String) -> void:
	var stroke := divider.get_node_or_null("Stroke") as ColorRect
	check(stroke != null and not divider.has_node("HierarchyConnection"), label + ": Stroke replaces the old additive gutter connector")
	if stroke == null:
		return
	check(near(divider.self_modulate.a, 0.0) and stroke.is_visible_in_tree() and stroke.color.a > 0.0, label + ": layout root is transparent while Stroke remains visible")
	check(stroke.color == divider.color and near(stroke.size.y, divider.size.y), label + ": divider color and thickness are preserved")
	check(stroke.mouse_filter == Control.MOUSE_FILTER_IGNORE and divider.mouse_filter == Control.MOUSE_FILTER_IGNORE, label + ": divider cannot intercept input")
	check(near(stroke.global_position.y, divider.global_position.y), label + ": stroke stays on its layout row")
	var rows := divider.get_parent()
	var expected_details: Control = null
	if rows.name == "Rows" and is_details(rows.get_parent()):
		expected_details = rows.get_parent()
	for index in range(divider.get_index() - 1, -1, -1):
		var previous := rows.get_child(index) as Control
		if previous == null or not previous.visible:
			continue
		if is_details(previous) and not visible_rows(previous).is_empty():
			expected_details = expected_closing_details(previous)
		break
	assert_closing(divider, expected_details, label)

func audit(node: Node, label: String) -> void:
	if node is Control and node.is_visible_in_tree():
		if is_details(node):
			audit_details(node, label + "/" + str(node.name))
		elif node is ColorRect and node.get_parent() is VBoxContainer:
			audit_divider(node, label + "/" + str(node.name))
	for child in node.get_children():
		audit(child, label)

func run() -> void:
	page = load("res://settings/settings_page.tscn").instantiate()
	root.add_child(page)
	setup([
		{"id":"show", "type":"toggle", "value":true},
		{"id":"outer", "type":"group", "expanded":true, "children":[
			{"id":"a", "type":"number"},
			{"id":"conditional", "type":"number", "visible_when":{"id":"show", "equals":true}},
			{"id":"outer_note", "type":"note", "text":"Parent explanation", "height":76},
			{"id":"binding", "type":"keybinding", "expanded":true, "children":[
				{"id":"child", "type":"keybinding"},
				{"id":"deep", "type":"group", "expanded":true, "children":[
					{"id":"x", "type":"number"},
					{"id":"explicit", "type":"divider"},
					{"id":"y", "type":"number"},
					{"id":"deep_note", "type":"note", "text":"Final explanation", "height":124}]}]}]},
		{"id":"after", "type":"number", "visible_when":{"id":"show", "equals":true}}
	], "Configure three-level mixed group/keybinding hierarchy")
	await settle()
	var outer: Control = content().get_node("outerDetails")
	var binding: Control = outer.get_node("Rows/bindingDetails")
	var deep: Control = binding.get_node("Rows/deepDetails")
	var closing: Control = content().get_node("AutoDivider_after")
	for details in [outer, binding, deep]:
		check(near(end_global(details).y, middle_y(closing)), "Every final nested spine retains its continuous ancestor closing height")
	assert_closing(closing, deep, "Three-level final boundary")
	check(closing.get_node("Stroke").global_position.x > closing.global_position.x, "Closing divider removes the surplus left-hand segment")
	audit(content(), "Expanded")

	page.set_value("show", false)
	await settle()
	check(not closing.visible, "Conditional closing boundary hides")
	for details in [outer, binding, deep]:
		check(near(end_global(details).y, bottom_y(outer)), "Without a trailing separator all final spines stop at the ancestor bottom")
	var hidden_branch := outer.get_node_or_null("Branches/conditional") as CanvasItem
	check(hidden_branch == null or not hidden_branch.visible, "Conditionally hidden child leaves no branch")
	audit(content(), "Condition hidden")

	page.set_value("show", true)
	page.set_expanded("binding", false)
	await settle()
	check(not spine(binding).is_visible_in_tree() and not binding.get_node("Branches").is_visible_in_tree() and not binding.get_node("HeaderConnection").is_visible_in_tree(), "Collapse hides nested spine, header connection and branches")
	check(near(end_global(outer).y, middle_y(closing)), "Outer closing height follows collapsed content")
	assert_closing(closing, outer, "Collapsed nested keybinding")
	audit(content(), "Binding collapsed")
	page.set_expanded("binding", true)
	page.set_expanded("deep", false)
	await settle()
	assert_closing(closing, binding, "Collapsed deepest group")
	page.set_expanded("deep", true)
	page.set_expanded("outer", false)
	await settle()
	assert_closing(closing, null, "Collapsed whole hierarchy")
	check(not outer.get_node("Branches/a").is_visible_in_tree(), "Collapsing the parent also hides the first child branch")
	page.set_expanded("outer", true)
	await settle()
	audit(content(), "Reopened")

	# Scene-authored geometry and style remain editable; no fixed gutter offsets.
	outer.add_theme_constant_override("margin_left", 68)
	outer.get_node("Rows").add_theme_constant_override("separation", 23)
	spine(outer).set_point_position(0, Vector2(31.5, 0))
	var template: Line2D = outer.get_node("BranchTemplate")
	template.width = 3.25
	template.default_color = Color(0.2, 0.4, 0.7, 0.8)
	var header_line: Line2D = outer.get_node("HeaderConnection")
	header_line.width = 2.5
	header_line.default_color = Color(0.7, 0.2, 0.4, 0.9)
	page.get_control("outer_note").custom_minimum_size.y = 117
	var explicit: ColorRect = page.get_control("explicit")
	explicit.color = Color(0.4, 0.5, 0.6, 0.75)
	explicit.custom_minimum_size.y = 3
	page.scale = Vector2(1.25, 1.1)
	page.size = Vector2(1500, 900)
	await settle()
	check(near(spine(outer).get_point_position(0).x, 31.5), "Authored spine x survives updates")
	check(header_line.width == 2.5 and header_line.default_color == Color(0.7, 0.2, 0.4, 0.9), "Authored header connection style survives geometry updates")
	check(near(explicit.size.y, 3), "Authored divider thickness participates in layout")
	audit(content(), "Edited gutter, row height, spacing, style and nonuniform scale")
	check(near(end_global(deep).y, middle_y(closing)), "Scaled ancestor endpoint remains exact")
	var scroll: ScrollContainer = page.get_node("Tabs/Test")
	scroll.scroll_vertical = 200
	await settle()
	check(scroll.scroll_vertical > 0, "Scroll fixture actually scrolls")
	audit(content(), "Scrolled")
	check(near(end_global(deep).y, middle_y(closing)), "Scrolling keeps boundary endpoints attached")

	var old_outer := outer
	check(page.add_option("Test", {"id":"added", "type":"number"}, "deep"), "Dynamic nested insertion succeeds")
	await settle()
	check(not is_instance_valid(old_outer), "Dynamic rebuilding releases obsolete connector geometry")
	outer = content().get_node("outerDetails")
	binding = outer.get_node("Rows/bindingDetails")
	deep = binding.get_node("Rows/deepDetails")
	closing = content().get_node("AutoDivider_after")
	check(deep.has_node("Branches/added"), "Dynamic last child receives its own branch")
	assert_closing(closing, deep, "Rebuilt final boundary")
	audit(content(), "Rebuilt")

	setup([
		{"id":"show", "type":"toggle", "value":true},
		{"id":"outer", "type":"group", "expanded":true, "children":[
			{"id":"inner", "type":"group", "expanded":true, "children":[
				{"id":"only", "type":"number", "visible_when":{"id":"show", "equals":true}}]},
			{"id":"sibling", "type":"number"}]},
		{"id":"after", "type":"number"}
	], "Configure nonfinal nested group")
	await settle()
	outer = content().get_node("outerDetails")
	var inner: Control = outer.get_node("Rows/innerDetails")
	var next_line: Control = outer.get_node("Rows/AutoDivider_sibling")
	closing = content().get_node("AutoDivider_after")
	check(near(end_global(inner).y, middle_y(next_line)), "Nonfinal nested spine ends at its own next separator")
	assert_closing(next_line, inner, "Nested group immediately before a sibling")
	assert_closing(closing, outer, "Later ordinary sibling prevents stale deepest indentation")
	audit(content(), "Nonfinal nested group")
	page.set_value("show", false)
	await settle()
	check(not spine(inner).visible, "All children hidden leaves no dangling spine")
	assert_closing(next_line, outer, "Empty conditional group uses containing spine")
	audit(content(), "All nested children hidden")
	page.set_value("show", true)
	await settle()
	check(spine(inner).visible, "Spine reappears with visible children")
	check(near(end_global(inner).y, middle_y(next_line)), "Reappearing spine reconnects to its closing boundary")
	assert_closing(next_line, inner, "Restored conditional group")

	setup([
		{"id":"empty", "type":"group", "expanded":true, "children":[]},
		{"id":"empty_binding", "type":"keybinding", "expanded":true, "children":[]},
		{"id":"divider_only", "type":"group", "expanded":true, "children":[{"id":"rule", "type":"divider"}]},
		{"id":"note_only", "type":"group", "expanded":true, "children":[{"id":"note", "type":"note", "text":"Only a note"}]},
		{"id":"after", "type":"number"}
	], "Configure empty, divider-only and note-only groups")
	await settle()
	for group_name in ["emptyDetails", "empty_bindingDetails", "divider_onlyDetails"]:
		var empty: Control = content().get_node(group_name)
		check(not spine(empty).visible, group_name + ": empty content never leaves a dangling spine")
		check(empty.get_visible_rows().is_empty(), group_name + ": no real visible rows")
	var note_only: Control = content().get_node("note_onlyDetails")
	check(note_only.has_node("Branches/note"), "A sole explanation row still receives a branch")
	assert_closing(content().get_node("AutoDivider_after"), note_only, "Note-only closing boundary")
	audit(content(), "Empty and note-only groups")

	page.clear()
	await settle()
	check(page.get_node("Tabs").get_child_count() == 0, "Clear removes all connector geometry")
	setup([{"id":"single", "type":"number"}], "Reconfigure after clear")
	await settle()
	check(content().get_child_count() == 1, "Reconfigure after clear leaves no stale branches or separators")
	page.queue_free()
	await settle()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
