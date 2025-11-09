# MainMenu.gd - Main Menu Screen with Unlocks
extends Control

var play_button: Button
var unlocks_button: Button
var quit_button: Button
var title_label: Label
var volume_slider: HSlider
var mute_button: Button

var save_manager = null

func _ready():
	print("=== MainMenu _ready() called ===")

	# CRITICAL: Always unpause when entering main menu
	# (Game may be paused from death screen, pause menu, etc.)
	get_tree().paused = false
	print("✅ Game unpaused")
	
	# Run audio diagnostic
	var diagnostic = load("res://AudioDiagnostic.gd").new()
	diagnostic.name = "AudioDiagnostic"
	add_child(diagnostic)
	
	# Start music
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		audio_manager.play_music()
		print("🎵 Music started")

	# Get SaveManager reference
	if has_node("/root/SaveManager"):
		save_manager = get_node("/root/SaveManager")
		print("✅ SaveManager found")
	else:
		print("❌ SaveManager NOT found")
	
	# Get button references with full paths
	play_button = get_node_or_null("CenterContainer/VBoxContainer/PlayButton")
	unlocks_button = get_node_or_null("CenterContainer/VBoxContainer/UnlocksButton")
	quit_button = get_node_or_null("CenterContainer/VBoxContainer/QuitButton")
	title_label = get_node_or_null("TitleContainer/TitleLabel")
	
	# Setup audio controls
	setup_audio_controls()
	
	# Debug print to see what we found
	print("Play button: ", play_button)
	print("Unlocks button: ", unlocks_button)
	print("Quit button: ", quit_button)
	print("Title label: ", title_label)
	
	# Connect button signals - with error checking
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
		print("✅ Play button connected")
	else:
		print("❌ Play button not found!")
	
	if unlocks_button:
		unlocks_button.pressed.connect(_on_unlocks_pressed)
		print("✅ Unlocks button connected")
	else:
		print("❌ Unlocks button not found!")
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		print("✅ Quit button connected")
	else:
		print("❌ Quit button not found!")
	
	# Animate title
	if title_label:
		animate_title()
		print("✅ Title animation started")
	else:
		print("❌ Title label not found!")
	
	print("✅ Main Menu loaded!")

func setup_audio_controls():
	if not has_node("/root/AudioManager"):
		print("⚠️ AudioManager not found")
		return
	
	var audio_manager = get_node("/root/AudioManager")
	
	# Create audio controls container
	var audio_container = VBoxContainer.new()
	audio_container.name = "AudioControls"
	audio_container.add_theme_constant_override("separation", 10)
	
	# Volume label
	var volume_label = Label.new()
	volume_label.text = "🔊 Music Volume"
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_label.add_theme_font_size_override("font_size", 18)
	audio_container.add_child(volume_label)
	
	# Volume slider
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.custom_minimum_size = Vector2(300, 40)
	# Connect signal BEFORE setting value to avoid triggering it
	volume_slider.value_changed.connect(_on_volume_changed)
	# Set value without triggering signal by using set_value_no_signal
	volume_slider.set_value_no_signal(audio_manager.get_volume())
	audio_container.add_child(volume_slider)
	
	# Mute button
	mute_button = Button.new()
	update_mute_button_text()
	mute_button.custom_minimum_size = Vector2(300, 50)
	mute_button.add_theme_font_size_override("font_size", 18)
	mute_button.pressed.connect(_on_mute_pressed)
	audio_container.add_child(mute_button)
	
	# Position in bottom right corner (well away from center buttons)
	audio_container.position = Vector2(
		get_viewport_rect().size.x - 330,
		get_viewport_rect().size.y - 160
	)
	
	add_child(audio_container)
	print("✅ Audio controls added")

func update_mute_button_text():
	if not mute_button or not has_node("/root/AudioManager"):
		return
	
	var audio_manager = get_node("/root/AudioManager")
	if audio_manager.is_music_muted():
		mute_button.text = "🔇 Unmute Music"
	else:
		mute_button.text = "🔊 Mute Music"

func _on_volume_changed(value: float):
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		audio_manager.set_volume(value)
		print("🔊 Volume changed to: %.2f" % value)

func _on_mute_pressed():
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		audio_manager.toggle_mute()
		update_mute_button_text()
		print("🔇 Mute toggled")

func animate_title():
	# Pulse animation for title
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 1.5)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.5)

func _on_play_pressed():
	print("=== PLAY BUTTON PRESSED ===")
	print("▶️ Attempting to go to CharacterSelect...")
	
	# Check if the scene file exists
	if ResourceLoader.exists("res://CharacterSelect.tscn"):
		print("✅ CharacterSelect.tscn found!")
		var result = get_tree().change_scene_to_file("res://CharacterSelect.tscn")
		if result == OK:
			print("✅ Scene change successful")
		else:
			print("❌ Scene change failed with error: ", result)
	else:
		print("❌ CharacterSelect.tscn NOT FOUND!")
		print("Falling back to main_game.tscn...")
		get_tree().change_scene_to_file("res://main_game.tscn")

func _on_unlocks_pressed():
	print("=== UNLOCKS BUTTON PRESSED ===")
	print("🔓 Opening unlocks menu...")
	show_unlocks_panel()

func _on_quit_pressed():
	print("=== QUIT BUTTON PRESSED ===")
	print("🚪 Quitting game...")
	get_tree().quit()

func show_unlocks_panel():
	if not save_manager:
		print("❌ No save manager, showing placeholder")
		show_placeholder("Save system not available")
		return
	
	print("✅ Creating unlocks panel...")
	
	# Create unlocks panel
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(800, 600)
	panel.name = "UnlocksPanel"
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.3, 0.4, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	panel.add_theme_stylebox_override("panel", style)
	
	# Create container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "CHARACTER UNLOCKS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1, 1))
	vbox.add_child(title)
	
	# Shards display
	var shards_label = Label.new()
	shards_label.text = "💎 Nebula Shards: %d" % save_manager.get_shards()
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shards_label.add_theme_font_size_override("font_size", 24)
	shards_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	vbox.add_child(shards_label)
	
	# Separator
	var hsep = HSeparator.new()
	vbox.add_child(hsep)
	
	# Scroll container for characters
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	vbox.add_child(scroll)
	
	var chars_vbox = VBoxContainer.new()
	chars_vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(chars_vbox)
	
	# Add character entries
	add_character_entry(chars_vbox, "Ranger", "🎯", Color(0.4, 0.8, 1), true, 0, 0)
	
	# Swordmaiden
	var is_unlocked = save_manager.is_swordmaiden_unlocked()
	var challenge_complete = save_manager.is_swordmaiden_challenge_complete()
	var progress = save_manager.get_swordmaiden_challenge_progress()
	add_character_entry(chars_vbox, "Swordmaiden", "⚔️", Color(1, 0.4, 0.8), 
						is_unlocked, 30, progress)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "[ CLOSE ]"
	close_button.custom_minimum_size = Vector2(200, 60)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(func(): panel.queue_free())
	vbox.add_child(close_button)
	
	# Center the panel
	panel.position = get_viewport_rect().size / 2 - panel.custom_minimum_size / 2
	add_child(panel)
	
	print("✅ Unlocks panel created and added")

func add_character_entry(parent: VBoxContainer, name: String, icon: String, 
						 color: Color, is_unlocked: bool, required_level: int, 
						 progress: int):
	var char_panel = PanelContainer.new()
	char_panel.custom_minimum_size = Vector2(0, 100)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	char_panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	char_panel.add_child(hbox)
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 48)
	icon_label.custom_minimum_size = Vector2(60, 60)
	hbox.add_child(icon_label)
	
	# Info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label = Label.new()
	name_label.text = name
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", color)
	info_vbox.add_child(name_label)
	
	var status_label = Label.new()
	if is_unlocked:
		status_label.text = "✅ UNLOCKED"
		status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
	elif name == "Ranger":
		status_label.text = "✅ DEFAULT CHARACTER"
		status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
	else:
		if progress >= required_level:
			status_label.text = "🏆 Challenge Complete! Purchase for 500 Shards"
			status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
		else:
			status_label.text = "🔒 Reach Level %d (Progress: %d/%d)" % [required_level, progress, required_level]
			status_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5, 1))
	
	status_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(status_label)
	
	parent.add_child(char_panel)

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
