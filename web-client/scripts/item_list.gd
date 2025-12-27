extends ItemList


func _on_item_clicked():
	var f = FileAccess.open("res://../shared/rules.json", FileAccess.READ)
	if f:
		var text = f.get_as_text()
		print(text)
	else:
		push_error("Could not open rules.json")
