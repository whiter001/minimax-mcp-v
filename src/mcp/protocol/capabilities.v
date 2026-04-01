module protocol

import json

// =============================================================================
// Default Server Capabilities
// =============================================================================

// default_server_capabilities returns the default server capabilities for MiniMax MCP
pub fn default_server_capabilities() ServerCapabilities {
	return ServerCapabilities{
		tools: ToolsCapability{}
		resources: ResourcesCapability{
			subscribe: true
		}
		sampling: SamplingCapability{}
		roots: RootsCapability{
			list: true
		}
	}
}

// =============================================================================
// Server Info
// =============================================================================

pub const server_name = 'minimax-mcp'
pub const server_version = '0.0.1'

// default_server_info returns the default server info
pub fn default_server_info() Implementation {
	return Implementation{
		name: server_name
		version: server_version
	}
}

// =============================================================================
// Capability Checking
// =============================================================================

// has_tools returns true if the server has tools capability
pub fn (c ServerCapabilities) has_tools() bool {
	return c.tools != none
}

// has_resources returns true if the server has resources capability
pub fn (c ServerCapabilities) has_resources() bool {
	return c.resources != none
}

// has_sampling returns true if the server has sampling capability
pub fn (c ServerCapabilities) has_sampling() bool {
	return c.sampling != none
}

// has_roots returns true if the server has roots capability
pub fn (c ServerCapabilities) has_roots() bool {
	return c.roots != none
}

// has_resource_subscribe returns true if the server supports resource subscriptions
pub fn (c ServerCapabilities) has_resource_subscribe() bool {
	if c.resources == none {
		return false
	}
	return c.resources?.subscribe
}

// has_roots_list returns true if the server supports listing roots
pub fn (c ServerCapabilities) has_roots_list() bool {
	if c.roots == none {
		return false
	}
	return c.roots?.list
}

// =============================================================================
// JSON Serialization for Capabilities
// =============================================================================

// capabilities_to_json serializes server capabilities to JSON value
pub fn (c ServerCapabilities) to_json() json.Value {
	mut obj := map[string]json.Value{}

	if c.tools != none {
		obj['tools'] = json.Value(json.bool(true))
	}

	if c.resources != none {
		mut res_obj := map[string]json.Value{}
		res_obj['subscribe'] = json.Value(json.bool(c.resources?.subscribe))
		obj['resources'] = json.Value(json.encode(res_obj))
	}

	if c.sampling != none {
		obj['sampling'] = json.Value(json.bool(true))
	}

	if c.roots != none {
		mut roots_obj := map[string]json.Value{}
		roots_obj['list'] = json.Value(json.bool(c.roots?.list))
		obj['roots'] = json.Value(json.encode(roots_obj))
	}

	return json.Value(json.encode(obj))
}

// implementation_to_json serializes an implementation to JSON value
pub fn (i Implementation) to_json() json.Value {
	mut obj := map[string]json.Value{}
	obj['name'] = json.Value(json.string(i.name))
	obj['version'] = json.Value(json.string(i.version))
	return json.Value(json.encode(obj))
}

// =============================================================================
// Initialize Result Building
// =============================================================================

// build_initialize_result creates the initialize result
pub fn build_initialize_result(client_info Implementation, client_caps ClientCapabilities) InitializeResult {
	return InitializeResult{
		protocol_version: protocol_version
		capabilities: default_server_capabilities()
		server_info: default_server_info()
		instructions: none
	}
}
