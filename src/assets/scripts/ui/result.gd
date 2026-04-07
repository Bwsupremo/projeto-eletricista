extends CanvasLayer

func _ready() -> void:
	$Panel/Buttons/PlayAgainButton.pressed.connect(_on_play_again)
	$Panel/Buttons/MainMenuButton.pressed.connect(_on_main_menu)
	# Apenas o host pode iniciar nova partida
	$Panel/Buttons/PlayAgainButton.visible = multiplayer.is_server()

func set_result(success: bool, score: int) -> void:
	$Panel/VBoxContainer/ResultLabel.text = "MISSÃO CONCLUÍDA!" if success else "MISSÃO FALHOU"
	$Panel/VBoxContainer/ScoreLabel.text = "Pontuação: %d" % score

func _on_play_again() -> void:
	if not multiplayer.is_server():
		return
	_return_to_lobby.rpc()

func _on_main_menu() -> void:
	NetworkManager._leave_from_result()

@rpc("authority", "call_local", "reliable")
func _return_to_lobby() -> void:
	NetworkManager._transition_to_lobby_from_result()
