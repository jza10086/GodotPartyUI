# 统一配色与字体

## 一个入口

在 Godot 文件系统面板选中 **`ui/theme/ui_config.tres`**，直接在 Inspector 编辑并保存。**全部 56 个设置项及六个分组均显示中文**，将鼠标停在属性名上可阅读中文说明：用途、当前影响的控件，以及对应的英文脚本字段。每个颜色都保留完整 RGBA 编辑；A（alpha）为透明度，0 完全透明、1 不透明。

- **字体与字号**：`界面字体` 接收 Godot `Font` 资源，默认使用项目内 Noto Sans CJK SC。17 个字号层级各自独立，单位为像素，范围 8～160；例如 `微型提示字号`（18）实际控制主页右上角“编辑玩家资料”，`调试信息字号`（19）控制右下角引擎/协议/场景信息，`设置项字号`（26）控制设置行及输入控件，`操作与页签字号`（28）控制主菜单按钮/页签，`品牌标题字号`（72）控制主菜单品牌标题。其余层级可悬停查看各自用途
- **文字与状态**：普通、悬停、禁用、深色底文字，错误提示及独立示例的启用/关闭/按键反馈色
- **表面与控件**：普通/弱化表面、主色背景、悬停表面、普通/悬停边框、焦点强调、分隔与层级线、文本选区、左右开关边框及选中文字
- **页面与遮罩**：设置页整屏背景、主菜单/列表/大厅/状态区底板、普通弹窗与按键录入遮罩，以及 F1 布局标尺
- **展示占位背景**：主界面全屏展示区的天空、远/近景色块、地面、地平线、标题与说明文字
- **开关禁用效果**：`开关禁用透明度` 是左右开关两侧文字原 alpha 的乘数，范围 0～1；不会抹掉颜色自身的透明度

下拉按钮箭头跟随各交互态文字色；PopupMenu 的 radio/check/子菜单图标保留原生尺寸和透明轮廓，使用 `普通文字颜色` / `禁用文字颜色`。

### 中文显示与旧配置兼容

中文字段是资源脚本自带的原生 Inspector 编辑入口，无需安装或启用编辑器插件。注释使用 GDScript `##` 文档格式，可在 Inspector 悬停查看，也保留在 `ui_config.gd` 源码中。`micro_size` 的示例注释已完善为实际说明：主页“编辑玩家资料”提示文字、未设置本地覆盖的 Micro 文字、默认 18 像素及 8～160 的可设范围，并提醒增大字号后检查裁切；中文属性使用相同说明。

已有英文 API 和 `.tres` 保存键保持不变：例如 Inspector 的 `微型提示字号` 读写 `micro_size`，`普通文字颜色` 读写 `text`。英文属性使用 `@export_storage` 继续保存旧配置值，中文代理只带 `PROPERTY_USAGE_EDITOR`，不会保存第二份冲突值。直接查看 `.tres` 时仍看到英文键属于正常行为；旧配置无需迁移，也无需修改使用 `config.micro_size` 等 API 的脚本。

中文入口保留原生 Font 选择器、带 alpha 的颜色选择器、数值范围、还原默认值与撤销/重做。修改中文入口会调用原字段 setter，只发出一次 `changed` 通知。新增字段或调整默认值时，应同步维护英文存储字段及中文代理的默认值，并运行下面的 Inspector 专项回归，避免还原按钮出现偏差。

主菜单、列表、大厅、全部弹窗、动态 schema 设置页、独立示例、tooltip、下拉菜单、按键录入层、层级连接线和开关动画使用这一个资源。Godot 品牌图标保留原始配色。

运行中的同一份 Resource 被修改时会同步更新已存在和随后实例化的控件，无需重新 configure；修改不会触发业务回调。配色、背景、共享字体/字号支持 2D 编辑器预览。编辑器里的 `@tool` 配色绑定仅更新视觉，不调用业务逻辑，也不把设置页 schema 生成为编辑器子节点。

注意：另一个进程里已启动的游戏并不会自动重新读取磁盘上的 `.tres`。编辑并保存后重新运行游戏，或者在运行进程中修改其已加载的 Resource。字号较大或换用宽字体时仍应检查实际排版；统一配置不会自行改动场景尺寸或重排设计。

## 局部覆盖优先级

不会遍历场景抹掉本地配置；主题只提供默认值。

1. **普通 Control 文本、字体、字号、样式**：节点的 `Theme Overrides` 最高优先级，按正常 Godot 工作流覆盖 Color / Font / Font Size / StyleBox。统一配置更新后这些 override 仍保留
2. **字号/语义预设**：`Theme Type Variation` 选择命名层级，例如 `PartyLabelSetting`、`PartyButtonAction`、`PartyButtonActionPrimary`、`PartyLabelNoteError`。没有本地 override 时，由统一资源决定对应字号/颜色。字号层级与字体独立，换字体不会把各级字号变成同一个大小
3. **背景、遮罩、ColorRect 分隔线**：关闭该节点脚本属性 `Use Global Color`，再编辑原生 `Color`。保持开启时，`Color Role` 选择统一语义色。恢复开启会立即重新跟随全局
4. **Line2D 层级线**：同样先关闭 `Use Global Color`，再编辑原生 `Default Color`。`HierarchyLine`、`HeaderConnection` 和 `BranchTemplate` 可分别控制。运行时各分支继承 `BranchTemplate`；改线宽、点位和缩进仍使用原场景工作流
5. **左右开关**：关闭根节点 `Use Global Colors`，使用已有 `Inactive Text Color`、`Active Text Color`、`Focus Color`。两侧 Label 的显式 `Theme Overrides > Colors > Font Color` 也会保留。选中色块另在 `Selection` 上关闭 `Use Global Color` 后编辑；Track 样式按下一条覆盖。位置与动画行为不变
6. **卡片等绑定 StyleBox**：若要单个节点独立，先在该节点的 `Theme Overrides > Styles` 给资源 **Make Unique**，再关闭该 StyleBox 的 `Use Global Colors`，然后改 `Bg Color` / `Border Color`。也可以直接提供普通 StyleBoxFlat。不要直接改共享 `card.tres` 来做单节点覆盖
7. **动态 schema 的说明字号**：`font_role` 使用上述后缀名，如 `Detail` / `Secondary`，跟随统一字号；显式 `font_size` 仍是局部像素 override，同时提供时 `font_size` 优先。现有 API 使用者无需迁移显式 override

Theme 中已有的字号变体遵循 `Party` + 原生控件类型 + 字号层级名，例如 `PartySpinBoxSetting`。`Primary` 后缀提供主按钮视觉；`OnPrimary` / `Error` / `DisplayText` / `DisplayCaption` 后缀选择文字语义色。

## 接入自己的组件

各独立场景根节点均引用 `ui/theme/party_theme.tres`。在这些场景内新增的 Control 默认继承它；新建独立场景请将根节点 Theme 设为同一资源，选好对应字号变体即可，不必复制字体或颜色。`settings_page.tscn` 不再有另一套内嵌 Theme。

新的 ColorRect 挂 `ui/theme/theme_color_rect.gd`，选择 `Color Role`；新的 Line2D 挂 `ui/theme/theme_line.gd`。布局、位置、边距、线宽仍在 `.tscn` 中直接编辑。默认 `Configuration` 已指向全局资源，无需逐节点重新设置。

`party_theme.gd` 根据统一资源生成共享 Theme；`theme_style.gd` 保持样式资源身份并同步颜色，因此大厅已分配给玩家槽位的样式也会刷新。通常只修改 `ui_config.tres`，不要把生成的 Theme 值当成第二个配置入口。`card.tres` / `primary.tres` / `muted.tres` 及 tab / focus 样式保留边宽与边距设计。

## 验证

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_theme_configuration.gd
godot --headless --path . --script res://tests/test_config_inspector.gd
```

专项测试覆盖全局 RGBA/字体/字号修改，既有和新建场景、动态 schema、tooltip、弹窗/遮罩/展示背景、交互态、开关动画，以及局部覆盖和恢复全局。测试在内存中改配置并恢复，不写入正式主题。Inspector 专项另检查全部 56 项中文名称/说明/类型/范围/默认值、英文 API 双向同步、单次通知、UndoRedo、Font 连接、深复制，以及所有旧英文键自定义值的读取、中文编辑、保存和重载；临时 `.tres` 仅写入 `user://` 并清理。headless 检查不等同于真实 Inspector 悬停和视觉验收。
