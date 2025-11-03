# upgrade_option.gd
extends Button

signal upgrade_selected(key: String)

var upgrade_key: String = ""

func set_data(key: String, title: String, description: String, icon = null):
	upgrade_key = key
	$HBoxContainer/VBoxContainer/title.text = title
	$HBoxContainer/VBoxContainer/description.text = description

func _pressed():
	upgrade_selected.emit(upgrade_key)
