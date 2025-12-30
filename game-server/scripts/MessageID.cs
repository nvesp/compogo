// Auto-generated from shared/message_ids.json; DO NOT EDIT
// Protocol Version: 0.020 | Schema Version: 0.1.0

public enum MessageID : int
{
    CONNECT = 0,
    HANDSHAKE_ACK = 1,
    MOVE = 2,
    ATTACK = 3,
    SNAPSHOT = 4,
    ERROR = 5,
    DISCONNECT = 6,
}

public enum ErrorCode : int
{
    PROTOCOL_VERSION_MISMATCH = 1001,
    INVALID_MOVE = 2001,
    INVALID_ATTACK = 2002,
    RATE_LIMITED = 2003,
    UNAUTHORIZED = 1002,
    INTERNAL_SERVER_ERROR = 9999,
}
