extends Control
func _ready() -> void:
	$Driver.bind_page($Page)
	$Driver.begin(8 if "--eight-players" in OS.get_cmdline_user_args() else 4)
	$Page.back_requested.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		capture()
func capture() -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://screenshots/21_monopoly_game.png")
	print("SCREENSHOT ", path, " error=", get_viewport().get_texture().get_image().save_png(path))
