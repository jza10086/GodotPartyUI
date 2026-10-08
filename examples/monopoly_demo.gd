extends Node3D
func _ready() -> void:
	$Driver.bind_page($Overlay/HUD)
	$Driver.begin(8 if "--eight-players" in OS.get_cmdline_user_args() else 4)
	$DemoUI/Controls/Event.pressed.connect($Driver.preview_event)
	$DemoUI/Controls/Reset.pressed.connect(func(): $Driver.begin(8 if "--eight-players" in OS.get_cmdline_user_args() else 4))
	$DemoUI/Controls/Back.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	$Overlay/HUD.modal_visibility_changed.connect(func(open):
		for button in $DemoUI/Controls.get_children():
			if button is Button: button.disabled = open)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		capture()
		get_viewport().set_input_as_handled()
func capture() -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://screenshots/21_monopoly_game.png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	print("SCREENSHOT ", path, " error=", get_viewport().get_texture().get_image().save_png(path))
