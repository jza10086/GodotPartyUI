@tool
extends MarginContainer
## Keep the editor-authored hierarchy line as tall as the visible child rows.
func _ready() -> void:
	resized.connect(_resize_line)
	_resize_line()

func _resize_line() -> void:
	var line: Line2D = $HierarchyLine
	if line.get_point_count() == 2:
		line.set_point_position(1, Vector2(line.get_point_position(0).x, size.y))
