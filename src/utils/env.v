module utils

import os

// =============================================================================
// Environment Variables
// =============================================================================

const env_minimax_api_key = 'MINIMAX_API_KEY'
const env_minimax_api_host = 'MINIMAX_API_HOST'
const env_minimax_mcp_base_path = 'MINIMAX_MCP_BASE_PATH'
const env_resource_mode = 'MINIMAX_API_RESOURCE_MODE'
const env_mcp_port = 'MINIMAX_MCP_PORT'
const env_mcp_mode = 'MINIMAX_MCP_MODE'

const resource_mode_url = 'url'
const resource_mode_local = 'local'

const mode_stdio = 'stdio'
const mode_sse = 'sse'

const default_api_host = 'https://api.minimaxi.com'
const default_port = 33000

// =============================================================================
// Config
// =============================================================================

pub struct Config {
pub:
	api_key       string
	host          string
	base_path     string
	resource_mode string
	port          int
	mode          string
}

// load_config loads configuration from environment variables
pub fn load_config() !Config {
	api_key := os.getenv(env_minimax_api_key)
	if api_key.len == 0 {
		return error('${env_minimax_api_key} environment variable is required')
	}

	mut host := os.getenv(env_minimax_api_host)
	if host.len == 0 {
		host = default_api_host
	}

	mut base_path := os.getenv(env_minimax_mcp_base_path)
	if base_path.len == 0 {
		base_path = os.home_dir() + '/Desktop'
	}

	mut resource_mode := os.getenv(env_resource_mode)
	if resource_mode.len == 0 {
		resource_mode = resource_mode_url
	}

	port_str := os.getenv(env_mcp_port)
	port := if port_str.len > 0 {
		port_str.int()
	} else {
		default_port
	}

	mut mode := os.getenv(env_mcp_mode)
	if mode.len == 0 {
		mode = mode_stdio
	}

	return Config{
		api_key:       api_key
		host:          host
		base_path:     base_path
		resource_mode: resource_mode
		port:          port
		mode:          mode
	}
}

// =============================================================================
// File Utilities
// =============================================================================

// build_output_path builds the output path for a file
pub fn build_output_path(base_path string, filename string) string {
	return base_path + '/' + filename
}

// file_exists checks if a file exists
pub fn file_exists(path string) bool {
	return os.exists(path)
}

// ensure_dir ensures a directory exists
pub fn ensure_dir(path string) ! {
	if !os.exists(path) {
		os.mkdir_all(path)!
	}
}
