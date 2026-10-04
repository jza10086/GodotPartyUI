@tool
extends StyleBoxFlat
const Config = preload("res://ui/theme/ui_config.gd")
## Disable global colors on a unique copy to keep a component-specific style.
@export var use_global_colors := true:
	set(value):
		use_global_colors = value
		notify_property_list_changed()
		_apply_colors()
@export_enum("surface", "muted_surface", "primary", "hover_surface", "focus", "toggle") var color_role := "surface":
	set(value):
		color_role = value
		_apply_colors()
@export var configuration: Config = preload("res://ui/theme/ui_config.tres"):
	set(value):
		if configuration != null and configuration.changed.is_connected(_apply_colors): configuration.changed.disconnect(_apply_colors)
		configuration = value
		_connect_config()
		_apply_colors()

func _init() -> void:
	_connect_config()
	# Native fields can be loaded before the script and its opt-out flag.
	# Wait for deserialization to finish, then resolve only global defaults.
	_apply_colors.call_deferred()

func _connect_config() -> void:
	if configuration != null and not configuration.changed.is_connected(_apply_colors): configuration.changed.connect(_apply_colors)

func _apply_colors() -> void:
	if not use_global_colors or configuration == null: return
	var fill: Color = Color.TRANSPARENT if color_role == "focus" else configuration.get("muted_surface" if color_role == "toggle" else color_role)
	var border: Color = configuration.focus if color_role == "focus" else (configuration.hover_border if color_role == "hover_surface" else (configuration.toggle_border if color_role == "toggle" else configuration.border))

	if bg_color != fill: bg_color = fill
	if border_color != border: border_color = border

func _validate_property(property: Dictionary) -> void:
	if use_global_colors and property.name in ["bg_color", "border_color"]: property.usage &= ~PROPERTY_USAGE_STORAGE
