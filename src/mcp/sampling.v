module mcp

import json

// =============================================================================
// Sampling Extension
// =============================================================================

// SamplingHandler handles sampling requests
// This allows the server to request the client to sample an LLM
pub type SamplingHandler = fn (method string, arguments ?json.Value, max_tokens int) !CreateMessageResult

// CreateMessageResult is the result of creating a sampling message
pub struct CreateMessageResult {
	content               []Content
	has_consumer_applied   bool
}

// =============================================================================
// Sampling Message
// =============================================================================

// SamplingMessage represents a message in a sampling request
pub struct SamplingMessage {
	role     string
	content  string
}

// =============================================================================
// Default Sampling Handler
// =============================================================================

// default_sampling_handler provides a default sampling handler
fn default_sampling_handler(method string, arguments ?json.Value, max_tokens int) !CreateMessageResult {
	return CreateMessageResult{
		content: []
		has_consumer_applied: false
	}
}

// =============================================================================
// Sampling Utilities
// =============================================================================

// is_valid_sampling_method checks if a sampling method is valid
pub fn is_valid_sampling_method(method string) bool {
	return method == 'createMessage'
}
