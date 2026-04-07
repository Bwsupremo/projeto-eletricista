extends CanvasLayer

const COUNTDOWN_DURATION := 10.0

var _countdown : float = COUNTDOWN_DURATION
var _ticking : bool = false

func _ready() -> void:
	$Panel/StartButton.visible = multiplayer.is_server()
	$Panel/StartButton.pressed.connect(_on_start_pressed)

func _process(delta: float) -> void:
	if not _ticking:
		return
	_countdown -= delta
	$Panel/VBoxContainer/CountdownLabel.text = "Iniciando em: %d" % ceili(_countdown)
	if _countdown <= 0.0:
		_ticking = false
		_go_to_game.rpc()

func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	_begin_countdown.rpc()

@rpc("authority", "call_local", "reliable")
func _begin_countdown() -> void:
	_ticking = true
	$Panel/StartButton.visible = false

@rpc("authority", "call_local", "reliable")
func _go_to_game() -> void:
	NetworkManager._transition_to_game()
