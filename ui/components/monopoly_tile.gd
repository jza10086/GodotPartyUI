@tool
extends Button
@export var tile_id := 0
@export var property_name := "蓝湾大道":
	set(value):
		property_name = value
		refresh()
@export var price_text := "$ 1,200":
	set(value):
		price_text = value
		refresh()
@export var district_color := Color("478cbf"):
	set(value):
		district_color = value
		refresh()
func _ready() -> void: refresh()
func refresh() -> void:
	if not is_node_ready(): return
	$Title.text = property_name
	$Price.text = price_text
	$Stripe.color = district_color
	tooltip_text = property_name + " · " + price_text + " · 查看地块"
func set_occupants(ids: Array) -> void:
	var names := PackedStringArray()
	for id in ids: names.append("P%d" % (int(id) + 1))
	$Tokens.text = " · ".join(names) if names.size() <= 3 else "%s · %s · +%d" % [names[0], names[1], names.size() - 2]
	$Tokens.tooltip_text = "停留玩家：" + "、".join(names)
	tooltip_text = property_name + " · " + price_text + " · 查看地块"
	if not names.is_empty(): tooltip_text += "\n" + $Tokens.tooltip_text
