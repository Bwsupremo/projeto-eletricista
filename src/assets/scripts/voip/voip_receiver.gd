extends AudioStreamPlayer
class_name VoipReceiver

# Reproduz a voz de UM jogador remoto específico.
# Requer twovoip (AudioStreamOpusChunked) para funcionar.
# O bus "Radio" aplica os efeitos de rádio de obra automaticamente.

var peer_id : int = 0

# Tipagem dinâmica: evita erro de parser se twovoip não estiver carregado
var _stream_opus  # AudioStreamOpusChunked | null
var _buffer : Array[PackedByteArray] = []
var _available : bool = false

func _ready() -> void:
	if not ClassDB.class_exists("AudioStreamOpusChunked"):
		push_warning("VoipReceiver: AudioStreamOpusChunked não disponível — twovoip não carregado.")
		return
	# Cria o stream Opus em runtime para não depender de sub-recurso na cena
	_stream_opus = ClassDB.instantiate("AudioStreamOpusChunked")
	stream = _stream_opus
	_available = true
	play()

func _process(_delta: float) -> void:
	if not _available:
		return
	while _stream_opus.chunk_space_available() and not _buffer.is_empty():
		_stream_opus.push_opus_packet(_buffer.pop_front(), 0, 0)

func push_chunks(chunks: Array[PackedByteArray]) -> void:
	if not _available:
		return
	_buffer.append_array(chunks)

func flush() -> void:
	_buffer.clear()
