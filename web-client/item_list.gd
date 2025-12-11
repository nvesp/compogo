extends ItemList


func _on_item_clicked(index, at_position, mouse_button_index):
	var f = FileAccess.open("res://../shared/rules.json", FileAccess.READ)
	if f:
		var text = f.get_as_text()
		print(text)
	else:
		push_error("Could not open rules.json")
