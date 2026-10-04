@tool
extends Button
const Config = preload("res://ui/theme/ui_config.gd")
## Boolean Button-compatible control. Click anywhere toggles the selection.
## Left = false, right = true; no dragging required.
## One tab stop; Space/Enter toggle, Left/Right choose a value.
@export var use_global_colors := true:
	set(value):
		use_global_colors = value
		queue_redraw()
@export var configuration: Config = preload("res://ui/theme/ui_config.tres"):
	set(value):
		if configuration != null and configuration.changed.is_connected(queue_redraw): configuration.changed.disconnect(queue_redraw)
		configuration = value
		_connect_config()
		queue_redraw()
@export var duration := 0.20
@export var inactive_text_color := Color(0.16, 0.16, 0.16)
@export var active_text_color := Color(0.98, 0.98, 0.96)
@export var focus_color := Color(0.48, 0.48, 0.46)
@export var off_text := "关"
@export var on_text := "开"
var _slide := 0.0:
	set(value):
		_slide = value
		queue_redraw()
var _tween: Tween
var _initialized := false
var _label_themes: Array[Theme] = []

func _connect_config() -> void:
	if configuration != null and not configuration.changed.is_connected(queue_redraw): configuration.changed.connect(queue_redraw)

func _ready() -> void:
	_connect_config()
	# Generated Themes are lower priority than the labels' native overrides.
	# Recreate on ready, so saving an editor preview cannot freeze an old color.
	_label_themes = [Theme.new(), Theme.new()]
	$Off.theme = _label_themes[0]
	$On.theme = _label_themes[1]
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(func(_value): sync_visual(true))
	sync_visual(false)

func _gui_input(event: InputEvent) -> void:
	if disabled: return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		button_pressed = event.is_action_pressed("ui_right")
		accept_event()

func sync_visual(animate: bool = true) -> void:
	var target := 1.0 if button_pressed else 0.0
	# Model synchronization after toggled must not restart an in-flight tween.
	if _initialized and is_equal_approx(target, get_meta("target", -1.0)): return
	set_meta("target", target)
	if _tween: _tween.kill()
	if animate and _initialized and is_inside_tree() and is_visible_in_tree():
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "_slide", target, duration)
	else:
		_slide = target
	_initialized = true
	queue_redraw()

func _exit_tree() -> void:
	if _tween: _tween.kill()

func _draw() -> void:
	# Scene nodes own appearance; only animated state is updated here.
	var selection: ColorRect = $Selection
	var inset := selection.offset_top
	selection.anchor_left = _slide * 0.5
	selection.anchor_right = 0.5 + _slide * 0.5
	selection.offset_left = inset * (1.0 - _slide)
	selection.offset_right = -inset * _slide
	$Off.text = off_text
	$On.text = on_text
	for index in range(2):
		var amount := _slide if index else 1.0 - _slide
		var inactive := configuration.text if use_global_colors else inactive_text_color
		var active := configuration.toggle_active_text if use_global_colors else active_text_color
		var color := inactive.lerp(active, amount)
		if disabled: color.a *= configuration.disabled_opacity
		if _label_themes.size() == 2 and (not _label_themes[index].has_color("font_color", "Label") or _label_themes[index].get_color("font_color", "Label") != color):
			_label_themes[index].set_color("font_color", "Label", color)
	if has_focus(): draw_rect(Rect2(Vector2.ZERO, size).grow(5), configuration.focus if use_global_colors else focus_color, false, 3.0)
