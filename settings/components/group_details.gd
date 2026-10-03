@tool
extends MarginContainer
## Geometry follows the actual arranged Controls, including ancestor boundaries.
## The scene still owns the gutter, line position, thickness and color.
func _process(_delta: float) -> void:
	var line: Line2D = $HierarchyLine
	var has_visible_rows := false
	for child in $Rows.get_children():
		if child is Control and child.visible:
			has_visible_rows = true
			break
	line.visible = has_visible_rows
	if not is_visible_in_tree() or not line.visible: return
	if line.get_point_count() != 2: return
	var endpoint := line.to_local(Vector2(global_position.x, divider_boundary_y()))
	var end := Vector2(line.get_point_position(0).x, endpoint.y)
	if line.get_point_position(1) != end: line.set_point_position(1, end)

func divider_boundary_y() -> float:
	var container := get_parent()
	if container is VBoxContainer:
		for index in range(get_index() + 1, container.get_child_count()):
			var sibling := container.get_child(index) as Control
			if sibling == null or not sibling.visible: continue
			if sibling is ColorRect and sibling.has_node("HierarchyConnection"):
				return (sibling.get_global_transform() * Vector2(0, sibling.size.y / 2.0)).y
			# Notes and other intentional boundaries do not acquire extra ink.
			return (get_global_transform() * Vector2(0, size.y)).y
		# A final nested group shares its parent's closing boundary, if present.
		var ancestor := container.get_parent()
		if container.name == "Rows" and ancestor != null and ancestor.has_method("divider_boundary_y"):
			return ancestor.divider_boundary_y()
	return (get_global_transform() * Vector2(0, size.y)).y
