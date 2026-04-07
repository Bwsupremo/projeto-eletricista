extends AudioStreamPlayer
class_name RadioCrackle

# Gera estática de rádio de obra proceduralmente via AudioStreamGenerator.
# - Estática de fundo contínua (amplitude muito baixa)
# - Burst de crackle ao pressionar/soltar PTT ("clic" de rádio)
# - Intensidade aumenta quando jogadores estão em andares diferentes

const MIX_RATE := 44100.0
const BUFFER_SIZE := 512

# Amplitudes base
const STATIC_FLOOR_AMPLITUDE  := 0.006  # estática de fundo
const STATIC_SPEAK_AMPLITUDE  := 0.018  # estática enquanto alguém fala
const CRACKLE_BURST_AMPLITUDE := 0.35   # burst ao abrir/fechar canal
const CRACKLE_BURST_DURATION  := 0.045  # segundos de burst

var _playback : AudioStreamGeneratorPlayback

# Estado
var _anyone_speaking : bool = false
var _burst_timer : float = 0.0
var _static_amplitude : float = STATIC_FLOOR_AMPLITUDE
var _floor_gap : int = 0  # diferença de andares entre jogadores

# Parâmetros ajustáveis pelo VoipManager
var floor_gap_distortion_index : int = 2  # índice do AudioEffectDistortion no bus Radio

func _ready() -> void:
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback

func _process(delta: float) -> void:
	if _playback == null:
		return

	# Decai burst
	if _burst_timer > 0.0:
		_burst_timer -= delta

	var frames_available := _playback.get_frames_available()
	if frames_available <= 0:
		return

	var burst_active := _burst_timer > 0.0
	var amplitude := CRACKLE_BURST_AMPLITUDE if burst_active else _static_amplitude

	# Ruído branco com envelope: crackle só nos primeiros ms do burst,
	# senão ruído branco suave (estática de fundo)
	var frames := PackedVector2Array()
	frames.resize(frames_available)
	for i in frames_available:
		var noise := randf_range(-1.0, 1.0)
		# Crackle "granular": apenas ~20% das amostras têm energia no burst
		if burst_active and randf() > 0.2:
			noise = 0.0
		var sample := noise * amplitude
		frames[i] = Vector2(sample, sample)
	_playback.push_buffer(frames)

# --- API pública ---

func on_peer_started_speaking() -> void:
	if not _anyone_speaking:
		_anyone_speaking = true
		_static_amplitude = STATIC_SPEAK_AMPLITUDE
		trigger_burst()

func on_peer_stopped_speaking() -> void:
	# Verifica se ainda há alguém falando (VoipManager controla)
	_anyone_speaking = false
	_static_amplitude = STATIC_FLOOR_AMPLITUDE
	trigger_burst()

func trigger_burst() -> void:
	_burst_timer = CRACKLE_BURST_DURATION

## Define quantos andares de distância há entre o jogador local e o mais distante.
## 0 = mesmo andar (efeito mínimo), 2+ = andares distantes (mais distorção/estática).
func set_floor_gap(gap: int) -> void:
	if gap == _floor_gap:
		return
	_floor_gap = gap
	_apply_floor_distortion(gap)

func _apply_floor_distortion(gap: int) -> void:
	var radio_bus_idx := AudioServer.get_bus_index("Radio")
	if radio_bus_idx == -1:
		return
	# Ajusta drive da distorção: +0.08 por andar de distância
	var distortion := AudioServer.get_bus_effect(
		radio_bus_idx, floor_gap_distortion_index
	) as AudioEffectDistortion
	if distortion == null:
		return
	distortion.drive = clampf(0.18 + gap * 0.08, 0.18, 0.55)
	# Aumenta levemente o pré-gain para simular sinal fraco
	distortion.pre_gain = clampf(6.0 + gap * 2.0, 6.0, 14.0)
	# Estática de fundo proporcional ao gap
	_static_amplitude = STATIC_FLOOR_AMPLITUDE + gap * 0.008
