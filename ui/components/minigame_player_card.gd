@tool
extends PanelContainer
## Editable player list row. State words, symbols and progress supplement semantic color.
const CONFIG = preload("res://ui/theme/ui_config.tres")
@export_range(1, 8) var slot_number := 1
@export var player_name := "等待加入"
@export_enum("empty", "loading", "not_ready", "ready") var state := "empty"
@export_range(0, 100) var progress := 0.0
@export var is_local := false
@export var avatar: Texture2D

func _ready() -> void:
	CONFIG.changed.connect(refresh)
	%Name.theme_changed.connect(_update_column_widths.call_deferred)
	%State.theme_changed.connect(_update_column_widths.call_deferred)
	refresh()

func set_player(data: Dictionary, local_id: String) -> void:
	player_name = str(data.get("name", "等待加入"))
	state = str(data.get("state", "empty"))
	progress = float(data.get("progress", 0.0))
	is_local = not data.is_empty() and str(data.get("id", "")) == local_id
	avatar = data.get("avatar") as Texture2D
	refresh()

func refresh() -> void:
	if not is_node_ready(): return
	var occupied := state != "empty"
	%Name.text = player_name if occupied else "等待加入"
	%Name.tooltip_text = %Name.text
	%LocalTag.text = "本机" if is_local else ("玩家 %02d" % slot_number if occupied else "空位 %02d" % slot_number)
	%Avatar.texture = avatar
	%Avatar.visible = avatar != null and occupied
	%AvatarText.visible = not %Avatar.visible
	%AvatarText.text = "%02d" % slot_number if occupied else "—"
	var role := "text_disabled"
	match state:
		"loading":
			%State.text = "◷ 加载中 · %d%%" % roundi(progress)
			role = "info"
		"not_ready": %State.text = "○ 未准备"
		"ready":
			%State.text = "✓ 已准备"
			role = "success"
		_: %State.text = "— 空位"
	_update_column_widths.call_deferred()
	%State.add_theme_color_override("font_color", CONFIG.get(role))
	%StatusLine.color_role = role
	%LocalTag.add_theme_color_override("font_color", CONFIG.primary if is_local else CONFIG.text_disabled)
	accessibility_name = "%s，%s%s" % [%Name.text, "本机，" if is_local else "", %State.text]

func _update_column_widths() -> void:
	if not is_node_ready(): return
	# All eight rows reserve the same status column, including after a font or
	# state change. Long names ellipsize without pushing the status out of view.
	var status_width := 0.0
	for label in ["◷ 加载中 · 99%", "○ 未准备", "✓ 已准备", "— 空位"]:
		status_width = maxf(status_width, %State.get_theme_font("font").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, %State.get_theme_font_size("font_size")).x)
	%State.custom_minimum_size.x = ceilf(status_width)
	%Name.custom_minimum_size.x = ceilf(%Name.get_theme_font("font").get_string_size("玩家名称", HORIZONTAL_ALIGNMENT_LEFT, -1, %Name.get_theme_font_size("font_size")).x)
