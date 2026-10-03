# 通用设置页 API

`settings/settings_page.tscn` 是可独立实例化的设置页，脚本为 `settings/settings_page.gd`。调用方用数据声明页签、设置项、分组和回调，不需要修改组件内部的场景树。组件负责原生 Godot 控件、数值编辑、分组和设置值；具体游戏逻辑由调用方接入。

本工程使用 Godot 4.7.2。设置页沿用 1920×1080 设计视口和当前灰阶主题，每个页签具有自己的滚动区域。场景自带返回按钮，点击时发送 `back_requested`；页面跳转、Esc 返回和窗口尺寸适配由宿主场景负责。

## 1. 直接运行示例

在 Godot 编辑器打开 `examples/settings_demo.tscn`，按 F6；也可以在项目目录执行：

```sh
godot --path . res://examples/settings_demo.tscn
```

从主菜单按 F10 也可以进入示例，示例中按 F10 返回主菜单。还可使用 `godot --path . -- --settings-demo` 直接进入。示例中 F12 保存真实视口截图到 `screenshots/17_settings_api_demo.png`。

示例覆盖所有设置项类型；改值会更新底部预览、只读结果行并打印回调，重置按钮演示静默赋值，返回按钮在该示例中用于重建页面。示例逻辑位于 `examples/settings_demo.gd`。工程主菜单的设置数据位于 `settings/main_settings_schema.json`，业务回调由 `main.gd` 接入。JSON 适合保存静态结构；`Callable` 不能放入 JSON，需要在脚本中补上。

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
| `add_option(tab_id: String, spec: Dictionary, parent_group: String = "") -> bool` | 向页签添加一项。省略 `parent_group` 时添加到页签顶层；否则添加到指定分组 |
| `get_value(id: String) -> Variant` | 获取单项当前值；未知 ID 或无值项返回 `null` |
| `get_values() -> Dictionary` | 获取当前设置值的深复制字典，以设置项 ID 为键 |
| `set_value(id: String, value: Variant, notify: bool = false) -> bool` | 更新单项值和对应控件。默认不发送业务通知；需要通知时传 `true` |
| `get_control(id: String) -> Control` | 获取设置项对应的原生控件；未知 ID 返回 `null` |
| `get_number_control(id: String) -> SpinBox` | 获取 `number` 或 `slider` 的数值框；未知 ID 或其他类型返回 `null` |
| `clear() -> void` | 清空页签、设置项和当前值 |

`last_error` 用于取得失败原因，应在方法返回 `false` 时读取。始终检查返回值，不要把无效输入当成已经应用。

`get_values()` 包含 `label`、`select`、`toggle`、`number`、`slider` 的值；不包含 `note`、`divider`、`action`、`group`。分组的展开状态不是设置值。隐藏或折叠不会删除已有子项值。

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

`parent_group` 使用分组设置项的全局 ID，而不是标题或节点路径。分组必须已经存在，并属于 `tab_id` 指定的页签。

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
- **没有隐含的应用行为。** `set_value()` 修改组件状态，不会自行切换全屏、修改音频总线、采集麦克风或发送网络请求
- **没有自动的应用/取消事务。** 若需要“编辑后应用”或“取消恢复”，由业务层保留已应用值和待应用值，再提供相应动作按钮
- **结构变更会重建控件。** `configure()`、`add_tab()`、`add_option()` 成功后，应重新取得所需控件引用；不要长期持有旧设置控件。动态添加会保留已有值和分组展开状态，但不应依赖原控件实例或焦点/滚动位置保留
- **校验失败不会部分替换页面。** 未知类型、重复 ID、错误分组/条件引用、非法数值范围和不在下拉选项内的值应作为配置错误处理；记录 `last_error` 后修正数据再重试
- **优先使用 ID 接口。** `get_value()`、`set_value()` 和 `get_control()` 比硬编码场景树路径更适合插件化或复用
- **复用时携带依赖。** 除 `settings_page.tscn/.gd` 外，还应保留场景引用的字体、图标等 `assets/` 资源，或改成自己的资源
- **中文字体有字集范围。** 当前字体为 UI 字符子集，增加文案时应检查缺字；需要通用中文输入文案时可替换完整字体


### 左右选项开关与动画

`toggle` 固定显示左右两个选项，默认左侧「关」、右侧「开」。点击按钮任意位置都会切换状态，无需拖动；深色选中底块以 0.20 秒缓出动画滑向另一侧。`off_text` / `on_text` 可自定义显示文字，例如 `"Off"` / `"On"`，两侧的业务值仍固定为 `false` / `true`。

- Tab 聚焦整个按钮；Space / Enter 切换；← 选择关，→ 选择开。聚焦时显示外框
- `get_control(id)` 仍返回兼容 `Button` 的控件，支持 `button_pressed`、`disabled`、`grab_focus()`
- 初始化直接显示正确选项，不播放初始动画、不调用业务回调
- `set_value(id, value)` 默认静默同步（可播放滑动）；传 `true` 才在值变化时通知。动画本身不触发额外回调
- 连续点击会从当前位置平滑转向最后一次选择；旧动画立即取消。重建 / 清空页面会停止旧控件动画
- 动画采用相对位置，宽度变化不会让选中底块脱离对应半区；不改变原设置行对齐和滚动方式
- 控件实现：`settings/segmented_toggle.gd`；回归测试：`tests/test_segmented_toggle.gd`
