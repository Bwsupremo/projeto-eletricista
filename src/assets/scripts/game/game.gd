extends Node

# Placeholder para a cena de gameplay principal.
# Substitua pela lógica real de Fio Pelado quando implementar o jogo.

@onready var _ptt_label     : Label = $HUD/VoipHUD/PttLabel
@onready var _speaking_label : Label = $HUD/VoipHUD/SpeakingLabel

func _ready() -> void:
	$HUD/DebugPanel/EndMissionButton.pressed.connect(_on_end_mission_pressed)
	$HUD/DebugPanel/EndMissionButton.visible = OS.is_debug_build() and multiplayer.is_server()
	VoipManager.started_speaking.connect(_on_started_speaking)
	VoipManager.stopped_speaking.connect(_on_stopped_speaking)

func _exit_tree() -> void:
	if VoipManager.started_speaking.is_connected(_on_started_speaking):
		VoipManager.started_speaking.disconnect(_on_started_speaking)
	if VoipManager.stopped_speaking.is_connected(_on_stopped_speaking):
		VoipManager.stopped_speaking.disconnect(_on_stopped_speaking)

func _on_end_mission_pressed() -> void:
	if not multiplayer.is_server():
		return
	_end_mission.rpc(true, 0)

# Chame este RPC quando a missão terminar (sucesso ou falha).
# success: bool — missão concluída com êxito
# score: int — pontuação final acumulada
@rpc("authority", "call_local", "reliable")
func _end_mission(success: bool, score: int) -> void:
	NetworkManager._transition_to_result(success, score)

# --- VoIP HUD ---

func _on_started_speaking(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_ptt_label.visible = false
		_speaking_label.visible = true

func _on_stopped_speaking(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_speaking_label.visible = false
		_ptt_label.visible = true
