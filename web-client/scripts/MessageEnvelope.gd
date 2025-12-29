extends Node

static func deserialize(json_string: String) -> Dictionary:
	var data = JSON.parse_string(json_string)
	
	# Type checks with assert (dev); warn only (prod)
	if assert(typeof(data.id) == TYPE_INT, "Message id must be int") && \
	assert(data.has("seq"), "Message must have seq field") && \
	assert(typeof(data.payload) == TYPE_DICTIONARY, "Payload must be dict"):
		return data
	push_warning("Malformed message envelope: %s" % json_string)

static func serialize(message: Dictionary) -> String:
	if assert(message.has("id") and message.has("seq") and message.has("payload")):
	    return JSON.stringify(message)
	push_warning("Malformed message dictionary: %s" % str(message))