extends Node

var socket: WebSocketPeer
var connected: bool = false
var seq: int = 0


func _ready() -> void:
	socket = WebSocketPeer.new()

func send_message(msg_id: int, payload: Dictionary) -> void:
	seq += 1
	var envelope: Dictionary = {
		"id": msg_id,
		"seq": seq,
		"payload": payload
	}
	var json = MessageEnvelope.serialize(envelope)
	socket.send_text(json)

func _on_message_received(message: String) -> void:
	var envelope = MessageEnvelope.deserialize(message)
	
	match envelope.id:
		MessageID.ERROR:
			handle_error(envelope.payload)
		MessageID.HANDSHAKE_ACK:
			handle_handshake(envelope.payload)
		MessageID.SNAPSHOT:
			handle_snapshot(envelope.payload)
		_:
			push_warning("Unknown message id: ", envelope.id)

### Error Handling
func handle_error(payload: Dictionary) -> void:
	var code = payload.get("code", "UNKNOWN")
	var reason = payload.get("reason", "Unknown error")
	
	match code:
		"PROTOCOL_VERSION_MISMATCH":
			# FATAL: hard disconnect
			disconnect_fatal("Version mismatch; upgrade required")
		"INVALID_MOVE":
			# WARN: rollback and retry
			rollback_to_last_snapshot()
			display_toast("Invalid move; try again")
		"RATE_LIMITED":
			# WARN: queue locally and retry
			queue_message_retry()
		_:
			display_toast("Error: %s" % reason)

func disconnect_fatal(message: String) -> void:
	connected = false
	socket.close()
	show_fatal_modal(message)  # Block reconnect


### Protocol/Schema Version Handling
func handle_handshake(payload: Dictionary) -> void:
	var server_protocol = payload.get("protocol_version", 0.0)
	var server_schema = payload.get("schema_version", "0.0.0")
	
	if server_protocol != RulesLoader.protocol_version:
		# FATAL: protocol_version mismatch
		var msg = "Client protocol %.3f ≠ server %.3f; upgrade required" % [
			RulesLoader.protocol_version,
			server_protocol
		]
		handle_error({"code": "PROTOCOL_VERSION_MISMATCH", "reason": msg})
		return
	
	if server_schema != RulesLoader.schema_version:
		# WARNING: schema_version mismatch (non-fatal)
		push_warning(
			"Schema version mismatch: client %s, server %s (non-fatal)" %
			[RulesLoader.schema_version, server_schema]
		)
		# Continue connection; may show UI warning
		show_schema_warning("Schema version mismatch (non-fatal)")
	
	# Connection successful
	connected = true
	spawn_players(payload.get("existing_players", []))