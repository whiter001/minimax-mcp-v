module protocol

import x.json2

// =============================================================================
// JSON-RPC 2.0 Base Types
// =============================================================================

pub struct JsonRpcRequest {
pub:
	jsonrpc string = '2.0'
	id      json2.Any
	method  string
	params  ?json2.Any
}

pub struct JsonRpcResponse {
pub:
	jsonrpc string = '2.0'
	id      json2.Any
	result  ?json2.Any
	error   ?JsonRpcError
}

pub struct JsonRpcNotification {
pub:
	jsonrpc string = '2.0'
	method  string
	params  ?json2.Any
}

pub struct JsonRpcError {
pub:
	code    int
	message string
	data    ?json2.Any
}

// JSON-RPC Error Codes
pub const jsonrpc_parse_error = -32700
pub const jsonrpc_invalid_request = -32600
pub const jsonrpc_method_not_found = -32601
pub const jsonrpc_invalid_params = -32602
pub const jsonrpc_internal_error = -32603

// MCP Error Codes (extends JSON-RPC)
pub const mcp_error_internal_error = -32603
pub const mcp_error_invalid_params = -32602
pub const mcp_error_method_not_found = -32601
pub const mcp_error_connection_closed = -32099
pub const mcp_error_protocol_error = -32098
pub const mcp_error_unsupported_protocol = -32097

// =============================================================================
// Protocol Version
// =============================================================================

pub const protocol_version = '2024-11-05'

pub type JsonRpcMessage = JsonRpcRequest | JsonRpcResponse | JsonRpcNotification
pub type JsonRpcResponseOrNotification = JsonRpcResponse | JsonRpcNotification

// =============================================================================
// Implementation Info
// =============================================================================

pub struct Implementation {
	name    string
	version string
}

// =============================================================================
// Server Capabilities
// =============================================================================

pub struct ServerCapabilities {
	tools     ?ToolsCapability
	resources ?ResourcesCapability
	sampling  ?SamplingCapability
	roots     ?RootsCapability
}

pub struct ToolsCapability {
	// tools can be listed
}

pub struct ResourcesCapability {
	// resources can be listed
	subscribe bool
}

pub struct SamplingCapability {
	// sampling is supported
}

pub struct RootsCapability {
	// roots can be listed
	list bool
}

// =============================================================================
// Client Capabilities
// =============================================================================

pub struct ClientCapabilities {
	tools     ?ClientToolsCapability
	resources ?ClientResourcesCapability
	sampling  ?ClientSamplingCapability
	roots     ?ClientRootsCapability
}

pub struct ClientToolsCapability {
	// tools can be listed
}

pub struct ClientResourcesCapability {
	subscribe bool
}

pub struct ClientSamplingCapability {
	// sampling is supported
}

pub struct ClientRootsCapability {
	list bool
}

// =============================================================================
// Initialize
// =============================================================================

@[params]
pub struct InitializeRequest {
pub:
	protocol_version string
	capabilities     ClientCapabilities
	client_info      Implementation
	root             ?string
}

@[params]
pub struct InitializeResult {
pub:
	protocol_version string
	capabilities     ServerCapabilities
	server_info      Implementation
	instructions     ?string
}

// =============================================================================
// Notifications
// =============================================================================

pub struct InitializedNotification {
	// No params
}

pub struct PingRequest {
	// No params
}

pub struct ProgressNotification {
	progress_token string
	progress       int
	total          ?int
}

pub struct CancelledNotification {
	request_id int
	reason     ?string
}

// =============================================================================
// Server State
// =============================================================================

pub enum ServerState {
	not_initialized
	initialized
}
