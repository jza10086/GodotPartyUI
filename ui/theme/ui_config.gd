@tool
class_name PartyUIConfig
extends Resource
## Shared visual tokens. Edit ui_config.tres in the Inspector.
## Geometry stays in scenes. Every Color includes an independently editable alpha.

@export_group("Typography")
@export var font: Font = preload("res://assets/NotoSansSC-UI.otf"): 
	set(value):
		if font != null and font.changed.is_connected(emit_changed): font.changed.disconnect(emit_changed)
		font = value
		if font != null and not font.changed.is_connected(emit_changed): font.changed.connect(emit_changed)
		emit_changed()
		
## 微观大小（没有注释，我不知道micro_size改的是什么的size）
## 这是一段micro_size的注释
@export_range(8, 160, 1) var micro_size := 18:
	set(value):
		micro_size = value
		emit_changed()
@export_range(8, 160, 1) var debug_size := 19:
	set(value):
		debug_size = value
		emit_changed()
@export_range(8, 160, 1) var meta_size := 20:
	set(value):
		meta_size = value
		emit_changed()
@export_range(8, 160, 1) var detail_size := 21:
	set(value):
		detail_size = value
		emit_changed()
@export_range(8, 160, 1) var note_size := 22:
	set(value):
		note_size = value
		emit_changed()
@export_range(8, 160, 1) var secondary_size := 23:
	set(value):
		secondary_size = value
		emit_changed()
@export_range(8, 160, 1) var body_size := 24:
	set(value):
		body_size = value
		emit_changed()
@export_range(8, 160, 1) var player_size := 25:
	set(value):
		player_size = value
		emit_changed()
@export_range(8, 160, 1) var setting_size := 26:
	set(value):
		setting_size = value
		emit_changed()
@export_range(8, 160, 1) var action_size := 28:
	set(value):
		action_size = value
		emit_changed()
@export_range(8, 160, 1) var section_size := 30:
	set(value):
		section_size = value
		emit_changed()
@export_range(8, 160, 1) var subheading_size := 38:
	set(value):
		subheading_size = value
		emit_changed()
@export_range(8, 160, 1) var compact_title_size := 40:
	set(value):
		compact_title_size = value
		emit_changed()
@export_range(8, 160, 1) var dialog_title_size := 42:
	set(value):
		dialog_title_size = value
		emit_changed()
@export_range(8, 160, 1) var display_size := 48:
	set(value):
		display_size = value
		emit_changed()
@export_range(8, 160, 1) var page_title_size := 58:
	set(value):
		page_title_size = value
		emit_changed()
@export_range(8, 160, 1) var brand_size := 72:
	set(value):
		brand_size = value
		emit_changed()

@export_group("Text and states")
@export var text := Color(0.16, 0.16, 0.16, 1):
	set(value):
		text = value
		emit_changed()
@export var text_hover := Color(0.1, 0.1, 0.1, 1):
	set(value):
		text_hover = value
		emit_changed()
@export var text_disabled := Color(0.40, 0.40, 0.38, 1):
	set(value):
		text_disabled = value
		emit_changed()
@export var text_on_primary := Color(0.96, 0.96, 0.94, 1):
	set(value):
		text_on_primary = value
		emit_changed()
@export var error := Color(0.65, 0.15, 0.12, 1):
	set(value):
		error = value
		emit_changed()
@export var success := Color(0.2, 0.55, 0.3, 1):
	set(value):
		success = value
		emit_changed()
@export var demo_inactive := Color(0.55, 0.25, 0.25, 1):
	set(value):
		demo_inactive = value
		emit_changed()
@export var info := Color(0.2, 0.4, 0.65, 1):
	set(value):
		info = value
		emit_changed()

@export_group("Surfaces and controls")
@export var surface := Color(0.965, 0.965, 0.945, 1):
	set(value):
		surface = value
		emit_changed()
@export var muted_surface := Color(0.84, 0.84, 0.81, 1):
	set(value):
		muted_surface = value
		emit_changed()
@export var primary := Color(0.14, 0.14, 0.14, 1):
	set(value):
		primary = value
		emit_changed()
@export var hover_surface := Color(0.73, 0.73, 0.70, 1):
	set(value):
		hover_surface = value
		emit_changed()
@export var border := Color(0.25, 0.25, 0.24, 1):
	set(value):
		border = value
		emit_changed()
@export var hover_border := Color(0.1, 0.1, 0.1, 1):
	set(value):
		hover_border = value
		emit_changed()
@export var focus := Color(0.48, 0.48, 0.46, 1):
	set(value):
		focus = value
		emit_changed()
@export var divider := Color(0.65, 0.65, 0.62, 1):
	set(value):
		divider = value
		emit_changed()
@export var selection := Color(0.48, 0.48, 0.46, 0.4):
	set(value):
		selection = value
		emit_changed()
@export var toggle_border := Color(0.38, 0.38, 0.36, 1):
	set(value):
		toggle_border = value
		emit_changed()
@export var toggle_active_text := Color(0.98, 0.98, 0.96, 1):
	set(value):
		toggle_active_text = value
		emit_changed()

@export_group("Pages and overlays")
@export var page_background := Color(0.91, 0.91, 0.90, 1):
	set(value):
		page_background = value
		emit_changed()
@export var menu_backdrop := Color(0.965, 0.965, 0.945, 0.96):
	set(value):
		menu_backdrop = value
		emit_changed()
@export var rooms_backdrop := Color(0.965, 0.965, 0.945, 0.97):
	set(value):
		rooms_backdrop = value
		emit_changed()
@export var lobby_backdrop := Color(0.965, 0.965, 0.945, 0.98):
	set(value):
		lobby_backdrop = value
		emit_changed()
@export var status_backdrop := Color(0.965, 0.965, 0.945, 0.97):
	set(value):
		status_backdrop = value
		emit_changed()
@export var modal_overlay := Color(0.08, 0.08, 0.08, 0.62):
	set(value):
		modal_overlay = value
		emit_changed()
@export var capture_overlay := Color(0, 0, 0, 0.32):
	set(value):
		capture_overlay = value
		emit_changed()
@export var ruler := Color(0.35, 0.35, 0.35, 0.6):
	set(value):
		ruler = value
		emit_changed()

@export_group("Display placeholder background")
@export var display_background := Color(0.91, 0.91, 0.90, 1):
	set(value):
		display_background = value
		emit_changed()
@export var display_far_left := Color(0.84, 0.84, 0.84, 1):
	set(value):
		display_far_left = value
		emit_changed()
@export var display_far_center := Color(0.86, 0.86, 0.86, 1):
	set(value):
		display_far_center = value
		emit_changed()
@export var display_far_right := Color(0.82, 0.82, 0.82, 1):
	set(value):
		display_far_right = value
		emit_changed()
@export var display_near_left := Color(0.77, 0.77, 0.77, 1):
	set(value):
		display_near_left = value
		emit_changed()
@export var display_near_right := Color(0.76, 0.76, 0.76, 1):
	set(value):
		display_near_right = value
		emit_changed()
@export var display_ground := Color(0.7, 0.7, 0.7, 1):
	set(value):
		display_ground = value
		emit_changed()
@export var display_horizon := Color(0.50, 0.50, 0.49, 1):
	set(value):
		display_horizon = value
		emit_changed()
@export var display_text := Color(0.39, 0.39, 0.38, 1):
	set(value):
		display_text = value
		emit_changed()
@export var display_caption := Color(0.42, 0.42, 0.41, 1):
	set(value):
		display_caption = value
		emit_changed()

@export_group("Animation")
## Multiplies the configured text alpha instead of replacing it.
@export_range(0.0, 1.0, 0.01) var disabled_opacity := 0.45:
	set(value):
		disabled_opacity = value
		emit_changed()
