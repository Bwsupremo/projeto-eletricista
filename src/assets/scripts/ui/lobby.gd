extends CanvasLayer

var player_container : VBoxContainer
var _is_ready : bool = false
@export var row : PackedScene

func _ready() -> void:
	NetworkManager.players_changed.connect(_on_players_changed)
	$Panel/Exit.pressed.connect(NetworkManager._leave_lobby)
	$Panel/Ready.pressed.connect(_on_ready)
	$Panel/Start.pressed.connect(_on_start)
	VoipManager.started_speaking.connect(_on_started_speaking)
	VoipManager.stopped_speaking.connect(_on_stopped_speaking)

func _exit_tree() -> void:
	if VoipManager.started_speaking.is_connected(_on_started_speaking):
		VoipManager.started_speaking.disconnect(_on_started_speaking)
	if VoipManager.stopped_speaking.is_connected(_on_stopped_speaking):
		VoipManager.stopped_speaking.disconnect(_on_stopped_speaking)

func _on_start() -> void:
	if not multiplayer.is_server():
		return
	_start_briefing.rpc()

@rpc("authority", "call_local", "reliable")
func _start_briefing() -> void:
	NetworkManager._transition_to_briefing()

func _add_row(name_ : String, id: int) -> void:
	var instance : HBoxContainer = row.instantiate()
	instance.get_node("Label").text = name_
	player_container.add_child(instance)
	NetworkManager.players[id]["object"] = instance

func _enter_tree() -> void:
	player_container = $Panel/VBoxContainer
	_on_players_changed()
	$Panel/RichTextLabel.text = NetworkManager.players[1]['name'] + "'s Lobby"

func _on_players_changed() -> void:
	_is_ready = false
	var i: = 1
	var my_id : int = multiplayer.get_unique_id()
	for child : HBoxContainer in player_container.get_children():
		child.queue_free()
	for peer : int in NetworkManager.players:
		if NetworkManager.lan:
			if peer == my_id:
				NetworkManager.players[peer]["name"] = "Player " + str(i) + "(you)"
			else:
				NetworkManager.players[peer]["name"] = "Player " + str(i)
			i+=1
		_add_row(NetworkManager.players[peer]["name"], peer)
	if NetworkManager.players.size() == 1:
		$Panel/Start.disabled = false
	else:
		$Panel/Start.disabled = true

func _on_ready() -> void:
	_is_ready = !_is_ready
	_on_ready_remote.rpc(_is_ready)

@rpc("any_peer", "call_local")
func _on_ready_remote(_is_ready_remote : bool) -> void:
	NetworkManager.players[multiplayer.get_remote_sender_id()]["object"].get_node("Ready").visible = _is_ready_remote
	if multiplayer.is_server() and NetworkManager.players.size() > 1:
		for child : HBoxContainer in player_container.get_children():
			if not child.get_node("Ready").visible:
				$Panel/Start.disabled = true
				return
		$Panel/Start.disabled = false

# --- VoIP: indicadores de fala ---

func _on_started_speaking(peer_id: int) -> void:
	_set_speaking_indicator(peer_id, true)

func _on_stopped_speaking(peer_id: int) -> void:
	_set_speaking_indicator(peer_id, false)

func _set_speaking_indicator(peer_id: int, speaking: bool) -> void:
	if not NetworkManager.players.has(peer_id):
		return
	var player_data : Dictionary = NetworkManager.players[peer_id]
	var row_node = player_data.get("object")
	if not is_instance_valid(row_node):
		return
	row_node.get_node("Speaking").visible = speaking
