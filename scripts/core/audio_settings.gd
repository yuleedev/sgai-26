extends Node

signal volumes_changed

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const CONFIG_PATH := "user://audio_settings.cfg"
const SILENT_THRESHOLD := 0.001

var music_volume := 1.0
var sfx_volume := 1.0

func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_load()
	_apply(MUSIC_BUS, music_volume)
	_apply(SFX_BUS, sfx_volume)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply(MUSIC_BUS, music_volume)
	_save()
	volumes_changed.emit()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply(SFX_BUS, sfx_volume)
	_save()
	volumes_changed.emit()

func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		return index
	index = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	return index

func _apply(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	if volume <= SILENT_THRESHOLD:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(volume))

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	music_volume = clampf(config.get_value("audio", "music", music_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx", sfx_volume), 0.0, 1.0)

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(CONFIG_PATH)
