# 蓝湾大富翁 · 棋盘 UI 原型

## 运行与范围

使用 Godot **4.7.2** 打开 `examples/monopoly_demo.tscn`，按 F6，或：

```sh
godot --path . res://examples/monopoly_demo.tscn
# 八人压力展示
godot --path . res://examples/monopoly_demo.tscn -- --eight-players
```

本轮是独立、本地、可交互的 UI 演示，不改变默认 `main.tscn`、大厅、设置或小游戏加载流程。默认四人，框架容纳一至八人；演示是本地轮流操作，不假装已经联网。F12 保存当前真实视口到 `screenshots/21_monopoly_game.png`；需要保留不同状态时请重命名截图。

- 左侧显示玩家资产概览，数字编号对应棋盘上的 P1–P8；当前玩家明确标注“行动中”
- 中央为 24 个原生 Button 地块围成的棋盘；蓝湾建筑是本项目原创 SVG 装饰，不是截图或不可编辑 UI
- 右侧集中骰子、道具预览和结束回合；底部 Kenney Space/Esc 提示复用现有组件
- 点击地块查看地产信息，Esc 或“返回棋盘”关闭并恢复焦点；弹层打开时屏蔽背景按钮和快捷键
- 掷骰依次产生 3+4、2+3、6+2、1+5，移动对应编号到地块；一个回合只能掷一次，之后才能结束回合
- 道具按钮仅选择并显示说明，不消耗库存，不改变骰子；资金、地产数量、租金、持有者全部为展示数据，不结算真实经济规则
- 原型无购买、拍卖、交易、破产、胜负、AI、存档或网络；正式游戏应自行接入这些逻辑

## 场景与职责

| 文件 | 职责 |
| --- | --- |
| `ui/pages/monopoly_game.tscn` | 可直接在 2D 编辑器调整的完整页面，含棋盘、八个玩家组件实例、行动区、地产详情弹层 |
| `ui/pages/monopoly_game.gd` | 只渲染快照和发出交互请求，不执行规则 |
| `ui/components/monopoly_tile.tscn/.gd` | 可复用地块；Inspector 修改 ID、名称、价格说明、地段色条 |
| `ui/components/monopoly_player.tscn/.gd` | 可复用玩家资产卡；编号、姓名、资产、行动状态 |
| `examples/monopoly_demo_driver.gd` | 确定性本地模拟，独立管理回合、棋子位置和道具说明 |
| `examples/monopoly_demo.tscn/.gd` | 绑定页面与驱动器、返回主菜单、F12 截图 |
| `assets/monopoly_city.svg` | 原创矢量城市装饰，可替换 |

设计视口沿用项目 1920×1080，默认窗口 1280×720，按现有 viewport stretch 等比例缩放。棋盘格、面板、按钮、文字全部是场景中的原生节点，可编辑位置、尺寸、主题变体、颜色覆盖和文字。统一主题沿用 `party_theme.tres` / `ui_config.tres`；地段色条、玩家识别色与 SVG 是局部游戏语义色，不覆盖全局主题。

## 接入正式玩法

```gdscript
var page = preload("res://ui/pages/monopoly_game.tscn").instantiate()
add_child(page)
page.roll_requested.connect(on_roll_requested)
page.end_turn_requested.connect(on_end_turn_requested)
page.item_requested.connect(on_item_requested) # 0 遥控骰子，1 租金护盾
page.property_selected.connect(on_property_selected) # 0..23
page.back_requested.connect(on_back_requested)

var ok = page.set_snapshot({
    "players": [
        {"id": "player-1", "name": "蓝莓", "cash": 12800,
         "properties": 3, "position": 0, "color": Color("478cbf")}
    ],
    "active": 0,
    "round": 3,
    "rolled": false,
    "can_act": true,
    "dice_text": "—  +  —",
    "result": "两枚骰子 · 2–12 步",
    "hint": "掷出骰子，开启下一段旅程",
    "activity": "轮到蓝莓行动。",
    "item_hint": "选择道具查看说明"
})
if not ok:
    push_warning(page.last_error)
```

`set_snapshot()` 在 `_ready()` 前后均可调用；原子校验玩家数量、唯一非空 ID、非负整数资产/地产数/位置、合法棋盘位置和当前玩家索引。错误返回 false，保留上一份有效画面，原因在 `last_error`。调用方应提供正确类型的可选展示字段：round 整数；rolled/can_act 布尔；各文案字符串；color 为 Color。`get_snapshot()` 返回深复制，外部修改不会污染页面。

`can_act=false` 用于观战或等待其他玩家时禁用骰子、道具和结束回合；地产详情仍可查看。正式规则层须再检查权限、回合状态和请求去重，并在异步请求发出后立即回填 `can_act=false`，得到权威结果后更新快照。页面发出的请求信号不代表服务器接受，也不会自行修改快照。正式接入时不实例化 demo driver。

当前地产信息弹层是示例格式：从场景地块名称/类型加固定公式显示价格，不是资产数据库；请将 `show_property()` 的示例详情替换为项目自己的地产模型。不存在购买/交易的伪提交按钮。正式资产、道具、回合总数和拥有权颜色仍需按玩法接入。

## 回归测试

```sh
godot --headless --path . --script res://tests/test_monopoly_game.gd
```

覆盖四人默认、八人完整一轮、重复掷骰/结束回合、道具说明、地块详情/特殊格、Esc 和焦点恢复、弹层屏蔽背景、只读观战状态、非法快照原子拒绝、深复制、拥挤棋子压缩显示/完整 tooltip、长中文名称，以及 ready 前回填。纯 UI 数据及交互测试不等于真实游戏规则或网络测试。
