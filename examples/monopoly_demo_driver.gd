extends Node
## LOCAL SAMPLE CONTROLLER ONLY. No board, dice result, movement or economy simulation.
const NAMES := ["蓝莓", "橘子", "薄荷", "葡萄", "可可", "桃子", "海盐", "柠檬"]
var page: Control
func bind_page(target: Control) -> void:
	page = target
	page.roll_requested.connect(func(): page.set_status("演示：已收到掷骰请求"))
	page.item_requested.connect(func(id): page.set_status("演示：道具请求 " + id))
	page.event_choice_requested.connect(func(event_id, choice_id):
		page.dismiss_event(event_id)
		page.set_status("演示：事件选项 " + choice_id))
func begin(player_count := 4) -> void:
	var ranks := []
	for i in clampi(player_count, 1, 8):
		ranks.append({"id": "player-%d" % i, "name": NAMES[i], "money": 12800 - i * 700, "diamonds": 36 - i * 3, "is_self": i == 0})
	page.set_snapshot({"money": 12800, "diamonds": 36, "leaderboard": ranks,
		"inventory": [{"id": "remote-dice", "name": "遥控骰子", "count": 1, "description": "道具说明由游戏提供；点击只发送 ID。"},
		{"id": "shield", "name": "护盾", "count": 2},
		{"id": "teleport", "name": "传送卡", "count": 0, "reason": "暂无库存"}],
		"roll_enabled": true, "roll_hint": "等待你的操作"})
func preview_event() -> void:
	page.show_event({"id": "sample-property-001", "title": "发现一处心仪的地产", "body": "海风花园 · 空置地产\n购买价格：2,400 金币。是否购入这块地产？\n价格、图示与按钮均由游戏控制器提供。", "illustration": preload("res://assets/ui/monopoly/property.svg"), "illustration_alt": "海风花园地产示意图", "choices": [
		{"id": "buy", "label": "购买地产 · 2,400 金币"},
		{"id": "skip", "label": "暂不购买"}]})
