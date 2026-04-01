module transport

import os
import io
import protocol

// =============================================================================
// Stdio Transport
// =============================================================================

// StdioTransport implements the MCP transport using stdio
// This is used for local communication with MCP clients like Claude Desktop
pub struct StdioTransport {
mut:
	reader io.BufferedReader
	writer io.BufferedWriter
}

// StdioTransportMessageHandler is called when a message is received
pub type StdioTransportMessageHandler = fn (msg string)

// new_stdio_transport creates a new stdio transport
pub fn new_stdio_transport() StdioTransport {
	return StdioTransport{
		reader: io.new_buffered_reader(reader: os.stdin())
		writer: io.new_buffered_writer(writer: os.stdout()) or { panic(err) }
	}
}

// start starts the stdio transport and processes messages
// This function blocks until the transport is closed
pub fn (mut t StdioTransport) start(handler StdioTransportMessageHandler) {
	for {
		line := t.reader.read_line() or {
			// EOF or error - exit gracefully
			break
		}

		if line.trim_space().len == 0 {
			continue
		}

		handler(line)
	}
}

// send sends a JSON-RPC message to stdout
pub fn (mut t StdioTransport) send(resp protocol.JsonRpcResponse) ! {
	raw := protocol.response_to_json(resp)!
	// Add newline for JSON Lines format
	t.writer.write(raw.bytes())!
	t.writer.write('\n'.bytes())!
	t.writer.flush()!
}

// send_notification sends a JSON-RPC notification to stdout
pub fn (mut t StdioTransport) send_notification(notification protocol.JsonRpcNotification) ! {
	raw := protocol.notification_to_json(notification)!
	// Add newline for JSON Lines format
	t.writer.write(raw.bytes())!
	t.writer.write('\n'.bytes())!
	t.writer.flush()!
}

// =============================================================================
// Stdio Transport Configuration
// =============================================================================

// StdioTransportConfig holds configuration for the stdio transport
pub struct StdioTransportConfig {
	// Whether to enable verbose logging
	verbose bool
}

// =============================================================================
// Line-based JSON Reading
// =============================================================================

// read_json_message reads a JSON message from a channel of strings
// This is used with the stdio transport to process incoming messages
pub fn read_json_message(line string) !protocol.JsonRpcMessage {
	return protocol.parse_jsonrpc_message(line)
}
