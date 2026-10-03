@tool
extends ColorRect
## Extend only the ink into the scene-authored gutter; never move the row.
func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	var connection: ColorRect = $HierarchyConnection
	var rows := get_parent()
	var details := rows.get_parent() if rows != null else null
	var spine := details.get_node_or_null("HierarchyLine") as Line2D if details != null else null
	connection.visible = spine != null and rows.name == "Rows" and spine.get_point_count() >= 2
	if not connection.visible: return
	var point := get_global_transform().affine_inverse() * spine.to_global(spine.get_point_position(0))
	connection.position = Vector2(minf(point.x, 0.0), 0)
	connection.size = Vector2(maxf(-point.x, 0.0), size.y)
	connection.color = color
