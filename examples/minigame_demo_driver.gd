extends Node
## Explicit mock host: owns fake loading, peers and the sample content.
## The reusable UI itself never simulates loading, contacts peers or starts games.
var page: Control
var initialized := false
var elapsed := 0.0
var local_name := "你"

func bind_page(target: Control) -> void:
	page = target
	page.demo_complete_load_requested.connect(complete_loading)
	page.demo_ready_peers_requested.connect(ready_peers)
	page.demo_reset_requested.connect(reset_demo)

func begin(display_name := "你") -> void:
	local_name = display_name
	if not initialized: reset_demo()

func reset_demo() -> void:
	if page == null: return
	elapsed = 0.0
	initialized = true
	page.show_demo_controls = true
	var peers := [
		{"id":"local", "name":local_name, "state":"loading", "progress":12},
		{"id":"p2", "name":"小林", "state":"ready"},
		{"id":"p3", "name":"阿舟", "state":"not_ready"},
		{"id":"p4", "name":"星河", "state":"loading", "progress":67},
		{"id":"p5", "name":"橙子", "state":"ready"},
		{"id":"p6", "name":"苏打", "state":"not_ready"},
		{"id":"p7", "name":"北北", "state":"ready"},
		{"id":"p8", "name":"小满", "state":"loading", "progress":84},
	]
	page.configure({"title":"云端跃迁", "subtitle":"跳过断层，抢先抵达终点。", "round":"第 01 回合  /  05", "controls":[
		{"actions":["party_demo_move_forward", "party_demo_move_left", "party_demo_move_back", "party_demo_move_right"], "binding_index":0, "separator":" ", "text":"移动"},
		{"action":"party_demo_jump", "text":"跳跃"},
		{"action":"party_demo_interact", "text":"交互"},
	]}, peers, "local")

func _process(delta: float) -> void:
	if not initialized or page == null or not page.is_visible_in_tree(): return
	var local: Dictionary = page.get_player("local")
	if local.is_empty() or local.state != "loading": return
	elapsed += delta
	if elapsed >= 2.5: page.set_local_loaded(true)
	else: page.set_player_state("local", "loading", 12.0 + 86.0 * elapsed / 2.5)

func complete_loading() -> void:
	for player in page.get_players():
		if player.state == "loading": page.set_player_state(player.id, "not_ready")

func ready_peers() -> void:
	for player in page.get_players():
		if player.id != page.get_local_player_id(): page.set_player_state(player.id, "ready")
