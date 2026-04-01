module main

import src.utils
import src.mcp
import src.minimax

// =============================================================================
// MiniMax MCP Server
// =============================================================================

struct MinimaxMcpServer {
mut:
	server mcp.McpServer
}

fn new_minimax_server(config utils.Config) MinimaxMcpServer {
	// Initialize the MiniMax API client
	minimax.init_client(config.api_key, config.host)

	// Create MCP server
	mut server := mcp.new_server()

	// Register tools
	tools := minimax.tool_definitions()
	for tool in tools {
		server.register_tool(tool)
	}

	return MinimaxMcpServer{
		server: server
	}
}

// =============================================================================
// Main Entry Point
// =============================================================================

fn main() {
	println('Starting MiniMax MCP server...')

	// Load configuration
	config := utils.load_config() or {
		eprintln('Failed to load config: ${err}')
		return
	}

	println('Config loaded:')
	println('  API Host: ${config.host}')
	println('  Mode: ${config.mode}')
	println('  Port: ${config.port}')

	// Create server
	mut server := new_minimax_server(config)

	// Start server based on mode
	match config.mode {
		'stdio' {
			println('Starting in stdio mode...')
			server.server.start()
		}
		'sse' {
			println('Starting in SSE mode on port ${config.port}...')
			// TODO: Implement SSE transport
			eprintln('SSE mode not yet implemented')
		}
		else {
			eprintln('Unknown mode: ${config.mode}')
			return
		}
	}
}
