extends PanelContainer
func configure(data: Dictionary, index: int, active: bool) -> void:
	$Content/Number.text = "%02d" % (index + 1)
	$Content/Stripe.color = data.get("color", Color("478cbf"))
	$Content/Name.text = ("行动中 · " if active else "") + str(data.get("name", "玩家"))
	$Content/Name.tooltip_text = $Content/Name.text
	$Content/Assets.text = "$ %s  /  %d 处地产" % [str(data.get("cash", 0)), data.get("properties", 0)]
	$Content/Assets.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	$Content/Assets.tooltip_text = $Content/Assets.text
	modulate = Color.WHITE if active else Color(0.88, 0.93, 0.98)
