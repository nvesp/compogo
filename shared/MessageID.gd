# Auto-generated from shared/message_ids.json; DO NOT EDIT
# Protocol Version: 0.020 | Schema Version: 0.1.0

# System Messages (0-9)
# Movement Messages (10-19)
# Combat Messages (30-39)
# Broadcast Messages (40-49)

const CONNECT = 0
const HANDSHAKE_ACK = 1
const MOVE = 2
const ATTACK = 3
const SNAPSHOT = 4
const ERROR = 5
const DISCONNECT = 6

# Error Codes
const ERROR_PROTOCOL_VERSION_MISMATCH = 1001
const ERROR_INVALID_MOVE = 2001
const ERROR_INVALID_ATTACK = 2002
const ERROR_RATE_LIMITED = 2003
const ERROR_UNAUTHORIZED = 1002
const ERROR_INTERNAL_SERVER_ERROR = 9999
