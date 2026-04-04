module protocol

import x.json2

// =============================================================================
// Default Server Capabilities
// =============================================================================

// default_server_capabilities returns the default server capabilities for MiniMax MCP
pub fn default_server_capabilities() ServerCapabilities {
	return ServerCapabilities{
		tools:     ToolsCapability{}
		resources: none
		sampling:  none
		roots:     none
	}
}

pub fn enable_resources(capabilities ServerCapabilities) ServerCapabilities {
	return ServerCapabilities{
		tools:     capabilities.tools
		resources: ResourcesCapability{
			subscribe: true
		}
		sampling:  capabilities.sampling
		roots:     capabilities.roots
	}
}

pub fn enable_sampling(capabilities ServerCapabilities) ServerCapabilities {
	return ServerCapabilities{
		tools:     capabilities.tools
		resources: capabilities.resources
		sampling:  SamplingCapability{}
		roots:     capabilities.roots
	}
}

pub fn enable_roots(capabilities ServerCapabilities) ServerCapabilities {
	return ServerCapabilities{
		tools:     capabilities.tools
		resources: capabilities.resources
		sampling:  capabilities.sampling
		roots:     RootsCapability{
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
		name:    server_name
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
	res := c.resources or { return false }
	return res.subscribe
}

// has_roots_list returns true if the server supports listing roots
pub fn (c ServerCapabilities) has_roots_list() bool {
	if c.roots == none {
		return false
	}
	res := c.roots or { return false }
	return res.list
}

// =============================================================================
// JSON Serialization for Capabilities
// =============================================================================

// capabilities_to_json serializes server capabilities to JSON value
pub fn (c ServerCapabilities) to_json() json2.Any {
	mut obj := map[string]json2.Any{}

	if c.tools != none {
		obj['tools'] = map[string]json2.Any{}
	}

	if res := c.resources {
		mut res_obj := map[string]json2.Any{}
		res_obj['subscribe'] = res.subscribe
		obj['resources'] = res_obj
	}

	if c.sampling != none {
		obj['sampling'] = true
	}

	if roots := c.roots {
		mut roots_obj := map[string]json2.Any{}
		roots_obj['list'] = roots.list
		obj['roots'] = roots_obj
	}

	return obj
}

// implementation_to_json serializes an implementation to JSON value
pub fn (i Implementation) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	obj['name'] = i.name
	obj['version'] = i.version
	return obj
}

// =============================================================================
// Initialize Result Building
// =============================================================================

// build_initialize_result creates the initialize result
pub fn build_initialize_result(client_info Implementation, client_caps ClientCapabilities) InitializeResult {
	return InitializeResult{
		protocol_version: protocol_version
		capabilities:     default_server_capabilities()
		server_info:      default_server_info()
		instructions:     none
	}
}
