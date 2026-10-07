# 按键图标与功能提示

## 已接入位置

- 主菜单、房间列表、大厅、设置页共用的右下角：Tab 切换、Enter 确认、Esc 返回、F1 标尺，均为「按键图标 + 中文功能」。引擎版本、MOCK 协议和场景 ID 仍是原始文本
- 按键录入弹层：Esc 取消、Delete / Backspace 清空。冲突时只替换错误消息，图标说明保留
- 独立设置示例底部：跳跃 / 交互提示读取真实 `party_demo_*` InputMap，修改绑定后自动更新；另有 F10 返回和 F12 截图提示

绑定表的主 / 次按键按钮、录入、冲突检测、取消和清空行为没有重做。说明图标本身不接收鼠标、不占键盘焦点、不修改 InputMap。

## 资产

[Kenney Input Prompts](https://kenney.nl/assets/input-prompts)，包内版本 **1.5A**，CC0。`assets/input_prompts/` 保存 104 个单色轮廓 SVG、原始许可及来源说明；使用单一矢量版本，未导入冗余 PNG、字体、精灵表、预览、ZIP 或整套手柄图标。

字母、数字、F1–F12、常见标点、修饰键、导航键和鼠标按键有现成映射。未包含的键（例如小键盘数字）明确显示原始键名，绝不会冒充主键盘按键。Meta 按平台显示 macOS Command、Windows Win；其他平台保留 Meta 文字。

原始白色 SVG 未修改。运行时用 AtlasTexture 裁去透明外围，再用主题文字色调制单色部分；源 alpha 原样保留，不做亮度转透明度。`.svg.import` 使用 4× 导入（256px），适配大图标、高 DPI 与窗口统一缩放。自定义多彩图标不自动染色。

## 编辑器用法

将 `ui/components/input_prompt.tscn` 拖入场景，直接在 Inspector 编辑：

- `keycodes`：一个或多个 Godot keycode；默认 Tab。组合键可直接使用带 `KEY_MASK_*` 的整数
- `key_separator`：多个 `keycodes` 之间的分隔符，默认 `+`；备选键可设为 `/`，按键顺序可设为 `→`
- `function_text`：功能名称，与按键分离，便于翻译
- `action_name`：可选 InputMap 动作名；非空时优先从动作读取，不使用固定键
- `binding_index`：`-1` 显示动作的全部备选输入；`0` 主绑定、`1` 次绑定。无绑定 / 索引越界显示「未绑定」
- `icon_height`：裁掉透明边距后的可见图标高度，默认 36 设计像素；保持宽高比
- `label_variation`：默认 `PartyLabelMeta`，可用共享主题的其他 Label 变体
- `disabled` / `highlighted`：只控制展示状态，分别使用全局禁用 / 悬停文字色；不改变输入或按钮状态

容器间距和内部 `Function` 文字节点可在 `.tscn` 编辑；场景中的运行时键列表由公开属性生成。`input_glyph.tscn` 提供每个图标及未知键 fallback 的可编辑模板。不要把按键内容烘焙进中文功能文本。

多个提示推荐放入 `HFlowContainer`，窄布局会以完整提示为单位换行。一个组合键保持并列而不拆开。独立示例的提示区固定底边、换行向上扩展，反馈文字跟随上移；真实双槽长组合键也不会从设计视口底部溢出。主界面仍沿用项目的 1920×1080 设计视口和整体缩放策略。

## 脚本 API

```gdscript
const PROMPT = preload("res://ui/components/input_prompt.tscn")
const Resolver = preload("res://ui/input_prompt_resolver.gd")

var prompt = PROMPT.instantiate()
add_child(prompt)
prompt.configure(KEY_E, "交互")
prompt.configure(KEY_MASK_CTRL | KEY_S, "保存")
prompt.configure("Ctrl+Shift+K", "命令面板")
prompt.configure([KEY_E, KEY_ENTER], "交互") # 两个备选键，用 / 分隔

# 原生鼠标 / 键盘 / 手柄输入事件也可直接传入
var mouse = InputEventMouseButton.new()
mouse.button_index = MOUSE_BUTTON_LEFT
prompt.configure(mouse, "选择")

# 读取真实动作，完全不修改 InputMap
prompt.action_name = &"party_demo_jump"
prompt.binding_index = -1
prompt.function_text = "跳跃"
prompt.refresh() # 立即刷新；否则动作变更最迟 0.2 秒后自动呈现

# 固定的按键顺序/组合：按需用 +、/ 或 →
prompt.action_name = &""
prompt.keycodes = PackedInt64Array([KEY_SHIFT, KEY_TAB])
prompt.key_separator = "+"
prompt.function_text = "上一个焦点"

# 便于无障碍说明 / 测试，不依赖显示节点路径
print(prompt.get_accessible_text())
print(prompt.get_tokens())
```

`set_binding(value)` 清除 `action_name` 并设置脚本输入（显式 `null` 使用未知输入文字回退，不恢复默认按键）；`configure(value, description)` 同时设置功能文本。之后给 `keycodes` 赋值可恢复 Inspector 固定键模式。`configure(settings_page.get_value(id), "功能")` 可直接读取双槽绑定值；备选数组内的 `0` 空槽会被忽略，全部为空才显示一次「未绑定」。事件属性在原对象上改变后，固定提示需手动 `refresh()`；动作提示会自动检查 InputMap。

解析器 `tokens(value)`、`key_tokens(code)`、`event_tokens(event)` 返回字典数组；真实输入包含 `label` 和 `asset`，分隔符含 `separator: true`。未知输入的 `asset` 为空，组件显示带括号的文字标签，不使用缺失纹理。`Esc` / `Escape`、`Return` / `Enter`、`Ctrl` / `Control`、`Spacebar`、`PgUp`、`LMB` / `RMB` / `MMB` 等别名均支持。物理键事件优先转为当前键盘布局的逻辑键，转换不可用时保留物理键名。

## 后续添加手柄图标

当前未主动导入不使用的设备全集，也不假定通用手柄按钮等于某家设备的 A / B / X / Y。手柄事件先显示「手柄按钮 N」或轴方向；应用确定设备族后可以注册对应图标：

```gdscript
Resolver.register_icon("joypad_button:0", preload("res://your_controller_a.svg"))
Resolver.register_icon("joypad_axis:0:+", preload("res://your_stick_right.svg"))
prompt.refresh()
# 设备族切换时重新注册，或移除单项 / 全部自定义映射
Resolver.register_icon("joypad_button:0", null)
Resolver.clear_registered_icons()
```

注册只影响图标解析，不修改事件。自定义图标保留原颜色和 alpha；使用新的图标包时同时补充来源与许可说明。`texture_for(token)` 提供正式组件同用的纹理解析，避免其他页面复制字符串映射。

## 主题与验证

功能文字、fallback 与分隔符继承共享字体和字号；正常图标颜色使用功能文字的主题色，禁用和高亮也读取共享 Theme。`ui_config.tres` 修改后立即刷新；功能 Label 的本地颜色覆盖在状态切换后恢复。

新增专项：`tests/test_input_prompts.gd`。同时保留导航、键绑定捕获、主题、布局、悬停、iOS 开关等全量回归。Headless 测试只验证逻辑 / 资源 / 几何；正式视觉验收仍应通过实际 Godot 窗口截图。
