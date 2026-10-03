extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.get_node("Home/Exit").pressed.emit()
	assert(ui.modal_kind == "Confirm")
	print("PASS Confirmation open; invoking actual quit signal")
	ui.get_node("Modal/Confirm/Quit").pressed.emit()
