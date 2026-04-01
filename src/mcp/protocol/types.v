module protocol

import json

// =============================================================================
// JSON-RPC 2.0 Base Types
// =============================================================================

pub struct JsonRpcRequest {
	jsonrpc string = '2.0'
	id      int
	method  string
	params  ?json.Value
}

pub struct JsonRpcResponse {
	jsonrpc string = '2.0'
	id      int
	result  ?json.Value
	error   ?JsonRpcError
}

pub struct JsonRpcNotification {
	jsonrpc string = '2.0'
	method  string
	params  ?json.Value
}

pub struct JsonRpcError {
	code    int
	message string
	data    ?json.Value
}

// JSON-RPC Error Codes
pub const (
	jsonrpc_parse_error     = -32700
	jsonrpc_invalid_request = -32600
	jsonrpc_method_not_found = -32601
	jsonrpc_invalid_params  = -32602
	jsonrpc_internal_error  = -32603
)

// MCP Error Codes (extends JSON-RPC)
pub const (
	mcp_error_internal_error         = -32603
	mcp_error_invalid_params         = -32602
	mcp_error_method_not_found       = -32601
	mcp_error_connection_closed      = -32099
	mcp_error_protocol_error         = -32098
	mcp_error_unsupported_protocol   = -32097
)

// =============================================================================
// Protocol Version
// =============================================================================

pub const protocol_version = '2024-11-05'

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
	tools        ?ToolsCapability
	resources    ?ResourcesCapability
	sampling     ?SamplingCapability
	roots        ?RootsCapability
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
	tools      ?ClientToolsCapability
	resources  ?ClientResourcesCapability
	sampling   ?ClientSamplingCapability
	roots      ?ClientRootsCapability
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

[params]
pub struct InitializeRequest {
	protocol_version    string
	capabilities        ClientCapabilities
	client_info         Implementation
	root               ?string
}

[params]
pub struct InitializeResult {
	protocol_version    string
	capabilities        ServerCapabilities
	server_info         Implementation
	instructions        ?string
}

// =============================================================================
// Tools
// =============================================================================

pub struct Tool {
	name        string
	description string
	input_schema json.Value
}

pub struct CallToolRequest {
	name   string
	arguments ?json.Value
}

pub struct CallToolResult {
	content []Content
	is_error bool
}

pub struct Content {
	@type string
	text   ?string
	data   ?string
	mime_type ?string
}

pub struct ListToolsResult {
	tools []Tool
}

// =============================================================================
// Resources
// =============================================================================

pub struct Resource {
	uri         string
	name        string
	description ?string
	mime_type   ?string
}

pub struct ResourceContents {
	uri       string
	mime_type ?string
	content   string
}

pub struct ReadResourceRequest {
	uri string
}

pub struct ReadResourceResult {
	contents []ResourceContents
}

pub struct ListResourcesRequest {
	uri ?string
}

pub struct ListResourcesResult {
	resources []Resource
}

pub struct SubscribeRequest {
	uri string
}

pub struct UnsubscribeRequest {
	uri string
}

// =============================================================================
// Sampling
// =============================================================================

pub struct CreateMessageRequest {
	method      string
	arguments   ?json.Value
	max_tokens  int
}

pub struct CreateMessageResult {
	content []Content
	has_consumer_applied bool
}

// =============================================================================
// Roots
// =============================================================================

pub struct ListRootsRequest {
	// No params
}

pub struct ListRootsResult {
	roots []Root
}

pub struct Root {
	uri  string
	name string
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
