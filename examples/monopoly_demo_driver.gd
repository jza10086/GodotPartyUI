extends Node
## Deterministic local hot-seat preview; intentionally no real economic or networking rules.
const NAMES := ["蓝莓", "橘子", "薄荷", "葡萄", "可可", "桃子", "海盐", "柠檬"]
const COLORS := ["478cbf", "c28d59", "659e92", "9482b2", "947c72", "bd889e", "5f9faf", "b3aa64"]
const ROLLS := [[3, 4], [2, 3], [6, 2], [1, 5]]
var page: Control
var state: Dictionary = {}
var roll_cursor := 0

func bind_page(target: Control) -> void:
	page = target
	page.roll_requested.connect(roll)
	page.end_turn_requested.connect(end_turn)
	page.item_requested.connect(select_item)

func begin(player_count := 4) -> void:
	var players := []
	for i in clampi(player_count, 1, 8):
		players.append({"id": "p%d" % i, "name": NAMES[i], "cash": 12800 - i * 700, "properties": 3 + i % 3, "position": [0, 5, 11, 17, 2, 8, 14, 20][i], "color": Color(COLORS[i])})
	roll_cursor = 0
	state = {"players": players, "active": 0, "round": 3, "rolled": false, "can_act": true, "activity": "欢迎来到蓝湾，轮到蓝莓行动。"}
	page.set_snapshot(state)

func roll() -> void:
	if state.is_empty() or state.rolled or not state.can_act: return
	var dice: Array = ROLLS[roll_cursor % ROLLS.size()]
	roll_cursor += 1
	var steps: int = dice[0] + dice[1]
	state.players[state.active].position = (state.players[state.active].position + steps) % 24
	state.rolled = true
	state.dice_text = "%d  +  %d" % dice
	state.result = "本次前进 %d 步" % steps
	state.hint = "已抵达新地块 · 可查看详情或结束回合"
	state.activity = "%s 掷出 %d 点，已移动棋子（模拟）。" % [state.players[state.active].name, steps]
	page.set_snapshot(state)

func end_turn() -> void:
	if state.is_empty() or not state.rolled or not state.can_act: return
	state.active = (state.active + 1) % state.players.size()
	if state.active == 0: state.round += 1
	state.rolled = false
	state.dice_text = "—  +  —"
	state.result = "两枚骰子 · 2–12 步"
	state.hint = "掷出骰子，开启下一段旅程"
	state.item_hint = "选择道具查看说明"
	state.activity = "轮到 %s 行动。本地轮流操作演示。" % state.players[state.active].name
	page.set_snapshot(state)

func select_item(index: int) -> void:
	if state.is_empty() or state.rolled or not state.can_act: return
	if index == 0: state.item_hint = "遥控骰子：指定前进步数。\n已选中预览，未实际消耗。"
	elif index == 1: state.item_hint = "租金护盾：抵挡一次租金。\n已选中预览，未实际消耗。"
	else: return
	page.set_snapshot(state)
