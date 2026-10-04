@tool
class_name PartyUIConfig
extends Resource
## 统一界面视觉配置：在 Inspector 打开 ui_config.tres，使用中文设置项编辑。
## 中文属性只负责编辑显示；英文属性继续保存资源并提供脚本 API，旧配置无需迁移。
## 布局尺寸仍在场景中编辑；所有颜色都能独立调整 RGBA，节点本地覆盖仍优先。

## 全局共享字体，影响主菜单、列表、大厅、弹窗、设置页、独立示例及悬停提示。可拖入 Font 资源；只替换字体，不合并各级字号；节点的本地字体覆盖仍优先。
@export_storage var font: Font = preload("res://assets/NotoSansSC-UI.otf"):
	set(value):
		if font != null and font.changed.is_connected(emit_changed): font.changed.disconnect(emit_changed)
		font = value
		if font != null and not font.changed.is_connected(emit_changed): font.changed.connect(emit_changed)
		emit_changed()

## 微型辅助提示字号：控制主菜单右上角玩家资料按钮下方的“编辑玩家资料”提示文字。
## 同时影响使用 PartyLabelMicro 主题变体、且未设置本地字号覆盖的文字；不改变玩家名字或其他字号层级。
## 单位为像素，默认 18，可设 8～160。建议从默认值小幅调整；增大后应检查文字是否被裁切，因为不会自动调整提示区域的布局尺寸。
@export_storage var micro_size := 18:
	set(value):
		micro_size = value
		emit_changed()
## 右下角状态区的引擎版本、MOCK 协议及当前场景信息字号；也影响 PartyLabelDebug 文字。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var debug_size := 19:
	set(value):
		debug_size = value
		emit_changed()
## 元信息与短标记字号，当前用于右下角快捷键提示、头像占位字、大厅顶部英文标记和高级设置标记；对应 PartyLabelMeta。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var meta_size := 20:
	set(value):
		meta_size = value
		emit_changed()
## 房间列表的房间说明、大厅玩家状态和连接信息、创建房间说明等细节文字字号；对应 PartyLabelDetail，也可用于 schema 的 Detail 说明。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var detail_size := 21:
	set(value):
		detail_size = value
		emit_changed()
## 普通提示与校验错误字号，当前用于创建房间提示、创建/直连/资料弹窗错误、大厅底部提示和 F1 测量说明；对应 PartyLabelNote / PartyLabelNoteError。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var note_size := 22:
	set(value):
		note_size = value
		emit_changed()
## 副说明文字字号，当前用于大厅副标题、玩家名字、弹窗说明及设置页默认 note 说明；对应 PartyLabelSecondary 和 schema 的 Secondary。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var secondary_size := 23:
	set(value):
		secondary_size = value
		emit_changed()
## 共享 Theme 的默认正文字号，影响未指定字号变体的文字，以及展示区说明、字段说明、按键列标题、录入层消息和普通输入框；对应 Body 层级。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var body_size := 24:
	set(value):
		body_size = value
		emit_changed()
## 玩家数量及较大表单说明字号，当前用于大厅人数、创建房间字段标题、预设说明；对应 PartyLabelPlayer。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var player_size := 25:
	set(value):
		player_size = value
		emit_changed()
## 设置行标签及其下拉、数值、滑条数值、按键绑定、分组和行内按钮字号，也用于大厅游戏选择；对应 Setting 层级。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var setting_size := 26:
	set(value):
		setting_size = value
		emit_changed()
## 主菜单操作按钮、返回按钮、设置页签和玩家资料按钮名字等主要操作文字字号；对应 Action 层级。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var action_size := 28:
	set(value):
		action_size = value
		emit_changed()
## 中型分区标题字号，当前用于房间列表条目名称、大厅设置分区和按键录入层标题；对应 PartyLabelSection。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var section_size := 30:
	set(value):
		section_size = value
		emit_changed()
## 创建房间弹窗标题字号；也影响所有使用 PartyLabelSubheading 的副标题。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var subheading_size := 38:
	set(value):
		subheading_size = value
		emit_changed()
## 直连房间、预设和玩家资料等较窄弹窗的标题字号；对应 PartyLabelCompactTitle。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var compact_title_size := 40:
	set(value):
		compact_title_size = value
		emit_changed()
## 确认、协议选择和高级设置弹窗的标题字号；对应 PartyLabelDialogTitle。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var dialog_title_size := 42:
	set(value):
		dialog_title_size = value
		emit_changed()
## 主界面全屏展示区占位标题及大厅主标题字号；对应 PartyLabelDisplay / PartyLabelDisplayDisplayText。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var display_size := 48:
	set(value):
		display_size = value
		emit_changed()
## 房间列表页面的大标题字号；也影响 PartyLabelPageTitle 文字。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var page_title_size := 58:
	set(value):
		page_title_size = value
		emit_changed()
## 主菜单品牌标题字号；也影响 PartyLabelBrand 文字。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
@export_storage var brand_size := 72:
	set(value):
		brand_size = value
		emit_changed()

## 普通文字、输入文字与光标、未选页签，以及普通状态的按钮/下拉/数值框箭头和菜单图标颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var text := Color(0.16, 0.16, 0.16, 1):
	set(value):
		text = value
		emit_changed()
## 按钮与下拉控件悬停/按下时的文字、图标和数值框箭头颜色，以及悬停页签文字颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var text_hover := Color(0.1, 0.1, 0.1, 1):
	set(value):
		text_hover = value
		emit_changed()
## 禁用控件文字/图标、只读与占位输入文字、菜单快捷键及禁用滑块手柄颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var text_disabled := Color(0.40, 0.40, 0.38, 1):
	set(value):
		text_disabled = value
		emit_changed()
## 主按钮、选中页签、Toast 提示及 OnPrimary 主题变体的文字颜色；用于和主色背景形成对比。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var text_on_primary := Color(0.96, 0.96, 0.94, 1):
	set(value):
		text_on_primary = value
		emit_changed()
## 创建房间、直连、玩家资料等输入校验错误文字颜色；也用于 Error 主题变体。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var error := Color(0.65, 0.15, 0.12, 1):
	set(value):
		error = value
		emit_changed()
## 独立设置示例中开关启用时的预览反馈颜色；也可作为全局 success 语义色使用。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var success := Color(0.2, 0.55, 0.3, 1):
	set(value):
		success = value
		emit_changed()
## 独立设置示例中开关关闭时的预览反馈颜色；不改变开关控件本身的文字或底色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var demo_inactive := Color(0.55, 0.25, 0.25, 1):
	set(value):
		demo_inactive = value
		emit_changed()
## 独立设置示例中，演示 InputMap 绑定的按键触发后，INPUT MAP 提示文字的反馈颜色；也可作为全局 info 语义色使用。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var info := Color(0.2, 0.4, 0.65, 1):
	set(value):
		info = value
		emit_changed()

## 普通按钮、卡片、弹窗面板、输入框、设置页签面板、下拉菜单、悬停提示及已占用玩家槽位的背景颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var surface := Color(0.965, 0.965, 0.945, 1):
	set(value):
		surface = value
		emit_changed()
## 禁用按钮、只读输入框、未选及悬停页签、空玩家槽位、头像占位、预设预览，以及滑条和滚动条轨道的背景颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var muted_surface := Color(0.84, 0.84, 0.81, 1):
	set(value):
		muted_surface = value
		emit_changed()
## 主按钮、选中页签、Toast、左右开关选中色块、滑条填充/手柄，以及原生 CheckButton 选中指示的颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var primary := Color(0.14, 0.14, 0.14, 1):
	set(value):
		primary = value
		emit_changed()
## 普通按钮悬停/按下、下拉菜单悬停项等交互表面的背景颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var hover_surface := Color(0.73, 0.73, 0.70, 1):
	set(value):
		hover_surface = value
		emit_changed()
## 普通卡片、弹窗、按钮和输入框的边框颜色；同时用于滚动条滑块和原生 CheckButton 未选中指示。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var border := Color(0.25, 0.25, 0.24, 1):
	set(value):
		border = value
		emit_changed()
## 按钮、下拉等使用 hover 样式的控件在悬停/按下时的边框颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var hover_border := Color(0.1, 0.1, 0.1, 1):
	set(value):
		hover_border = value
		emit_changed()
## 键盘焦点边框、左右开关焦点线、滑条高亮与手柄悬停、滚动条悬停滑块的颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var focus := Color(0.48, 0.48, 0.46, 1):
	set(value):
		focus = value
		emit_changed()
## 设置行分隔线、分组及嵌套按键绑定的层级连接线、原生分隔控件和菜单分隔线的颜色；线宽与布局仍在场景中编辑。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var divider := Color(0.65, 0.65, 0.62, 1):
	set(value):
		divider = value
		emit_changed()
## 输入框和文本编辑区的文字选区背景颜色；不控制左右开关选中色块或弹出菜单悬停背景。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var selection := Color(0.48, 0.48, 0.46, 0.4):
	set(value):
		selection = value
		emit_changed()
## 左右分段开关轨道的边框颜色；选中色块使用“主色背景颜色”，焦点线使用“焦点强调颜色”。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var toggle_border := Color(0.38, 0.38, 0.36, 1):
	set(value):
		toggle_border = value
		emit_changed()
## 左右分段开关中当前选中一侧的文字颜色；未选一侧使用“普通文字颜色”，禁用时再乘以“开关禁用透明度”。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var toggle_active_text := Color(0.98, 0.98, 0.96, 1):
	set(value):
		toggle_active_text = value
		emit_changed()

## 通用设置页与主界面设置页整屏背景颜色，包括独立示例中的设置页。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var page_background := Color(0.91, 0.91, 0.90, 1):
	set(value):
		page_background = value
		emit_changed()
## 主菜单左侧品牌标题与操作按钮后方的底板颜色；透明部分透出展示背景。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var menu_backdrop := Color(0.965, 0.965, 0.945, 0.96):
	set(value):
		menu_backdrop = value
		emit_changed()
## 房间列表页面大底板颜色；透明部分透出其后方的展示背景。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var rooms_backdrop := Color(0.965, 0.965, 0.945, 0.97):
	set(value):
		rooms_backdrop = value
		emit_changed()
## 房间大厅页面大底板颜色；不改变玩家槽位与设置卡片的独立表面颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var lobby_backdrop := Color(0.965, 0.965, 0.945, 0.98):
	set(value):
		lobby_backdrop = value
		emit_changed()
## 主界面右下角快捷键、引擎/协议/场景信息块的底板颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var status_backdrop := Color(0.965, 0.965, 0.945, 0.97):
	set(value):
		status_backdrop = value
		emit_changed()
## 普通弹窗打开时覆盖主界面、位于弹窗面板后方的全屏遮罩颜色；透明度越高，背景被遮挡越明显。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var modal_overlay := Color(0.08, 0.08, 0.08, 0.62):
	set(value):
		modal_overlay = value
		emit_changed()
## 设置页按键录入层打开时的背景遮罩颜色；与普通弹窗遮罩分开配置。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var capture_overlay := Color(0, 0, 0, 0.32):
	set(value):
		capture_overlay = value
		emit_changed()
## F1 布局辅助标尺和参考线颜色；仅在显示标尺时可见，不改变正常界面分隔线。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var ruler := Color(0.35, 0.35, 0.35, 0.6):
	set(value):
		ruler = value
		emit_changed()

## 主界面全屏展示占位背景的天空底色，位于远景、近景、地面和菜单等界面内容后方。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_background := Color(0.91, 0.91, 0.90, 1):
	set(value):
		display_background = value
		emit_changed()
## 全屏展示占位背景中左侧远景色块颜色；只影响装饰层，不改变菜单底板。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_far_left := Color(0.84, 0.84, 0.84, 1):
	set(value):
		display_far_left = value
		emit_changed()
## 全屏展示占位背景中间远景色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_far_center := Color(0.86, 0.86, 0.86, 1):
	set(value):
		display_far_center = value
		emit_changed()
## 全屏展示占位背景中右侧远景色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_far_right := Color(0.82, 0.82, 0.82, 1):
	set(value):
		display_far_right = value
		emit_changed()
## 全屏展示占位背景中左侧近景色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_near_left := Color(0.77, 0.77, 0.77, 1):
	set(value):
		display_near_left = value
		emit_changed()
## 全屏展示占位背景中右侧近景色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_near_right := Color(0.76, 0.76, 0.76, 1):
	set(value):
		display_near_right = value
		emit_changed()
## 全屏展示占位背景底部地面色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_ground := Color(0.7, 0.7, 0.7, 1):
	set(value):
		display_ground = value
		emit_changed()
## 全屏展示占位背景的水平地平线颜色；线条位置与厚度仍在场景中编辑。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_horizon := Color(0.50, 0.50, 0.49, 1):
	set(value):
		display_horizon = value
		emit_changed()
## 全屏展示占位背景的大标题文字颜色；对应 DisplayText 主题变体。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_text := Color(0.39, 0.39, 0.38, 1):
	set(value):
		display_text = value
		emit_changed()
## 全屏展示占位背景中标题下方说明文字颜色；对应 DisplayCaption 主题变体。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
@export_storage var display_caption := Color(0.42, 0.42, 0.41, 1):
	set(value):
		display_caption = value
		emit_changed()

## 左右分段开关禁用时，对两侧文字原有 alpha 施加的透明度乘数；范围 0～1，0 完全透明，1 保持原透明度。不会覆盖原颜色的 alpha，也不控制其他控件的禁用颜色。
@export_storage var disabled_opacity := 0.45:
	set(value):
		disabled_opacity = value
		emit_changed()


# 中文 Inspector 代理：保留与英文项相同的默认值，原生还原按钮才能还原到正确值。
# 只带 EDITOR 标记，不序列化第二份配置；读写均委托原字段，保留 changed 通知。

@export_group("字体与字号")
## 全局共享字体，影响主菜单、列表、大厅、弹窗、设置页、独立示例及悬停提示。可拖入 Font 资源；只替换字体，不合并各级字号；节点的本地字体覆盖仍优先。
## 对应脚本字段：[member font]。
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Font", PROPERTY_USAGE_EDITOR) var 界面字体: Font = preload("res://assets/NotoSansSC-UI.otf"):
	get:
		return font
	set(value):
		font = value
## 微型辅助提示字号：控制主菜单右上角玩家资料按钮下方的“编辑玩家资料”提示文字。
## 同时影响使用 PartyLabelMicro 主题变体、且未设置本地字号覆盖的文字；不改变玩家名字或其他字号层级。
## 单位为像素，默认 18，可设 8～160。建议从默认值小幅调整；增大后应检查文字是否被裁切，因为不会自动调整提示区域的布局尺寸。
## 对应脚本字段：[member micro_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 微型提示字号 := 18:
	get:
		return micro_size
	set(value):
		micro_size = value
## 右下角状态区的引擎版本、MOCK 协议及当前场景信息字号；也影响 PartyLabelDebug 文字。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member debug_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 调试信息字号 := 19:
	get:
		return debug_size
	set(value):
		debug_size = value
## 元信息与短标记字号，当前用于右下角快捷键提示、头像占位字、大厅顶部英文标记和高级设置标记；对应 PartyLabelMeta。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member meta_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 标记信息字号 := 20:
	get:
		return meta_size
	set(value):
		meta_size = value
## 房间列表的房间说明、大厅玩家状态和连接信息、创建房间说明等细节文字字号；对应 PartyLabelDetail，也可用于 schema 的 Detail 说明。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member detail_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 详细信息字号 := 21:
	get:
		return detail_size
	set(value):
		detail_size = value
## 普通提示与校验错误字号，当前用于创建房间提示、创建/直连/资料弹窗错误、大厅底部提示和 F1 测量说明；对应 PartyLabelNote / PartyLabelNoteError。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member note_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 提示与错误字号 := 22:
	get:
		return note_size
	set(value):
		note_size = value
## 副说明文字字号，当前用于大厅副标题、玩家名字、弹窗说明及设置页默认 note 说明；对应 PartyLabelSecondary 和 schema 的 Secondary。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member secondary_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 次要说明字号 := 23:
	get:
		return secondary_size
	set(value):
		secondary_size = value
## 共享 Theme 的默认正文字号，影响未指定字号变体的文字，以及展示区说明、字段说明、按键列标题、录入层消息和普通输入框；对应 Body 层级。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member body_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 正文字号 := 24:
	get:
		return body_size
	set(value):
		body_size = value
## 玩家数量及较大表单说明字号，当前用于大厅人数、创建房间字段标题、预设说明；对应 PartyLabelPlayer。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member player_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 玩家与表单字号 := 25:
	get:
		return player_size
	set(value):
		player_size = value
## 设置行标签及其下拉、数值、滑条数值、按键绑定、分组和行内按钮字号，也用于大厅游戏选择；对应 Setting 层级。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member setting_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 设置项字号 := 26:
	get:
		return setting_size
	set(value):
		setting_size = value
## 主菜单操作按钮、返回按钮、设置页签和玩家资料按钮名字等主要操作文字字号；对应 Action 层级。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member action_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 操作与页签字号 := 28:
	get:
		return action_size
	set(value):
		action_size = value
## 中型分区标题字号，当前用于房间列表条目名称、大厅设置分区和按键录入层标题；对应 PartyLabelSection。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member section_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 分区标题字号 := 30:
	get:
		return section_size
	set(value):
		section_size = value
## 创建房间弹窗标题字号；也影响所有使用 PartyLabelSubheading 的副标题。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member subheading_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 创建房间标题字号 := 38:
	get:
		return subheading_size
	set(value):
		subheading_size = value
## 直连房间、预设和玩家资料等较窄弹窗的标题字号；对应 PartyLabelCompactTitle。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member compact_title_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 紧凑弹窗标题字号 := 40:
	get:
		return compact_title_size
	set(value):
		compact_title_size = value
## 确认、协议选择和高级设置弹窗的标题字号；对应 PartyLabelDialogTitle。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member dialog_title_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 标准弹窗标题字号 := 42:
	get:
		return dialog_title_size
	set(value):
		dialog_title_size = value
## 主界面全屏展示区占位标题及大厅主标题字号；对应 PartyLabelDisplay / PartyLabelDisplayDisplayText。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member display_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 展示与大厅标题字号 := 48:
	get:
		return display_size
	set(value):
		display_size = value
## 房间列表页面的大标题字号；也影响 PartyLabelPageTitle 文字。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member page_title_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 列表页面标题字号 := 58:
	get:
		return page_title_size
	set(value):
		page_title_size = value
## 主菜单品牌标题字号；也影响 PartyLabelBrand 文字。 单位为像素，范围 8～160；修改字号不会自动调整场景布局。
## 对应脚本字段：[member brand_size]。
@export_custom(PROPERTY_HINT_RANGE, "8,160,1", PROPERTY_USAGE_EDITOR) var 品牌标题字号 := 72:
	get:
		return brand_size
	set(value):
		brand_size = value

@export_group("文字与状态")
## 普通文字、输入文字与光标、未选页签，以及普通状态的按钮/下拉/数值框箭头和菜单图标颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member text]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 普通文字颜色 := Color(0.16, 0.16, 0.16, 1):
	get:
		return text
	set(value):
		text = value
## 按钮与下拉控件悬停/按下时的文字、图标和数值框箭头颜色，以及悬停页签文字颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member text_hover]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 悬停文字颜色 := Color(0.1, 0.1, 0.1, 1):
	get:
		return text_hover
	set(value):
		text_hover = value
## 禁用控件文字/图标、只读与占位输入文字、菜单快捷键及禁用滑块手柄颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member text_disabled]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 禁用文字颜色 := Color(0.40, 0.40, 0.38, 1):
	get:
		return text_disabled
	set(value):
		text_disabled = value
## 主按钮、选中页签、Toast 提示及 OnPrimary 主题变体的文字颜色；用于和主色背景形成对比。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member text_on_primary]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 深色底文字颜色 := Color(0.96, 0.96, 0.94, 1):
	get:
		return text_on_primary
	set(value):
		text_on_primary = value
## 创建房间、直连、玩家资料等输入校验错误文字颜色；也用于 Error 主题变体。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member error]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 错误提示颜色 := Color(0.65, 0.15, 0.12, 1):
	get:
		return error
	set(value):
		error = value
## 独立设置示例中开关启用时的预览反馈颜色；也可作为全局 success 语义色使用。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member success]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 示例启用反馈颜色 := Color(0.2, 0.55, 0.3, 1):
	get:
		return success
	set(value):
		success = value
## 独立设置示例中开关关闭时的预览反馈颜色；不改变开关控件本身的文字或底色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member demo_inactive]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 示例关闭反馈颜色 := Color(0.55, 0.25, 0.25, 1):
	get:
		return demo_inactive
	set(value):
		demo_inactive = value
## 独立设置示例中，演示 InputMap 绑定的按键触发后，INPUT MAP 提示文字的反馈颜色；也可作为全局 info 语义色使用。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member info]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 示例按键反馈颜色 := Color(0.2, 0.4, 0.65, 1):
	get:
		return info
	set(value):
		info = value

@export_group("表面与控件")
## 普通按钮、卡片、弹窗面板、输入框、设置页签面板、下拉菜单、悬停提示及已占用玩家槽位的背景颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member surface]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 普通表面颜色 := Color(0.965, 0.965, 0.945, 1):
	get:
		return surface
	set(value):
		surface = value
## 禁用按钮、只读输入框、未选及悬停页签、空玩家槽位、头像占位、预设预览，以及滑条和滚动条轨道的背景颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member muted_surface]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 弱化表面颜色 := Color(0.84, 0.84, 0.81, 1):
	get:
		return muted_surface
	set(value):
		muted_surface = value
## 主按钮、选中页签、Toast、左右开关选中色块、滑条填充/手柄，以及原生 CheckButton 选中指示的颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member primary]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 主色背景颜色 := Color(0.14, 0.14, 0.14, 1):
	get:
		return primary
	set(value):
		primary = value
## 普通按钮悬停/按下、下拉菜单悬停项等交互表面的背景颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member hover_surface]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 悬停表面颜色 := Color(0.73, 0.73, 0.70, 1):
	get:
		return hover_surface
	set(value):
		hover_surface = value
## 普通卡片、弹窗、按钮和输入框的边框颜色；同时用于滚动条滑块和原生 CheckButton 未选中指示。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member border]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 普通边框颜色 := Color(0.25, 0.25, 0.24, 1):
	get:
		return border
	set(value):
		border = value
## 按钮、下拉等使用 hover 样式的控件在悬停/按下时的边框颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member hover_border]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 悬停边框颜色 := Color(0.1, 0.1, 0.1, 1):
	get:
		return hover_border
	set(value):
		hover_border = value
## 键盘焦点边框、左右开关焦点线、滑条高亮与手柄悬停、滚动条悬停滑块的颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member focus]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 焦点强调颜色 := Color(0.48, 0.48, 0.46, 1):
	get:
		return focus
	set(value):
		focus = value
## 设置行分隔线、分组及嵌套按键绑定的层级连接线、原生分隔控件和菜单分隔线的颜色；线宽与布局仍在场景中编辑。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member divider]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 分隔与层级线颜色 := Color(0.65, 0.65, 0.62, 1):
	get:
		return divider
	set(value):
		divider = value
## 输入框和文本编辑区的文字选区背景颜色；不控制左右开关选中色块或弹出菜单悬停背景。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member selection]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 文本选区颜色 := Color(0.48, 0.48, 0.46, 0.4):
	get:
		return selection
	set(value):
		selection = value
## 左右分段开关轨道的边框颜色；选中色块使用“主色背景颜色”，焦点线使用“焦点强调颜色”。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member toggle_border]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 左右开关边框颜色 := Color(0.38, 0.38, 0.36, 1):
	get:
		return toggle_border
	set(value):
		toggle_border = value
## 左右分段开关中当前选中一侧的文字颜色；未选一侧使用“普通文字颜色”，禁用时再乘以“开关禁用透明度”。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member toggle_active_text]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 左右开关选中文字颜色 := Color(0.98, 0.98, 0.96, 1):
	get:
		return toggle_active_text
	set(value):
		toggle_active_text = value

@export_group("页面与遮罩")
## 通用设置页与主界面设置页整屏背景颜色，包括独立示例中的设置页。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member page_background]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 设置页面背景颜色 := Color(0.91, 0.91, 0.90, 1):
	get:
		return page_background
	set(value):
		page_background = value
## 主菜单左侧品牌标题与操作按钮后方的底板颜色；透明部分透出展示背景。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member menu_backdrop]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 主菜单底板颜色 := Color(0.965, 0.965, 0.945, 0.96):
	get:
		return menu_backdrop
	set(value):
		menu_backdrop = value
## 房间列表页面大底板颜色；透明部分透出其后方的展示背景。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member rooms_backdrop]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 房间列表底板颜色 := Color(0.965, 0.965, 0.945, 0.97):
	get:
		return rooms_backdrop
	set(value):
		rooms_backdrop = value
## 房间大厅页面大底板颜色；不改变玩家槽位与设置卡片的独立表面颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member lobby_backdrop]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 大厅底板颜色 := Color(0.965, 0.965, 0.945, 0.98):
	get:
		return lobby_backdrop
	set(value):
		lobby_backdrop = value
## 主界面右下角快捷键、引擎/协议/场景信息块的底板颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member status_backdrop]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 状态信息底板颜色 := Color(0.965, 0.965, 0.945, 0.97):
	get:
		return status_backdrop
	set(value):
		status_backdrop = value
## 普通弹窗打开时覆盖主界面、位于弹窗面板后方的全屏遮罩颜色；透明度越高，背景被遮挡越明显。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member modal_overlay]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 普通弹窗遮罩颜色 := Color(0.08, 0.08, 0.08, 0.62):
	get:
		return modal_overlay
	set(value):
		modal_overlay = value
## 设置页按键录入层打开时的背景遮罩颜色；与普通弹窗遮罩分开配置。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member capture_overlay]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 按键录入遮罩颜色 := Color(0, 0, 0, 0.32):
	get:
		return capture_overlay
	set(value):
		capture_overlay = value
## F1 布局辅助标尺和参考线颜色；仅在显示标尺时可见，不改变正常界面分隔线。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member ruler]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 布局标尺颜色 := Color(0.35, 0.35, 0.35, 0.6):
	get:
		return ruler
	set(value):
		ruler = value

@export_group("展示占位背景")
## 主界面全屏展示占位背景的天空底色，位于远景、近景、地面和菜单等界面内容后方。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_background]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区天空颜色 := Color(0.91, 0.91, 0.90, 1):
	get:
		return display_background
	set(value):
		display_background = value
## 全屏展示占位背景中左侧远景色块颜色；只影响装饰层，不改变菜单底板。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_far_left]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区远景左侧颜色 := Color(0.84, 0.84, 0.84, 1):
	get:
		return display_far_left
	set(value):
		display_far_left = value
## 全屏展示占位背景中间远景色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_far_center]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区远景中部颜色 := Color(0.86, 0.86, 0.86, 1):
	get:
		return display_far_center
	set(value):
		display_far_center = value
## 全屏展示占位背景中右侧远景色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_far_right]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区远景右侧颜色 := Color(0.82, 0.82, 0.82, 1):
	get:
		return display_far_right
	set(value):
		display_far_right = value
## 全屏展示占位背景中左侧近景色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_near_left]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区近景左侧颜色 := Color(0.77, 0.77, 0.77, 1):
	get:
		return display_near_left
	set(value):
		display_near_left = value
## 全屏展示占位背景中右侧近景色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_near_right]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区近景右侧颜色 := Color(0.76, 0.76, 0.76, 1):
	get:
		return display_near_right
	set(value):
		display_near_right = value
## 全屏展示占位背景底部地面色块颜色。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_ground]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区地面颜色 := Color(0.7, 0.7, 0.7, 1):
	get:
		return display_ground
	set(value):
		display_ground = value
## 全屏展示占位背景的水平地平线颜色；线条位置与厚度仍在场景中编辑。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_horizon]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区地平线颜色 := Color(0.50, 0.50, 0.49, 1):
	get:
		return display_horizon
	set(value):
		display_horizon = value
## 全屏展示占位背景的大标题文字颜色；对应 DisplayText 主题变体。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_text]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区标题颜色 := Color(0.39, 0.39, 0.38, 1):
	get:
		return display_text
	set(value):
		display_text = value
## 全屏展示占位背景中标题下方说明文字颜色；对应 DisplayCaption 主题变体。 使用 RGBA；A（alpha）为透明度，0 完全透明，1 不透明。
## 对应脚本字段：[member display_caption]。
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var 展示区说明颜色 := Color(0.42, 0.42, 0.41, 1):
	get:
		return display_caption
	set(value):
		display_caption = value

@export_group("开关禁用效果")
## 左右分段开关禁用时，对两侧文字原有 alpha 施加的透明度乘数；范围 0～1，0 完全透明，1 保持原透明度。不会覆盖原颜色的 alpha，也不控制其他控件的禁用颜色。
## 对应脚本字段：[member disabled_opacity]。
@export_custom(PROPERTY_HINT_RANGE, "0,1,0.01", PROPERTY_USAGE_EDITOR) var 开关禁用透明度 := 0.45:
	get:
		return disabled_opacity
	set(value):
		disabled_opacity = value
