module mcp

import x.json2

// =============================================================================
// Resources Extension
// =============================================================================

// ResourceHandler is called to handle resource read requests
pub type ResourceHandler = fn (uri string) !json2.Any

// ResourceSubscriptionHandler is called to handle resource subscriptions
pub type ResourceSubscriptionHandler = fn (uri string) !

// =============================================================================
// Default Resource Handlers
// =============================================================================

// default_resource_handler provides a default resource handler
fn default_resource_handler(uri string) !json2.Any {
	mut obj := map[string]json2.Any{}
	obj['contents'] = []json2.Any{}
	return obj
}

// =============================================================================
// Resource Utilities
// =============================================================================

// is_valid_resource_uri checks if a URI is a valid resource URI
pub fn is_valid_resource_uri(uri string) bool {
	return uri.starts_with('resource://') || uri.starts_with('file://') || uri.starts_with('data:')
}

// parse_resource_uri parses a resource URI
pub fn parse_resource_uri(uri string) !string {
	if uri.starts_with('resource://') {
		return uri['resource://'.len..]
	}
	if uri.starts_with('file://') {
		return uri['file://'.len..]
	}
	if uri.starts_with('data:') {
		return error('data: URIs not supported')
	}
	return uri
}
