class_name SFXSynth
extends RefCounted

const SAMPLE_RATE: int = 22050
const TWO_PI: float = TAU

var _cache: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 19380728


func get_sfx(sfx_name: String) -> AudioStreamWAV:
	var key: String = sfx_name.to_lower().strip_edges()
	if _cache.has(key):
		return _cache[key] as AudioStreamWAV

	var stream: AudioStreamWAV = _build_sfx(key)
	if stream != null:
		_cache[key] = stream
	return stream


func _build_sfx(key: String) -> AudioStreamWAV:
	match key:
		"aboio":
			return generate_aboio(1.4)
		"grito":
			return generate_grito()
		"berro_bode":
			return generate_berro_bode(false)
		"berro_pavor_bode":
			return generate_berro_bode(true)
		"chupacabra_rosnado":
			return generate_chupacabra_rosnado()
		"cumade_assobio", "fulo_assobio":
			return generate_cumade_assobio(1.0)
		"cordel_folhear":
			return generate_cordel_folhear()
		"sino_badalo":
			return generate_sino_badalo()
		"prensa_impacto":
			return generate_prensa_impacto()
		"chicote":
			return generate_chicote()
		"pickup", "coleta":
			return generate_pickup()
		"item_descobrir", "moita":
			return generate_item_descobrir()
		"passos":
			return generate_passos()
		"escavacao", "botija":
			return generate_escavacao()
		"rasga_canto", "rasga_mortalha":
			return generate_rasga_canto()
		"ui_click":
			return generate_ui_click()
		"ui_hover":
			return generate_ui_hover()
		"victory_jingle", "vitoria":
			return generate_victory_jingle()
		"defeat_jingle", "derrota":
			return generate_defeat_jingle()
		"glitch_censura", "censura":
			return generate_glitch_censura()
		"hurt_cacto", "dano", "tropeco":
			return generate_hurt_cacto()
		"fruit_eat":
			return generate_fruit_eat()
		"viola_repente":
			return generate_viola_repente()
		_:
			return null


func _samples_to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var count: int = samples.size()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for i: int in range(count):
		var clamped: float = clampf(samples[i], -1.0, 1.0)
		var pcm: int = clampi(int(roundf(clamped * 32767.0)), -32768, 32767)
		bytes.encode_s16(i * 2, pcm)

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _new_buffer(duration: float) -> PackedFloat32Array:
	var count: int = maxi(1, int(roundf(duration * float(SAMPLE_RATE))))
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(count)
	return buf


func _osc_sample(wave_type: int, phase: float) -> float:
	# 0=sine, 1=triangle, 2=sawtooth, 3=square
	var p: float = phase - floorf(phase)
	match wave_type:
		0:
			return sin(p * TWO_PI)
		1:
			return 1.0 - 4.0 * absf(p - 0.5)
		2:
			return 2.0 * p - 1.0
		3:
			return 1.0 if p < 0.5 else -1.0
		_:
			return sin(p * TWO_PI)


func _exp_ramp(v0: float, v1: float, t: float) -> float:
	var a: float = maxf(v0, 0.0001)
	var b: float = maxf(v1, 0.0001)
	return a * pow(b / a, clampf(t, 0.0, 1.0))


func _lin_ramp(v0: float, v1: float, t: float) -> float:
	return lerpf(v0, v1, clampf(t, 0.0, 1.0))


func _biquad_coeffs(filter_type: int, freq: float, q: float) -> Array[float]:
	# 0=lowpass, 1=bandpass, 2=highpass
	var fc: float = clampf(freq, 20.0, float(SAMPLE_RATE) * 0.45)
	var w0: float = TWO_PI * fc / float(SAMPLE_RATE)
	var cos_w0: float = cos(w0)
	var sin_w0: float = sin(w0)
	var alpha: float = sin_w0 / (2.0 * maxf(q, 0.1))

	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a0: float = 1.0 + alpha
	var a1: float = -2.0 * cos_w0
	var a2: float = 1.0 - alpha

	match filter_type:
		0:
			b0 = (1.0 - cos_w0) * 0.5
			b1 = 1.0 - cos_w0
			b2 = (1.0 - cos_w0) * 0.5
		1:
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
		2:
			b0 = (1.0 + cos_w0) * 0.5
			b1 = -(1.0 + cos_w0)
			b2 = (1.0 + cos_w0) * 0.5

	return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]


func _apply_biquad(buf: PackedFloat32Array, filter_type: int, freq_start: float, freq_end: float, q: float) -> PackedFloat32Array:
	var count: int = buf.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)

	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var coeffs: Array[float] = _biquad_coeffs(filter_type, freq_start, q)
	var dynamic_freq: bool = not is_equal_approx(freq_start, freq_end)

	for i: int in range(count):
		if dynamic_freq and (i & 15) == 0:
			var prog: float = float(i) / float(maxi(1, count - 1))
			coeffs = _biquad_coeffs(filter_type, lerpf(freq_start, freq_end, prog), q)
		var x0: float = buf[i]
		var y0: float = coeffs[0] * x0 + coeffs[1] * x1 + coeffs[2] * x2 - coeffs[3] * y1 - coeffs[4] * y2
		x2 = x1
		x1 = x0
		y2 = y1
		y1 = y0
		out[i] = y0

	return out


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


# 1. ABOIO TRADICIONAL NORDESTINO
func generate_aboio(duration: float = 1.4) -> AudioStreamWAV:
	var dur: float = maxf(duration, 0.4)
	var buf: PackedFloat32Array = _new_buffer(dur)
	var count: int = buf.size()
	var phase1: float = 0.0
	var phase2: float = 0.0
	var vib_phase: float = 0.0
	var dt: float = 1.0 / float(SAMPLE_RATE)

	for i: int in range(count):
		var t: float = float(i) * dt
		var freq: float
		if t < 0.35:
			freq = _exp_ramp(329.63, 440.0, t / 0.35)
		elif t < 0.8:
			freq = _lin_ramp(440.0, 392.0, (t - 0.35) / 0.45)
		else:
			freq = _exp_ramp(392.0, 293.66, (t - 0.8) / maxf(0.01, dur - 0.8))

		var vib_depth: float = _lin_ramp(0.0, 14.0, minf(t / 0.3, 1.0))
		vib_phase += 5.5 * dt
		var vib: float = sin(vib_phase * TWO_PI) * vib_depth
		var f_inst: float = maxf(40.0, freq + vib)

		phase1 += f_inst * dt
		phase2 += (f_inst * 2.0) * dt

		var raw: float = _osc_sample(1, phase1) + _osc_sample(0, phase2) * 0.15

		var env: float
		if t < 0.15:
			env = _lin_ramp(0.001, 0.35, t / 0.15)
		elif t < dur - 0.3:
			env = _lin_ramp(0.35, 0.32, (t - 0.15) / maxf(0.01, dur - 0.45))
		else:
			env = _exp_ramp(0.32, 0.0001, (t - (dur - 0.3)) / 0.3)

		buf[i] = raw * env

	buf = _apply_biquad(buf, 0, 1800.0, 800.0, 0.707)
	return _samples_to_wav(buf)


# 2. GRITO DE ESPANTAR
func generate_grito() -> AudioStreamWAV:
	var dur: float = 0.45
	var buf: PackedFloat32Array = _new_buffer(dur)
	var noise_buf: PackedFloat32Array = _new_buffer(dur)
	var count: int = buf.size()
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var phase: float = 0.0
	var lfo_phase: float = 0.0

	for i: int in range(count):
		var t: float = float(i) * dt
		noise_buf[i] = _noise()

	noise_buf = _apply_biquad(noise_buf, 1, 1200.0, 1200.0, 2.0)

	for i: int in range(count):
		var t: float = float(i) * dt
		var base_f: float = _exp_ramp(750.0, 180.0, t / dur)
		lfo_phase += 30.0 * dt
		var f_inst: float = maxf(50.0, base_f + sin(lfo_phase * TWO_PI) * 40.0)
		phase += f_inst * dt

		var n_gain: float = _exp_ramp(0.2, 0.001, t / dur)
		var m_gain: float = _lin_ramp(0.01, 0.4, t / 0.04) if t < 0.04 else _exp_ramp(0.4, 0.001, (t - 0.04) / (dur - 0.04))
		buf[i] = (_osc_sample(2, phase) + noise_buf[i] * n_gain) * m_gain

	return _samples_to_wav(buf)


# 3. BERRO DOS BODES
func generate_berro_bode(scared: bool = false) -> AudioStreamWAV:
	var dur: float = 0.65 if scared else 0.45
	var base_freq: float = 380.0 if scared else 310.0
	var lfo_rate: float = 18.0 if scared else 13.0
	var buf: PackedFloat32Array = _new_buffer(dur)
	var count: int = buf.size()
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var phase: float = 0.0
	var lfo_phase: float = 0.0

	for i: int in range(count):
		var t: float = float(i) * dt
		var freq: float
		if t < 0.1:
			freq = _lin_ramp(base_freq, base_freq * 1.15, t / 0.1)
		else:
			freq = _exp_ramp(base_freq * 1.15, base_freq * 0.85, (t - 0.1) / (dur - 0.1))

		lfo_phase += lfo_rate * dt
		var f_inst: float = freq + sin(lfo_phase * TWO_PI) * 28.0
		phase += f_inst * dt

		var env: float
		if t < 0.05:
			env = _lin_ramp(0.01, 0.35, t / 0.05)
		elif t < dur - 0.1:
			env = _lin_ramp(0.35, 0.3, (t - 0.05) / maxf(0.01, dur - 0.15))
		else:
			env = _exp_ramp(0.3, 0.001, (t - (dur - 0.1)) / 0.1)

		buf[i] = _osc_sample(2, phase) * env

	buf = _apply_biquad(buf, 1, 1100.0, 1100.0, 3.5)
	for i: int in range(count):
		buf[i] *= 1.8
	return _samples_to_wav(buf)


# 4. ROSNADO DO CHUPA-CABRA
func generate_chupacabra_rosnado() -> AudioStreamWAV:
	var dur: float = 0.8
	var buf: PackedFloat32Array = _new_buffer(dur)
	var noise_buf: PackedFloat32Array = _new_buffer(dur)
	var count: int = buf.size()
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var p1: float = 0.0
	var p2: float = 0.0
	var lfo_p: float = 0.0

	for i: int in range(count):
		noise_buf[i] = _noise()
	noise_buf = _apply_biquad(noise_buf, 0, 350.0, 350.0, 0.707)

	for i: int in range(count):
		var t: float = float(i) * dt
		var f1: float = _lin_ramp(75.0, 60.0, t / 0.4) if t < 0.4 else _exp_ramp(60.0, 45.0, (t - 0.4) / 0.4)
		var f2: float = _exp_ramp(110.0, 50.0, t / dur)
		lfo_p += 28.0 * dt
		var mod: float = _osc_sample(2, lfo_p) * 35.0

		p1 += maxf(20.0, f1 + mod) * dt
		p2 += f2 * dt

		buf[i] = _osc_sample(2, p1) * 0.55 + _osc_sample(1, p2) * 0.45 + noise_buf[i] * 0.45

	buf = _apply_biquad(buf, 0, 450.0, 450.0, 4.0)
	for i: int in range(count):
		var t: float = float(i) * dt
		var env: float
		if t < 0.08:
			env = _lin_ramp(0.01, 0.45, t / 0.08)
		elif t < 0.5:
			env = _lin_ramp(0.45, 0.4, (t - 0.08) / 0.42)
		else:
			env = _exp_ramp(0.4, 0.001, (t - 0.5) / 0.3)
		buf[i] = tanh(buf[i] * 1.4) * env

	return _samples_to_wav(buf)


# 5. ASSOBIO MISTICO DA CUMADE FULOZINHA
func generate_cumade_assobio(intensity: float = 1.0) -> AudioStreamWAV:
	var dur: float = 0.9
	var extra_echo: float = 0.4
	var total_dur: float = dur + extra_echo
	var dry: PackedFloat32Array = _new_buffer(total_dur)
	var count: int = dry.size()
	var dur_samples: int = int(roundf(dur * float(SAMPLE_RATE)))
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var p1: float = 0.0
	var p2: float = 0.0
	var vib_p: float = 0.0
	var start_f: float = 1500.0 * intensity

	for i: int in range(mini(count, dur_samples)):
		var t: float = float(i) * dt
		var f1: float
		if t < 0.25:
			f1 = _exp_ramp(start_f, 2600.0 * intensity, t / 0.25)
		elif t < 0.5:
			f1 = _lin_ramp(2600.0 * intensity, 1900.0 * intensity, (t - 0.25) / 0.25)
		elif t < 0.75:
			f1 = _exp_ramp(1900.0 * intensity, 3100.0 * intensity, (t - 0.5) / 0.25)
		else:
			f1 = _exp_ramp(3100.0 * intensity, 1200.0 * intensity, (t - 0.75) / (dur - 0.75))

		var f2: float
		if t < 0.25:
			f2 = _exp_ramp(start_f * 1.5, 2600.0 * 1.5 * intensity, t / 0.25)
		else:
			f2 = _exp_ramp(2600.0 * 1.5 * intensity, 1200.0 * 1.5 * intensity, (t - 0.25) / (dur - 0.25))

		vib_p += 8.0 * dt
		var vib: float = sin(vib_p * TWO_PI) * 25.0
		p1 += (f1 + vib) * dt
		p2 += f2 * dt

		var env: float
		if t < 0.08:
			env = _lin_ramp(0.001, 0.28, t / 0.08)
		elif t < 0.6:
			env = _lin_ramp(0.28, 0.25, (t - 0.08) / 0.52)
		else:
			env = _exp_ramp(0.25, 0.0001, (t - 0.6) / (dur - 0.6))

		dry[i] = (_osc_sample(0, p1) + _osc_sample(0, p2) * 0.08) * env

	# Echo / delay 180ms feedback 0.35
	var delay_samples: int = int(roundf(0.18 * float(SAMPLE_RATE)))
	var out: PackedFloat32Array = _new_buffer(total_dur)
	for i: int in range(count):
		var delayed: float = out[i - delay_samples] * 0.35 if i >= delay_samples else 0.0
		out[i] = dry[i] + delayed

	return _samples_to_wav(out)


# 6. FOLHEAR DE CORDEL
func generate_cordel_folhear() -> AudioStreamWAV:
	var dur: float = 0.22
	var buf: PackedFloat32Array = _new_buffer(dur)
	var count: int = buf.size()
	for i: int in range(count):
		buf[i] = _noise()

	buf = _apply_biquad(buf, 1, 2400.0, 1200.0, 2.5)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	for i: int in range(count):
		var t: float = float(i) * dt
		var env: float
		if t < 0.02:
			env = _lin_ramp(0.001, 0.3, t / 0.02)
		elif t < 0.07:
			env = _lin_ramp(0.3, 0.05, (t - 0.02) / 0.05)
		elif t < 0.11:
			env = _lin_ramp(0.05, 0.35, (t - 0.07) / 0.04)
		else:
			env = _exp_ramp(0.35, 0.001, (t - 0.11) / (dur - 0.11))
		buf[i] *= env * 2.2

	return _samples_to_wav(buf)


# 7. BADALO DE SINO
func generate_sino_badalo() -> AudioStreamWAV:
	var dur: float = 2.4
	var buf: PackedFloat32Array = _new_buffer(dur)
	var count: int = buf.size()
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var fundamental: float = 523.25
	var ratios: Array[float] = [0.5, 1.0, 1.19, 1.5, 2.0, 2.76, 4.07]
	var amps: Array[float] = [0.35, 0.45, 0.30, 0.25, 0.20, 0.15, 0.08]
	var phases: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

	var clank_dur: float = 0.05
	var clank: PackedFloat32Array = _new_buffer(clank_dur)
	for i: int in range(clank.size()):
		clank[i] = _noise()
	clank = _apply_biquad(clank, 2, 3000.0, 3000.0, 0.707)

	for i: int in range(count):
		var t: float = float(i) * dt
		var sum: float = 0.0
		for idx: int in range(ratios.size()):
			var decay_t: float = dur / (1.0 + float(idx) * 0.35)
			if t < decay_t:
				phases[idx] += fundamental * ratios[idx] * dt
				var wave: int = 0 if idx == 0 else 1
				var env: float = _exp_ramp(amps[idx], 0.0001, t / decay_t)
				sum += _osc_sample(wave, phases[idx]) * env

		if i < clank.size():
			var c_env: float = _exp_ramp(0.2, 0.001, t / clank_dur)
			sum += clank[i] * c_env

		buf[i] = sum * 0.4

	return _samples_to_wav(buf)


# 8. IMPACTO DA PRENSA DE XILOGRAVURA
func generate_prensa_impacto() -> AudioStreamWAV:
	var dur: float = 0.65
	var buf: PackedFloat32Array = _new_buffer(dur)
	var crack_dur: float = 0.18
	var crack: PackedFloat32Array = _new_buffer(crack_dur)
	for i: int in range(crack.size()):
		crack[i] = _noise()
	crack = _apply_biquad(crack, 1, 800.0, 800.0, 2.0)

	var count: int = buf.size()
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var phase: float = 0.0

	for i: int in range(count):
		var t: float = float(i) * dt
		var freq: float = _exp_ramp(140.0, 32.0, minf(t / 0.35, 1.0))
		phase += freq * dt

		var sub_env: float = 0.0
		if t < 0.02:
			sub_env = _lin_ramp(0.01, 0.6, t / 0.02)
		elif t < 0.5:
			sub_env = _exp_ramp(0.6, 0.001, (t - 0.02) / 0.48)

		var sample: float = _osc_sample(0, phase) * sub_env
		if i < crack.size():
			var c_env: float = _exp_ramp(0.5, 0.001, t / crack_dur)
			sample += crack[i] * c_env * 2.0

		buf[i] = sample

	return _samples_to_wav(buf)


# 9. CHICOTADA DE CIPO
func generate_chicote() -> AudioStreamWAV:
	var dur: float = 0.12
	var buf: PackedFloat32Array = _new_buffer(dur)
	var count: int = buf.size()
	for i: int in range(count):
		buf[i] = _noise()

	var p1: PackedFloat32Array = _apply_biquad(buf, 2, 2000.0, 6000.0, 0.707)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	for i: int in range(count):
		var t: float = float(i) * dt
		var env: float = _lin_ramp(0.01, 0.55, t / 0.02) if t < 0.02 else _exp_ramp(0.55, 0.001, (t - 0.02) / (dur - 0.02))
		p1[i] *= env * 1.4
	return _samples_to_wav(p1)


# 10. COLETA DE ITEM
func generate_pickup() -> AudioStreamWAV:
	var notes: Array[float] = [587.33, 739.99, 880.0, 1174.66]
	return _render_arpeggio(notes, 0.07, 0.18, 1, 0.3)


# 11. ITEM DESCOBERTO NA MOITA
func generate_item_descobrir() -> AudioStreamWAV:
	var notes: Array[float] = [659.25, 830.61, 987.77, 1318.51]
	return _render_arpeggio(notes, 0.06, 0.35, 0, 0.22)


func _render_arpeggio(notes: Array[float], step: float, note_dur: float, wave: int, peak: float) -> AudioStreamWAV:
	var total_dur: float = float(notes.size() - 1) * step + note_dur
	var buf: PackedFloat32Array = _new_buffer(total_dur)
	var dt: float = 1.0 / float(SAMPLE_RATE)

	for idx: int in range(notes.size()):
		var start_i: int = int(roundf(float(idx) * step * float(SAMPLE_RATE)))
		var len_i: int = int(roundf(note_dur * float(SAMPLE_RATE)))
		var phase: float = 0.0
		var freq: float = notes[idx]
		for j: int in range(len_i):
			var pos: int = start_i + j
			if pos >= buf.size():
				break
			var t: float = float(j) * dt
			phase += freq * dt
			var env: float = _lin_ramp(0.01, peak, t / 0.01) if t < 0.01 else _exp_ramp(peak, 0.001, (t - 0.01) / maxf(0.01, note_dur - 0.01))
			buf[pos] += _osc_sample(wave, phase) * env

	return _samples_to_wav(buf)


# 12. PASSOS NA TERRA BATIDA
func generate_passos() -> AudioStreamWAV:
	var dur: float = 0.07
	var buf: PackedFloat32Array = _new_buffer(dur)
	for i: int in range(buf.size()):
		buf[i] = _noise()
	buf = _apply_biquad(buf, 1, 380.0, 380.0, 1.5)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	for i: int in range(buf.size()):
		var t: float = float(i) * dt
		buf[i] *= _exp_ramp(0.14, 0.001, t / dur) * 2.5
	return _samples_to_wav(buf)


# 13. ESCAVACAO DA BOTIJA
func generate_escavacao() -> AudioStreamWAV:
	var dur: float = 0.2
	var buf: PackedFloat32Array = _new_buffer(dur)
	for i: int in range(buf.size()):
		buf[i] = _noise()
	buf = _apply_biquad(buf, 1, 450.0, 900.0, 2.0)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	for i: int in range(buf.size()):
		var t: float = float(i) * dt
		var env: float = _lin_ramp(0.01, 0.25, t / 0.03) if t < 0.03 else _exp_ramp(0.25, 0.001, (t - 0.03) / (dur - 0.03))
		buf[i] *= env * 2.2
	return _samples_to_wav(buf)


# 14. GRASNADO DA RASGA-MORTALHA
func generate_rasga_canto() -> AudioStreamWAV:
	var dur: float = 0.55
	var buf: PackedFloat32Array = _new_buffer(dur)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var phase: float = 0.0
	for i: int in range(buf.size()):
		var t: float = float(i) * dt
		var freq: float = _exp_ramp(1400.0, 650.0, t / dur)
		phase += freq * dt
		buf[i] = _osc_sample(2, phase) + _noise() * 0.5

	buf = _apply_biquad(buf, 1, 1200.0, 1200.0, 4.0)
	for i: int in range(buf.size()):
		var t: float = float(i) * dt
		var env: float = _lin_ramp(0.01, 0.35, t / 0.04) if t < 0.04 else _exp_ramp(0.35, 0.001, (t - 0.04) / (dur - 0.04))
		buf[i] *= env * 1.6
	return _samples_to_wav(buf)


# 15. UI CLICK & HOVER
func generate_ui_click() -> AudioStreamWAV:
	var dur: float = 0.04
	var buf: PackedFloat32Array = _new_buffer(dur)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var phase: float = 0.0
	for i: int in range(buf.size()):
		var t: float = float(i) * dt
		var freq: float = _exp_ramp(800.0, 300.0, t / dur)
		phase += freq * dt
		buf[i] = _osc_sample(1, phase) * _exp_ramp(0.2, 0.001, t / dur)
	return _samples_to_wav(buf)


func generate_ui_hover() -> AudioStreamWAV:
	var dur: float = 0.03
	var buf: PackedFloat32Array = _new_buffer(dur)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var phase: float = 0.0
	for i: int in range(buf.size()):
		var t: float = float(i) * dt
		phase += 520.0 * dt
		buf[i] = _osc_sample(0, phase) * _exp_ramp(0.08, 0.001, t / dur)
	return _samples_to_wav(buf)


# 16. FANFARRA DE VITORIA
func generate_victory_jingle() -> AudioStreamWAV:
	var freqs: Array[float] = [293.66, 369.99, 440.0, 587.33, 659.25, 739.99, 880.0]
	var durs: Array[float] = [0.12, 0.12, 0.12, 0.22, 0.12, 0.12, 0.35]
	return _render_sequence(freqs, durs, 0.85, 3, 0.25)


# 17. JINGLE DE DERROTA
func generate_defeat_jingle() -> AudioStreamWAV:
	var freqs: Array[float] = [349.23, 329.63, 311.13, 261.63]
	var durs: Array[float] = [0.2, 0.2, 0.25, 0.6]
	return _render_sequence(freqs, durs, 0.8, 2, 0.25)


func _render_sequence(freqs: Array[float], durs: Array[float], overlap: float, wave: int, peak: float) -> AudioStreamWAV:
	var total_dur: float = 0.0
	var starts: Array[float] = []
	var offset: float = 0.0
	for idx: int in range(freqs.size()):
		starts.append(offset)
		total_dur = maxf(total_dur, offset + durs[idx])
		offset += durs[idx] * overlap

	var buf: PackedFloat32Array = _new_buffer(total_dur)
	var dt: float = 1.0 / float(SAMPLE_RATE)

	for idx: int in range(freqs.size()):
		var start_i: int = int(roundf(starts[idx] * float(SAMPLE_RATE)))
		var note_dur: float = durs[idx]
		var len_i: int = int(roundf(note_dur * float(SAMPLE_RATE)))
		var phase: float = 0.0
		for j: int in range(len_i):
			var pos: int = start_i + j
			if pos >= buf.size():
				break
			var t: float = float(j) * dt
			phase += freqs[idx] * dt
			var env: float
			if t < 0.025:
				env = _lin_ramp(0.01, peak, t / 0.025)
			elif t < note_dur * 0.7:
				env = _lin_ramp(peak, peak * 0.8, (t - 0.025) / maxf(0.01, note_dur * 0.7 - 0.025))
			else:
				env = _exp_ramp(peak * 0.8, 0.001, (t - note_dur * 0.7) / maxf(0.01, note_dur * 0.3))
			buf[pos] += _osc_sample(wave, phase) * env

	return _samples_to_wav(buf)


# 18. GLITCH / CENSURA COMICA
func generate_glitch_censura() -> AudioStreamWAV:
	var dur: float = 0.42
	var buf: PackedFloat32Array = _new_buffer(dur)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var phase: float = 0.0
	for i: int in range(buf.size()):
		var t: float = float(i) * dt
		var freq: float = 880.0
		if t < 0.08:
			freq = 950.0
		elif t < 0.16:
			freq = 420.0
		elif t < 0.24:
			freq = 1200.0
		elif t < 0.32:
			freq = 310.0

		phase += freq * dt
		var osc_env: float = _exp_ramp(0.35, 0.001, t / dur)
		var noise_env: float = _exp_ramp(0.25, 0.001, t / dur)
		buf[i] = _osc_sample(3, phase) * osc_env + _noise() * noise_env

	return _samples_to_wav(buf)


# 19. DANO DE CACTO / TROPECO
func generate_hurt_cacto() -> AudioStreamWAV:
	var dur: float = 0.28
	var buf: PackedFloat32Array = _new_buffer(dur)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var phase: float = 0.0
	for i: int in range(buf.size()):
		var t: float = float(i) * dt
		var freq: float = _exp_ramp(750.0, 140.0, t / dur)
		phase += freq * dt
		buf[i] = _osc_sample(2, phase) * _exp_ramp(0.4, 0.001, t / dur)
	return _samples_to_wav(buf)


# 20. COMER FRUTA REGIONAL
func generate_fruit_eat() -> AudioStreamWAV:
	var notes: Array[float] = [392.0, 523.25, 659.25, 783.99]
	return _render_arpeggio(notes, 0.07, 0.18, 0, 0.28)


# 21. VIOLA DO REPENTE
func generate_viola_repente() -> AudioStreamWAV:
	var notes: Array[float] = [220.0, 277.18, 329.63, 440.0]
	return _render_arpeggio(notes, 0.035, 0.45, 1, 0.25)
