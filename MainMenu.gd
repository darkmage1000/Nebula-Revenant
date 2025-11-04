# MainMenu.gd - Main Menu Screen
extends Control

@onready var play_button = $CenterContainer/VBoxContainer/PlayButton
@onready var unlocks_button = $CenterContainer/VBoxContainer/UnlocksButton
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton
@onready var title_label = $TitleContainer/TitleLabel

func _ready():
	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	unlocks_button.pressed.connect(_on_unlocks_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Animate title
	animate_title()
	
	print("✅ Main Menu loaded!")

func animate_title():
	# Pulse animation for title
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 1.5)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.5)

func _on_play_pressed():
	print("▶️ Starting game...")
	# Transition to main game
	get_tree().change_scene_to_file("res://main_game.tscn")

func _on_unlocks_pressed():
	print("🔓 Opening unlocks menu...")
	# TODO: Open unlocks screen
	# For now, show a placeholder message
	show_placeholder("Unlocks system coming soon!")

func _on_quit_pressed():
	print("🚪 Quitting game...")
	get_tree().quit()

func show_placeholder(message: String):
	# Create a simple popup for placeholder
	var popup = Panel.new()
	popup.custom_minimum_size = Vector2(400, 200)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	popup.add_child(vbox)
	
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(label)
	
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(150, 50)
	close_button.pressed.connect(func(): popup.queue_free())
	vbox.add_child(close_button)
	
	# Center the popup
	popup.position = get_viewport_rect().size / 2 - popup.custom_minimum_size / 2
	add_child(popup)
