# character_select.gd - UPDATED: No autoload needed!
extends Control

signal character_selected(character_type: String)

@onready var ranger_panel = $MarginContainer/VBoxContainer/CharactersContainer/RangerPanel
@onready var swordmaiden_panel = $MarginContainer/VBoxContainer/CharactersContainer/SwordmaidenPanel
@onready var back_button = $MarginContainer/VBoxContainer/BackButton
@onready var info_label = $MarginContainer/VBoxContainer/InfoLabel

var save_manager = null

func _ready():
	# Get save manager
	if has_node("/root/SaveManager"):
		save_manager = get_node("/root/SaveManager")
	
	# Setup buttons
	setup_ranger_panel()
	setup_swordmaiden_panel()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Update info
	update_info_label()

func setup_ranger_panel():
	if not ranger_panel:
		return
	
	var select_button = ranger_panel.get_node_or_null("VBoxContainer/SelectButton")
	if select_button:
		select_button.pressed.connect(_on_ranger_selected)

func setup_swordmaiden_panel():
	if not swordmaiden_panel:
		return
	
	var select_button = swordmaiden_panel.get_node_or_null("VBoxContainer/SelectButton")
	var unlock_button = swordmaiden_panel.get_node_or_null("VBoxContainer/UnlockButton")
	var locked_label = swordmaiden_panel.get_node_or_null("VBoxContainer/LockedLabel")
	
	if not save_manager:
		return
	
	# Check unlock status
	var is_unlocked = save_manager.is_swordmaiden_unlocked()
	var challenge_complete = save_manager.is_swordmaiden_challenge_complete()
	var progress = save_manager.get_swordmaiden_challenge_progress()
	
	if is_unlocked:
		# Character is unlocked - show select button
		if select_button:
			select_button.visible = true
			select_button.disabled = false
			select_button.pressed.connect(_on_swordmaiden_selected)
		if unlock_button:
			unlock_button.visible = false
		if locked_label:
			locked_label.visible = false
	elif challenge_complete:
		# Challenge complete - can purchase
		if select_button:
			select_button.visible = false
		if unlock_button:
			unlock_button.visible = true
			unlock_button.disabled = false
			unlock_button.text = "Unlock (5000 Shards)"
			unlock_button.pressed.connect(_on_unlock_pressed)
		if locked_label:
			locked_label.visible = false
	else:
		# Still locked - show progress
		if select_button:
			select_button.visible = false
		if unlock_button:
			unlock_button.visible = false
		if locked_label:
			locked_label.visible = true
			locked_label.text = "🔒 Locked\nChallenge: Reach Level 30\nProgress: %d/30" % progress

func _on_ranger_selected():
	print("Selected: Ranger")
	start_game_with_character("ranger")

func _on_swordmaiden_selected():
	print("Selected: Swordmaiden")
	start_game_with_character("swordmaiden")

func start_game_with_character(character_type: String):
	# Load main game scene
	var main_game_scene = load("res://main_game.tscn")
	var main_game = main_game_scene.instantiate()
	
	# Set the selected character BEFORE adding to tree
	if "selected_character" in main_game:
		main_game.selected_character = character_type
		print("✅ Set character to: %s" % character_type)
	else:
		print("⚠️ Warning: main_game doesn't have selected_character property")
	
	# Switch to game scene
	get_tree().root.add_child(main_game)
	queue_free()

func _on_unlock_pressed():
	if not save_manager:
		return
	
	var current_shards = save_manager.get_shards()
	
	if current_shards < 5000:
		update_info_label("❌ Not enough shards! Need 5000, have %d" % current_shards)
		return
	
	if save_manager.try_unlock_swordmaiden():
		update_info_label("🗡️ SWORDMAIDEN UNLOCKED!")
		# Refresh UI
		setup_swordmaiden_panel()
	else:
		update_info_label("❌ Failed to unlock Swordmaiden")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func update_info_label(custom_text: String = ""):
	if not info_label:
		return
	
	if custom_text != "":
		info_label.text = custom_text
		return
	
	if not save_manager:
		info_label.text = "Select your character"
		return
	
	var shards = save_manager.get_shards()
	info_label.text = "Nebula Shards: %d" % shards
