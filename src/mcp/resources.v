module mcp

import json

// =============================================================================
// Resources Extension
// =============================================================================

// ResourceHandler is called to handle resource read requests
pub type ResourceHandler = fn (uri string) !ReadResourceResult

// ResourceSubscriptionHandler is called to handle resource subscriptions
pub type ResourceSubscriptionHandler = fn (uri string) !

// Resource represents a resource
pub struct Resource {
	uri         string
	name        string
	description string
	mime_type   string
}

// ResourceContent represents the content of a resource
pub struct ResourceContent {
	uri       string
	mime_type string
	content   string
}

// ReadResourceResult is the result of reading a resource
pub struct ReadResourceResult {
	contents []ResourceContent
}

// ListResourcesResult is the result of listing resources
pub struct ListResourcesResult {
	resources []Resource
}

// =============================================================================
// Default Resource Handlers
// =============================================================================

// default_resource_handler provides a default resource handler
fn default_resource_handler(uri string) !ReadResourceResult {
	return ReadResourceResult{
		contents: []
	}
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
