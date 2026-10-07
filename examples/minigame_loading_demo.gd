extends Control
const Bindings = preload("res://settings/demo_bindings.gd")

func _ready() -> void:
	# Set up only the sample actions if no application-owned binding exists.
	for spec in [["party_demo_jump", KEY_SPACE], ["party_demo_interact", KEY_E], ["party_demo_move_forward", KEY_W], ["party_demo_move_left", KEY_A], ["party_demo_move_back", KEY_S], ["party_demo_move_right", KEY_D]]:
		if not InputMap.has_action(spec[0]): Bindings.apply_value([spec[1], 0], spec[0])
	$Page.back_text = "← 返回主菜单"
	$Page.back_requested.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	$Driver.bind_page($Page)
	$Driver.begin()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		capture()

func capture() -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://screenshots/20_minigame_loading.png")
	print("SCREENSHOT ", path, " error=", get_viewport().get_texture().get_image().save_png(path))
