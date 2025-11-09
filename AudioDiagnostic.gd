# AudioDiagnostic.gd - Debug audio issues
extends Node

func _ready():
	print("\n=== AUDIO DIAGNOSTIC ===")
	
	# Check if AudioManager exists
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		print("✅ AudioManager found")
		
		# Check music player
		if audio_manager.has_node("MusicPlayer"):
			var music_player = audio_manager.get_node("MusicPlayer")
			print("✅ MusicPlayer found")
			print("   - Stream: ", music_player.stream)
			print("   - Playing: ", music_player.playing)
			print("   - Volume DB: ", music_player.volume_db)
			print("   - Bus: ", music_player.bus)
			
			# Check if stream exists and has data
			if music_player.stream:
				print("   - Stream type: ", music_player.stream.get_class())
				if music_player.stream is AudioStreamWAV:
					var wav = music_player.stream as AudioStreamWAV
					print("   - Loop mode: ", wav.loop_mode)
					print("   - Mix rate: ", wav.mix_rate)
					print("   - Stereo: ", wav.stereo)
					print("   - Data length: ", wav.data.size() if wav.data else "No data!")
			else:
				print("❌ No stream loaded!")
		else:
			print("❌ MusicPlayer not found!")
	else:
		print("❌ AudioManager not found!")
	
	# Check audio bus
	print("\n=== AUDIO BUS INFO ===")
	var bus_count = AudioServer.bus_count
	print("Total buses: ", bus_count)
	
	for i in range(bus_count):
		var bus_name = AudioServer.get_bus_name(i)
		var volume_db = AudioServer.get_bus_volume_db(i)
		var muted = AudioServer.is_bus_mute(i)
		print("Bus %d: %s | Volume: %.1f dB | Muted: %s" % [i, bus_name, volume_db, muted])
	
	print("=== END DIAGNOSTIC ===\n")
