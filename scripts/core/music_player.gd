extends AudioStreamPlayer

func play_track(track: AudioStream, track_volume_db: float = 0.0) -> void:
	if stream == track and playing:
		return
	stream = track
	volume_db = track_volume_db
	play()

func fade_out(duration: float = 0.6) -> void:
	if not playing:
		return
	var tween := create_tween()
	tween.tween_property(self, "volume_db", -40.0, duration)
	tween.tween_callback(stop)
