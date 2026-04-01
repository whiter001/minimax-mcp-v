module protocol

import json

// =============================================================================
// JSON-RPC Message Parsing
// =============================================================================

// parse_request parses a JSON-RPC request or notification from a json.Value
pub fn parse_request(value json.Value) !JsonRpcRequest {
	if value.kind != .object {
		return error('Invalid JSON-RPC request: expected object')
	}

	obj := value.as_map()

	jsonrpc := obj['jsonrpc'] or {
		return error('Invalid JSON-RPC request: missing jsonrpc field')
	}
	if jsonrpc.as_str() != '2.0' {
		return error('Invalid JSON-RPC request: wrong version')
	}

	method := obj['method'] or {
		return error('Invalid JSON-RPC request: missing method field')
	}

	// id is optional for notifications
	id_val := obj['id']
	id := if id_val != none {
		id_val.unwrap().as_int()
	} else {
		0
	}

	params := obj['params']

	return JsonRpcRequest{
		jsonrpc: '2.0'
		id: id
		method: method.as_str()
		params: params
	}
}

// parse_response parses a JSON-RPC response from a json.Value
pub fn parse_response(value json.Value) !JsonRpcResponse {
	if value.kind != .object {
		return error('Invalid JSON-RPC response: expected object')
	}

	obj := value.as_map()

	jsonrpc := obj['jsonrpc'] or {
		return error('Invalid JSON-RPC response: missing jsonrpc field')
	}
	if jsonrpc.as_str() != '2.0' {
		return error('Invalid JSON-RPC response: wrong version')
	}

	id := obj['id'] or {
		return error('Invalid JSON-RPC response: missing id field')
	}

	// Check for error
	if obj.contains('error') {
		err_val := obj['error'] or { return error('Missing error value') }
		err := parse_jsonrpc_error(err_val)!
		return JsonRpcResponse{
			jsonrpc: '2.0'
			id: id.as_int()
			error: err
		}
	}

	// Check for result
	result := obj['result'] or {
		return error('Invalid JSON-RPC response: missing result or error')
	}

	return JsonRpcResponse{
		jsonrpc: '2.0'
		id: id.as_int()
		result: result
	}
}

// parse_jsonrpc_error parses a JSON-RPC error object
fn parse_jsonrpc_error(value json.Value) !JsonRpcError {
	if value.kind != .object {
		return error('Invalid JSON-RPC error: expected object')
	}

	obj := value.as_map()

	code := obj['code'] or {
		return error('Invalid JSON-RPC error: missing code field')
	}

	message := obj['message'] or {
		return error('Invalid JSON-RPC error: missing message field')
	}

	data := obj['data']

	return JsonRpcError{
		code: code.as_int()
		message: message.as_str()
		data: data
	}
}

// =============================================================================
// JSON-RPC Response Building
// =============================================================================

// build_response creates a successful JSON-RPC response
pub fn build_response(id int, result json.Value) JsonRpcResponse {
	return JsonRpcResponse{
		jsonrpc: '2.0'
		id: id
		result: result
	}
}

// build_error_response creates an error JSON-RPC response
pub fn build_error_response(id int, code int, message string) JsonRpcResponse {
	return JsonRpcResponse{
		jsonrpc: '2.0'
		id: id
		error: JsonRpcError{
			code: code
			message: message
		}
	}
}

// build_error_response_with_data creates an error JSON-RPC response with data
pub fn build_error_response_with_data(id int, code int, message string, data json.Value) JsonRpcResponse {
	return JsonRpcResponse{
		jsonrpc: '2.0'
		id: id
		error: JsonRpcError{
			code: code
			message: message
			data: data
		}
	}
}

// =============================================================================
// JSON-RPC Notification Building
// =============================================================================

// build_notification creates a JSON-RPC notification
pub fn build_notification(method string, params ?json.Value) JsonRpcNotification {
	return JsonRpcNotification{
		jsonrpc: '2.0'
		method: method
		params: params
	}
}

// =============================================================================
// JSON Serialization
// =============================================================================

// request_to_json serializes a JsonRpcRequest to JSON string
pub fn request_to_json(req JsonRpcRequest) !string {
	mut obj := map[string]json.Value{}
	obj['jsonrpc'] = json.Value(json.string('2.0'))
	obj['id'] = json.Value(json.int(req.id))
	obj['method'] = json.Value(json.string(req.method))
	if req.params != none {
		obj['params'] = req.params
	}
	return json.encode(obj)
}

// response_to_json serializes a JsonRpcResponse to JSON string
pub fn response_to_json(resp JsonRpcResponse) !string {
	mut obj := map[string]json.Value{}
	obj['jsonrpc'] = json.Value(json.string('2.0'))
	obj['id'] = json.Value(json.int(resp.id))
	if resp.error != none {
		err := resp.error?
		mut err_obj := map[string]json.Value{}
		err_obj['code'] = json.Value(json.int(err.code))
		err_obj['message'] = json.Value(json.string(err.message))
		if err.data != none {
			err_obj['data'] = err.data?
		}
		obj['error'] = json.Value(json.encode(err_obj))
	} else if resp.result != none {
		obj['result'] = resp.result?
	}
	return json.encode(obj)
}

// notification_to_json serializes a JsonRpcNotification to JSON string
pub fn notification_to_json(n JsonRpcNotification) !string {
	mut obj := map[string]json.Value{}
	obj['jsonrpc'] = json.Value(json.string('2.0'))
	obj['method'] = json.Value(json.string(n.method))
	if n.params != none {
		obj['params'] = n.params
	}
	return json.encode(obj)
}

// =============================================================================
// JSON Parsing
// =============================================================================

// parse_jsonrpc_message parses a raw JSON string into a protocol message
pub fn parse_jsonrpc_message(raw string) !JsonRpcRequest | JsonRpcResponse | JsonRpcNotification {
	value := json.parse(raw)!
	obj := value.as_map()

	// Determine message type based on fields
	if obj.contains('id') && obj.contains('method') {
		// Request
		return parse_request(value)!
	} else if obj.contains('id') && !obj.contains('method') {
		// Response
		return parse_response(value)!
	} else if !obj.contains('id') && obj.contains('method') {
		// Notification
		return parse_notification(value)!
	}

	return error('Invalid JSON-RPC message: missing required fields')
}

// parse_notification parses a JSON-RPC notification
fn parse_notification(value json.Value) !JsonRpcNotification {
	if value.kind != .object {
		return error('Invalid JSON-RPC notification: expected object')
	}

	obj := value.as_map()

	jsonrpc := obj['jsonrpc'] or {
		return error('Invalid JSON-RPC notification: missing jsonrpc field')
	}
	if jsonrpc.as_str() != '2.0' {
		return error('Invalid JSON-RPC notification: wrong version')
	}

	method := obj['method'] or {
		return error('Invalid JSON-RPC notification: missing method field')
	}

	params := obj['params']

	return JsonRpcNotification{
		jsonrpc: '2.0'
		method: method.as_str()
		params: params
	}
}
