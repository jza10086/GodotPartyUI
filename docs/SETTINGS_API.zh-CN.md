# 通用设置页 API

`settings/settings_page.tscn` 是可独立实例化的设置页，脚本为 `settings/settings_page.gd`。调用方用数据声明页签、设置项、分组和回调，不需要修改组件内部的场景树。组件负责原生 Godot 控件、数值编辑、分组和设置值；具体游戏逻辑由调用方接入。

本工程使用 Godot 4.7.2。设置页沿用 1920×1080 设计视口和当前灰阶主题，每个页签具有自己的滚动区域。场景自带返回按钮，点击时发送 `back_requested`；页面跳转、Esc 返回和窗口尺寸适配由宿主场景负责。

## 1. 直接运行示例

在 Godot 编辑器打开 `examples/settings_demo.tscn`，按 F6；也可以在项目目录执行：

```sh
godot --path . res://examples/settings_demo.tscn
```

从主菜单按 F10 也可以进入示例，示例中按 F10 返回主菜单。还可使用 `godot --path . -- --settings-demo` 直接进入。示例中 F12 保存真实视口截图到 `screenshots/17_settings_api_demo.png`。

示例另有「按键绑定」页签，可修改主 / 次按键、展开移动分组和跳跃子操作；录入结束后按动作键，底部预览会显示实际 InputMap 动作名称。若按钮仍有焦点，Space / Enter 等 UI 键可能先被控件消费，可点击说明区域后再试。

示例覆盖所有设置项类型；改值会更新底部预览、只读结果行并打印回调，重置按钮演示静默赋值，返回按钮在该示例中用于重建页面。示例逻辑位于 `examples/settings_demo.gd`。工程主菜单的设置数据位于 `settings/main_settings_schema.json`，业务回调由 `main.gd` 接入；第四个按键绑定页由 `settings/demo_bindings.gd` 程序化生成。JSON 适合保存静态结构；`Callable` 不能放入 JSON，需要在脚本中补上。

## 2. 最小接入示例

在自己的 `Control` 场景上挂载以下脚本。`configure()` 的参数是页签数组，每个页签有 `id`、`title` 和 `options`。

```gdscript
extends Control

const SETTINGS_SCENE = preload("res://settings/settings_page.tscn")
var settings

func _ready() -> void:
    settings = SETTINGS_SCENE.instantiate()
    add_child(settings)
    settings.setting_changed.connect(_on_setting_changed)
    settings.back_requested.connect(func() -> void: settings.hide())

    var tabs: Array = [{
        "id": "display",
        "title": "显示设置",
        "options": [
            {
                "id": "display.mode",
                "type": "select",
                "label": "显示方式",
                "items": [
                    {"label": "窗口化", "value": "windowed"},
                    {"label": "全屏", "value": "fullscreen"}
                ],
                "value": "windowed"
            },
            {
                "id": "display.window",
                "type": "group",
                "label": "窗口化选项",
                "expanded": true,
                "visible_when": {
                    "id": "display.mode",
                    "equals": "windowed"
                },
                "children": [{
                    "id": "display.width",
                    "type": "number",
                    "label": "窗口宽度",
                    "min": 640.0,
                    "max": 3840.0,
                    "step": 1.0,
                    "suffix": "px",
                    "value": 1280.0
                }]
            },
            {
                "id": "audio.volume",
                "type": "slider",
                "label": "音效音量",
                "min": 0.0,
                "max": 100.0,
                "step": 1.0,
                "suffix": "%",
                "value": 70.0,
                "callback": _on_volume_changed
            },
            {
                "id": "display.apply",
                "type": "action",
                "label": "应用设置",
                "callback": _on_apply
            }
        ]
    }]

    if not settings.configure(tabs):
        push_error(settings.last_error)

func _on_setting_changed(id: String, value: Variant) -> void:
    print("设置变化：", id, " = ", value)

func _on_volume_changed(value: Variant, id: String) -> void:
    # 在这里接入自己的音效系统。
    print(id, " 的当前音量为 ", value)

func _on_apply(_id: String) -> void:
    # 在这里决定如何应用和保存；按钮本身不会更改窗口或写入文件。
    print(settings.get_values())
```

注意参数顺序：统一信号是 `(id, value)`，单项值回调是 `(value, id)`，动作回调是 `(id)`。

## 3. 公共方法

| 方法 | 用途 |
| --- | --- |
| `configure(tabs: Array) -> bool` | 校验并重建整个页面。失败返回 `false`，原有页面和数值保持不变；读取 `last_error` 查看原因 |
| `add_tab(id: String, title: String) -> bool` | 动态添加页签 |
| `add_option(tab_id: String, spec: Dictionary, parent_group: String = "") -> bool` | 向页签添加一项。省略 `parent_group` 时添加到页签顶层；否则添加到指定分组或具有 `children` 的按键行 |
| `get_value(id: String) -> Variant` | 获取单项当前值（数组 / 字典返回复制）；未知 ID 或无值项返回 `null` |
| `get_values() -> Dictionary` | 获取当前设置值的深复制字典，以设置项 ID 为键 |
| `set_value(id: String, value: Variant, notify: bool = false) -> bool` | 更新单项值和对应控件。默认不发送业务通知；需要通知时传 `true` |
| `get_control(id: String) -> Control` | 获取设置项对应的原生控件；未知 ID 返回 `null` |
| `get_number_control(id: String) -> SpinBox` | 获取 `number` 或 `slider` 的数值框；未知 ID 或其他类型返回 `null` |
| `get_binding_control(id: String, slot: int) -> Button` | 获取按键行的主键（`0`）或次键（`1`）按钮；无效 ID / 槽位返回 `null` |
| `get_expander(id: String) -> Button` | 获取分组或带子项按键行的展开按钮 |
| `set_expanded(id: String, expanded: bool) -> bool` | 修改展开状态，不改变绑定或发出值回调 |
| `begin_binding_capture(id: String, slot: int) -> bool` | 开始指定按键槽位的录入 |
| `cancel_binding_capture() -> void` | 取消录入，保留原值 |
| `is_capturing_binding() -> bool` | 是否正在录入按键 |
| `clear() -> void` | 清空页签、设置项和当前值 |

`last_error` 用于取得失败原因，应在方法返回 `false` 时读取。始终检查返回值，不要把无效输入当成已经应用。

`get_values()` 包含 `label`、`select`、`toggle`、`number`、`slider`、`keybinding` 的值；不包含 `note`、`divider`、`action`、`group`、`bindings_header`。分组的展开状态不是设置值。隐藏或折叠不会删除已有子项值。

公共信号：

- `setting_changed(id: String, value: Variant)`：设置值发生变化时通知
- `back_requested`：点击返回按钮时通知；宿主连接此信号处理自己的导航

### 动态添加

```gdscript
if not settings.add_tab("game", "游戏设置"):
    push_error(settings.last_error)

var added: bool = settings.add_option("game", {
    "id": "game.hints",
    "type": "toggle",
    "label": "显示提示",
    "value": true,
    "callback": func(value: Variant, id: String) -> void:
        print(id, " = ", value)
})
if not added:
    push_error(settings.last_error)

# 向已有的同一页签中的分组添加子项。
if not settings.add_option("display", {
    "id": "display.height",
    "type": "number",
    "label": "窗口高度",
    "min": 360.0,
    "max": 2160.0,
    "step": 1.0,
    "suffix": "px",
    "value": 720.0
}, "display.window"):
    push_error(settings.last_error)
```

`parent_group` 使用分组设置项的全局 ID，而不是标题或节点路径。父项必须已经存在（分组或带 `children` 的按键行），并属于 `tab_id` 指定的页签。

## 4. 数据结构

### 页签

```gdscript
{
    "id": "audio",
    "title": "声音设置",
    "options": [] # 依次放入设置项 Dictionary
}
```

- `id` 是程序使用的稳定标识；`title` 是页签上显示的文字
- 页签 ID 不应重复
- 每个设置项，包括静态文本、分隔线和分组，都必须有唯一 `id`
- 设置项 ID 在整个设置页中全局唯一，不能只保证同一页签内唯一。建议使用 `audio.volume` 这样的前缀
- 控件 `label` 是显示名称，不作为值查询键

### 支持的设置项类型

| `type` | 作用 | 主要字段 |
| --- | --- | --- |
| `label` | 左侧名称、右侧只读文字 | `label`、`value` |
| `select` | 下拉选择 | `label`、`items`、`value`、`callback` |
| `toggle` | 左右选项开关（点击切换 + 滑动动画） | `label`、`value`、`callback`、`off_text`、`on_text` |
| `number` | 可直接输入的数值框 | `label`、`value`、`min`、`max`、`step`、`suffix`、`callback` |
| `slider` | 滑块与精确数值框 | 与 `number` 相同 |
| `note` | 说明文字 | `text` |
| `divider` | 分隔线 | 只需 `id` 与 `type` |
| `action` | 动作按钮 | `label`、`callback` |
| `bindings_header` | 三列标题：功能名称 / 主按键 / 次要按键 | `id`、`type` |
| `keybinding` | 双槽位按键绑定，可含折叠子项 | `label`、`value`、`callback`、`conflict_scope`、`children`、`expanded` |
| `group` | 可展开的缩进子项组 | `label`、`children`、`expanded`、`visible_when` |

`callback` 使用有效的 GDScript `Callable`，如方法名、`Callable` 对象或 lambda；不要填写方法名字符串并期待自动调用。可以省略回调，仅通过 `setting_changed` 信号集中处理。

### 默认行分隔线

`configure()` 和 `add_option()` 默认在相邻可见设置行之间生成 1 px 灰色细线，无需手动写 `divider`。只读值、下拉、开关、数值、滑条、操作按钮和分组标题都按同一规则处理；分组内任意层级的子行也自动分隔。

显式 `divider` 与 `note` 是段落边界，不会叠加自动线，因此已有手动分隔布局保持原样。条件隐藏行不会留下多余线或首尾线；折叠分组时其内部线随子项隐藏。自动线不占用设置 ID，也不会出现在 `get_values()` 或触发回调。

回归测试：`tests/test_settings_dividers.gd`（任意配置、混合显式线、显隐、嵌套分组、动态追加及重建）。

### 下拉选择：显示文字与业务值分离

```gdscript
{
    "id": "quality",
    "type": "select",
    "label": "画面质量",
    "items": [
        {"label": "低", "value": "low"},
        {"label": "高", "value": "high"}
    ],
    "value": "high"
}
```

`get_value("quality")` 返回 `"high"`，不是第二项的索引，也不是 `"高"`。`set_value("quality", "low")` 同样传入业务值。若业务值本身使用整数，整数仍是 `items[].value`，不应默认理解为选项索引。

### 数值框与滑块

```gdscript
{
    "id": "camera.sensitivity",
    "type": "slider",
    "label": "灵敏度",
    "value": 1.5,
    "min": 0.1,
    "max": 5.0,
    "step": 0.1,
    "suffix": "倍"
}
```

`min`、`max` 和 `step` 定义合法范围与步长；`min` 不能大于 `max`，`step` 必须大于 0。数值必须为有限的 `int` 或 `float`。赋值会先对齐步长，再限制到合法范围，因此例如步长 1 时 `80.6` 会成为 `81.0`。`suffix` 只影响显示，读取到的值仍是数值。为需要整数的业务接口自行转换，例如 `int(settings.get_value("display.width"))`。

`slider` 使用 `HSlider` 加 `SpinBox`，两者保持同步。`get_control(id)` 返回滑块；访问旁边的输入框应使用 `get_number_control(id)`，不要依赖内部节点路径。

### 分组与条件显示

```gdscript
{
    "id": "advanced",
    "type": "group",
    "label": "高级选项",
    "expanded": false,
    "visible_when": {"id": "game.hints", "equals": true},
    "children": [
        {"id": "advanced.note", "type": "note", "text": "这里是子项说明"},
        {"id": "advanced.separator", "type": "divider"}
    ]
}
```

- `children` 使用同样的设置项结构
- `expanded` 指定分组的初始展开状态，省略时为 `false`
- `visible_when.id` 指向控制显隐的设置项，`equals` 是匹配的实际值；对于下拉框，应匹配业务值而不是显示文字
- 条件目标必须存在；只有等值比较，不执行表达式或脚本
- 折叠与条件隐藏只改变界面可见性，不代表“应用设置”或“恢复默认值”

## 5. 值、回调与业务逻辑

```gdscript
# 读取状态
var mode: Variant = settings.get_value("display.mode")
var current: Dictionary = settings.get_values()

# 静默回填，例如加载已保存的用户偏好。
if not settings.set_value("audio.volume", 45.0):
    push_error(settings.last_error)

# 有意触发通知，例如希望业务系统立即跟随该次改值。
if not settings.set_value("audio.volume", 60.0, true):
    push_error(settings.last_error)
```

用户操作值控件时，可以通过单项 `callback(value, id)` 或 `setting_changed(id, value)` 接收变化。`configure()` 初始化不会触发值回调；`set_value(..., true)` 也只在规范化后的值确实变化时通知，重复设置相同值不会再次通知。动作按钮使用 `callback(id)`，不发送 `setting_changed`。

通知前模型、控件和条件显隐已同步。正常情况下先调用单项回调，再发送统一信号；如果回调重建或释放了页面，会跳过旧页面对应的后续信号。

建议选择一个明确的业务接入口，避免同一项同时通过回调和统一信号重复应用。需要在回调中回写值时，优先使用默认静默的 `set_value()`，避免循环通知。

## 6. 边界与接入约定

- **没有自动持久化。** 组件不自动读取或写入 `user://`、`ConfigFile` 或项目配置；调用方决定保存位置和格式
- **按键由业务层应用。** 组件不调用 InputMap、不修改 `ui_*`；本工程示例只更新独立的 `party_demo_*` 动作，默认值由调用方在 `configure()` 成功后显式应用
- **没有隐含的应用行为。** `set_value()` 修改组件状态，不会自行切换全屏、修改音频总线、采集麦克风或发送网络请求
- **没有自动的应用/取消事务。** 若需要“编辑后应用”或“取消恢复”，由业务层保留已应用值和待应用值，再提供相应动作按钮
- **结构变更会重建控件。** `configure()`、`add_tab()`、`add_option()` 成功后，应重新取得所需控件引用；不要长期持有旧设置控件。动态添加会保留已有值和分组展开状态，但不应依赖原控件实例或焦点/滚动位置保留
- **校验失败不会部分替换页面。** 未知类型、重复 ID、错误分组/条件引用、非法数值范围和不在下拉选项内的值应作为配置错误处理；记录 `last_error` 后修正数据再重试
- **优先使用 ID 接口。** `get_value()`、`set_value()` 和 `get_control()` 比硬编码场景树路径更适合插件化或复用
- **复用时携带依赖。** 除 `settings_page.tscn/.gd` 外，还应保留场景引用的字体、图标等 `assets/` 资源，或改成自己的资源
- **中文字体。** 当前资源使用完整 Noto Sans CJK SC；替换字体后应检查新增文案的字形覆盖


### 左右选项开关与动画

`toggle` 固定显示左右两个选项，默认左侧「关」、右侧「开」。点击按钮任意位置都会切换状态，无需拖动；深色选中底块以 0.20 秒缓出动画滑向另一侧。`off_text` / `on_text` 可自定义显示文字，例如 `"Off"` / `"On"`，两侧的业务值仍固定为 `false` / `true`。

- Tab 聚焦整个按钮；Space / Enter 切换；← 选择关，→ 选择开。聚焦时显示外框
- `get_control(id)` 仍返回兼容 `Button` 的控件，支持 `button_pressed`、`disabled`、`grab_focus()`
- 初始化直接显示正确选项，不播放初始动画、不调用业务回调
- `set_value(id, value)` 默认静默同步（可播放滑动）；传 `true` 才在值变化时通知。动画本身不触发额外回调
- 连续点击会从当前位置平滑转向最后一次选择；旧动画立即取消。重建 / 清空页面会停止旧控件动画
- 动画采用相对位置，宽度变化不会让选中底块脱离对应半区；不改变原设置行对齐和滚动方式
- 控件实现：`settings/segmented_toggle.gd`；回归测试：`tests/test_segmented_toggle.gd`


## 7. 程序化按键绑定与三列布局

`bindings_header` 和 `keybinding` 由同一套列宽规则布局，依次是「功能名称 / 主按键 / 次要按键」。主 / 次键可以独立点击修改。分组和按键行的 `children` 使用相同结构，支持嵌套展开 / 收起；名称缩进不会改变两个按键列的对齐。内容高度自然超出页签后滚动，无需空白占位。

```gdscript
var tab := {
    "id": "bindings",
    "title": "按键绑定",
    "options": [
        {"id": "bindings.header", "type": "bindings_header"},
        {
            "id": "bindings.movement", "type": "group",
            "label": "移动", "expanded": true,
            "children": [
                {
                    "id": "move_forward", "type": "keybinding",
                    "label": "向前移动", "value": [KEY_W, KEY_UP],
                    "conflict_scope": "global", "callback": apply_binding
                },
                {
                    "id": "jump", "type": "keybinding",
                    "label": "跳跃", "value": [KEY_SPACE, 0],
                    "callback": apply_binding, "expanded": false,
                    "children": [{
                        "id": "air_dash", "type": "keybinding",
                        "label": "空中冲刺", "value": [KEY_Q | KEY_MASK_CTRL, 0],
                        "callback": apply_binding
                    }]
                }
            ]
        }
    ]
}
if not settings.configure([tab]):
    push_error(settings.last_error)

# configure 不发通知；业务层自行决定何时应用初始状态。
for id in ["move_forward", "jump", "air_dash"]:
    apply_binding(settings.get_value(id), id)

# 只修改次按键的示例：读取的是副本，必须 set_value 才会提交。
var keys: Array = settings.get_value("move_forward")
keys[1] = KEY_I
if not settings.set_value("move_forward", keys, true):
    push_error(settings.last_error)

settings.set_expanded("jump", true)
settings.get_binding_control("move_forward", 1).grab_focus()
```

### 值格式、通知与冲突

- `value` 是两个整数构成的数组 `[主按键, 次要按键]`，`0` 表示未绑定；例如 `[KEY_W, KEY_UP]`、`[KEY_K | KEY_MASK_CTRL, 0]`
- 整数对应 Godot 逻辑 `keycode` 与修饰键掩码，不是字符串、物理键扫描码、鼠标键或手柄键；支持 Ctrl / Alt / Shift / Meta 组合
- `get_control(id)` 返回主按键按钮；次按键用 `get_binding_control(id, 1)`。带子项行的展开按钮用 `get_expander(id)`，不能把主键按钮当作展开按钮
- 修改成功后先更新控件和数据，再通知 `Callable(value, id)` / `setting_changed(id, value)`。取消、无效输入、冲突和重复赋相同值均不发变化通知
- 两个槽位不能使用相同的非空键；同一设置页内、同一 `conflict_scope` 的其他行也不能复用同一非空组合。默认范围是 `"global"`，折叠 / 隐藏行也参与冲突检查
- 仅完整组合相同才冲突，例如 `K` 与 `Ctrl+K` 是不同绑定；不同范围允许复用（如 `"player1"` / `"player2"`），但同一行仍禁止主 / 次键重复
- 冲突原子拒绝，不自动清空或抢占另一行；录入时保留原值并提示继续选择。通过 `configure`、`add_option` 或 `set_value` 传入无效绑定也会失败，应检查返回值及 `last_error`

### 录入与保留键

点击任一按键按钮后显示录入遮罩，提供清空 / 取消按钮。按 Esc 取消；Delete 或 Backspace 清空当前槽位；单独按 Ctrl / Alt / Shift / Meta 不会提交，等待与普通键组成组合。Esc / Delete / Backspace 和纯修饰键均为保留键；通过程序化初始化或 `set_value` 也会拒绝它们作为绑定（包括带修饰键的 Esc / Delete / Backspace）。

捕获中的按键由组件消费：按 Enter / Space / Tab / 方向键是在录入该键，而不是操作背景设置。Esc 只取消本次录入，不同时返回主菜单；F10 / F12 等快捷键也不应同时切换场景或截图。宿主的快捷键和动作预览放在 `_unhandled_key_input` / `_unhandled_input`，不要在 `_input` 中提前执行游戏动作；原始 `Input` 轮询不受事件消费影响，且提交当帧录入状态会关闭；因此游戏逻辑应在整个设置页打开期间暂停轮询动作，不能仅依赖 `is_capturing_binding()`。如果现有第三方代码必须使用 `_input`，也必须先检测 `settings.is_capturing_binding()` 并跳过快捷键逻辑；遮罩打开时不要由其他输入处理器抢先消费事件。

### Callable 中应用到 InputMap

组件只管理编辑状态，应用层负责 InputMap。读取动作时应使用精确修饰键匹配，例如 `event.is_action_pressed(action, false, true)` 或 `Input.is_action_pressed(action, true)`；默认非精确匹配会忽略额外修饰键，可能让 `K` 和 `Ctrl+K` 同时触发。原始 Input 轮询仍需在设置页打开期间暂停。下面只修改应用自有动作，避免覆盖 Godot UI 导航：

```gdscript
func apply_binding(value: Variant, id: String) -> void:
    var action := "my_game_" + id
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    InputMap.action_erase_events(action)
    for packed_key in value:
        var code := int(packed_key)
        if code == 0:
            continue
        var event := InputEventKey.new()
        event.keycode = code & KEY_CODE_MASK
        event.shift_pressed = bool(code & KEY_MASK_SHIFT)
        event.ctrl_pressed = bool(code & KEY_MASK_CTRL)
        event.alt_pressed = bool(code & KEY_MASK_ALT)
        event.meta_pressed = bool(code & KEY_MASK_META)
        InputMap.action_add_event(action, event)
```

可运行参考见 `settings/demo_bindings.gd`、`main.gd` 和 `examples/settings_demo.gd`。示例创建的 `party_demo_*` 动作只保留在当前进程，不调用 `ProjectSettings.save()`；重建示例会重新应用默认绑定，且回调计数仍从零开始。当前未实现文件持久化、鼠标 / 手柄重绑定或跨设置页实例的全局冲突管理。


## 可编辑组件场景（场景化布局）

设置页不再在脚本里创建和排列控件。`settings_page.gd` 保留 schema 校验、数据绑定、动态实例化、信号、可见性和输入路由；所有静态布局使用 `settings/components/` 中的 PackedScene。API、稳定 ID、Callable 参数与回调语义不变，已有接入代码可继续使用。

可在编辑器直接打开并修改：

- `tab_content.tscn`：页签的 ScrollContainer、Padding、Content，调内边距和行间距
- `label_row.tscn`、`select_row.tscn`、`number_row.tscn`、`slider_row.tscn`、`toggle_row.tscn`：名称与值控件、行高、列宽、字号和对齐；滑块行包含独立精确数值框
- `action.tscn`、`note.tscn`、`divider.tscn`、`group.tscn`：动作、说明、水平分隔线与展开按钮
- `group_details.tscn`：嵌套缩进与子行间距，`HierarchyLine` 是独立 Line2D；可调 x、颜色、粗细。脚本只让末点 y 跟随容器高度，折叠时整组隐藏；嵌套组各有一条线
- `keybinding.tscn`、`keybinding_group.tscn`、`bindings_header.tscn`：三列按键布局。三者 Function 列宽应保持一致；运行时只减去实际祖先缩进，以保持主/次按键列跨层级对齐
- `binding_capture.tscn`：遮罩、面板、标题、提示、清除与取消按钮，均是可视节点
- `tooltip.tscn`：提示文本水平和垂直居中；按键行控件通过 tooltip 脚本实例化，脚本只填文字
- `segmented_toggle.tscn`：开关轨道、滑动选中块、左右标签。脚本仅处理键盘、状态、动画位置和随状态变化的文字颜色；颜色/文案/动画时长可在根节点导出属性中修改
- `settings_page.tscn`：页面大小、返回按钮、主题、页签位置；hover/未选中页签共用相同边距，避免鼠标悬停造成文字偏移

运行时不会每次重设场景里的字号、普通行尺寸、边距、间距和样式。schema 显式提供的 `row_height` / `label_width` / `font_size` / `height` 仍优先于场景默认值；标签、选项、数值范围、绑定提示等业务数据也由 schema 接管。`node_name` / `label_name` / `control_name` / `number_name` / `details_name` 仍可覆盖运行时名称。编辑组件时请保留脚本使用的节点名与结构（例如 Value、Label、Number、Rows、Function、Primary、Secondary）。复用设置页时应携带整个 `settings/components/` 目录。

动态数据需要运行时实例化，因此页签实际业务内容在运行后出现；无需把每一种配置烘焙成独立场景。单个组件可独立打开、编辑和实例化。新增 `tests/test_scene_components.gd` 覆盖全部组件加载、API 组装、布局默认值、层级线伸缩/折叠、居中提示、捕获弹层与 hover 边距。

主界面弹窗位于 `ui/dialogs/*.tscn`，各自拥有 `Dialog` 背景节点。可在对应场景修改背景的位置、大小与样式；`open_modal()` 只控制显隐和业务值，不再写死面板几何。原内部共享背景 `Modal/Dialog` 已替换成 `Modal/<弹窗名>/Dialog`，业务控件路径与设置 API 不变。
