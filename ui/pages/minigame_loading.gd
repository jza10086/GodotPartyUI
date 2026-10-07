@tool
extends Control
## Presentation-only pre-game screen. No networking, asset loader or game launch.
## Layouts are editable PackedScenes. Public updates are safe before _ready().
signal back_requested
signal ready_changed(player_id: String, ready: bool)
signal player_state_changed(player_id: String, state: String)
signal all_ready
signal demo_complete_load_requested
signal demo_ready_peers_requested
signal demo_reset_requested

const RULE = preload("res://ui/components/minigame_rule.tscn")
const PROMPT = preload("res://ui/components/input_prompt.tscn")
const MAX_PLAYERS := 8
const STATES := ["loading", "not_ready", "ready"]
@export var game_title := "云端跃迁"
@export var game_subtitle := "跳过断层，抢先抵达终点。"
@export var round_text := "第 01 回合  /  05"
@export var rule_lines: Array[String] = ["在浮空平台间移动与跳跃，避开断层。", "掉落后回到上一平台，继续向终点前进。", "率先碰到金色星标的玩家获胜。"]
@export var preview_image: Texture2D
@export var preview_video: VideoStream
@export var preview_caption := "玩法演示 · 原创示意图"
@export var show_demo_controls := false
@export var back_text := "← 返回大厅"
var last_error := ""
var _players: Array[Dictionary] = []
var _local_id := ""
var _ready_callback := Callable()
var _controls: Array[Dictionary] = [
	{"keys": [KEY_W, KEY_A, KEY_S, KEY_D], "separator": " ", "text": "移动"},
	{"binding": KEY_SPACE, "text": "跳跃"},
	{"binding": KEY_E, "text": "交互 / 抵达终点"},
]
var _all_ready_latched := false
var _last_image: Texture2D
var _last_video: VideoStream
var _video_failed := false
var _video_wait_seconds := 0.0

func _enter_tree() -> void:
	_sync_video_playback.call_deferred()

func _ready() -> void:
	%Back.pressed.connect(func(): back_requested.emit())
	%Ready.pressed.connect(toggle_local_ready)
	%CompleteLoad.pressed.connect(func(): demo_complete_load_requested.emit())
	%ReadyPeers.pressed.connect(func(): demo_ready_peers_requested.emit())
	%ResetDemo.pressed.connect(func(): demo_reset_requested.emit())
	%Video.finished.connect(_restart_video)
	set_process(false)
	visibility_changed.connect(_sync_video_playback)
	resized.connect(_adapt_layout)
	refresh_content()
	_render_players()
	_adapt_layout()

## Atomically configure content and roster. Invalid data leaves the page unchanged.
## Initialization is silent. Callback signature: (ready: bool, player_id: String).
func configure(game: Dictionary, players: Array, local_player_id: String, callback: Callable = Callable()) -> bool:
	if not _validate_players(players): return false
	if game.has("image") and game.image != null and not game.image is Texture2D: return _fail("image 必须为 Texture2D 或 null")
	if game.has("video") and game.video != null and not game.video is VideoStream: return _fail("video 必须为 VideoStream 或 null")
	if game.has("rules") and not (game.rules is Array or game.rules is PackedStringArray): return _fail("rules 必须为文字数组")
	if game.has("controls"):
		if not game.controls is Array: return _fail("controls 必须为字典数组")
		for spec in game.controls:
			if not spec is Dictionary: return _fail("每条 controls 必须为字典")
			if spec.has("action"):
				if not (spec.action is String or spec.action is StringName) or str(spec.action).is_empty(): return _fail("action 必须为非空动作名称")
			if spec.has("binding_index") and (not spec.binding_index is int or spec.binding_index < -1 or spec.binding_index > 32): return _fail("binding_index 必须为 -1～32 的整数")
			if spec.has("separator") and not spec.separator is String: return _fail("separator 必须为字符串")
			if spec.has("actions"):
				if not (spec.actions is Array or spec.actions is PackedStringArray): return _fail("actions 必须为动作名称数组")
				if spec.actions.is_empty(): return _fail("actions 不可为空数组")
				for action in spec.actions:
					if not (action is String or action is StringName) or str(action).is_empty(): return _fail("actions 必须为非空动作名称数组")
			if spec.has("keys"):
				if not (spec.keys is Array or spec.keys is PackedInt32Array or spec.keys is PackedInt64Array): return _fail("keys 必须为整数数组")
				for key in spec.keys:
					if not key is int: return _fail("keys 必须为整数数组")
	game_title = str(game.get("title", game_title))
	game_subtitle = str(game.get("subtitle", game_subtitle))
	round_text = str(game.get("round", round_text))
	if game.has("rules"):
		rule_lines.clear()
		for line in game.rules: rule_lines.append(str(line))
	if game.has("controls"):
		_controls.clear()
		for spec in game.controls: _controls.append(spec.duplicate(true))
	preview_image = game.get("image", preview_image)
	preview_video = game.get("video", preview_video)
	preview_caption = str(game.get("preview_caption", preview_caption))
	_local_id = local_player_id
	_ready_callback = callback
	_players = _normalized_players(players)
	_all_ready_latched = is_everyone_ready()
	last_error = ""
	if is_node_ready():
		refresh_content()
		_render_players()
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false

func _validate_players(players: Array) -> bool:
	if players.size() > MAX_PLAYERS: return _fail("最多支持 8 位玩家")
	var seen: Dictionary = {}
	for data in players:
		if not data is Dictionary: return _fail("玩家数据必须为字典")
		var raw_id: Variant = data.get("id", "")
		if not (raw_id is String or raw_id is StringName): return _fail("玩家 id 必须为字符串")
		var id := str(raw_id)
		if id.strip_edges().is_empty() or seen.has(id): return _fail("玩家 id 必须非空且唯一")
		seen[id] = true
		if not str(data.get("state", "loading")) in STATES: return _fail("无效玩家状态")
		if data.has("avatar") and data.avatar != null and not data.avatar is Texture2D: return _fail("avatar 必须为 Texture2D 或 null")
		if data.has("progress"):
			if not (data.progress is float or data.progress is int): return _fail("progress 必须为数值")
			if not is_finite(float(data.progress)): return _fail("progress 必须为有限数值")
	return true

func _normalized_players(players: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source in players:
		var data: Dictionary = source.duplicate(true)
		data.id = str(data.id)
		data.name = str(data.get("name", "玩家"))
		data.state = str(data.get("state", "loading"))
		data.progress = clampf(float(data.get("progress", 0.0)), 0.0, 99.0) if data.state == "loading" else 100.0
		result.append(data)
	return result

## Replace the current connected roster. Empty seats do not block readiness.
func set_players(players: Array, local_player_id: String = _local_id) -> bool:
	if not _validate_players(players): return false
	_players = _normalized_players(players)
	_local_id = local_player_id
	last_error = ""
	_render_players()
	_check_all_ready()
	return true

func get_players() -> Array[Dictionary]:
	return _players.duplicate(true)

func get_local_player_id() -> String:
	return _local_id

func get_player(player_id: String) -> Dictionary:
	for data in _players:
		if data.id == player_id: return data.duplicate(true)
	return {}

func set_player_state(player_id: String, state: String, progress := 0.0) -> bool:
	if not state in STATES: return _fail("无效玩家状态")
	if not is_finite(progress): return _fail("progress 必须为有限数值")
	for data in _players:
		if data.id != player_id: continue
		var next_progress := clampf(progress, 0.0, 99.0) if state == "loading" else 100.0
		if data.state == state and is_equal_approx(data.progress, next_progress):
			last_error = ""
			return true
		var state_changed: bool = data.state != state
		data.state = state
		data.progress = next_progress
		last_error = ""
		_render_players()
		if state_changed: player_state_changed.emit(player_id, state)
		_check_all_ready()
		return true
	return _fail("未找到玩家：" + player_id)

func set_local_loaded(loaded: bool, progress := 0.0) -> bool:
	var current := get_player(_local_id)
	if loaded and not current.is_empty() and current.state == "ready": return true
	return set_player_state(_local_id, "not_ready" if loaded else "loading", progress)

## User action only. Disabled, absent, hidden and loading local players cannot ready.
func toggle_local_ready() -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree(): return
	var data := get_player(_local_id)
	if data.is_empty() or data.state == "loading": return
	var ready: bool = data.state != "ready"
	var id := _local_id
	var callback := _ready_callback
	set_player_state(id, "ready" if ready else "not_ready")
	ready_changed.emit(id, ready)
	if callback.is_valid(): callback.call(ready, id)

func is_everyone_ready() -> bool:
	if _players.is_empty(): return false
	for data in _players:
		if data.state != "ready": return false
	return true

func _check_all_ready() -> void:
	var now := is_everyone_ready()
	var entered := now and not _all_ready_latched
	_all_ready_latched = now
	if entered: all_ready.emit()

func _render_players() -> void:
	if not is_node_ready(): return
	var ready_count := 0
	var loaded_count := 0
	for i in MAX_PLAYERS:
		%Players.get_child(i).set_player(_players[i] if i < _players.size() else {}, _local_id)
	for data in _players:
		if data.state == "ready": ready_count += 1
		if data.state != "loading": loaded_count += 1
	%ReadyCount.text = "已准备 %d / %d    ·    已加载 %d / %d" % [ready_count, _players.size(), loaded_count, _players.size()]
	var local := get_player(_local_id)
	%Ready.disabled = local.is_empty() or local.state == "loading"
	%ReadyPrompt.disabled = %Ready.disabled
	if local.is_empty():
		%Ready.text = "等待本机加入"
		%Summary.text = "未指定本机玩家 · 可查看规则和演示"
	elif local.state == "loading":
		%Ready.text = "加载中 · %d%%" % roundi(local.progress)
		%Summary.text = "正在加载本机资源，完成后即可准备"
	else:
		%Ready.text = "取消准备" if local.state == "ready" else "准备"
		%Summary.text = "全部准备完成 · 等待游戏开始" if is_everyone_ready() else ("你已准备 · 等待其他玩家" if local.state == "ready" else "本机加载完成 · 看完规则后请准备")
	%ReadyPrompt.function_text = "确认当前按钮"

## Call after editing exported presentation values at runtime.
func refresh_content() -> void:
	if not is_node_ready(): return
	%GameTitle.text = game_title
	%Subtitle.text = game_subtitle
	%Round.text = round_text
	%Back.text = back_text
	%DemoBar.visible = show_demo_controls and not Engine.is_editor_hint()
	_rebuild_rules()
	_rebuild_controls()
	set_preview(preview_image, preview_video, preview_caption)

func _rebuild_rules() -> void:
	for child in %Rules.get_children():
		%Rules.remove_child(child)
		child.queue_free()
	for i in rule_lines.size():
		var row := RULE.instantiate()
		%Rules.add_child(row)
		row.get_node("NumberFrame/Number").text = "%02d" % (i + 1)
		row.get_node("Text").text = rule_lines[i]

func _rebuild_controls() -> void:
	for child in %Controls.get_children():
		%Controls.remove_child(child)
		child.queue_free()
	for spec in _controls:
		var prompt := PROMPT.instantiate()
		%Controls.add_child(prompt)
		prompt.label_variation = &"PartyLabelBody"
		prompt.icon_height = 40
		prompt.function_text = str(spec.get("text", "操作"))
		if spec.has("actions"):
			prompt.action_names = PackedStringArray(spec.actions)
			prompt.binding_index = int(spec.get("binding_index", 0))
			prompt.key_separator = str(spec.get("separator", " "))
		elif spec.has("action"):
			prompt.action_name = StringName(spec.action)
			prompt.binding_index = int(spec.get("binding_index", -1))
		elif spec.has("keys"):
			prompt.keycodes = PackedInt64Array(spec.keys)
			prompt.key_separator = str(spec.get("separator", "+"))
		else: prompt.set_binding(spec.get("binding"))
		prompt.refresh()

## Video takes precedence, then image, then readable placeholder. Always muted.
func set_preview(image: Texture2D = null, video: VideoStream = null, caption := "") -> void:
	preview_image = image
	preview_video = video
	preview_caption = caption
	if not is_node_ready(): return
	var changed := _last_image != image or _last_video != video
	_video_failed = false
	_video_wait_seconds = 0.0
	if changed:
		%Video.stop()
		%Video.stream = video
		_video_failed = false
		_video_wait_seconds = 0.0
		_last_video = video
		_last_image = image
	%Image.texture = image
	%Image.visible = video == null and image != null
	%Video.visible = video != null
	%Placeholder.visible = video == null and image == null
	%MediaCaption.text = caption if not caption.is_empty() else ("玩法演示 · 视频静音播放" if video != null else ("玩法演示 · 图片" if image != null else "暂无演示资源 · 可先阅读右侧规则"))
	%Video.volume = 0.0
	_sync_video_playback()

func _sync_video_playback() -> void:
	if not is_node_ready() or not %Video.is_inside_tree(): return
	set_process(not Engine.is_editor_hint() and is_visible_in_tree() and preview_video != null and not _video_failed)
	if Engine.is_editor_hint() or not is_visible_in_tree() or preview_video == null or _video_failed:
		%Video.stop()
	elif not %Video.is_playing(): %Video.play()

func _restart_video() -> void:
	if is_visible_in_tree() and preview_video != null and not Engine.is_editor_hint() and not _video_failed: %Video.play()

func _process(delta: float) -> void:
	# Broken/unsupported decoder streams must not leave the preview blank.
	var texture: Texture2D = %Video.get_video_texture()
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		%VideoFrame.ratio = float(texture.get_width()) / float(texture.get_height())
		set_process(false)
		return
	_video_wait_seconds += delta
	if _video_wait_seconds < 2.0: return
	_video_failed = true
	%Video.stop()
	%Video.visible = false
	%Image.visible = preview_image != null
	%Placeholder.visible = preview_image == null
	%MediaCaption.text = "视频暂不可用 · 已显示演示图片" if preview_image != null else "视频暂不可用 · 请先阅读游戏规则"
	set_process(false)

func _exit_tree() -> void:
	if is_instance_valid(get_node_or_null("%Video")): %Video.stop()

func focus_primary() -> void:
	if not %Ready.disabled: %Ready.grab_focus()
	else: %Back.grab_focus()

func _adapt_layout() -> void:
	if not is_node_ready(): return
	%Body.vertical = size.x < 1350
	%Players.columns = 4 if size.x < 1350 else 8
	%Media.custom_minimum_size.y = 360 if size.x < 1350 else 430
	%Info.custom_minimum_size.x = 0 if size.x < 1350 else 610

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		back_requested.emit()
		get_viewport().set_input_as_handled()
