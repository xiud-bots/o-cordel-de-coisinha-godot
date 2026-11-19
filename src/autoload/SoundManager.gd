extends Node

const SFXSynthScript := preload("res://src/audio/SFXSynth.gd")
const MusicTrackerScript := preload("res://src/audio/MusicTracker.gd")
const SFX_POOL_SIZE: int = 12

var _sfx_synth: SFXSynthScript = SFXSynthScript.new()
var _music_tracker: MusicTrackerScript = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_cursor: int = 0

var _master_volume: float = 0.8
var _bgm_volume: float = 0.6
var _sfx_volume: float = 0.85
var _muted: bool = false

var _current_bgm: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_tracker = MusicTrackerScript.new()
	_music_tracker.name = "MusicTracker"
	add_child(_music_tracker)
	for i: int in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		_sfx_pool.append(player)
	_refresh_volumes()

func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_M:
		return

	var muted_now: bool = toggle_mute()
	DialogPanel.post_message(
		"Som desligado [M]" if muted_now else "Som ligado [M]",
		{"icon": "🔇" if muted_now else "🔊"}
	)

func is_muted() -> bool:
	return _muted


func set_muted(muted: bool) -> void:
	_muted = muted
	_refresh_volumes()


func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted


func get_master_volume() -> float:
	return _master_volume


func set_master_volume(vol: float) -> void:
	_master_volume = clampf(vol, 0.0, 1.0)
	_refresh_volumes()


func get_bgm_volume() -> float:
	return _bgm_volume


func set_bgm_volume(vol: float) -> void:
	_bgm_volume = clampf(vol, 0.0, 1.0)
	_refresh_volumes()


func get_sfx_volume() -> float:
	return _sfx_volume


func set_sfx_volume(vol: float) -> void:
	_sfx_volume = clampf(vol, 0.0, 1.0)
	_refresh_volumes()


func _refresh_volumes() -> void:
	var sfx_db: float = _calc_db(_master_volume * _sfx_volume)
	for player: AudioStreamPlayer in _sfx_pool:
		if not player.playing:
			player.volume_db = sfx_db
	if _music_tracker != null:
		_music_tracker.set_volume_db(_calc_db(_master_volume * _bgm_volume))


func _calc_db(linear: float) -> float:
	if _muted or linear <= 0.0001:
		return -80.0
	return linear_to_db(clampf(linear, 0.0001, 1.0))


func _acquire_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_pool:
		if not player.playing:
			return player
	var fallback: AudioStreamPlayer = _sfx_pool[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _sfx_pool.size()
	fallback.stop()
	return fallback


func play_sfx(sfx_name: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> void:
	if _sfx_pool.is_empty():
		return
	var stream: AudioStreamWAV = _sfx_synth.get_sfx(sfx_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _acquire_sfx_player()
	player.stream = stream
	player.volume_db = _calc_db(_master_volume * _sfx_volume * volume_scale)
	player.pitch_scale = clampf(pitch_scale, 0.25, 4.0)
	player.play()


func play_sfx_stream(stream: AudioStreamWAV, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> void:
	if stream == null or _sfx_pool.is_empty():
		return
	var player: AudioStreamPlayer = _acquire_sfx_player()
	player.stream = stream
	player.volume_db = _calc_db(_master_volume * _sfx_volume * volume_scale)
	player.pitch_scale = clampf(pitch_scale, 0.25, 4.0)
	player.play()


# --- BGM (MusicTracker Nordestino Procedural) ---
func play_music(track_name: String, _crossfade_duration: float = 0.3) -> void:
	if track_name.strip_edges().is_empty():
		stop_music(_crossfade_duration)
		return
	if _music_tracker != null:
		_music_tracker.set_volume_db(_calc_db(_master_volume * _bgm_volume))
		_music_tracker.play(track_name)
		_current_bgm = _music_tracker.get_current_track()
	else:
		_current_bgm = track_name


func stop_music(_fade_duration: float = 0.3) -> void:
	_current_bgm = ""
	if _music_tracker != null:
		_music_tracker.stop()


func get_current_music() -> String:
	return _current_bgm


func is_music_playing() -> bool:
	return _music_tracker != null and _music_tracker.is_playing()


func set_music_tension(tension: float) -> void:
	if _music_tracker != null:
		_music_tracker.set_tension(tension)


func set_music_tempo_multiplier(mult: float) -> void:
	if _music_tracker != null:
		_music_tracker.set_tempo_multiplier(mult)


# --- Metodos diretos de conveniencia ---
func play_aboio(duration: float = 1.4) -> void:
	if is_equal_approx(duration, 1.4):
		play_sfx("aboio")
	else:
		play_sfx_stream(_sfx_synth.generate_aboio(duration))


func play_grito() -> void:
	play_sfx("grito")


func play_berro_bode(scared: bool = false) -> void:
	play_sfx("berro_pavor_bode" if scared else "berro_bode")


func play_chupacabra_rosnado() -> void:
	play_sfx("chupacabra_rosnado")


func play_cumade_assobio(intensity: float = 1.0) -> void:
	if is_equal_approx(intensity, 1.0):
		play_sfx("cumade_assobio")
	else:
		play_sfx_stream(_sfx_synth.generate_cumade_assobio(intensity))


func play_cordel_folhear() -> void:
	play_sfx("cordel_folhear")


func play_sino_badalo() -> void:
	play_sfx("sino_badalo")


func play_prensa_impacto() -> void:
	play_sfx("prensa_impacto")


func play_chicote() -> void:
	play_sfx("chicote")


func play_pickup() -> void:
	play_sfx("pickup")


func play_item_descobrir() -> void:
	play_sfx("item_descobrir")


func play_passos() -> void:
	play_sfx("passos")


func play_escavacao() -> void:
	play_sfx("escavacao")


func play_rasga_canto() -> void:
	play_sfx("rasga_canto")


func play_ui_click() -> void:
	play_sfx("ui_click")


func play_ui_hover() -> void:
	play_sfx("ui_hover")


func play_victory_jingle() -> void:
	play_sfx("victory_jingle")


func play_defeat_jingle() -> void:
	play_sfx("defeat_jingle")


func play_glitch_censura() -> void:
	play_sfx("glitch_censura")


func play_hurt_cacto() -> void:
	play_sfx("hurt_cacto")


func play_fruit_eat() -> void:
	play_sfx("fruit_eat")


func play_berro_pavor_bode() -> void:
	play_sfx("berro_pavor_bode")


func play_viola_repente() -> void:
	play_sfx("viola_repente")
