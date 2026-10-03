extends SceneTree
var failures := 0
var checks := 0
var ui: Control
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL " + title)
	else:
		print("PASS ", title)
func settle() -> void:
	for i in range(4):
		await process_frame
func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.show_page("Settings")
	var tabs: TabContainer = ui.get_node("Settings/Tabs")
	ui.get_node("Settings/Tabs/UI/Padding/Content/WindowOptions").button_pressed = true
	for index in range(3):
		tabs.current_tab = index
		await settle()
		var scroll: ScrollContainer = tabs.get_current_tab_control()
		check(scroll.clip_contents, "Content clipped by real scroll viewport " + scroll.name)
		check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "No horizontal overflow " + scroll.name)
		var content: VBoxContainer = scroll.get_node("Padding/Content")
		for row_node in content.find_children("*Row", "HBoxContainer", true, false):
			if not row_node.is_visible_in_tree():
				continue
			var center: float = row_node.get_global_rect().get_center().y
			for field in row_node.get_children():
				check(absf(field.get_global_rect().get_center().y - center) < 1.0, "Centered " + scroll.name + "/" + row_node.name + "/" + field.name)
				check(field.get_global_rect().end.x <= scroll.get_global_rect().end.x - 24, "No field horizontal clipping " + field.name)
		check(content.find_children("*Divider", "ColorRect", true, false).size() >= 2, "Fine row/group dividers " + scroll.name)
		if index != 1:
			check(scroll.get_v_scroll_bar().max_value <= scroll.get_v_scroll_bar().page, "Short content has no artificial overflow " + scroll.name)
	tabs.current_tab = 1
	await settle()
	var scroll: ScrollContainer = tabs.get_current_tab_control()
	var bar := scroll.get_v_scroll_bar()
	print("UI viewport ", scroll.size, " content ", bar.max_value, " page ",bar.page)
	check(bar.max_value > bar.page, "Expanded window options naturally overflow")
	var fixed_tab_y := tabs.get_tab_bar().global_position.y
	var fixed_back_y: float = ui.get_node("Settings/Back").global_position.y
	var fixed_debug_y: float = ui.get_node("Status").global_position.y
	var volume: SpinBox = scroll.get_node("Padding/Content/VolumeRow/VolumeValue")
	var old_value := volume.value
	var top_y := volume.global_position.y
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = volume.get_global_rect().get_center()
	ui._input(wheel)
	await settle()
	check(scroll.scroll_vertical > 0, "Wheel over numeric field scrolls content")
	check(volume.value == old_value, "Wheel does not change numeric value")
	check(volume.global_position.y < top_y, "Visible field moves upward after wheel")
	check(tabs.get_tab_bar().global_position.y == fixed_tab_y, "Tabs stay fixed")
	check(ui.get_node("Settings/Back").global_position.y == fixed_back_y, "Back stays fixed")
	check(ui.get_node("Status").global_position.y == fixed_debug_y, "Debug stays fixed")
	scroll.scroll_vertical = 10000
	await settle()
	var note: Label = scroll.get_node("Padding/Content/Note")
	check(note.get_global_rect().end.y <= scroll.get_global_rect().end.y, "Last help text fully reachable without clipping")
	# Recheck the same real layout in a shorter content viewport without filler rows.
	tabs.size.y = 520
	await settle()
	scroll.scroll_vertical = 10000
	await settle()
	check(scroll.scroll_vertical > 200, "Smaller viewport exposes real scroll range")
	check(note.get_global_rect().end.y <= scroll.get_global_rect().end.y, "Small viewport reaches final text")
	ui.get_node("Settings/Tabs/UI/Padding/Content/WindowOptions").button_pressed = false
	await settle()
	check(not scroll.get_node("Padding/Content/WindowDetails").visible, "Collapsing removes nested rows from layout")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
