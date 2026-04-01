module mcp

// =============================================================================
// Roots Extension
// =============================================================================

// RootsHandler handles roots listing requests
pub type RootsHandler = fn () !ListRootsResult

// Root represents a root directory
pub struct Root {
	uri  string
	name string
}

// ListRootsResult is the result of listing roots
pub struct ListRootsResult {
	roots []Root
}

// =============================================================================
// Default Roots Handler
// =============================================================================

// default_roots_handler provides a default roots handler
fn default_roots_handler() !ListRootsResult {
	return ListRootsResult{
		roots: []
	}
}
