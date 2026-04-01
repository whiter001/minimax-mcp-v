module mcp

import x.json2

// =============================================================================
// Sampling Extension
// =============================================================================

// SamplingHandler handles sampling requests
// This allows the server to request the client to sample an LLM
pub type SamplingHandler = fn (method string, arguments ?json2.Any, max_tokens int) !json2.Any

// =============================================================================
// Sampling Message
// =============================================================================

// =============================================================================
// Default Sampling Handler
// =============================================================================

// default_sampling_handler provides a default sampling handler
fn default_sampling_handler(method string, arguments ?json2.Any, max_tokens int) !json2.Any {
	return map[string]json2.Any{}
}

// =============================================================================
// Sampling Utilities
// =============================================================================

// is_valid_sampling_method checks if a sampling method is valid
pub fn is_valid_sampling_method(method string) bool {
	return method == 'createMessage'
}
