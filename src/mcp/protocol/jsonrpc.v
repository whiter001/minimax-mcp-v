module protocol

import x.json2

// =============================================================================
// JSON-RPC Message Parsing
// =============================================================================

// parse_request parses a JSON-RPC request or notification from a json.Value
pub fn parse_request(value json2.Any) !JsonRpcRequest {
	if value !is map[string]json2.Any {
		return error('Invalid JSON-RPC request: expected object')
	}

	obj := value.as_map()

	jsonrpc := obj['jsonrpc'] or { return error('Invalid JSON-RPC request: missing jsonrpc field') }
	if jsonrpc.str() != '2.0' {
		return error('Invalid JSON-RPC request: wrong version')
	}

	method := obj['method'] or { return error('Invalid JSON-RPC request: missing method field') }

	// id is optional for notifications
	id := if id_val := obj['id'] { id_val } else { json2.Any(0) }

	params := if params_val := obj['params'] { params_val } else { none }

	return JsonRpcRequest{
		jsonrpc: '2.0'
		id:      id
		method:  method.str()
		params:  params
	}
}

// parse_response parses a JSON-RPC response from a json.Value
pub fn parse_response(value json2.Any) !JsonRpcResponse {
	if value !is map[string]json2.Any {
		return error('Invalid JSON-RPC response: expected object')
	}

	obj := value.as_map()

	jsonrpc := obj['jsonrpc'] or {
		return error('Invalid JSON-RPC response: missing jsonrpc field')
	}
	if jsonrpc.str() != '2.0' {
		return error('Invalid JSON-RPC response: wrong version')
	}

	id := obj['id'] or { return error('Invalid JSON-RPC response: missing id field') }

	// Check for error
	if 'error' in obj {
		err_val := obj['error'] or { return error('Missing error value') }
		err := parse_jsonrpc_error(err_val)!
		return JsonRpcResponse{
			jsonrpc: '2.0'
			id:      id
			error:   err
		}
	}

	// Check for result
	result := obj['result'] or {
		return error('Invalid JSON-RPC response: missing result or error')
	}

	return JsonRpcResponse{
		jsonrpc: '2.0'
		id:      id
		result:  result
	}
}

// parse_jsonrpc_error parses a JSON-RPC error object
fn parse_jsonrpc_error(value json2.Any) !JsonRpcError {
	if value !is map[string]json2.Any {
		return error('Invalid JSON-RPC error: expected object')
	}

	obj := value.as_map()

	code := obj['code'] or { return error('Invalid JSON-RPC error: missing code field') }

	message := obj['message'] or { return error('Invalid JSON-RPC error: missing message field') }

	data := if data_val := obj['data'] { data_val } else { none }

	return JsonRpcError{
		code:    code.int()
		message: message.str()
		data:    data
	}
}

// =============================================================================
// JSON-RPC Response Building
// =============================================================================

// build_response creates a successful JSON-RPC response
pub fn build_response(id json2.Any, result json2.Any) JsonRpcResponse {
	return JsonRpcResponse{
		jsonrpc: '2.0'
		id:      id
		result:  result
	}
}

// build_error_response creates an error JSON-RPC response
pub fn build_error_response(id json2.Any, code int, message string) JsonRpcResponse {
	return JsonRpcResponse{
		jsonrpc: '2.0'
		id:      id
		error:   JsonRpcError{
			code:    code
			message: message
		}
	}
}

// build_error_response_with_data creates an error JSON-RPC response with data
pub fn build_error_response_with_data(id json2.Any, code int, message string, data json2.Any) JsonRpcResponse {
	return JsonRpcResponse{
		jsonrpc: '2.0'
		id:      id
		error:   JsonRpcError{
			code:    code
			message: message
			data:    data
		}
	}
}

// =============================================================================
// JSON-RPC Notification Building
// =============================================================================

// build_notification creates a JSON-RPC notification
pub fn build_notification(method string, params ?json2.Any) JsonRpcNotification {
	return JsonRpcNotification{
		jsonrpc: '2.0'
		method:  method
		params:  params
	}
}

// =============================================================================
// JSON Serialization
// =============================================================================

// request_to_json serializes a JsonRpcRequest to JSON string
pub fn request_to_json(req JsonRpcRequest) !string {
	mut obj := map[string]json2.Any{}
	obj['jsonrpc'] = '2.0'
	obj['id'] = req.id
	obj['method'] = req.method
	if req.params != none {
		obj['params'] = req.params
	}
	return json2.encode(obj, json2.EncoderOptions{})
}

// response_to_json serializes a JsonRpcResponse to JSON string
pub fn response_to_json(resp JsonRpcResponse) !string {
	mut obj := map[string]json2.Any{}
	obj['jsonrpc'] = '2.0'
	obj['id'] = resp.id
	if err := resp.error {
		mut err_obj := map[string]json2.Any{}
		err_obj['code'] = err.code
		err_obj['message'] = err.message
		if data := err.data {
			err_obj['data'] = data
		}
		obj['error'] = err_obj
	} else if result := resp.result {
		obj['result'] = result
	}
	return json2.encode(obj, json2.EncoderOptions{})
}

// notification_to_json serializes a JsonRpcNotification to JSON string
pub fn notification_to_json(n JsonRpcNotification) !string {
	mut obj := map[string]json2.Any{}
	obj['jsonrpc'] = '2.0'
	obj['method'] = n.method
	if n.params != none {
		obj['params'] = n.params
	}
	return json2.encode(obj, json2.EncoderOptions{})
}

// =============================================================================
// JSON Parsing
// =============================================================================

// parse_jsonrpc_message parses a raw JSON string into a protocol message
pub fn parse_jsonrpc_message(raw string) !JsonRpcMessage {
	value := json2.decode[json2.Any](raw, json2.DecoderOptions{})!
	obj := value.as_map()

	// Determine message type based on fields
	if 'id' in obj && 'method' in obj {
		// Request
		return parse_request(value)!
	} else if 'id' in obj && 'method' !in obj {
		// Response
		return parse_response(value)!
	} else if 'id' !in obj && 'method' in obj {
		// Notification
		return parse_notification(value)!
	}

	return error('Invalid JSON-RPC message: missing required fields')
}

// parse_notification parses a JSON-RPC notification
fn parse_notification(value json2.Any) !JsonRpcNotification {
	if value !is map[string]json2.Any {
		return error('Invalid JSON-RPC notification: expected object')
	}

	obj := value.as_map()

	jsonrpc := obj['jsonrpc'] or {
		return error('Invalid JSON-RPC notification: missing jsonrpc field')
	}
	if jsonrpc.str() != '2.0' {
		return error('Invalid JSON-RPC notification: wrong version')
	}

	method := obj['method'] or {
		return error('Invalid JSON-RPC notification: missing method field')
	}

	params := if params_val := obj['params'] { params_val } else { none }

	return JsonRpcNotification{
		jsonrpc: '2.0'
		method:  method.str()
		params:  params
	}
}
