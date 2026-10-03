extends Button
## Boolean Button-compatible control. Click anywhere toggles the selection.
## Left = false, right = true; no dragging required.
## One tab stop; Space/Enter toggle, Left/Right choose a value.
const DURATION := 0.20
var off_text := "关"
var on_text := "开"
var _slide := 0.0:
	set(value):
		_slide = value
		queue_redraw()
var _tween: Tween
var _initialized := false

func _init() -> void:
	toggle_mode = true
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())

func _ready() -> void:
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
		_tween.tween_property(self, "_slide", target, DURATION)
	else:
		_slide = target
	_initialized = true
	queue_redraw()

func _exit_tree() -> void:
	if _tween: _tween.kill()

func _draw() -> void:
	var inset := 4.0
	var track := Rect2(Vector2.ZERO, size)
	draw_rect(track, Color(0.84, 0.84, 0.81))
	draw_rect(track, Color(0.38, 0.38, 0.36), false, 2.0)
	var half := maxf(0, (size.x - inset * 2) / 2.0)
	draw_rect(Rect2(Vector2(inset + half * _slide, inset), Vector2(half, maxf(0, size.y - inset * 2))), Color(0.14, 0.14, 0.14))
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	for index in range(2):
		var caption := on_text if index else off_text
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var point := Vector2(size.x * (0.25 + index * 0.5) - width / 2, (size.y - font.get_height(font_size)) / 2 + font.get_ascent(font_size))
		var amount := _slide if index else 1.0 - _slide
		var color := Color(0.16, 0.16, 0.16).lerp(Color(0.98, 0.98, 0.96), amount)
		if disabled: color.a = 0.45
		draw_string(font, point, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	if has_focus(): draw_rect(track.grow(5), Color(0.48, 0.48, 0.46), false, 3.0)
