extends Label

func _make_custom_tooltip(for_text: String) -> Object:
	var tooltip := preload("res://settings/components/tooltip.tscn").instantiate()
	tooltip.text = for_text
	return tooltip
