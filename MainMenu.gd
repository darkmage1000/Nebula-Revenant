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

	# Get the main menu VBoxContainer
	var main_vbox = get_node_or_null("CenterContainer/VBoxContainer")
	if not main_vbox:
		print("⚠️ VBoxContainer not found for audio controls")
		return

	# Add separator before audio controls
	var separator = HSeparator.new()
	main_vbox.add_child(separator)

	# Volume label
	var volume_label = Label.new()
	volume_label.text = "🔊 Music Volume"
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_label.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(volume_label)

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
	main_vbox.add_child(volume_slider)

	# Mute button
	mute_button = Button.new()
	update_mute_button_text()
	mute_button.custom_minimum_size = Vector2(300, 50)
	mute_button.add_theme_font_size_override("font_size", 18)
	mute_button.pressed.connect(_on_mute_pressed)
	main_vbox.add_child(mute_button)

	print("✅ Audio controls added below buttons")

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

	# Get viewport size and calculate panel size (90% width, 85% height)
	var screen_size = get_viewport().get_visible_rect().size
	var panel_width = screen_size.x * 0.9
	var panel_height = screen_size.y * 0.85

	# Create unlocks panel - Full screen responsive
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size = Vector2(panel_width, panel_height)
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
	title.text = "UNLOCKS & UPGRADES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1, 1))
	vbox.add_child(title)

	# Shards display
	var shards_label = Label.new()
	shards_label.name = "ShardsLabel"
	shards_label.text = "💎 Nebula Shards: %d" % save_manager.get_shards()
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shards_label.add_theme_font_size_override("font_size", 24)
	shards_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	vbox.add_child(shards_label)

	# Separator
	var hsep = HSeparator.new()
	vbox.add_child(hsep)

	# Create TabContainer
	var tab_container = TabContainer.new()
	tab_container.custom_minimum_size = Vector2(0, 450)
	vbox.add_child(tab_container)

	# TAB 1: CHARACTERS
	var characters_tab = create_characters_tab()
	characters_tab.name = "CHARACTERS"
	tab_container.add_child(characters_tab)

	# TAB 2: UPGRADES
	var upgrades_tab = create_upgrades_tab(panel)
	upgrades_tab.name = "UPGRADES"
	tab_container.add_child(upgrades_tab)

	# Close button
	var close_button = Button.new()
	close_button.text = "[ CLOSE ]"
	close_button.custom_minimum_size = Vector2(200, 60)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(func(): panel.queue_free())
	vbox.add_child(close_button)

	# Center the panel on screen
	panel.position = (screen_size - panel.size) / 2
	add_child(panel)

	print("✅ Unlocks panel created and added")

func create_characters_tab() -> ScrollContainer:
	# Scroll container for characters - VERTICAL SCROLLING ONLY
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var chars_vbox = VBoxContainer.new()
	chars_vbox.add_theme_constant_override("separation", 15)
	chars_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Use full width
	scroll.add_child(chars_vbox)

	# Add character entries
	add_character_entry(chars_vbox, "Ranger", "🎯", Color(0.4, 0.8, 1), true, 0, 0)

	# Swordmaiden
	var is_swordmaiden_unlocked = save_manager.is_swordmaiden_unlocked()
	var swordmaiden_challenge_complete = save_manager.is_swordmaiden_challenge_complete()
	var swordmaiden_progress = save_manager.get_swordmaiden_challenge_progress()
	add_character_entry(chars_vbox, "Swordmaiden", "⚔️", Color(1, 0.4, 0.8),
						is_swordmaiden_unlocked, 30, swordmaiden_progress)

	# Alien Monk
	var is_alien_monk_unlocked = save_manager.is_alien_monk_unlocked()
	var alien_monk_challenge_complete = save_manager.is_alien_monk_challenge_complete()
	# For Alien Monk, we show the challenge requirement (30:00 on grassy field) not a level
	# We'll use the is_unlocked and challenge_complete flags to display the right status
	add_alien_monk_entry(chars_vbox)

	return scroll

func create_upgrades_tab(parent_panel: Panel) -> ScrollContainer:
	# Scroll container for upgrades - VERTICAL SCROLLING ONLY
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Use full width
	scroll.add_child(main_vbox)

	# COMBAT STATS SECTION
	var combat_label = Label.new()
	combat_label.text = "⚔️ COMBAT STATS"
	combat_label.add_theme_font_size_override("font_size", 24)
	combat_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3, 1))
	main_vbox.add_child(combat_label)

	# Combat stat upgrades
	add_upgrade_entry(main_vbox, parent_panel, "attack_speed_boost", "Attack Speed", "⚡", "+%d%% Attack Speed")
	add_upgrade_entry(main_vbox, parent_panel, "armor_boost", "Armor", "🛡️", "+%d Armor")
	add_upgrade_entry(main_vbox, parent_panel, "crit_chance_boost", "Crit Chance", "🎯", "+%d%% Crit Chance")
	add_upgrade_entry(main_vbox, parent_panel, "crit_damage_boost", "Crit Damage", "💥", "+%d%% Crit Damage")
	add_upgrade_entry(main_vbox, parent_panel, "aoe_boost", "AOE Size", "💫", "+%d%% AOE Size")

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# UTILITY SECTION
	var utility_label = Label.new()
	utility_label.text = "🔧 UTILITY"
	utility_label.add_theme_font_size_override("font_size", 24)
	utility_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1, 1))
	main_vbox.add_child(utility_label)

	# Weapon Slots upgrade - EXPENSIVE but powerful!
	add_weapon_slot_upgrade_entry(main_vbox, parent_panel)

	# Banish upgrade - Remove unwanted level-up options
	add_tier_upgrade_entry(main_vbox, parent_panel, "banish_tier", "Banish", "🚫", "+%d Use(s) per run")

	# Skip upgrade - Decline level-up for partial XP refund
	add_tier_upgrade_entry(main_vbox, parent_panel, "skip_tier", "Skip", "⏭️", "+%d Use(s) per run")

	# Separator
	var sep2 = HSeparator.new()
	main_vbox.add_child(sep2)

	# SURVIVAL SECTION
	var survival_label = Label.new()
	survival_label.text = "❤️ SURVIVAL"
	survival_label.add_theme_font_size_override("font_size", 24)
	survival_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	main_vbox.add_child(survival_label)

	# Revives upgrade
	add_revive_upgrade_entry(main_vbox, parent_panel)

	return scroll

func add_character_entry(parent: VBoxContainer, name: String, icon: String,
						 color: Color, is_unlocked: bool, required_level: int,
						 progress: int):
	var char_panel = PanelContainer.new()
	char_panel.custom_minimum_size = Vector2(0, 140)
	char_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Use full width

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

	# Sprite (if available) or icon fallback
	var sprite_texture = null
	match name:
		"Ranger":
			if ResourceLoader.exists("res://Player_Sprite.png"):
				sprite_texture = load("res://Player_Sprite.png")
		"Swordmaiden":
			if ResourceLoader.exists("res://female hero.png"):
				sprite_texture = load("res://female hero.png")

	if sprite_texture:
		var sprite_rect = TextureRect.new()
		sprite_rect.texture = sprite_texture
		sprite_rect.custom_minimum_size = Vector2(100, 100)
		sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(sprite_rect)
	else:
		# Fallback to icon
		var icon_label = Label.new()
		icon_label.text = icon
		icon_label.add_theme_font_size_override("font_size", 48)
		icon_label.custom_minimum_size = Vector2(100, 100)
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

func add_alien_monk_entry(parent: VBoxContainer):
	var is_unlocked = save_manager.is_alien_monk_unlocked()
	var challenge_complete = save_manager.is_alien_monk_challenge_complete()

	var char_panel = PanelContainer.new()
	char_panel.custom_minimum_size = Vector2(0, 140)
	char_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var color = Color(0.7, 0.4, 1.0)  # Purple for Alien Monk

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

	# Sprite (if available) or icon fallback
	var sprite_texture = null
	if ResourceLoader.exists("res://alien monk.png"):
		sprite_texture = load("res://alien monk.png")

	if sprite_texture:
		var sprite_rect = TextureRect.new()
		sprite_rect.texture = sprite_texture
		sprite_rect.custom_minimum_size = Vector2(100, 100)
		sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(sprite_rect)
	else:
		# Fallback to icon
		var icon_label = Label.new()
		icon_label.text = "⚡"  # Lightning bolt emoji for Alien Monk
		icon_label.add_theme_font_size_override("font_size", 48)
		icon_label.custom_minimum_size = Vector2(100, 100)
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(icon_label)

	# Info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = "Alien Monk"
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", color)
	info_vbox.add_child(name_label)

	var status_label = Label.new()
	if is_unlocked:
		status_label.text = "✅ UNLOCKED"
		status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
	elif challenge_complete:
		status_label.text = "🏆 Challenge Complete! Purchase for 750 Shards"
		status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	else:
		status_label.text = "🔒 Survive 30:00 on Grassy Field Map"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5, 1))

	status_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(status_label)

	parent.add_child(char_panel)

func add_upgrade_entry(parent: VBoxContainer, parent_panel: Panel, upgrade_key: String, display_name: String, icon: String, format_string: String):
	var current_level = save_manager.get_upgrade_level(upgrade_key)
	var max_level = save_manager.get_max_level(upgrade_key)
	var cost = save_manager.get_upgrade_cost(upgrade_key, current_level)

	var upgrade_panel = PanelContainer.new()
	upgrade_panel.custom_minimum_size = Vector2(0, 80)
	upgrade_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Use full width
	upgrade_panel.name = upgrade_key  # For refreshing later

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.6, 1, 0.6)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	upgrade_panel.add_theme_stylebox_override("panel", panel_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	upgrade_panel.add_child(hbox)

	# Icon
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.custom_minimum_size = Vector2(50, 50)
	hbox.add_child(icon_label)

	# Info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	info_vbox.add_child(name_label)

	var progress_label = Label.new()
	if current_level >= max_level:
		progress_label.text = "MAX LEVEL"
		progress_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	else:
		# Calculate current and next bonus values
		var current_bonus = get_upgrade_bonus_value(upgrade_key, current_level)
		var next_bonus = get_upgrade_bonus_value(upgrade_key, current_level + 1)

		var current_text = ""
		var next_text = ""

		if current_level > 0:
			current_text = format_string % current_bonus
		else:
			current_text = "Not purchased"

		next_text = format_string % next_bonus

		progress_label.text = "Level %d/%d | Current: %s | Next: %s" % [current_level, max_level, current_text, next_text]
		progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))

	progress_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(progress_label)

	# Purchase button
	var button = Button.new()
	button.custom_minimum_size = Vector2(150, 60)

	if current_level >= max_level:
		button.text = "MAX"
		button.disabled = true
	else:
		button.text = "Buy (%d 💎)" % cost
		if save_manager.get_shards() < cost:
			button.disabled = true

		button.pressed.connect(func(): purchase_upgrade(upgrade_key, cost, parent_panel))

	button.add_theme_font_size_override("font_size", 16)
	hbox.add_child(button)

	parent.add_child(upgrade_panel)

func add_revive_upgrade_entry(parent: VBoxContainer, parent_panel: Panel):
	var upgrade_key = "revives"
	var current_level = save_manager.get_upgrade_level(upgrade_key)
	var max_level = save_manager.get_max_level(upgrade_key)
	var cost = save_manager.get_upgrade_cost(upgrade_key, current_level)

	var upgrade_panel = PanelContainer.new()
	upgrade_panel.custom_minimum_size = Vector2(0, 80)
	upgrade_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Use full width
	upgrade_panel.name = upgrade_key

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.15, 0.15, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1, 0.4, 0.4, 0.6)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	upgrade_panel.add_theme_stylebox_override("panel", panel_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	upgrade_panel.add_child(hbox)

	# Icon
	var icon_label = Label.new()
	icon_label.text = "💚"
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.custom_minimum_size = Vector2(50, 50)
	hbox.add_child(icon_label)

	# Info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = "Revives"
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	info_vbox.add_child(name_label)

	var progress_label = Label.new()
	if current_level >= max_level:
		progress_label.text = "MAX LEVEL (2 Revives per run)"
		progress_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	else:
		var current_text = "%d Revive(s)" % current_level if current_level > 0 else "No revives"
		var next_text = "%d Revive(s)" % (current_level + 1)
		progress_label.text = "Level %d/%d | Current: %s | Next: %s" % [current_level, max_level, current_text, next_text]
		progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))

	progress_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(progress_label)

	# Purchase button
	var button = Button.new()
	button.custom_minimum_size = Vector2(150, 60)

	if current_level >= max_level:
		button.text = "MAX"
		button.disabled = true
	else:
		button.text = "Buy (%d 💎)" % cost
		if save_manager.get_shards() < cost:
			button.disabled = true

		button.pressed.connect(func(): purchase_upgrade(upgrade_key, cost, parent_panel))

	button.add_theme_font_size_override("font_size", 16)
	hbox.add_child(button)

	parent.add_child(upgrade_panel)

func add_weapon_slot_upgrade_entry(parent: VBoxContainer, parent_panel: Panel):
	var upgrade_key = "starting_weapon_slot"
	var current_level = save_manager.get_upgrade_level(upgrade_key)
	var max_level = save_manager.get_max_level(upgrade_key)
	var cost = save_manager.get_upgrade_cost(upgrade_key, current_level)

	var upgrade_panel = PanelContainer.new()
	upgrade_panel.custom_minimum_size = Vector2(0, 80)
	upgrade_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Use full width
	upgrade_panel.name = upgrade_key

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.2, 0.2, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.5, 0.8, 1, 0.6)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	upgrade_panel.add_theme_stylebox_override("panel", panel_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	upgrade_panel.add_child(hbox)

	# Icon
	var icon_label = Label.new()
	icon_label.text = "🎒"
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.custom_minimum_size = Vector2(50, 50)
	hbox.add_child(icon_label)

	# Info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = "Weapon Slots"
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	info_vbox.add_child(name_label)

	var progress_label = Label.new()
	if current_level >= max_level:
		progress_label.text = "MAX LEVEL (6 Weapon Slots)"
		progress_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	else:
		# Calculate current and next slot count
		var current_slots = 3 + current_level  # Base 3 + upgrades
		var next_slots = current_slots + 1

		var current_text = "%d Slot(s)" % current_slots
		var next_text = "%d Slot(s)" % next_slots

		progress_label.text = "Level %d/%d | Current: %s | Next: %s" % [current_level, max_level, current_text, next_text]
		progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))

	progress_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(progress_label)

	# Purchase button
	var button = Button.new()
	button.custom_minimum_size = Vector2(150, 60)

	if current_level >= max_level:
		button.text = "MAX"
		button.disabled = true
	else:
		button.text = "Buy (%d 💎)" % cost
		if save_manager.get_shards() < cost:
			button.disabled = true

		button.pressed.connect(func(): purchase_upgrade(upgrade_key, cost, parent_panel))

	button.add_theme_font_size_override("font_size", 16)
	hbox.add_child(button)

	parent.add_child(upgrade_panel)

func add_tier_upgrade_entry(parent: VBoxContainer, parent_panel: Panel, upgrade_key: String, display_name: String, icon: String, format_string: String):
	var current_level = save_manager.get_upgrade_level(upgrade_key)
	var max_level = save_manager.get_max_level(upgrade_key)
	var cost = save_manager.get_upgrade_cost(upgrade_key, current_level)

	var upgrade_panel = PanelContainer.new()
	upgrade_panel.custom_minimum_size = Vector2(0, 80)
	upgrade_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_panel.name = upgrade_key

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.6, 0.4, 1, 0.6)  # Purple border for tier upgrades
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	upgrade_panel.add_theme_stylebox_override("panel", panel_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	upgrade_panel.add_child(hbox)

	# Icon
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.custom_minimum_size = Vector2(50, 50)
	hbox.add_child(icon_label)

	# Info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	info_vbox.add_child(name_label)

	var progress_label = Label.new()
	if current_level >= max_level:
		progress_label.text = "MAX LEVEL"
		progress_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	else:
		# For tier upgrades, the bonus is simply the tier level (number of uses)
		var current_text = ""
		var next_text = format_string % (current_level + 1)

		if current_level > 0:
			current_text = format_string % current_level
		else:
			current_text = "Not purchased (0 uses)"

		progress_label.text = "Tier %d/%d | Current: %s | Next: %s" % [current_level, max_level, current_text, next_text]
		progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))

	progress_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(progress_label)

	# Purchase button
	var button = Button.new()
	button.custom_minimum_size = Vector2(150, 60)

	if current_level >= max_level:
		button.text = "MAX"
		button.disabled = true
	else:
		button.text = "Buy (%d 💎)" % cost
		if save_manager.get_shards() < cost:
			button.disabled = true

		button.pressed.connect(func(): purchase_upgrade(upgrade_key, cost, parent_panel))

	button.add_theme_font_size_override("font_size", 16)
	hbox.add_child(button)

	parent.add_child(upgrade_panel)

func get_upgrade_bonus_value(upgrade_key: String, level: int) -> int:
	match upgrade_key:
		"attack_speed_boost":
			return level * 8
		"armor_boost":
			return level * 2
		"crit_chance_boost":
			return level * 2
		"crit_damage_boost":
			return level * 10
		"aoe_boost":
			return level * 8
	return 0

func purchase_upgrade(upgrade_key: String, cost: int, parent_panel: Panel):
	if not save_manager:
		return

	# Attempt purchase
	if save_manager.purchase_upgrade(upgrade_key, cost):
		print("✅ Purchased upgrade: %s" % upgrade_key)

		# Refresh the UI
		refresh_upgrades_panel(parent_panel)

		# Visual/audio feedback
		flash_button_success(parent_panel)
	else:
		print("❌ Failed to purchase upgrade: %s" % upgrade_key)

func refresh_upgrades_panel(parent_panel: Panel):
	if not parent_panel:
		return

	# Find the shards label and update it
	var shards_label = parent_panel.find_child("ShardsLabel", true, false)
	if shards_label:
		shards_label.text = "💎 Nebula Shards: %d" % save_manager.get_shards()

	# Find tab container
	var tab_container = parent_panel.find_child("TabContainer", true, false)
	if not tab_container:
		return

	# Find UPGRADES tab (should be index 1)
	if tab_container.get_child_count() > 1:
		var upgrades_tab = tab_container.get_child(1)
		if upgrades_tab:
			# Remove and recreate upgrades tab
			upgrades_tab.queue_free()
			var new_upgrades_tab = create_upgrades_tab(parent_panel)
			new_upgrades_tab.name = "UPGRADES"
			tab_container.add_child(new_upgrades_tab)
			tab_container.move_child(new_upgrades_tab, 1)  # Move to correct position
			tab_container.current_tab = 1  # Switch to upgrades tab

func flash_button_success(parent_panel: Panel):
	# Simple visual feedback - flash the panel border
	if not parent_panel:
		return

	var original_style = parent_panel.get_theme_stylebox("panel")
	if original_style:
		var flash_style = original_style.duplicate()
		flash_style.border_color = Color(0.3, 1, 0.3, 1)  # Green flash
		parent_panel.add_theme_stylebox_override("panel", flash_style)

		# Reset after delay
		await get_tree().create_timer(0.2).timeout
		parent_panel.add_theme_stylebox_override("panel", original_style)

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
