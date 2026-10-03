@tool
extends MarginContainer
## The scene owns gutter, stroke styling and branch template; actual arranged
## controls determine connections, so edited scenes and dynamic schemas agree.
var header_control: Button

func get_visible_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for child in $Rows.get_children():
		if child is Control and child.visible and not child.has_method("divider_boundary_y") and not child.has_node("Stroke"):
			rows.append(child)
	return rows

func _process(_delta: float) -> void:
	var line: Line2D = $HierarchyLine
	var rows := get_visible_rows()
	line.visible = not rows.is_empty()
	$Branches.visible = line.visible
	$HeaderConnection.visible = line.visible
	if not is_visible_in_tree(): return
	for branch in $Branches.get_children():
		branch.visible = false
	if not line.visible or line.get_point_count() != 2: return
	var start := line.get_point_position(0)
	# Preserve the authored spine x and join the actual icon with a short
	# slanted lead-in; their horizontal positions need not coincide.
	var header := header_control
	if not is_instance_valid(header):
		var previous := get_parent().get_child(get_index() - 1) if get_index() > 0 else null
		header = previous as Button
		if header == null and previous != null: header = previous.get_node_or_null("Function") as Button
	if is_instance_valid(header):
		var icon_size := header.icon.get_size() if header.icon != null else Vector2.ZERO
		var icon_center := Vector2(header.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT) + icon_size.x / 2.0, header.size.y / 2.0)
		start.y = line.to_local(header.get_global_transform() * Vector2(0, icon_center.y + icon_size.y)).y
		var lead: Line2D = $HeaderConnection
		lead.points = PackedVector2Array([lead.to_local(header.get_global_transform() * icon_center), lead.to_local(line.to_global(start))])
	else:
		$HeaderConnection.visible = false
	var endpoint := line.to_local(Vector2(global_position.x, divider_boundary_y()))
	line.set_point_position(0, start)
	line.set_point_position(1, Vector2(start.x, endpoint.y))
	for row in rows:
		var branch := $Branches.get_node_or_null(NodePath(row.name)) as Line2D
		if branch == null:
			branch = $BranchTemplate.duplicate() as Line2D
			branch.name = row.name
			$Branches.add_child(branch)
		branch.width = $BranchTemplate.width
		branch.default_color = $BranchTemplate.default_color
		branch.visible = true
		var destination := row.get_global_transform() * Vector2(0, row.size.y / 2.0)
		var end := branch.to_local(destination)
		var spine_x := branch.to_local(line.to_global(start)).x
		branch.points = PackedVector2Array([Vector2(spine_x, end.y), end])

## The closing separator starts at the final expanded child's spine, without
## drawing back into the preceding outer gutter (the erased red segment).
func closing_spine_global() -> Vector2:
	for index in range($Rows.get_child_count() - 1, -1, -1):
		var child := $Rows.get_child(index) as Control
		if child == null or not child.visible: continue
		if child.has_method("closing_spine_global") and not child.get_visible_rows().is_empty():
			return child.closing_spine_global()
		break
	var line: Line2D = $HierarchyLine
	return line.to_global(line.get_point_position(1))

func divider_boundary_y() -> float:
	var container := get_parent()
	if container is VBoxContainer:
		for index in range(get_index() + 1, container.get_child_count()):
			var sibling := container.get_child(index) as Control
			if sibling == null or not sibling.visible: continue
			if sibling is ColorRect and sibling.has_node("Stroke"):
				return (sibling.get_global_transform() * Vector2(0, sibling.size.y / 2.0)).y
			return (get_global_transform() * Vector2(0, size.y)).y
		var ancestor := container.get_parent()
		if container.name == "Rows" and ancestor != null and ancestor.has_method("divider_boundary_y"):
			return ancestor.divider_boundary_y()
	return (get_global_transform() * Vector2(0, size.y)).y
