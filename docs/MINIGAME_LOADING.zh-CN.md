# 小游戏加载 / 规则界面

## 体验入口

- 主菜单 → 创建房间 → 房主大厅「开始游戏」→ 小游戏加载页；左下角或 Esc 返回同一大厅，房间名、主游戏、地图、回合及设置不丢失。再进入保留本次小游戏准备状态；创建 / 加入新房间后重新初始化
- 编辑器打开 `examples/minigame_loading_demo.tscn` 按 F6，或运行 `godot --path . -- --minigame-demo`。独立演示的返回按钮回主菜单
- 本机在可见页面内用 2.5 秒模拟加载；加载中准备按钮禁用，完成后可以「准备 / 取消准备」。其他七名玩家是明确标记的 MOCK 数据，不连接网络
- 「模拟加载完成」完成所有仍在加载的玩家；「模拟其他人就绪」将其他七人标为已准备；「重新演示」恢复八人混合三态。全员准备后只提示等待开始，不倒计时或启动真实小游戏
- F12 保存当前真实 Godot 视口。独立示例固定输出 `screenshots/20_minigame_loading.png`

## 设计与可编辑结构

延续共享 Godot 蓝主题：大游戏名称、左侧演示画面、右侧编号规则及图标操作、下方八人就绪条、固定底部操作。每位玩家都包含头像 / 编号占位、名字、本机标记及「加载中 / 未准备 / 已准备」文字和不同符号；空位明确显示，颜色不是唯一提示。长名字省略但保留 tooltip。没有资源时显示清晰占位。

布局由原生 `.tscn` 组成，脚本负责内容与状态绑定：

- `ui/pages/minigame_loading.tscn`：完整页面，可在编辑器调整布局、容器间距、预览资源和节点
- `ui/components/minigame_player_card.tscn`：单个玩家卡，八个场景实例
- `ui/components/minigame_rule.tscn`：规则编号与可换行正文模板
- `ui/components/input_prompt.tscn`：复用 Kenney 图标与文字提示；动作可读取真实 InputMap；四方向按真实主绑定合并为「移动」，跳跃 / 交互显示所有备选绑定
- `examples/minigame_demo_driver.gd`：独立 mock 数据与加载模拟，正式接入时无需使用
- `assets/minigames/cloud_hop.svg`：为本项目原创的云台跳跃示意图，不含《揍击派对》的游戏美术

字体、字号、背景、主按钮、边框、分隔线沿用 `ui/theme/ui_config.tres` 的中文 Inspector 设置。已准备使用「示例启用反馈颜色」（success），加载中使用「示例按键反馈颜色」（info），未准备 / 空位使用「禁用文字颜色」，可统一修改 RGBA。游戏画面是独立媒体，不随 UI 调色。

默认遵循项目 1920×1080 设计视口，窗口统一缩放。将组件实际尺寸缩到 1350 以下时，演示与规则变为上下结构，玩家位变为两排四列。内容增大时使用 ScrollContainer；底部返回与准备操作始终固定，不挤压或覆盖正文。规则 / 操作从可编辑 PackedScene 模板实例化，不在代码中构造布局节点。

## 接入 API

```gdscript
var page = preload("res://ui/pages/minigame_loading.tscn").instantiate()
add_child(page)
var ok = page.configure({
    "title": "云端跃迁",
    "subtitle": "跳过断层，抢先抵达终点。",
    "round": "第 1 回合 / 5",
    "rules": ["在平台间移动和跳跃。", "率先抵达终点获胜。"],
    "controls": [
        {"actions": ["game_up", "game_left", "game_down", "game_right"], "binding_index": 0, "text": "移动"},
        {"action": "game_jump", "text": "跳跃"},
        {"binding": KEY_E, "text": "交互"}
    ],
    "image": preload("res://assets/minigames/cloud_hop.svg"),
    "video": null,
    "preview_caption": "玩法演示"
}, [
    {"id": "local", "name": "你", "state": "loading", "progress": 25},
    {"id": "peer", "name": "小林", "state": "ready"}
], "local", on_local_ready)
if not ok:
    push_error(page.last_error)

func on_local_ready(ready: bool, player_id: String) -> void:
    # 将本机意图交给你自己的游戏 / 联机层；界面先更新本地显示。
    print(player_id, ready)
```

`configure(game, players, local_player_id, callback)` 可以在加入场景树前调用。初始化不发准备回调，也不发 `all_ready`。未提供的游戏字段保留原值；显式传 `image: null` / `video: null` 清除资源。名单最多八位、id 非空且唯一，非法配置原子拒绝并保留旧数据。玩家缺省 state 为 loading；其他状态只接受 `not_ready` / `ready`。可传 `avatar: Texture2D`。progress 是 0～100 的百分比；loading 最高显示 99，只有明确切换状态才算加载完成。

```gdscript
page.set_player_state("peer", "loading", 60)
page.set_player_state("peer", "not_ready")
page.set_local_loaded(true)                 # 本机从加载中变为未准备
page.set_local_loaded(false, 0)             # 重新加载并撤销准备
page.set_players(updated_roster, "local")   # 玩家加入/离开，空席不阻塞
var roster = page.get_players()             # 防御性副本
var local = page.get_player("local")
page.toggle_local_ready()                   # 同按钮；加载/缺席/隐藏时无效
```

信号：

- `ready_changed(player_id, ready)`：仅本机用户准备 / 取消操作，随后调用 configure 的 Callable，签名为 `(ready, player_id)`
- `player_state_changed(player_id, state)`：单个玩家真实状态转换；仅进度变化和重复赋相同状态不重复通知
- `all_ready()`：名单非空，所有当前玩家进入已准备时触发一次；重复同步不触发，取消再准备可再次触发。只有显示事件，不授权或执行真正开始
- `back_requested()`：点击返回或 Esc，由接入方导航；组件不擅自销毁房间

未指定 / 已移除本机玩家时准备按钮禁用。程序同步玩家状态不会冒充本机用户回调。外部游戏层负责资源实际加载、连接状态与权威校验；UI 自己不会加载关卡、调用网络或保存数据到磁盘。`show_demo_controls` 默认关闭。

## 图片与视频

```gdscript
page.set_preview(my_texture, null, "玩法示意图")
page.set_preview(fallback_texture, my_video_stream, "玩法演示 · 静音")
page.set_preview() # 清空媒体并显示占位
```

VideoStream 优先，Texture2D 作为无视频或解码未输出画面时的回退。视频播放器音量固定为 0，不改变 Master 总线；隐藏页面、离开树、替换资源时停止旧播放。再次显示从头播放；完成后循环。视频按实际帧比例适配，图片保持宽高比。两秒仍未获得有效视频纹理时显示图片 / 占位和明确提示。默认仅提供原创 SVG，不下载或打包外部版权视频。

Godot 内置支持 Ogg Theora `.ogv`；其他格式需要应用自己的解码扩展。参考：[Godot VideoStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_videostreamplayer.html)。

## 参考边界

参考《揍击派对》的小游戏介绍结构，不复制其美术。官方资料可核实名称、说明、预览图和视频失败回退，但本次未获得可可靠检视的小游戏规则页精确布局，因此不声称像素复刻：

- [官方 Mod Settings](https://workshop.pummelparty.com/wiki/Mod_Settings)
- [官方小游戏教程](https://workshop.pummelparty.com/wiki/Tutorials/Building_A_Minigame_Mod)
- [官方 Steam 更新说明（含视频预览与截图回退）](https://store.steampowered.com/news/posts/?appids=880940&enddate=1680750553&feed=steam_community_announcements)

## 验证

`tests/test_minigame_loading.gd` 共 223 项，覆盖状态/API、八人列表、准备回调、数据替换、媒体与主题生命周期、几何及大厅往返；另以 `-- --minigame-demo` 执行 5 项 CLI 入口往返检查。`tests/test_minigame_video.gd` 共 22 项，以仓库内 8.9 KB 原创 FFmpeg 测试图样验证真实 Ogg/Theora 解码、像素尺寸、播放进度、结束循环、静音、隐藏停止和资源替换，同时覆盖四方向动作重绑 / 未绑定及非法分组输入。

连同既有回归，官方 Godot 4.7.2 共 7390 项检查通过；导入、主界面 / 独立 demo 各 180 帧 headless smoke、真实退出测试及 diff check 通过，无脚本错误或警告。headless 验证不能替代真实窗口渲染验收。

真实 Godot 4.7.2 窗口另通过默认 1920×1080 设计视口、云桌面实际约 1180 px 宽窗口、准备 / 取消 / 全员就绪、返回同一大厅保留房间状态，以及实际 1000×1080 组件尺寸加 14 条长规则的滚动验收：内容上下排列、八人四列两行、固定底部按钮均可见可用。云桌面窗口管理器未保留请求的精确 1280×720 物理窗口，未把这一尺寸记作实测。
