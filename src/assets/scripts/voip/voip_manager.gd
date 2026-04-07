extends Node

# Singleton (autoload via voip_manager.tscn).
# Gerencia captura de voz Opus e transmissão peer-to-peer.
# Requer o addon twovoip (AudioEffectOpusChunked) para funcionar.
# Degrada graciosamente se twovoip não estiver carregado.
#
# Fluxo:
#   NetworkManager._transition_to_lobby()  → VoipManager.activate()
#   NetworkManager._leave_lobby()          → VoipManager.deactivate()
#
# Push-to-Talk: segure V (ação "speak")

signal started_speaking(peer_id: int)
signal stopped_speaking(peer_id: int)

const SPEAK_ACTION         := &"speak"
const RECEIVER_SCENE       := "res://assets/scenes/voip/voip_receiver.tscn"
const SPEAKING_TIMEOUT_SEC := 0.4

var _active       : bool = false
var _is_speaking  : bool = false
var _voip_available : bool = false  # false se twovoip não carregou

@onready var _mic_player : AudioStreamPlayer = $MicrophonePlayer
@onready var _crackle    : RadioCrackle       = $RadioCrackle

# Tipagem dinâmica para evitar erro de parser quando twovoip não está carregado
var _opuschunked  # AudioEffectOpusChunked | null
var _prepend : PackedByteArray = PackedByteArray()

var _receivers       : Dictionary = {}
var _peer_last_packet : Dictionary = {}
var _peer_speaking    : Dictionary = {}
var _speaking_count  : int = 0

func _ready() -> void:
	if not ClassDB.class_exists("AudioEffectOpusChunked"):
		push_warning("VoipManager: twovoip não carregado — VoIP desativado. Instale o addon twovoip compatível com Godot 4.4.")
		return
	_voip_available = true
	var record_idx := AudioServer.get_bus_index("_Record")
	if record_idx == -1:
		push_error("VoipManager: bus '_Record' não encontrado. Verifique bus.tres.")
		return
	# Verifica se o efeito já existe no bus (adicionado pelo editor)
	if AudioServer.get_bus_effect_count(record_idx) > 0:
		_opuschunked = AudioServer.get_bus_effect(record_idx, 0)
	# Se não, cria em runtime
	if _opuschunked == null:
		_opuschunked = ClassDB.instantiate("AudioEffectOpusChunked")
		AudioServer.add_bus_effect(record_idx, _opuschunked, 0)

func activate() -> void:
	if _active or not _voip_available:
		return
	_active = true
	_mic_player.play()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	for id in NetworkManager.players:
		if id != multiplayer.get_unique_id():
			_on_peer_connected(id)

func deactivate() -> void:
	if not _active:
		return
	_active = false
	_set_local_speaking(false)
	_mic_player.stop()
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	for receiver in _receivers.values():
		receiver.queue_free()
	_receivers.clear()
	_peer_last_packet.clear()
	_peer_speaking.clear()
	_speaking_count = 0

func _process(delta: float) -> void:
	if not _active:
		return
	_tick_speaking_timeouts(delta)
	if Input.is_action_just_pressed(SPEAK_ACTION):
		_set_local_speaking(true)
	elif Input.is_action_just_released(SPEAK_ACTION):
		_set_local_speaking(false)
	if not _is_speaking or _opuschunked == null:
		return
	var chunks : Array[PackedByteArray] = []
	while _opuschunked.chunk_available():
		chunks.append(_opuschunked.read_opus_packet(_prepend))
		_opuschunked.drop_chunk()
	if not chunks.is_empty():
		_receive_voice_data.rpc(chunks)

func _tick_speaking_timeouts(delta: float) -> void:
	for id in _peer_last_packet.keys():
		if not _peer_speaking.get(id, false):
			continue
		_peer_last_packet[id] += delta
		if _peer_last_packet[id] >= SPEAKING_TIMEOUT_SEC:
			_peer_speaking[id] = false
			_update_speaking_count(-1)
			_crackle.on_peer_stopped_speaking()
			stopped_speaking.emit(id)

func _set_local_speaking(speaking: bool) -> void:
	if speaking == _is_speaking:
		return
	_is_speaking = speaking
	if speaking:
		started_speaking.emit(multiplayer.get_unique_id())
		_update_speaking_count(1)
	else:
		stopped_speaking.emit(multiplayer.get_unique_id())
		_update_speaking_count(-1)
		if _opuschunked:
			while _opuschunked.chunk_available():
				_opuschunked.drop_chunk()

func _on_peer_connected(id: int) -> void:
	if id == multiplayer.get_unique_id():
		return
	if _receivers.has(id):
		return
	if not _voip_available:
		return
	var scene : PackedScene = load(RECEIVER_SCENE)
	if scene == null:
		push_error("VoipManager: não encontrou %s" % RECEIVER_SCENE)
		return
	var receiver = scene.instantiate()
	receiver.peer_id = id
	_receivers[id] = receiver
	_peer_last_packet[id] = 0.0
	_peer_speaking[id] = false
	add_child(receiver)

func _on_peer_disconnected(id: int) -> void:
	if not _receivers.has(id):
		return
	_receivers[id].queue_free()
	_receivers.erase(id)
	_peer_last_packet.erase(id)
	if _peer_speaking.get(id, false):
		_peer_speaking.erase(id)
		_update_speaking_count(-1)
		stopped_speaking.emit(id)
	else:
		_peer_speaking.erase(id)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _receive_voice_data(chunks: Array[PackedByteArray]) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if not _receivers.has(sender_id):
		return
	_receivers[sender_id].push_chunks(chunks)
	_peer_last_packet[sender_id] = 0.0
	if not _peer_speaking.get(sender_id, false):
		_peer_speaking[sender_id] = true
		_update_speaking_count(1)
		_crackle.on_peer_started_speaking()
		started_speaking.emit(sender_id)

func set_floor_gap(gap: int) -> void:
	_crackle.set_floor_gap(gap)

func _update_speaking_count(delta: int) -> void:
	_speaking_count = maxi(0, _speaking_count + delta)

func is_local_speaking() -> bool:
	return _is_speaking

func is_anyone_speaking() -> bool:
	return _speaking_count > 0

func is_voip_available() -> bool:
	return _voip_available
