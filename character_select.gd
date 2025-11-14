# character_select.gd - UPDATED: Map selection support!
extends Control

signal character_selected(character_type: String)

@onready var ranger_panel = $MarginContainer/VBoxContainer/CharactersContainer/RangerPanel
@onready var swordmaiden_panel = $MarginContainer/VBoxContainer/CharactersContainer/SwordmaidenPanel
@onready var alien_monk_panel = $MarginContainer/VBoxContainer/CharactersContainer/AlienMonkPanel
@onready var back_button = $MarginContainer/VBoxContainer/BackButton
@onready var info_label = $MarginContainer/VBoxContainer/InfoLabel

# Map selection nodes (will create dynamically if not in scene)
var map_selector_container = null
var space_map_button = null
var grassy_map_button = null

# Curse selection nodes
var curse_selector_container = null
var curse_buttons: Dictionary = {}  # curse_key -> CheckBox
var selected_curses: Array[String] = []  # Array of active curse keys

# Game mode selection nodes
var game_mode_selector_container = null
var game_mode_buttons: Dictionary = {}  # mode_key -> Button
var selected_game_mode: String = "30min"  # Default to 30-minute Epic mode

var save_manager = null
var selected_map: String = "space"  # Default to space map

func _ready():
	# Get save manager
	if has_node("/root/SaveManager"):
		save_manager = get_node("/root/SaveManager")

	# Add ESC hint label in top right corner
	add_esc_hint()

	# Setup map selector UI
	setup_map_selector()

	# Setup curse selector UI
	setup_curse_selector()

	# Setup game mode selector UI
	setup_game_mode_selector()

	# Setup buttons
	setup_ranger_panel()
	setup_swordmaiden_panel()
	setup_alien_monk_panel()

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Update info
	update_info_label()

func add_esc_hint():
	# Create ESC hint label in top right corner
	var esc_label = Label.new()
	esc_label.text = "ESC to go back"
	esc_label.add_theme_font_size_override("font_size", 16)
	esc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))

	# Position in top right corner
	esc_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	esc_label.position = Vector2(-150, 10)

	add_child(esc_label)

func _input(event):
	# Handle ESC key to go back to main menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func setup_map_selector():
	# Create map selector UI dynamically
	var vbox = get_node_or_null("MarginContainer/VBoxContainer")
	if not vbox:	
		print("⚠️ Warning: Could not find VBoxContainer for map selector")
		return

	# Create container for map selection
	map_selector_container = VBoxContainer.new()
	map_selector_container.add_theme_constant_override("separation", 10)

	# Map selector title
	var map_title = Label.new()
	map_title.text = "SELECT MAP"
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.add_theme_font_size_override("font_size", 24)
	map_selector_container.add_child(map_title)

	# Map buttons container
	var map_buttons = HBoxContainer.new()
	map_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	map_buttons.add_theme_constant_override("separation", 20)

	# Space map button (always available)
	space_map_button = Button.new()
	space_map_button.text = "Space"
	space_map_button.custom_minimum_size = Vector2(150, 50)
	space_map_button.pressed.connect(_on_space_map_selected)
	map_buttons.add_child(space_map_button)

	# Grassy field button (locked unless unlocked)
	grassy_map_button = Button.new()
	grassy_map_button.custom_minimum_size = Vector2(150, 50)

	if save_manager and save_manager.is_grassy_field_unlocked():
		grassy_map_button.text = "Grassy Field"
		grassy_map_button.disabled = false
		grassy_map_button.pressed.connect(_on_grassy_map_selected)
	else:
		grassy_map_button.text = "🔒 Grassy Field"
		grassy_map_button.disabled = true

	map_buttons.add_child(grassy_map_button)

	map_selector_container.add_child(map_buttons)

	# Add map selector to UI (above character selection)
	# Insert as second child (after first spacer or title)
	vbox.add_child(map_selector_container)
	vbox.move_child(map_selector_container, 1)

	# Update initial selection visuals
	update_map_button_visuals()

	print("✅ Map selector UI created")

func _on_space_map_selected():
	selected_map = "space"
	update_map_button_visuals()
	print("🌌 Selected map: Space")

func _on_grassy_map_selected():
	selected_map = "grassy_field"
	update_map_button_visuals()
	print("🌱 Selected map: Grassy Field")

func update_map_button_visuals():
	# Highlight selected button
	if space_map_button:
		if selected_map == "space":
			space_map_button.modulate = Color(0.5, 1.0, 1.0)
		else:
			space_map_button.modulate = Color(1.0, 1.0, 1.0)

	if grassy_map_button:
		if selected_map == "grassy_field":
			grassy_map_button.modulate = Color(0.5, 1.0, 0.5)
		else:
			grassy_map_button.modulate = Color(1.0, 1.0, 1.0)

func setup_curse_selector():
	# Create curse selector UI dynamically
	var vbox = get_node_or_null("MarginContainer/VBoxContainer")
	if not vbox:
		print("⚠️ Warning: Could not find VBoxContainer for curse selector")
		return

	# Create container for curse selection
	curse_selector_container = VBoxContainer.new()
	curse_selector_container.add_theme_constant_override("separation", 10)

	# Curse selector title
	var curse_title = Label.new()
	curse_title.text = "CURSES (Risk & Reward)"
	curse_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	curse_title.add_theme_font_size_override("font_size", 20)
	curse_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	curse_selector_container.add_child(curse_title)

	# Curse definitions (must match main_game.gd)
	const CURSE_DATA = {
		"frailty": {"name": "Curse of Frailty", "desc": "-50% Max HP", "bonus": "+100% Shards", "color": Color(0.8, 0.2, 0.2)},
		"haste": {"name": "Curse of Haste", "desc": "+100% Enemy Speed", "bonus": "+50% XP", "color": Color(1.0, 0.8, 0.0)},
		"swarm": {"name": "Curse of the Swarm", "desc": "+50% Spawn Rate", "bonus": "+75% Shards", "color": Color(0.5, 0.0, 0.8)},
		"fragility": {"name": "Curse of Fragility", "desc": "-50% Armor", "bonus": "+50% Drops", "color": Color(0.6, 0.6, 0.6)},
		"weakness": {"name": "Curse of Weakness", "desc": "-25% Damage", "bonus": "+100% XP", "color": Color(0.2, 0.5, 0.8)}
	}

	# Create checkboxes for each curse
	var curse_grid = GridContainer.new()
	curse_grid.columns = 1
	curse_grid.add_theme_constant_override("v_separation", 5)

	for curse_key in CURSE_DATA.keys():
		var curse = CURSE_DATA[curse_key]

		# Create checkbox with label
		var curse_box = HBoxContainer.new()
		curse_box.add_theme_constant_override("separation", 10)

		var checkbox = CheckBox.new()
		checkbox.text = curse.name
		checkbox.tooltip_text = curse.desc + " → " + curse.bonus
		checkbox.add_theme_color_override("font_color", curse.color)
		checkbox.toggled.connect(_on_curse_toggled.bind(curse_key))
		curse_box.add_child(checkbox)

		# Store reference
		curse_buttons[curse_key] = checkbox

		# Add description labels
		var desc_label = Label.new()
		desc_label.text = "(" + curse.desc + " → " + curse.bonus + ")"
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		curse_box.add_child(desc_label)

		curse_grid.add_child(curse_box)

	curse_selector_container.add_child(curse_grid)

	# Add curse selector to UI (after map selector)
	vbox.add_child(curse_selector_container)
	vbox.move_child(curse_selector_container, 2)

	print("✅ Curse selector UI created")

func setup_game_mode_selector():
	# Create game mode selector UI on the RIGHT side of screen (not in center VBoxContainer)
	# Create container for game mode selection
	game_mode_selector_container = VBoxContainer.new()
	game_mode_selector_container.add_theme_constant_override("separation", 8)

	# Position on right side of screen
	game_mode_selector_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	game_mode_selector_container.position = Vector2(-200, 100)  # 200px from right, 100px from top
	game_mode_selector_container.size = Vector2(180, 200)

	# Game mode selector title
	var mode_title = Label.new()
	mode_title.text = "RUN DURATION"
	mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_title.add_theme_font_size_override("font_size", 18)
	mode_title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))  # Cyan
	game_mode_selector_container.add_child(mode_title)

	# Game mode definitions
	const MODE_DATA = {
		"10min": {"name": "10 min", "desc": "Fast-paced, intense difficulty"},
		"20min": {"name": "20 min", "desc": "Balanced challenge"},
		"30min": {"name": "30 min", "desc": "Full experience (default)"}
	}

	# Create buttons for each game mode (SMALLER)
	var mode_buttons_container = VBoxContainer.new()
	mode_buttons_container.add_theme_constant_override("separation", 6)

	for mode_key in ["10min", "20min", "30min"]:
		var mode = MODE_DATA[mode_key]

		# Create button with label (SMALLER SIZE)
		var mode_button = Button.new()
		mode_button.text = mode.name
		mode_button.tooltip_text = mode.desc
		mode_button.custom_minimum_size = Vector2(160, 35)  # Smaller: 160x35 (was 250x40)
		mode_button.add_theme_font_size_override("font_size", 14)  # Smaller font
		mode_button.pressed.connect(_on_game_mode_selected.bind(mode_key))
		mode_buttons_container.add_child(mode_button)

		# Store reference
		game_mode_buttons[mode_key] = mode_button

	game_mode_selector_container.add_child(mode_buttons_container)

	# Add to root (NOT to VBoxContainer) - this prevents blocking character panels
	add_child(game_mode_selector_container)

	# Update initial selection visuals
	update_game_mode_button_visuals()

	print("✅ Game mode selector UI created on RIGHT side")

func _on_game_mode_selected(mode_key: String):
	selected_game_mode = mode_key
	update_game_mode_button_visuals()
	print("⏱️ Selected game mode: %s" % mode_key)

func update_game_mode_button_visuals():
	# Highlight selected button
	var mode_colors = {
		"10min": Color(1.0, 0.5, 0.5),  # Light red
		"20min": Color(1.0, 0.9, 0.5),  # Light yellow
		"30min": Color(0.5, 1.0, 0.7)   # Light green
	}

	for mode_key in game_mode_buttons.keys():
		var button = game_mode_buttons[mode_key]
		if button:
			if mode_key == selected_game_mode:
				button.modulate = mode_colors[mode_key]
			else:
				button.modulate = Color(1.0, 1.0, 1.0)

func _on_curse_toggled(is_active: bool, curse_key: String):
	if is_active:
		if not selected_curses.has(curse_key):
			selected_curses.append(curse_key)
			print("✅ Activated curse: %s" % curse_key)
	else:
		if selected_curses.has(curse_key):
			selected_curses.erase(curse_key)
			print("❌ Deactivated curse: %s" % curse_key)

	# Update info label to show active curses
	update_curse_info()

func update_curse_info():
	# Show bonus multipliers in info label
	if selected_curses.is_empty():
		return

	var info_text = "Active Curses: " + str(selected_curses.size())
	# Could add more detailed info here if desired
	print("🔥 Active curses: %s" % str(selected_curses))

func setup_ranger_panel():
	if not ranger_panel:
		return

	# Load and display Ranger sprite
	var sprite_container = ranger_panel.get_node_or_null("VBoxContainer/SpriteContainer/CharacterSprite")
	if sprite_container:
		if ResourceLoader.exists("res://Player_Sprite.png"):
			sprite_container.texture = load("res://Player_Sprite.png")
			print("✅ Ranger sprite loaded")
		else:
			print("⚠️ Warning: Player_Sprite.png not found")

	# Ranger is ALWAYS available (default character)
	var select_button = ranger_panel.get_node_or_null("VBoxContainer/SelectButton")
	if select_button:
		select_button.visible = true  # CRITICAL: Explicitly show button
		select_button.disabled = false
		select_button.pressed.connect(_on_ranger_selected)
		print("✅ Ranger SELECT button made visible and enabled")

func setup_swordmaiden_panel():
	if not swordmaiden_panel:
		print("❌ ERROR: swordmaiden_panel is null!")
		return

	print("🔍 Setting up Swordmaiden panel...")

	# Load and display Swordmaiden sprite
	var sprite_container = swordmaiden_panel.get_node_or_null("VBoxContainer/SpriteContainer/CharacterSprite")
	if sprite_container:
		if ResourceLoader.exists("res://female hero.png"):
			sprite_container.texture = load("res://female hero.png")
			print("✅ Swordmaiden sprite loaded")
		else:
			print("⚠️ Warning: female hero.png not found")

	var select_button = swordmaiden_panel.get_node_or_null("VBoxContainer/SelectButton")
	var unlock_button = swordmaiden_panel.get_node_or_null("VBoxContainer/UnlockButton")
	var locked_label = swordmaiden_panel.get_node_or_null("VBoxContainer/LockedLabel")
	var name_label = swordmaiden_panel.get_node_or_null("VBoxContainer/NameLabel")

	print("🔍 Swordmaiden node check:")
	print("  - select_button: %s" % str(select_button))
	print("  - unlock_button: %s" % str(unlock_button))
	print("  - locked_label: %s" % str(locked_label))
	print("  - name_label: %s" % str(name_label))

	if not select_button or not unlock_button or not locked_label:
		print("❌ ERROR: Missing required nodes in Swordmaiden panel!")
		return

	if not save_manager:
		print("⚠️ WARNING: SaveManager not found! Defaulting to unlocked state.")
		# Default to showing SELECT button if SaveManager not available
		if name_label:
			name_label.text = "⚔️ SWORDMAIDEN"
			name_label.visible = true
		select_button.visible = true
		select_button.disabled = false
		select_button.pressed.connect(_on_swordmaiden_selected)
		unlock_button.visible = false
		locked_label.visible = false
		print("✅ Swordmaiden defaulted to unlocked (no SaveManager)")
		return

	# Check unlock status
	var is_unlocked = save_manager.is_swordmaiden_unlocked()
	var challenge_complete = save_manager.is_swordmaiden_challenge_complete()
	var progress = save_manager.get_swordmaiden_challenge_progress()

	print("  - is_unlocked: %s" % str(is_unlocked))
	print("  - challenge_complete: %s" % str(challenge_complete))
	print("  - progress: %d/30" % progress)

	# CRITICAL: First hide ALL buttons, then show the correct one
	select_button.visible = false
	unlock_button.visible = false
	locked_label.visible = false

	if is_unlocked:
		# Character is unlocked - show SELECT button
		print("  → Showing SELECT button for unlocked character")
		if name_label:
			name_label.text = "⚔️ SWORDMAIDEN"
			name_label.visible = true
		select_button.visible = true
		select_button.disabled = false
		if not select_button.pressed.is_connected(_on_swordmaiden_selected):
			select_button.pressed.connect(_on_swordmaiden_selected)
		print("✅ Swordmaiden SELECT button now visible=%s, disabled=%s" % [select_button.visible, select_button.disabled])
	elif challenge_complete:
		# Challenge complete - can purchase, show UNLOCK button
		print("  → Showing UNLOCK button (challenge complete)")
		if name_label:
			name_label.text = "⚔️ SWORDMAIDEN"
			name_label.visible = true
		unlock_button.visible = true
		unlock_button.disabled = false
		unlock_button.text = "Unlock (500 Shards)"
		if not unlock_button.pressed.is_connected(_on_unlock_pressed):
			unlock_button.pressed.connect(_on_unlock_pressed)
		print("✅ Swordmaiden UNLOCK button now visible=%s" % unlock_button.visible)
	else:
		# Still locked - show challenge + price
		print("  → Showing locked label (challenge incomplete)")
		if name_label:
			name_label.visible = false
		locked_label.visible = true
		locked_label.text = "🔒 LOCKED\n\nChallenge: Reach Level 30\nProgress: %d/30\n\nPrice: 500 Shards" % progress
		print("✅ Swordmaiden locked_label now visible=%s" % locked_label.visible)

func setup_alien_monk_panel():
	if not alien_monk_panel:
		print("❌ ERROR: alien_monk_panel is null!")
		return

	print("🔍 Setting up Alien Monk panel...")

	# Load and display Alien Monk sprite
	var sprite_container = alien_monk_panel.get_node_or_null("VBoxContainer/SpriteContainer/CharacterSprite")
	if sprite_container:
		if ResourceLoader.exists("res://alien monk.png"):
			sprite_container.texture = load("res://alien monk.png")
			print("✅ Alien Monk sprite loaded")
		else:
			print("⚠️ Warning: alien monk.png not found")

	var select_button = alien_monk_panel.get_node_or_null("VBoxContainer/SelectButton")
	var unlock_button = alien_monk_panel.get_node_or_null("VBoxContainer/UnlockButton")
	var locked_label = alien_monk_panel.get_node_or_null("VBoxContainer/LockedLabel")
	var name_label = alien_monk_panel.get_node_or_null("VBoxContainer/NameLabel")

	print("🔍 Alien Monk node check:")
	print("  - select_button: %s" % str(select_button))
	print("  - unlock_button: %s" % str(unlock_button))
	print("  - locked_label: %s" % str(locked_label))
	print("  - name_label: %s" % str(name_label))

	if not select_button or not unlock_button or not locked_label:
		print("❌ ERROR: Missing required nodes in Alien Monk panel!")
		return

	if not save_manager:
		print("⚠️ WARNING: SaveManager not found! Defaulting to unlocked state.")
		# Default to showing SELECT button if SaveManager not available
		if name_label:
			name_label.text = "⚡ ALIEN MONK"
			name_label.visible = true
		select_button.visible = true
		select_button.disabled = false
		select_button.pressed.connect(_on_alien_monk_selected)
		unlock_button.visible = false
		locked_label.visible = false
		print("✅ Alien Monk defaulted to unlocked (no SaveManager)")
		return

	# Check unlock status
	var is_unlocked = save_manager.is_alien_monk_unlocked()
	var challenge_complete = save_manager.is_alien_monk_challenge_complete()

	print("  - is_unlocked: %s" % str(is_unlocked))
	print("  - challenge_complete: %s" % str(challenge_complete))

	# CRITICAL: First hide ALL buttons, then show the correct one
	select_button.visible = false
	unlock_button.visible = false
	locked_label.visible = false

	if is_unlocked:
		# Character is unlocked - show SELECT button
		print("  → Showing SELECT button for unlocked character")
		if name_label:
			name_label.text = "⚡ ALIEN MONK"
			name_label.visible = true
		select_button.visible = true
		select_button.disabled = false
		if not select_button.pressed.is_connected(_on_alien_monk_selected):
			select_button.pressed.connect(_on_alien_monk_selected)
		print("✅ Alien Monk SELECT button now visible=%s, disabled=%s" % [select_button.visible, select_button.disabled])
	elif challenge_complete:
		# Challenge complete - can purchase, show UNLOCK button
		print("  → Showing UNLOCK button (challenge complete)")
		if name_label:
			name_label.text = "⚡ ALIEN MONK"
			name_label.visible = true
		unlock_button.visible = true
		unlock_button.disabled = false
		unlock_button.text = "Unlock (750 Shards)"
		if not unlock_button.pressed.is_connected(_on_unlock_alien_monk_pressed):
			unlock_button.pressed.connect(_on_unlock_alien_monk_pressed)
		print("✅ Alien Monk UNLOCK button now visible=%s" % unlock_button.visible)
	else:
		# Still locked - show challenge + price
		print("  → Showing locked label (challenge incomplete)")
		if name_label:
			name_label.visible = false
		locked_label.visible = true
		locked_label.text = "🔒 LOCKED\n\nChallenge: Survive 30:00\non Grassy Field\n\nPrice: 750 Shards"
		print("✅ Alien Monk locked_label now visible=%s" % locked_label.visible)

func _on_ranger_selected():
	print("Selected: Ranger")
	start_game_with_character("ranger")

func _on_swordmaiden_selected():
	print("Selected: Swordmaiden")
	start_game_with_character("swordmaiden")

func _on_alien_monk_selected():
	print("Selected: Alien Monk")
	start_game_with_character("alien_monk")

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

	# Set the selected map BEFORE adding to tree
	if "selected_map" in main_game:
		main_game.selected_map = selected_map
		print("✅ Set map to: %s" % selected_map)
	else:
		print("⚠️ Warning: main_game doesn't have selected_map property")

	# Set active curses BEFORE adding to tree
	if "active_curses" in main_game:
		main_game.active_curses = selected_curses.duplicate()
		print("✅ Set active curses: %s" % str(selected_curses))
	else:
		print("⚠️ Warning: main_game doesn't have active_curses property")

	# Set selected game mode BEFORE adding to tree
	if "game_mode" in main_game:
		main_game.game_mode = selected_game_mode
		print("✅ Set game mode to: %s" % selected_game_mode)
	else:
		print("⚠️ Warning: main_game doesn't have game_mode property")

	# Switch to game scene
	get_tree().root.add_child(main_game)
	queue_free()

func _on_unlock_pressed():
	if not save_manager:
		return

	var current_shards = save_manager.get_shards()

	if current_shards < 500:
		update_info_label("❌ Not enough shards! Need 500, have %d" % current_shards)
		return

	if save_manager.try_unlock_swordmaiden():
		update_info_label("🗡️ SWORDMAIDEN UNLOCKED!")
		# Refresh UI
		setup_swordmaiden_panel()
	else:
		update_info_label("❌ Failed to unlock Swordmaiden")

func _on_unlock_alien_monk_pressed():
	if not save_manager:
		return

	var current_shards = save_manager.get_shards()

	if current_shards < 750:
		update_info_label("❌ Not enough shards! Need 750, have %d" % current_shards)
		return

	if save_manager.try_unlock_alien_monk():
		update_info_label("🧙 ALIEN MONK UNLOCKED!")
		# Refresh UI
		setup_alien_monk_panel()
	else:
		update_info_label("❌ Failed to unlock Alien Monk")

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
