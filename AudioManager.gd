# AudioManager.gd - Global Audio Controller
extends Node

var music_player: AudioStreamPlayer = null
var music_volume: float = 0.5  # 0.0 to 1.0
var is_muted: bool = false

const SAVE_PATH = "user://audio_settings.save"

func _ready():
	print("=== AudioManager _ready() called ===")
	# Create the audio player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.name = "MusicPlayer"
	music_player.autoplay = false  # We'll control playback manually
	add_child(music_player)
	print("✅ AudioStreamPlayer created")
	
	# Try to load the music
	var music_path = "res://nebula revenant mian theme 4 allies version.wav"
	if ResourceLoader.exists(music_path):
		var music = load(music_path)
		if music:
			music_player.stream = music
			# Set to loop
			if music is AudioStreamWAV:
				music.loop_mode = AudioStreamWAV.LOOP_FORWARD
				print("✅ Loop mode set to: LOOP_FORWARD")
			print("✅ Music loaded successfully!")
			print("🎵 Music stream: ", music)
			print("🎵 Stream length: ", music.get_length() if music.has_method("get_length") else "unknown")
		else:
			print("⚠️ Music loaded but couldn't set stream")
	else:
		print("⚠️ Music file not found at: ", music_path)
		print("⚠️ Please copy 'nebula_revenant_mian_theme_4_allies_version.wav' to the game folder")
		print("⚠️ Audio system will run without music")
	
	# Load saved settings
	load_settings()
	
	# Apply volume BEFORE we try to play
	update_volume()
	
	# Start playing immediately in _ready
	if music_player.stream:
		print("🎵 Starting music playback...")
		music_player.play()
		print("🎵 Play() called, playing state: ", music_player.playing)
		# Connect to finished signal to debug
		if not music_player.finished.is_connected(_on_music_finished):
			music_player.finished.connect(_on_music_finished)
			print("🎵 Connected to finished signal")

func _process(_delta):
	# Debug: Check music state periodically
	pass  # Removed auto-restart loop

func _on_music_finished():
	print("🎵 Music finished signal received! This shouldn't happen with loop mode.")
	if music_player and music_player.stream:
		print("   Restarting music...")
		music_player.play()

func play_music():
	if not music_player:
		print("❌ No music_player!")
		return
	
	if not music_player.stream:
		print("❌ No audio stream loaded!")
		return
	
	if music_player.playing:
		print("ℹ️ Music already playing")
		return
	
	# Just play - don't stop first
	music_player.play()
	print("🎵 play_music() called - playing now: ", music_player.playing)

func stop_music():
	if music_player:
		music_player.stop()
		print("🎵 Music stopped")

func set_volume(volume: float):
	var was_playing = music_player.playing if music_player else false
	music_volume = clamp(volume, 0.0, 1.0)
	update_volume()
	save_settings()
	# Make sure we didn't accidentally stop the music
	if was_playing and music_player and not music_player.playing and music_player.stream:
		print("⚠️ Volume change stopped music! Restarting...")
		music_player.play()

func set_muted(muted: bool):
	is_muted = muted
	update_volume()
	save_settings()

func toggle_mute():
	is_muted = not is_muted
	update_volume()
	save_settings()

func update_volume():
	if not music_player:
		return
	
	var was_playing = music_player.playing
	var playback_pos = music_player.get_playback_position() if was_playing else 0.0
	
	if is_muted:
		music_player.volume_db = -80  # Effectively silent
		print("🔇 Audio muted")
	else:
		# Convert 0.0-1.0 to decibels (-40 to -10 dB)
		# Using a logarithmic scale for natural volume perception
		if music_volume > 0:
			music_player.volume_db = -40 + (music_volume * 30)  # Changed from 40 to 30
			print("🔊 Volume set to: %.2f (%.1f dB)" % [music_volume, music_player.volume_db])
		else:
			music_player.volume_db = -80
			print("🔇 Volume at 0")
	
	# Resume playback if it was playing before
	if was_playing and not music_player.playing:
		music_player.play(playback_pos)
		print("🎵 Resumed music after volume change")

func get_volume() -> float:
	return music_volume

func is_music_muted() -> bool:
	return is_muted

func save_settings():
	var save_data = {
		"volume": music_volume,
		"muted": is_muted
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("💾 Audio settings saved: Vol=%.2f, Muted=%s" % [music_volume, is_muted])

func load_settings():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var save_data = file.get_var()
			file.close()
			
			if save_data is Dictionary:
				music_volume = save_data.get("volume", 0.5)
				is_muted = save_data.get("muted", false)
				print("✅ Audio settings loaded: Vol=%.2f, Muted=%s" % [music_volume, is_muted])
			else:
				print("⚠️ Invalid audio settings file")
	else:
		print("ℹ️ No saved audio settings, using defaults")
