# 大富翁悬浮 HUD：叠加在完整 3D 场景上

Godot **4.7.2**。正式组件是透明背景上的纯悬浮 UI：左上紧凑钱包、左下背包图标、右下掷骰图标、右侧中部常驻排行榜，以及按数据打开的事件弹窗。中间留给已有 3D 场景；HUD 不绘制棋盘、城市、骰子投掷结果或中心占位区，不包含移动、资产结算或回合规则。现有 3D 场景和 3D 骰子由项目自己控制。默认主菜单、大厅、设置和加载页保持原有流程。

## 运行示例

```sh
godot --path . res://examples/monopoly_demo.tscn
# 八人排行榜
godot --path . res://examples/monopoly_demo.tscn -- --eight-players
```

或在编辑器打开上述场景按 F6。F12 保存真实视口到 `screenshots/21_monopoly_game.png`（再次截图覆盖同一文件）。示例顶部「预览事件 / 重置 / 返回」和「本地 UI 示例」标识只属于示例；「预览事件」打开数据驱动的地产购买示例，购买 / 跳过都是该事件的选项。背景是独立 `SampleBackgroundOnly` 节点内的极简全幅 3D 天空和地面，用来验证 UI 浮动关系，不是正式棋盘。`Driver` 只提供固定示例数据并把请求写成状态文案；不生成骰子点数、不移动棋子、不消耗道具、不结算金钱。

## 可编辑场景与贴图

- `ui/pages/monopoly_overlay.tscn`：生产用 CanvasLayer（layer 20），子节点 `HUD` 提供下述 API。
- `ui/pages/monopoly_game.tscn/.gd`：透明 Control HUD，也可直接放入你现有 CanvasLayer。所有可视布局在场景中，不在运行时重新搭整页。
- `ui/components/monopoly_wallet.tscn`：左上横向紧凑排列的金币 / 钻石图标与数字。
- `ui/components/monopoly_image_button.tscn`：可复用 TextureButton 图片按钮，用于掷骰和背包入口。
- `ui/components/monopoly_rank_row.tscn`：动态实例化的排行榜行，最多八行；每人同时展示金币和钻石。
- `ui/components/monopoly_option.tscn`：道具 / 事件选项的可复用原生按钮。事件选项文案支持自动换行，道具保持单行省略和完整 tooltip。
- `ui/components/monopoly_event_modal.tscn`：事件遮罩、标题、可选插图、独立正文滚动、独立选项滚动及关闭按钮。
- `assets/ui/monopoly/`：自制 SVG 图标与示例图片，可作为占位资源直接替换。
- `ui/theme/monopoly_option_*.tres`：此 HUD 的内边距、圆角与状态样式，颜色仍跟随 `ui_config.tres` 的共享蓝色主题。可在 Inspector 单独改布局和 Theme Overrides。
- `examples/monopoly_demo_driver.gd`：明确标记的本地示例控制器；正式场景不实例化它。

设计坐标沿用项目 **1920×1080** 和 viewport 等比例缩放；默认物理窗口 1280×720。左下背包初始收起，点击图片按钮后，道具区域向右横向展开；再次点击收起。右侧中部排行榜以半透明面板常驻，不提供折叠入口。右下只有掷骰图片按钮及状态提示，没有独立行动区或常驻购买按钮。大量道具可在背包区域滚动，事件正文与选项分别滚动。若宿主使用不同的实际 UI 逻辑尺寸，应在编辑器调整边缘锚点 / 区域宽高，或沿用本项目基准视口缩放；本版本不是任意极窄逻辑视口的自适应布局。

替换掷骰图片时，打开 `monopoly_game.tscn`，选中 `Roll/Button`，在 Inspector 的 `Texture Normal`（`texture_normal`）中拖入自己的 Texture2D。背包入口位于 `Inventory/Toggle`，同样是 `monopoly_image_button.tscn` 的实例，可替换其 `texture_normal`；保留按钮节点与信号连接。图片仅表示可点击入口，不展示掷骰结果。事件插图由数据指定，见下文。

## 最小接入

```gdscript
var overlay = preload("res://ui/pages/monopoly_overlay.tscn").instantiate()
add_child(overlay) # 加在已有 3D 主场景下面
var hud = overlay.get_node("HUD")

hud.roll_requested.connect(_on_roll_requested)
hud.item_requested.connect(_on_item_requested)
hud.event_choice_requested.connect(_on_event_choice_requested)
hud.event_dismissed.connect(_on_event_dismissed)
hud.modal_visibility_changed.connect(_on_ui_modal_changed)

hud.set_snapshot({
    "money": 12800,
    "diamonds": 36,
    "leaderboard": [
        {"id": "player-a", "name": "蓝莓", "money": 12800,
         "diamonds": 36, "is_self": true},
        {"id": "player-b", "name": "橘子", "money": 12100, "diamonds": 42}
    ],
    "inventory": [
        {"id": "shield", "name": "护盾", "count": 2,
         "enabled": true, "description": "抵挡一次伤害"},
        {"id": "teleport", "name": "传送卡", "count": 0, "reason": "暂无库存"}
    ],
    "roll_enabled": true,
    "roll_hint": "轮到你行动",
    "status": ""
})

func _on_roll_requested():
    # UI 已锁住重复请求；外部控制器启动现有 3D 骰子 / 发送服务器请求。
    # 结果、动画、移动和结算都由你的游戏实现。
    hud.set_roll_enabled(false, "等待骰子动画结束")
    your_game.request_roll()

func _on_item_requested(item_id: String):
    your_game.request_item(item_id)

func _on_event_choice_requested(event_id: String, choice_id: String):
    your_game.request_event_choice(event_id, choice_id)
    # 等权威结果到达后，再调用 hud.dismiss_event(event_id) 或 show_event 刷新。
```

代码中的 `your_game` 和事件处理器是宿主自己的逻辑。网络 / 本地权威控制器仍须校验权限、请求去重和库存；UI 信号只表示用户意图。

## 快照及局部更新 API

数据更新方法返回 `bool`。无效数据返回 false，`last_error` 给出原因，之前的有效数据 / 画面 / pending 状态保持不变。`set_snapshot()` 与 `show_event()` 支持在 `_ready()` 前调用。输入和 getter 中的 Dictionary / Array 均深复制；Texture2D 等资源引用有意共享，不复制纹理资源本身。

`set_snapshot(state: Dictionary) -> bool` 是完整替换；遗漏字段取下列安全默认值，不是局部合并。额外字段可保存但不参与展示，**旧 `actions` 字段例外：只要出现便拒绝，包括空数组**。

- `money: int = 0`、`diamonds: int = 0`：非负整数，钱包自动加千位分隔。
- `leaderboard: Array = []`：0–8 项，**按调用方顺序展示，不自行排序**。每项必需唯一非空 `id: String`、`name: String`、非负 `money: int` 和 `diamonds: int`；可选 `is_self: bool = false`。每行同时显示两种资产并自动加千位分隔，不再以通用 `value` 文案表示排行数值。
- `inventory: Array = []`：0–128 项。必需唯一非空 `id: String`、`name: String`、非负 `count: int`。可选 `enabled: bool = true`、`description: String = ""`、`reason: String = ""`。count 为 0 或 enabled 为 false 时禁用；完整名称 / 描述 / 原因在 tooltip 中。
- `roll_enabled: bool = false`：掷骰按钮可用性；不代表已掷出的点数。
- `roll_hint: String = "等待游戏状态"`：掷骰状态与 tooltip。
- `status: String = ""`：若不为空，替代右下角提示文案；完整内容保留在 tooltip。

`get_snapshot() -> Dictionary` 返回复制后的完整数据。局部 setter 只更新其对应字段：

```gdscript
hud.set_wallet(money: int, diamonds: int) -> bool
hud.set_leaderboard(entries: Array) -> bool
hud.set_inventory(entries: Array) -> bool
hud.set_roll_enabled(enabled: bool, hint: String = "") -> bool
hud.set_status(text: String) -> bool
hud.set_inventory_open(open: bool) -> void
```

`set_inventory_open()` 只控制背包展开状态，不消耗道具或改变库存。排行榜始终显示，没有折叠 API。

### 请求信号与重复点击

- `roll_requested()`
- `item_requested(item_id: String)`

点击在发信号**之前**锁定该请求，重复点击无效；UI 不会自行修改金额、数量或掷骰结果。调用 `set_roll_enabled()` 解除掷骰 pending；`set_inventory()` 解除道具 pending；`set_snapshot()` 解除这两类 pending 并重新采用传入 availability。更新钱包、状态、排行不会解除其它请求的 pending。网络在途时若收到全量状态，应继续给相应请求传 enabled=false，避免错误重新授权。

`request_roll()`、`request_item(id: String)` 提供与按钮相同的校验 / latch，可由宿主自行绑定输入。隐藏、未 ready、模态打开、不可用或不存在的 ID 都不会触发请求。背包重建时使用 generation 校验，已经移出树、等待释放的旧道具按钮不能通过旧回调请求新数据中的同名 ID。HUD **不注册全局 Space 或其它掷骰快捷键**，不修改 InputMap。

## 数据驱动事件弹窗与插图

地产购买和随机事件都走同一个 `show_event()` 接口。事件标题、正文、插图和选项来自调用方；HUD 不内置地产价格、购买判定或结算逻辑。

```gdscript
# 宿主只解析自己信任的资源；这里使用项目自带的示例插图。
const PROPERTY_ILLUSTRATION: Texture2D = preload("res://assets/ui/monopoly/property.svg")

func show_property_offer(hud):
    hud.show_event({
        "id": "property-offer-123", # 用事件实例 ID，而非重复使用事件类型名称
        "title": "是否购买这处地产？",
        "body": "你来到一处待售地产。\n购买价格：2,000 金币。",
        "illustration": PROPERTY_ILLUSTRATION,
        "illustration_alt": "临街小屋与庭院",
        "dismissible": true,
        "choices": [
            {"id": "buy", "label": "购买 · 2,000 金币", "enabled": true},
            {"id": "skip", "label": "跳过"}
        ]
    })
```

`show_event(data: Dictionary) -> bool`：

- `id`、`title`、`body` 必须是 String，id 非空。
- `choices: Array = []`：0–32 项。每项必需唯一非空 `id: String`、`label: String`；可选 `enabled: bool = true`、`reason: String = ""`、`description: String = ""`。禁用选项保留显示及原因提示。
- `dismissible: bool = true`：是否允许用户关闭；不限制控制器按当前 ID 关闭。
- `illustration: Texture2D | null = null`：可选插图；省略或传 null 时不显示插图区。必须传已解析的 Texture2D，路径字符串或其它类型会被拒绝。
- `illustration_alt: String = ""`：可选的插图文字说明。

资源加载由调用方负责，例如使用 `preload()` 或宿主维护的可信资源映射。来自服务器或用户的数据应先在宿主转换成允许使用的 Texture2D；HUD 不接受任意图片路径，也不会自行调用 `load()` 加载外部指定资源。输入数据和 `get_event()` 的 Dictionary / Array 会复制，`illustration` 保持同一个 Texture2D 资源引用；宿主修改该资源本身可能影响正在显示的插图。

### 事件生命周期与模态输入

- 不同 ID：原子替换当前弹窗，不叠加遮罩、不排队；旧 ID 发 `event_dismissed(old_id, "replaced")`。保留第一次打开前的焦点。
- 相同 ID：刷新内容、插图及选项 availability，解除选项 pending，不发旧事件 dismissal。
- `event_choice_requested(event_id: String, choice_id: String)`：选择前锁定当前事件所有选项，**不自动关闭弹窗**；控制器回填同 ID 数据重试、用新 ID 替换，或权威关闭。
- `request_event_choice(choice_id: String)`：与点击选项同样的校验。旧按钮携带 generation，替换后不会用旧回调选择新事件。
- `close_event() -> bool`：用户式关闭；仅 dismissible=true 时生效，发 `event_dismissed(id, "closed")`。关闭按钮与 Esc 同样如此。
- `dismiss_event(event_id: String) -> bool`：控制器式关闭；匹配当前 ID 才生效，即使 dismissible=false 也能关闭，发 `event_dismissed(id, "controller")`；过期 ID 返回 false。
- `is_modal_open() -> bool`；`get_event() -> Dictionary`（无弹窗时 `{}`，容器数据复制，资源引用共享）。
- `modal_visibility_changed(open: bool)`：仅开 / 关边沿发出；替换或同 ID 刷新不重新发 true。用于宿主禁用 3D 输入 / 相机操作。

这些状态在信号发出前提交；同步回调可安全刷新、关闭或打开下一事件。无效刷新不改变当前弹窗。重复关闭不发重复信号。正文和大量选项分别滚动；标题省略时 tooltip 保留全文；Tab / Shift-Tab 保持在弹窗内；关闭后恢复仍有效且可用的旧焦点，否则回到可用的 HUD 控件。不可关闭且全部选项不可用的事件也保持可滚动，等待宿主刷新或 dismiss_event。

## 3D 输入集成要点

生产根节点、布局容器均 `MOUSE_FILTER_IGNORE`，只有真实面板 / 按钮接收鼠标。HUD 空白中心不遮挡 3D 输入。模态打开时全屏拦截鼠标，背景 HUD 请求禁用，未处理输入被消耗。

**Godot 的 `_input()` 和 `Input.is_action_pressed()` 轮询发生在 GUI 拦截之外；UI 无法撤销宿主已经处理的输入。** 3D 游戏应优先使用 `_unhandled_input()` 处理点击，同时在自定义 `_input()` / `_process()` / `_physics_process()` 中用 `hud.is_modal_open()` 或 `modal_visibility_changed` 驱动的标记禁用游戏操作。普通 HUD 上的鼠标事件同样应走 GUI 后的 `_unhandled_input()`，不要在早期 `_input()` 无条件点选棋盘。隐藏整个 HUD 前，按你的游戏流程关闭现有事件；弹窗数据不会因为节点 hide() 被静默销毁。

## 旧版接入迁移

- 删除快照中的 `actions`，包括原来的 `"actions": []`；这一字段现在会使 `set_snapshot()` 原子拒绝整份更新。将购买 / 跳过等情境操作改为 `show_event({..., "choices": [...]})`，通过 `event_choice_requested(event_id, choice_id)` 交给游戏处理。
- 删除 `action_requested` 信号连接和 `set_actions()`、`request_action()` 调用；这些 API 已移除。
- 排行条目从 `value: String` 改为必需的非负 `money: int` 与 `diamonds: int`。仅含旧 `value` 的条目无效；格式化由 UI 完成，排序仍由调用方负责。
- 删除 `set_leaderboard_open()` 调用；右侧中部排行榜常驻，不再折叠。
- 掷骰按钮节点路径改为 `Roll/Button`，使用 TextureButton 的 `texture_normal` 更换图片。背包初始收起，按需调用 `set_inventory_open(true)` 展开。
- `money` / `diamonds`、库存字段、掷骰 / 道具请求、事件生命周期及模态信号保持原有职责。场景运行路径和 F12 截图路径不变。

此接口同时替代旧棋盘演示的 position / active / rolled / property_selected / end_turn_requested 等协议；正式游戏不应继续调用旧棋盘接口。

## 测试

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_monopoly_game.gd
```

专项测试覆盖透明中心、无棋盘 / 骰子展示、图片按钮与背包默认收起、钱包 / 八人双资产排行、长名 / 空背包 / 不可用道具、稳定 ID、旧 actions / 非法状态原子拒绝、容器深复制与纹理资源共享、数据与事件 pre-ready、请求 latch 与局部更新、过期道具 / 事件回调、可选事件插图、模态背景隔离、Tab / Esc、关闭 / 强制关闭 / 事件替换 / 同 ID 刷新及同步回调重入。headless 验证不等于真实视觉验收，真实窗口截图由 F12 单独保存。
