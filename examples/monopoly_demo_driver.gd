extends Node
## LOCAL SAMPLE CONTROLLER ONLY. No board, dice result, movement or economy simulation.
const NAMES := ["蓝莓", "橘子", "薄荷", "葡萄", "可可", "桃子", "海盐", "柠檬"]
var page: Control
func bind_page(target: Control) -> void:
	page = target
	page.roll_requested.connect(func(): page.set_status("演示：已收到掷骰请求"))
	page.item_requested.connect(func(id): page.set_status("演示：道具请求 " + id))
	page.action_requested.connect(func(id): page.set_status("演示：行动请求 " + id))
	page.event_choice_requested.connect(func(event_id, choice_id):
		page.dismiss_event(event_id)
		page.set_status("演示：事件选项 " + choice_id))
func begin(player_count := 4) -> void:
	var ranks := []
	for i in clampi(player_count, 1, 8):
		ranks.append({"id": "player-%d" % i, "name": NAMES[i], "value": str(12800 - i * 700), "is_self": i == 0})
	page.set_snapshot({"money": 12800, "diamonds": 36, "leaderboard": ranks,
		"inventory": [{"id": "remote-dice", "name": "遥控骰子", "count": 1, "description": "道具说明由游戏提供；点击只发送 ID。"},
		{"id": "shield", "name": "护盾", "count": 2},
		{"id": "teleport", "name": "传送卡", "count": 0, "reason": "暂无库存"}],
		"actions": [{"id": "buy", "label": "购买地产"}, {"id": "skip", "label": "放弃购买"}],
		"roll_enabled": true, "roll_hint": "等待你的操作"})
func preview_event() -> void:
	page.show_event({"id": "sample-chance", "title": "旅途中的意外惊喜", "body": "你收到一份神秘邀请。\n选择下一步行动。事件内容、条件与结果均由外部游戏逻辑提供。", "choices": [
		{"id": "accept", "label": "接受邀请"},
		{"id": "leave", "label": "继续旅程"},
		{"id": "special", "label": "特殊行动 · 暂不可用", "enabled": false, "reason": "由游戏决定可用条件"}]})
