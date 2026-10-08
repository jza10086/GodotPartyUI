extends Control
## Presentation layer. Requests are signals; authoritative state belongs to the caller.
signal roll_requested
signal end_turn_requested
signal item_requested(item_index: int)
signal property_selected(tile_id: int)
signal back_requested
const MAX_PLAYERS := 8
const TILE_COUNT := 24
var last_error := ""
var _snapshot: Dictionary = {}
var _focus_before_modal: Control

func _ready() -> void:
	$Back.pressed.connect(func(): back_requested.emit())
	$TurnPanel/Roll.pressed.connect(request_roll)
	$EndTurn.pressed.connect(request_end_turn)
	$Item0.pressed.connect(func(): request_item(0))
	$Item1.pressed.connect(func(): request_item(1))
	$Modal/Dialog/Close.pressed.connect(close_property)
	$Modal/Dialog/Close.focus_next = NodePath(".")
	$Modal/Dialog/Close.focus_previous = NodePath(".")
	for tile in _tiles(): tile.pressed.connect(show_property.bind(tile.tile_id))
	if not _snapshot.is_empty(): _render()

## Atomic validation: malformed state never partially replaces the current UI.
## Players require a stable unique id, display name, nonnegative cash/properties and a 0..23 position.
func set_snapshot(state: Dictionary) -> bool:
	last_error = ""
	var players: Variant = state.get("players", [])
	if not players is Array or players.size() < 1 or players.size() > MAX_PLAYERS:
		return _reject("玩家数量必须为 1–8。")
	var ids := {}
	for player in players:
		if not player is Dictionary: return _reject("玩家数据必须为 Dictionary。")
		var id := str(player.get("id", ""))
		if id.is_empty() or ids.has(id): return _reject("玩家 ID 不能为空或重复。")
		ids[id] = true
		if player.has("color") and not player.color is Color: return _reject("玩家颜色必须为 Color。")
		for field in ["cash", "properties", "position"]:
			if not player.get(field) is int or player[field] < 0: return _reject("玩家数值必须为非负整数。")
		if player.position >= TILE_COUNT: return _reject("地块位置超出范围。")
	if not state.get("active") is int or state.active < 0 or state.active >= players.size():
		return _reject("当前玩家索引无效。")
	for field in ["rolled", "can_act"]:
		if state.has(field) and not state[field] is bool: return _reject("行动标记必须为布尔值。")
	if state.has("round") and (not state.round is int or state.round < 1): return _reject("回合数必须为正整数。")
	_snapshot = state.duplicate(true)
	if is_node_ready(): _render()
	return true

func get_snapshot() -> Dictionary: return _snapshot.duplicate(true)
func _reject(message: String) -> bool:
	last_error = message
	return false

func _tiles() -> Array:
	return $Board.get_children().filter(func(child): return child is Button)

func _render() -> void:
	var players: Array = _snapshot.players
	var active: int = _snapshot.active
	for i in MAX_PLAYERS:
		var card: Control = $Players.get_child(i)
		card.visible = i < players.size()
		if card.visible: card.configure(players[i], i, i == active)
	$PlayerCount.text = "%d 位玩家 · 最多支持 8 人" % players.size()
	$Round.text = "第 %02d / 12 回合" % int(_snapshot.get("round", 1))
	$Board/TurnTitle.text = str(players[active].get("name", "玩家")) + "的回合"
	$Board/TurnTitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	$Board/TurnTitle.tooltip_text = $Board/TurnTitle.text
	$Board/TurnHint.text = str(_snapshot.get("hint", "掷出骰子，开启下一段旅程"))
	$TurnPanel/Phase.text = "可结束回合" if _snapshot.get("rolled", false) else "等待掷骰"
	$TurnPanel/Dice.text = str(_snapshot.get("dice_text", "—  +  —"))
	$TurnPanel/RollResult.text = str(_snapshot.get("result", "两枚骰子 · 2–12 步"))
	$ItemHint.text = str(_snapshot.get("item_hint", "选择道具查看说明"))
	$Activity.text = "城市快讯  /  " + str(_snapshot.get("activity", "欢迎来到蓝湾。"))
	$Activity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	$Activity.tooltip_text = $Activity.text
	for tile in _tiles():
		var occupants := []
		for i in players.size():
			if players[i].position == tile.tile_id: occupants.append(i)
		tile.set_occupants(occupants)
	_update_actions()

func _update_actions() -> void:
	var blocked: bool = $Modal.visible or _snapshot.is_empty() or not _snapshot.get("can_act", false)
	var rolled: bool = _snapshot.get("rolled", false)
	$TurnPanel/Roll.disabled = blocked or rolled
	$EndTurn.disabled = blocked or not rolled
	$Item0.disabled = blocked or rolled
	$Item1.disabled = blocked or rolled
	$Back.disabled = $Modal.visible
	for tile in _tiles(): tile.disabled = $Modal.visible

func request_roll() -> void:
	if not $TurnPanel/Roll.disabled: roll_requested.emit()
func request_end_turn() -> void:
	if not $EndTurn.disabled: end_turn_requested.emit()
func request_item(index: int) -> void:
	if index in [0, 1] and not $Item0.disabled: item_requested.emit(index)

func show_property(tile_id: int) -> void:
	if $Modal.visible or tile_id < 0 or tile_id >= TILE_COUNT: return
	var tile: Button = $Board.get_node("Tile%02d" % tile_id)
	_focus_before_modal = get_viewport().gui_get_focus_owner()
	if _focus_before_modal == null: _focus_before_modal = tile
	$Modal/Dialog/Name.text = tile.property_name
	var special: bool = not tile.price_text.begins_with("$")
	$Modal/Dialog/District.text = "城市事件 · 特殊地块" if special else "蓝湾城市 · 地产信息示例"
	var value := 800 + tile_id * 100
	$Modal/Dialog/Details.text = ("类型    %s\n效果    由玩法逻辑接入\n状态    本地 UI 预览" % tile.price_text) if special else ("地价    $ %d\n基础租金    $ %d\n持有者    暂无（示例）" % [value, value / 10])
	$Modal.show()
	_update_actions()
	$Modal/Dialog/Close.grab_focus()
	property_selected.emit(tile_id)

func close_property() -> void:
	if not $Modal.visible: return
	$Modal.hide()
	_update_actions()
	if is_instance_valid(_focus_before_modal): _focus_before_modal.grab_focus()

func _input(event: InputEvent) -> void:
	# Space is the advertised global roll shortcut, even when an item has focus.
	# Enter remains available for normal focused-button activation.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and not $Modal.visible:
		request_roll()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and $Modal.visible:
		close_property()
		get_viewport().set_input_as_handled()
