class_name MusicTracker
extends Node

const SAMPLE_RATE: float = 22050.0
const BUFFER_LENGTH: float = 0.25
const TOTAL_STEPS: int = 32
const MAX_FRAMES_PER_TICK: int = 2048

const VOICE_PULSE: int = 0
const VOICE_SAW: int = 1
const VOICE_BASS: int = 2
const VOICE_PERC_TRI_OPEN: int = 3
const VOICE_PERC_TRI_CLOSED: int = 4
const VOICE_PERC_ZABUMBA_LOW: int = 5
const VOICE_PERC_ZABUMBA_RIM: int = 6

# MIDI Note Constants
const C3: int = 48
const D3: int = 50
const Eb3: int = 51
const E3: int = 52
const F3: int = 53
const G3: int = 55
const A3: int = 57
const B3: int = 59

const C4: int = 60
const D4: int = 62
const Eb4: int = 63
const E4: int = 64
const F4: int = 65
const Fs4: int = 66
const G4: int = 67
const Ab4: int = 68
const Gs4: int = 68
const A4: int = 69
const Bb4: int = 70
const B4: int = 71

const C5: int = 72
const Cs5: int = 73
const D5: int = 74
const Eb5: int = 75
const E5: int = 76
const F5: int = 77
const Fs5: int = 78
const G5: int = 79
const Ab5: int = 80
const A5: int = 81
const Bb5: int = 82
const B5: int = 83

const C6: int = 84
const D6: int = 86


class NoteEvent extends RefCounted:
	var note: int
	var duration: int
	var velocity: float

	func _init(p_note: int, p_duration: int, p_velocity: float = 1.0) -> void:
		note = p_note
		duration = p_duration
		velocity = p_velocity


class TrackPattern extends RefCounted:
	var lead: Array[NoteEvent] = []
	var harmony: Array[NoteEvent] = []
	var bass: Array[NoteEvent] = []
	var percussion: Array[int] = []


class ActiveVoice extends RefCounted:
	var kind: int = 0
	var phase: float = 0.0
	var freq: float = 440.0
	var freq_end: float = 440.0
	var elapsed: float = 0.0
	var duration: float = 0.1
	var gain: float = 0.2
	var cutoff_start: float = 2400.0
	var cutoff_end: float = 800.0
	var lp_state: float = 0.0
	var hp_state: float = 0.0
	var prev_in: float = 0.0
	var svf_lp: float = 0.0
	var svf_bp: float = 0.0


var _player: AudioStreamPlayer = null
var _generator: AudioStreamGenerator = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _tracks: Dictionary = {}
var _current_track: String = ""
var _is_playing: bool = false
var _bpm: float = 115.0
var _step: int = 0
var _samples_until_next_step: float = 0.0
var _tempo_multiplier: float = 1.0
var _tension: float = 0.0
var _volume_db: float = -4.4

var _voices: Array[ActiveVoice] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 19460802
	_init_patterns()
	_setup_player()


func _setup_player() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = BUFFER_LENGTH

	_player = AudioStreamPlayer.new()
	_player.name = "MusicGeneratorPlayer"
	_player.stream = _generator
	_player.volume_db = _volume_db
	add_child(_player)


func _n(midi: int, dur: int, vel: float = 1.0) -> NoteEvent:
	return NoteEvent.new(midi, dur, vel)


func _midi_to_freq(midi: int) -> float:
	if midi <= 0:
		return 0.0
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


func _normalize_track_id(track_name: String) -> String:
	var key: String = track_name.strip_edges().to_upper()
	match key:
		"STUDIO", "MENU", "XILOGRAVURA":
			return "STUDIO"
		"STAGE1", "STAGE_1", "STAGE1_CHUPACABRA", "CHUPACABRA":
			return "STAGE1_CHUPACABRA"
		"STAGE2", "STAGE_2", "STAGE2_FULOZINHA", "FULOZINHA":
			return "STAGE2_FULOZINHA"
		"STAGE3", "STAGE_3", "STAGE3_RASGAMORTALHA", "RASGAMORTALHA":
			return "STAGE3_RASGAMORTALHA"
		"STAGE4", "STAGE_4", "STAGE4_BOTIJA", "BOTIJA":
			return "STAGE4_BOTIJA"
		"VICTORY", "VITORIA", "WIN":
			return "VICTORY"
		_:
			return key


func _init_patterns() -> void:
	# 1. STUDIO: "O Baiao da Xilogravura" (108 BPM)
	var studio: TrackPattern = TrackPattern.new()
	studio.lead = [
		_n(D5, 2), _n(F5, 2), _n(A5, 4), _n(G5, 2), _n(F5, 2), _n(E5, 2), _n(D5, 2),
		_n(C5, 2), _n(E5, 2), _n(G5, 4), _n(F5, 2), _n(E5, 2), _n(D5, 4)
	]
	studio.harmony = [
		_n(F4, 2), _n(A4, 2), _n(F4, 2), _n(A4, 2), _n(G4, 2), _n(Bb4, 2), _n(E4, 2), _n(G4, 2),
		_n(E4, 2), _n(G4, 2), _n(E4, 2), _n(G4, 2), _n(F4, 2), _n(A4, 2), _n(D4, 4)
	]
	studio.bass = [
		_n(D3, 3), _n(D3, 1), _n(A3, 2), _n(D3, 2), _n(C3, 3), _n(C3, 1), _n(G3, 2), _n(C3, 2),
		_n(A3, 3), _n(A3, 1), _n(E3, 2), _n(A3, 2), _n(D3, 4), _n(D3, 4)
	]
	studio.percussion = [
		3, 2, 4, 1, 3, 2, 4, 1, 3, 2, 4, 1, 3, 2, 4, 1,
		3, 2, 4, 1, 3, 2, 4, 1, 3, 2, 4, 1, 3, 2, 4, 1
	]
	_tracks["STUDIO"] = {"bpm": 108.0, "pattern": studio}

	# 2. STAGE 1: "O Galope do Chupa-Cabra" (132 BPM)
	var stage1: TrackPattern = TrackPattern.new()
	stage1.lead = [
		_n(E5, 1), _n(G5, 1), _n(B5, 2), _n(A5, 2), _n(G5, 2),
		_n(Fs5, 1), _n(G5, 1), _n(A5, 2), _n(G5, 2), _n(E5, 2),
		_n(E5, 1), _n(G5, 1), _n(B5, 2), _n(D6, 2), _n(B5, 2),
		_n(A5, 2), _n(B5, 2), _n(E5, 4)
	]
	stage1.harmony = [
		_n(G4, 2), _n(B4, 2), _n(G4, 2), _n(B4, 2), _n(A4, 2), _n(C5, 2), _n(G4, 2), _n(B4, 2),
		_n(G4, 2), _n(B4, 2), _n(A4, 2), _n(C5, 2), _n(Fs4, 2), _n(A4, 2), _n(E4, 4)
	]
	stage1.bass = [
		_n(E3, 3), _n(E3, 1), _n(B3, 2), _n(E3, 2), _n(A3, 3), _n(A3, 1), _n(E3, 2), _n(A3, 2),
		_n(E3, 3), _n(E3, 1), _n(B3, 2), _n(E3, 2), _n(B3, 2), _n(B3, 2), _n(E3, 4)
	]
	stage1.percussion = [
		3, 4, 2, 1, 3, 4, 2, 1, 3, 4, 2, 1, 3, 4, 2, 1,
		3, 4, 2, 1, 3, 4, 2, 1, 3, 4, 2, 1, 3, 4, 2, 1
	]
	_tracks["STAGE1_CHUPACABRA"] = {"bpm": 132.0, "pattern": stage1}

	# 3. STAGE 2: "O Misterio de Fulo" (118 BPM)
	var stage2: TrackPattern = TrackPattern.new()
	stage2.lead = [
		_n(A5, 3), _n(C6, 1), _n(B5, 2), _n(A5, 2), _n(G5, 2), _n(E5, 2), _n(G5, 4),
		_n(F5, 2), _n(A5, 2), _n(G5, 2), _n(F5, 2), _n(E5, 4), _n(A5, 4)
	]
	stage2.harmony = [
		_n(C5, 2), _n(E5, 2), _n(C5, 2), _n(E5, 2), _n(B4, 2), _n(D5, 2), _n(B4, 2), _n(D5, 2),
		_n(A4, 2), _n(C5, 2), _n(A4, 2), _n(C5, 2), _n(Gs4, 4), _n(A4, 4)
	]
	stage2.bass = [
		_n(A3, 3), _n(A3, 1), _n(E3, 2), _n(A3, 2), _n(G3, 3), _n(G3, 1), _n(D3, 2), _n(G3, 2),
		_n(F3, 3), _n(F3, 1), _n(C3, 2), _n(F3, 2), _n(E3, 4), _n(A3, 4)
	]
	stage2.percussion = [
		3, 2, 4, 1, 0, 2, 4, 1, 3, 2, 4, 1, 0, 2, 4, 1,
		3, 2, 4, 1, 0, 2, 4, 1, 3, 2, 4, 1, 3, 2, 4, 1
	]
	_tracks["STAGE2_FULOZINHA"] = {"bpm": 118.0, "pattern": stage2}

	# 4. STAGE 3: "A Toada da Rasga-Mortalha" (98 BPM)
	var stage3: TrackPattern = TrackPattern.new()
	stage3.lead = [
		_n(G5, 2), _n(Bb5, 2), _n(D6, 4), _n(C6, 2), _n(Bb5, 2), _n(A5, 4),
		_n(F5, 2), _n(A5, 2), _n(C6, 4), _n(Bb5, 2), _n(A5, 2), _n(G5, 4)
	]
	stage3.harmony = [
		_n(D4, 1), _n(G4, 1), _n(Bb4, 2), _n(D4, 1), _n(G4, 1), _n(Bb4, 2),
		_n(F4, 1), _n(A4, 1), _n(C5, 2), _n(F4, 1), _n(A4, 1), _n(C5, 2),
		_n(D4, 1), _n(F4, 1), _n(A4, 2), _n(D4, 1), _n(F4, 1), _n(A4, 2),
		_n(D4, 1), _n(G4, 1), _n(Bb4, 4)
	]
	stage3.bass = [
		_n(G3, 4), _n(D3, 4), _n(F3, 4), _n(C3, 4),
		_n(D3, 4), _n(A3, 4), _n(G3, 8)
	]
	stage3.percussion = [
		3, 1, 2, 1, 4, 1, 2, 1, 3, 1, 2, 1, 4, 1, 2, 1,
		3, 1, 2, 1, 4, 1, 2, 1, 3, 1, 2, 1, 3, 4, 1, 2
	]
	_tracks["STAGE3_RASGAMORTALHA"] = {"bpm": 98.0, "pattern": stage3}

	# 5. STAGE 4: "A Botija e a Paroquia" (124 BPM)
	var stage4: TrackPattern = TrackPattern.new()
	stage4.lead = [
		_n(C5, 2), _n(Eb5, 2), _n(G5, 3), _n(Ab5, 1), _n(G5, 2), _n(F5, 2), _n(Eb5, 4),
		_n(D5, 2), _n(F5, 2), _n(Ab5, 4), _n(G5, 2), _n(D5, 2), _n(C5, 4)
	]
	stage4.harmony = [
		_n(Eb4, 2), _n(G4, 2), _n(Eb4, 2), _n(G4, 2), _n(F4, 2), _n(Ab4, 2), _n(Eb4, 2), _n(G4, 2),
		_n(D4, 2), _n(F4, 2), _n(D4, 2), _n(F4, 2), _n(B3, 2), _n(D4, 2), _n(C4, 4)
	]
	stage4.bass = [
		_n(C3, 3), _n(C3, 1), _n(G3, 2), _n(C3, 2), _n(F3, 3), _n(F3, 1), _n(C3, 2), _n(Eb3, 2),
		_n(G3, 3), _n(G3, 1), _n(D3, 2), _n(G3, 2), _n(C3, 4), _n(C3, 4)
	]
	stage4.percussion = [
		3, 0, 4, 1, 3, 2, 4, 1, 3, 0, 4, 1, 3, 2, 4, 1,
		3, 0, 4, 1, 3, 2, 4, 1, 3, 0, 4, 1, 3, 4, 2, 1
	]
	_tracks["STAGE4_BOTIJA"] = {"bpm": 124.0, "pattern": stage4}

	# 6. VICTORY: "O Grande Forro da Prensa Dourada" (140 BPM)
	var victory: TrackPattern = TrackPattern.new()
	victory.lead = [
		_n(D5, 2), _n(Fs5, 2), _n(A5, 2), _n(D6, 2), _n(Cs5, 2), _n(B5, 2), _n(A5, 4),
		_n(G5, 2), _n(B5, 2), _n(A5, 2), _n(G5, 2), _n(Fs5, 2), _n(E5, 2), _n(D5, 4)
	]
	victory.harmony = [
		_n(Fs4, 2), _n(A4, 2), _n(Fs4, 2), _n(A4, 2), _n(G4, 2), _n(B4, 2), _n(Fs4, 2), _n(A4, 2),
		_n(G4, 2), _n(B4, 2), _n(G4, 2), _n(B4, 2), _n(E4, 2), _n(A4, 2), _n(D4, 4)
	]
	victory.bass = [
		_n(D3, 3), _n(D3, 1), _n(A3, 2), _n(D3, 2), _n(A3, 3), _n(A3, 1), _n(E3, 2), _n(A3, 2),
		_n(G3, 3), _n(G3, 1), _n(D3, 2), _n(G3, 2), _n(A3, 2), _n(A3, 2), _n(D3, 4)
	]
	victory.percussion = [
		3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2,
		3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2
	]
	_tracks["VICTORY"] = {"bpm": 140.0, "pattern": victory}


func play(track_name: String) -> void:
	var canonical: String = _normalize_track_id(track_name)
	if not _tracks.has(canonical):
		push_warning("MusicTracker: Track nao encontrada: %s" % track_name)
		return
	if _current_track == canonical and _is_playing:
		return

	var track_data: Dictionary = _tracks[canonical] as Dictionary
	_current_track = canonical
	_bpm = float(track_data["bpm"])
	_step = 0
	_samples_until_next_step = 0.0
	_voices.clear()
	_is_playing = true

	if _player != null:
		_player.volume_db = _volume_db
		if not _player.playing:
			_player.play()


func stop() -> void:
	_is_playing = false
	_current_track = ""
	_step = 0
	_samples_until_next_step = 0.0
	_voices.clear()
	if _player != null and _player.playing:
		_player.stop()


func is_playing() -> bool:
	return _is_playing


func get_current_track() -> String:
	return _current_track


func get_available_tracks() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for k: Variant in _tracks.keys():
		names.append(str(k))
	return names


func set_tension(tension: float) -> void:
	_tension = clampf(tension, 0.0, 1.0)


func get_tension() -> float:
	return _tension


func set_tempo_multiplier(mult: float) -> void:
	_tempo_multiplier = clampf(mult, 0.5, 2.0)


func get_tempo_multiplier() -> float:
	return _tempo_multiplier


func set_volume_db(db: float) -> void:
	_volume_db = clampf(db, -80.0, 6.0)
	if _player != null:
		_player.volume_db = _volume_db


func _process(_delta: float) -> void:
	if not _is_playing or _current_track.is_empty() or _player == null:
		return
	if not _player.playing:
		return

	var playback: AudioStreamGeneratorPlayback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var frames_available: int = mini(playback.get_frames_available(), MAX_FRAMES_PER_TICK)
	if frames_available <= 0:
		return

	var track_data: Dictionary = _tracks.get(_current_track, {}) as Dictionary
	if track_data.is_empty():
		return
	var pattern: TrackPattern = track_data["pattern"] as TrackPattern
	var dt: float = 1.0 / SAMPLE_RATE

	for _i: int in range(frames_available):
		if _samples_until_next_step <= 0.0:
			var effective_bpm: float = _bpm * (1.0 + _tension * 0.2) * _tempo_multiplier
			var step_sec: float = 60.0 / (effective_bpm * 4.0)
			_schedule_step(_step, pattern, step_sec)
			_step = (_step + 1) % TOTAL_STEPS
			_samples_until_next_step += step_sec * SAMPLE_RATE

		var mix: float = _render_voices_sample(dt)
		var out: float = clampf(mix, -1.0, 1.0)
		playback.push_frame(Vector2(out, out))
		_samples_until_next_step -= 1.0


func _schedule_step(step_index: int, pattern: TrackPattern, step_sec: float) -> void:
	var lead_note: NoteEvent = _find_note_at_step(pattern.lead, step_index)
	if lead_note != null and lead_note.note > 0:
		_spawn_synth_voice(VOICE_PULSE, lead_note.note, float(lead_note.duration) * step_sec, 0.22 * lead_note.velocity, 2400.0, 800.0)

	var harm_note: NoteEvent = _find_note_at_step(pattern.harmony, step_index)
	if harm_note != null and harm_note.note > 0:
		_spawn_synth_voice(VOICE_SAW, harm_note.note, float(harm_note.duration) * step_sec, 0.13 * harm_note.velocity, 1600.0, 800.0)

	var bass_note: NoteEvent = _find_note_at_step(pattern.bass, step_index)
	if bass_note != null and bass_note.note > 0:
		_spawn_bass_voice(bass_note.note, float(bass_note.duration) * step_sec, 0.35 * bass_note.velocity)

	if not pattern.percussion.is_empty():
		var perc_type: int = pattern.percussion[step_index % pattern.percussion.size()]
		if perc_type > 0:
			_spawn_percussion_voice(perc_type)


func _find_note_at_step(events: Array[NoteEvent], target_step: int) -> NoteEvent:
	var current: int = 0
	for ev: NoteEvent in events:
		if current == target_step:
			return ev
		current += ev.duration
		if current > target_step:
			break
	return null


func _spawn_synth_voice(kind: int, midi: int, dur: float, gain: float, cutoff_start: float, cutoff_end: float) -> void:
	var v: ActiveVoice = ActiveVoice.new()
	v.kind = kind
	v.freq = _midi_to_freq(midi)
	v.freq_end = v.freq
	v.duration = maxf(dur, 0.02)
	v.gain = gain
	v.cutoff_start = cutoff_start
	v.cutoff_end = cutoff_end
	_voices.append(v)


func _spawn_bass_voice(midi: int, dur: float, gain: float) -> void:
	var v: ActiveVoice = ActiveVoice.new()
	v.kind = VOICE_BASS
	v.freq = _midi_to_freq(midi)
	v.freq_end = v.freq
	v.duration = maxf(dur, 0.02)
	v.gain = gain
	_voices.append(v)


func _spawn_percussion_voice(perc_type: int) -> void:
	var v: ActiveVoice = ActiveVoice.new()
	match perc_type:
		1:
			v.kind = VOICE_PERC_TRI_OPEN
			v.duration = 0.12
			v.gain = 0.18
		2:
			v.kind = VOICE_PERC_TRI_CLOSED
			v.duration = 0.04
			v.gain = 0.12
		3:
			v.kind = VOICE_PERC_ZABUMBA_LOW
			v.freq = 110.0
			v.freq_end = 45.0
			v.duration = 0.12
			v.gain = 0.30
		4:
			v.kind = VOICE_PERC_ZABUMBA_RIM
			v.duration = 0.05
			v.gain = 0.18
		_:
			return
	_voices.append(v)


func _render_voices_sample(dt: float) -> float:
	var mix: float = 0.0
	var idx: int = _voices.size() - 1
	while idx >= 0:
		var v: ActiveVoice = _voices[idx]
		var t_norm: float = v.elapsed / v.duration
		if t_norm >= 1.0:
			_voices.remove_at(idx)
			idx -= 1
			continue

		var sample: float = 0.0
		match v.kind:
			VOICE_PULSE, VOICE_SAW:
				var p: float = v.phase - floorf(v.phase)
				var raw: float = (1.0 if p < 0.5 else -1.0) if v.kind == VOICE_PULSE else (2.0 * p - 1.0)
				v.phase += v.freq * dt
				var cutoff: float = v.cutoff_start * pow(v.cutoff_end / maxf(v.cutoff_start, 1.0), t_norm)
				var rc: float = 1.0 / (TAU * cutoff)
				var alpha: float = dt / (rc + dt)
				v.lp_state += alpha * (raw - v.lp_state)
				var env: float = _synth_envelope(v.elapsed, v.duration, v.gain)
				sample = v.lp_state * env
			VOICE_BASS:
				var pb: float = v.phase - floorf(v.phase)
				var tri: float = 1.0 - 4.0 * absf(pb - 0.5)
				v.phase += v.freq * dt
				var env_b: float = _exp_decay_envelope(v.elapsed, 0.01, v.duration, v.gain)
				sample = tri * env_b
			VOICE_PERC_TRI_OPEN, VOICE_PERC_TRI_CLOSED:
				var wn: float = _rng.randf_range(-1.0, 1.0)
				var rc_hp: float = 1.0 / (TAU * 7500.0)
				var a_hp: float = rc_hp / (rc_hp + dt)
				v.hp_state = a_hp * (v.hp_state + wn - v.prev_in)
				v.prev_in = wn
				var env_t: float = v.gain * pow(0.001, t_norm)
				sample = v.hp_state * env_t
			VOICE_PERC_ZABUMBA_LOW:
				var f_z: float = v.freq * pow(v.freq_end / v.freq, t_norm)
				v.phase += f_z * dt
				var sine_z: float = sin(v.phase * TAU)
				var env_z: float = v.gain * pow(0.003, t_norm)
				sample = sine_z * env_z
			VOICE_PERC_ZABUMBA_RIM:
				var wn_r: float = _rng.randf_range(-1.0, 1.0)
				var svf_f: float = 2.0 * sin(PI * 2200.0 / SAMPLE_RATE)
				v.svf_lp += svf_f * v.svf_bp
				var svf_hp: float = wn_r - v.svf_lp - (1.0 / 3.0) * v.svf_bp
				v.svf_bp += svf_f * svf_hp
				var env_r: float = v.gain * pow(0.001, t_norm)
				sample = v.svf_bp * env_r

		mix += sample
		v.elapsed += dt
		idx -= 1

	return mix


func _synth_envelope(elapsed: float, dur: float, peak: float) -> float:
	var attack: float = minf(0.015, dur * 0.25)
	var sustain_end: float = dur * 0.7
	if elapsed < attack:
		return peak * (elapsed / maxf(attack, 0.0001))
	if elapsed < sustain_end:
		var u: float = (elapsed - attack) / maxf(sustain_end - attack, 0.0001)
		return peak * lerpf(1.0, 0.8, u)
	var rel_u: float = (elapsed - sustain_end) / maxf(dur - sustain_end, 0.0001)
	return peak * 0.8 * pow(0.001, clampf(rel_u, 0.0, 1.0))


func _exp_decay_envelope(elapsed: float, attack: float, dur: float, peak: float) -> float:
	if elapsed < attack:
		return peak * (elapsed / maxf(attack, 0.0001))
	var u: float = (elapsed - attack) / maxf(dur - attack, 0.0001)
	return peak * pow(0.001, clampf(u, 0.0, 1.0))
