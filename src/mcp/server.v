module mcp

import json
import protocol
import protocol as proto
import transport

// =============================================================================
// MCP Server
// =============================================================================

// McpServer is the main MCP server implementation
pub struct McpServer {
mut:
	state             proto.ServerState
	transport         transport.StdioTransport
	capabilities      proto.ServerCapabilities
	server_info       proto.Implementation
	tools             []Tool
	resource_handler  ?ResourceHandler
	sampling_handler  ?SamplingHandler
	roots_handler     ?RootsHandler
}

// Tool represents an MCP tool
pub struct Tool {
	name        string
	description string
	input_schema json.Value
	handler     ToolHandler
}

// ToolHandler is the function type for tool handlers
pub type ToolHandler = fn (name string, arguments ?json.Value) !CallToolResult

// ResourceHandler handles resource operations
pub type ResourceHandler = fn (uri string) !ReadResourceResult

// SamplingHandler handles sampling operations
pub type SamplingHandler = fn (method string, arguments ?json.Value, max_tokens int) !CreateMessageResult

// RootsHandler handles roots listing
pub type RootsHandler = fn () !ListRootsResult

// CallToolResult represents the result of a tool call
pub struct CallToolResult {
pub:
	content []Content
	is_error bool
}

// Content represents content in a tool result
pub struct Content {
	@type string
	text   ?string
	data   ?string
	mime_type ?string
}

// ReadResourceResult represents the result of reading a resource
pub struct ReadResourceResult {
pub:
	contents []ResourceContent
}

// ResourceContent represents a resource content
pub struct ResourceContent {
	uri       string
	mime_type ?string
	content   string
}

// CreateMessageResult represents the result of creating a sampling message
pub struct CreateMessageResult {
pub:
	content []Content
	has_consumer_applied bool
}

// ListRootsResult represents the result of listing roots
pub struct ListRootsResult {
pub:
	roots []Root
}

// Root represents a root directory
pub struct Root {
	uri  string
	name string
}

// new_server creates a new MCP server
pub fn new_server() McpServer {
	return McpServer{
		state: .not_initialized
		transport: transport.new_stdio_transport()
		capabilities: proto.default_server_capabilities()
		server_info: proto.default_server_info()
		tools: []
	}
}

// register_tool registers a tool with the server
pub fn (s &McpServer) register_tool(tool Tool) {
	s.tools << tool
}

// set_resource_handler sets the resource handler
pub fn (s &McpServer) set_resource_handler(handler ResourceHandler) {
	s.resource_handler = handler
}

// set_sampling_handler sets the sampling handler
pub fn (s &McpServer) set_sampling_handler(handler SamplingHandler) {
	s.sampling_handler = handler
}

// set_roots_handler sets the roots handler
pub fn (s &McpServer) set_roots_handler(handler RootsHandler) {
	s.roots_handler = handler
}

// =============================================================================
// Request Handling
// =============================================================================

// handle_message handles an incoming JSON-RPC message
pub fn (s &McpServer) handle_message(raw_msg string) !protocol.JsonRpcResponse | protocol.JsonRpcNotification {
	msg := protocol.parse_jsonrpc_message(raw_msg)!

	// Handle different message types
	match msg {
		protocol.JsonRpcRequest {
			return s.handle_request(msg)
		}
		protocol.JsonRpcNotification {
			s.handle_notification(msg)
			return none
		}
		protocol.JsonRpcResponse {
			// Server doesn't handle responses to requests it didn't send
			return error('Server received unexpected response')
		}
	}
}

fn (s &McpServer) handle_request(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	// Route request based on method
	match req.method {
		'initialize' {
			return s.handle_initialize(req)
		}
		'tools/list' {
			return s.handle_list_tools(req)
		}
		'tools/call' {
			return s.handle_call_tool(req)
		}
		'resources/list' {
			return s.handle_list_resources(req)
		}
		'resources/read' {
			return s.handle_read_resource(req)
		}
		'resources/subscribe' {
			return s.handle_subscribe_resource(req)
		}
		'resources/unsubscribe' {
			return s.handle_unsubscribe_resource(req)
		}
		'sampling/createMessage' {
			return s.handle_create_message(req)
		}
		'roots/list' {
			return s.handle_list_roots(req)
		}
		'ping' {
			return s.handle_ping(req)
		}
		else {
			return protocol.build_error_response(
				req.id,
				proto.jsonrpc_method_not_found,
				'Method not found: ${req.method}'
			)
		}
	}
}

fn (s &McpServer) handle_notification(notif protocol.JsonRpcNotification) {
	match notif.method {
		'initialized' {
			s.state = .initialized
		}
		'notifications/cancelled' {
			// Handle cancellation
		}
		'notifications/progress' {
			// Handle progress
		}
		else {
			// Unknown notification - ignore
		}
	}
}

// =============================================================================
// Initialize
// =============================================================================

fn (s &McpServer) handle_initialize(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	// Parse client capabilities
	mut client_caps := proto.ClientCapabilities{}

	if req.params != none {
		params := req.params?
		obj := params.as_map()
		if obj.contains('capabilities') {
			caps_val := obj['capabilities']
			// Parse client capabilities from JSON value
			client_caps = parse_client_capabilities(caps_val)!
		}
	}

	result := proto.build_initialize_result(proto.Implementation{}, client_caps)

	s.state = .initialized

	return protocol.build_response(req.id, json.Value(json.encode({
		protocol_version: result.protocol_version
		capabilities: result.capabilities
		server_info: result.server_info
		instructions: result.instructions or { '' }
	})))
}

fn parse_client_capabilities(value json.Value) !proto.ClientCapabilities {
	// Simplified - in production would parse full capabilities
	return proto.ClientCapabilities{}
}

// =============================================================================
// Tools
// =============================================================================

fn (s &McpServer) handle_list_tools(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	tools := s.tools.map(fn (t Tool) json.Value {
		return json.Value(json.encode({
			name: t.name
			description: t.description
			input_schema: t.input_schema
		}))
	})

	result := json.Value(json.encode({ tools: tools }))
	return protocol.build_response(req.id, result)
}

fn (s &McpServer) handle_call_tool(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	if req.params == none {
		return protocol.build_error_response(
			req.id,
			proto.jsonrpc_invalid_params,
			'Missing parameters for tools/call'
		)
	}

	params := req.params?
	obj := params.as_map()

	name := obj['name'] or {
		return protocol.build_error_response(
			req.id,
			proto.jsonrpc_invalid_params,
			'Missing tool name'
		)
	}

	arguments := obj['arguments']

	// Find the tool
	tool := s.tools.find(fn (t Tool) bool {
		return t.name == name.as_str()
	}) or {
		return protocol.build_error_response(
			req.id,
			proto.jsonrpc_method_not_found,
			'Tool not found: ${name.as_str()}'
		)
	}

	// Call the tool handler
	result := tool.handler(name.as_str(), arguments)!

	// Convert result to JSON
	content_arr := result.content.map(fn (c Content) json.Value {
		mut obj := map[string]json.Value{}
		obj['type'] = json.Value(json.string(c.@type))
		if c.text != none {
			obj['text'] = json.Value(json.string(c.text?))
		}
		if c.data != none {
			obj['data'] = json.Value(json.string(c.data?))
		}
		if c.mime_type != none {
			obj['mimeType'] = json.Value(json.string(c.mime_type?))
		}
		return json.Value(json.encode(obj))
	})

	response_obj := {
		content: content_arr
		isError: result.is_error
	}

	return protocol.build_response(req.id, json.Value(json.encode(response_obj)))
}

// =============================================================================
// Resources
// =============================================================================

fn (s &McpServer) handle_list_resources(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	// Return empty list - resources are optional
	result := json.Value(json.encode({ resources: []protocol.Resource{} }))
	return protocol.build_response(req.id, result)
}

fn (s &McpServer) handle_read_resource(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	if req.params == none {
		return protocol.build_error_response(
			req.id,
			proto.jsonrpc_invalid_params,
			'Missing parameters for resources/read'
		)
	}

	params := req.params?
	obj := params.as_map()

	uri := obj['uri'] or {
		return protocol.build_error_response(
			req.id,
			proto.jsonrpc_invalid_params,
			'Missing resource URI'
		)
	}

	if s.resource_handler == none {
		return protocol.build_error_response(
			req.id,
			proto.mcp_error_internal_error,
			'Resource handler not set'
		)
	}

	result := s.resource_handler!(uri.as_str())!

	response_json := json.Value(json.encode({
		contents: result.contents.map(fn (c ResourceContent) json.Value {
			mut obj := map[string]json.Value{}
			obj['uri'] = json.Value(json.string(c.uri))
			if c.mime_type != none {
				obj['mimeType'] = json.Value(json.string(c.mime_type?))
			}
			obj['content'] = json.Value(json.string(c.content))
			return json.Value(json.encode(obj))
		})
	}))

	return protocol.build_response(req.id, response_json)
}

fn (s &McpServer) handle_subscribe_resource(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	// Subscriptions are not implemented yet
	return protocol.build_response(req.id, json.Value(json.encode({})))
}

fn (s &McpServer) handle_unsubscribe_resource(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	// Subscriptions are not implemented yet
	return protocol.build_response(req.id, json.Value(json.encode({})))
}

// =============================================================================
// Sampling
// =============================================================================

fn (s &McpServer) handle_create_message(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	return protocol.build_error_response(
		req.id,
		proto.mcp_error_internal_error,
		'Sampling not implemented'
	)
}

// =============================================================================
// Roots
// =============================================================================

fn (s &McpServer) handle_list_roots(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	if s.roots_handler == none {
		return protocol.build_error_response(
			req.id,
			proto.mcp_error_internal_error,
			'Roots handler not set'
		)
	}

	result := s.roots_handler!()

	response_json := json.Value(json.encode({
		roots: result.roots.map(fn (r Root) json.Value {
			return json.Value(json.encode({
				uri: r.uri
				name: r.name
			}))
		})
	}))

	return protocol.build_response(req.id, response_json)
}

// =============================================================================
// Ping
// =============================================================================

fn (s &McpServer) handle_ping(req protocol.JsonRpcRequest) !protocol.JsonRpcResponse {
	return protocol.build_response(req.id, json.Value(json.encode({})))
}

// =============================================================================
// Start Server
// =============================================================================

// start starts the MCP server with stdio transport
pub fn (s &McpServer) start() {
	transport := transport.new_stdio_transport()

	handler := fn [s] (msg string) {
		result := s.handle_message(msg)
		if result != none {
			transport.send(result!)
		}
	}

	transport.start(handler)
}
