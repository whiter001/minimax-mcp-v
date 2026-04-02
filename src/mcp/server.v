module mcp

import x.json2
import protocol as proto
import transport

// =============================================================================
// MCP Server
// =============================================================================

pub struct McpServer {
mut:
	state            proto.ServerState
	transport        transport.StdioTransport
	capabilities     proto.ServerCapabilities
	server_info      proto.Implementation
	tools            []Tool
	resource_handler ?ResourceHandler
	sampling_handler ?SamplingHandler
	roots_handler    ?RootsHandler
}

pub struct Tool {
pub:
	name         string
	description  string
	input_schema json2.Any
	handler      ToolHandler
}

pub type ToolHandler = fn (name string, arguments ?json2.Any) !CallToolResult

pub struct CallToolResult {
pub:
	content  []Content
	is_error bool
}

pub struct Content {
pub:
	@type     string
	text      ?string
	data      ?string
	mime_type ?string
}

pub fn new_server() McpServer {
	return McpServer{
		state:        .not_initialized
		transport:    transport.new_stdio_transport()
		capabilities: proto.default_server_capabilities()
		server_info:  proto.default_server_info()
		tools:        []
	}
}

pub fn (mut s McpServer) register_tool(tool Tool) {
	s.tools << tool
}

pub fn (mut s McpServer) set_resource_handler(handler ResourceHandler) {
	s.resource_handler = handler
}

pub fn (mut s McpServer) set_sampling_handler(handler SamplingHandler) {
	s.sampling_handler = handler
}

pub fn (mut s McpServer) set_roots_handler(handler RootsHandler) {
	s.roots_handler = handler
}

pub fn (mut s McpServer) handle_message(raw_msg string) !proto.JsonRpcResponseOrNotification {
	msg := proto.parse_jsonrpc_message(raw_msg)!
	if msg is proto.JsonRpcRequest {
		resp := s.handle_request(msg)!
		return resp
	}
	if msg is proto.JsonRpcNotification {
		s.handle_notification(msg)
		return msg
	}
	return error('Server received unexpected response')
}

fn (mut s McpServer) handle_request(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	return match req.method {
		'initialize' {
			s.handle_initialize(req)
		}
		'tools/list' {
			s.handle_list_tools(req)
		}
		'tools/call' {
			s.handle_call_tool(req)
		}
		'resources/list' {
			s.handle_list_resources(req)
		}
		'resources/read' {
			s.handle_read_resource(req)
		}
		'resources/subscribe' {
			s.handle_subscribe_resource(req)
		}
		'resources/unsubscribe' {
			s.handle_unsubscribe_resource(req)
		}
		'sampling/createMessage' {
			s.handle_create_message(req)
		}
		'roots/list' {
			s.handle_list_roots(req)
		}
		'ping' {
			s.handle_ping(req)
		}
		else {
			proto.build_error_response(req.id, proto.jsonrpc_method_not_found, 'Method not found: ${req.method}')
		}
	}
}

fn (mut s McpServer) handle_notification(notif proto.JsonRpcNotification) {
	match notif.method {
		'initialized' { s.state = .initialized }
		'notifications/cancelled', 'notifications/progress' {}
		else {}
	}
}

fn (mut s McpServer) handle_initialize(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	mut client_caps := proto.ClientCapabilities{}
	if params := req.params {
		obj := params.as_map()
		if caps_val := obj['capabilities'] {
			client_caps = parse_client_capabilities(caps_val)!
		}
	}

	result := proto.build_initialize_result(proto.Implementation{}, client_caps)
	s.state = .initialized

	mut resp := map[string]json2.Any{}
	resp['protocol_version'] = result.protocol_version
	resp['capabilities'] = result.capabilities.to_json()
	resp['server_info'] = result.server_info.to_json()
	if instr := result.instructions {
		resp['instructions'] = instr
	}
	return proto.build_response(req.id, resp)
}

fn parse_client_capabilities(value json2.Any) !proto.ClientCapabilities {
	return proto.ClientCapabilities{}
}

fn (s &McpServer) handle_list_tools(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	mut tools := []json2.Any{}
	for t in s.tools {
		mut tool_obj := map[string]json2.Any{}
		tool_obj['name'] = t.name
		tool_obj['description'] = t.description
		tool_obj['input_schema'] = t.input_schema
		tools << tool_obj
	}

	mut resp := map[string]json2.Any{}
	resp['tools'] = tools
	return proto.build_response(req.id, resp)
}

fn (s &McpServer) handle_call_tool(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	params := req.params or {
		return proto.build_error_response(req.id, proto.jsonrpc_invalid_params, 'Missing parameters for tools/call')
	}

	obj := params.as_map()

	name_val := obj['name'] or {
		return proto.build_error_response(req.id, proto.jsonrpc_invalid_params, 'Missing tool name')
	}
	tool_name := name_val.str()
	arguments := obj['arguments']

	mut tool := Tool{}
	mut found := false
	for candidate in s.tools {
		if candidate.name == tool_name {
			tool = candidate
			found = true
			break
		}
	}
	if !found {
		return proto.build_error_response(req.id, proto.jsonrpc_method_not_found, 'Tool not found: ${tool_name}')
	}

	result := tool.handler(tool_name, arguments) or {
		return proto.build_error_response(req.id, proto.mcp_error_internal_error, err.msg())
	}

	mut content_arr := []json2.Any{}
	for c in result.content {
		mut content_obj := map[string]json2.Any{}
		content_obj['type'] = c.@type
		if text := c.text {
			content_obj['text'] = text
		}
		if data := c.data {
			content_obj['data'] = data
		}
		if mime := c.mime_type {
			content_obj['mimeType'] = mime
		}
		content_arr << content_obj
	}

	mut resp_obj := map[string]json2.Any{}
	resp_obj['content'] = content_arr
	resp_obj['isError'] = result.is_error
	return proto.build_response(req.id, resp_obj)
}

fn (s &McpServer) handle_list_resources(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	mut resp := map[string]json2.Any{}
	resp['resources'] = []json2.Any{}
	return proto.build_response(req.id, resp)
}

fn (s &McpServer) handle_read_resource(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	params := req.params or {
		return proto.build_error_response(req.id, proto.jsonrpc_invalid_params, 'Missing parameters for resources/read')
	}

	obj := params.as_map()

	uri_val := obj['uri'] or {
		return proto.build_error_response(req.id, proto.jsonrpc_invalid_params, 'Missing resource URI')
	}
	handler := s.resource_handler or {
		return proto.build_error_response(req.id, proto.mcp_error_internal_error, 'Resource handler not set')
	}

	result := handler(uri_val.str()) or {
		return proto.build_error_response(req.id, proto.mcp_error_internal_error, err.msg())
	}
	return proto.build_response(req.id, result)
}

fn (s &McpServer) handle_subscribe_resource(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	return proto.build_response(req.id, map[string]json2.Any{})
}

fn (s &McpServer) handle_unsubscribe_resource(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	return proto.build_response(req.id, map[string]json2.Any{})
}

fn (s &McpServer) handle_create_message(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	if s.sampling_handler == none {
		return proto.build_error_response(req.id, proto.mcp_error_internal_error, 'Sampling not implemented')
	}
	return proto.build_error_response(req.id, proto.mcp_error_internal_error, 'Sampling not implemented')
}

fn (s &McpServer) handle_list_roots(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	handler := s.roots_handler or {
		return proto.build_error_response(req.id, proto.mcp_error_internal_error, 'Roots handler not set')
	}

	result := handler() or {
		return proto.build_error_response(req.id, proto.mcp_error_internal_error, err.msg())
	}
	return proto.build_response(req.id, result)
}

fn (s &McpServer) handle_ping(req proto.JsonRpcRequest) !proto.JsonRpcResponse {
	return proto.build_response(req.id, map[string]json2.Any{})
}

pub fn (mut s McpServer) start() {
	mut tr := transport.new_stdio_transport()
	handler := fn [mut s, mut tr] (msg string) {
		result := s.handle_message(msg) or { return }
		match result {
			proto.JsonRpcResponse { tr.send(result) or { return } }
			proto.JsonRpcNotification {}
		}
	}
	tr.start(handler)
}
