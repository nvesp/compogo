extends Node2D

func _ready() -> void:
	RulesLoader.load_rules()
	var max_speed = RulesLoader.get_nested(["movement", "max_speed"], 0.0)
	print("Max speed: %s" % str(max_speed))
