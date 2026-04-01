module mcp

import x.json2

// =============================================================================
// Roots Extension
// =============================================================================

// RootsHandler handles roots listing requests
pub type RootsHandler = fn () !json2.Any

// =============================================================================
// Default Roots Handler
// =============================================================================

// default_roots_handler provides a default roots handler
fn default_roots_handler() !json2.Any {
	mut obj := map[string]json2.Any{}
	obj['roots'] = []json2.Any{}
	return obj
}
