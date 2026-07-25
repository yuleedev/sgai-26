extends AudioStreamPlayer

var _fade_tween: Tween

func play_track(track: AudioStream, track_volume_db: float = 0.0) -> void:
	if stream == track and playing:
		return
	_kill_fade()
	stream = track
	volume_db = track_volume_db
	play()

func fade_in(track: AudioStream, target_volume_db: float = 0.0, duration: float = 0.6) -> void:
	_kill_fade()
	stream = track
	volume_db = -40.0
	play()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "volume_db", target_volume_db, duration)

func fade_out(duration: float = 0.6) -> void:
	if not playing:
		return
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "volume_db", -40.0, duration)
	_fade_tween.tween_callback(stop)

func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
