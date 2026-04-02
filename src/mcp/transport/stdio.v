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

const content_length_prefix = 'Content-Length:'

fn read_stdin_message(mut reader io.BufferedReader) !string {
	mut content_length := 0
	mut saw_content_length := false

	for {
		line := reader.read_line() or { return error('EOF') }
		trimmed := line.trim_space()

		if trimmed.len == 0 {
			if saw_content_length {
				break
			}
			continue
		}

		if trimmed.starts_with(content_length_prefix) {
			length_str := trimmed[content_length_prefix.len..].trim_space()
			content_length = length_str.int()
			saw_content_length = true
			continue
		}

		// Plain JSON-line mode: use the line directly.
		if !saw_content_length {
			return trimmed
		}
	}

	if saw_content_length {
		if content_length <= 0 {
			return error('Invalid Content-Length')
		}

		mut body := []u8{len: content_length}
		mut read := 0
		for read < content_length {
			n := reader.read(mut body[read..]) or { return error('EOF') }
			if n == 0 {
				return error('EOF')
			}
			read += n
		}
		return body.bytestr()
	}

	return error('EOF')
}

// new_stdio_transport creates a new stdio transport
pub fn new_stdio_transport() StdioTransport {
	return StdioTransport{
		reader: io.new_buffered_reader(reader: os.stdin())
		writer: io.new_buffered_writer(writer: os.stdout()) or { panic(err) }
	}
}

// start starts the stdio transport and processes messages
// This function blocks until the transport is closed
pub fn (mut t StdioTransport) start(handler StdioTransportMessageHandler) ! {
	for {
		// Use simple line-based reading that works with pipe redirection
		mut line := []u8{}
		mut got_newline := false
		for {
			mut buf := []u8{len: 1}
			n := os.stdin().read(mut buf) or {
				return // EOF or error
			}
			if n == 0 {
				return // EOF
			}
			if buf[0] == `\n` {
				got_newline = true
				break
			}
			if buf[0] != `\r` {
				line << buf[0]
			}
		}
		if !got_newline {
			continue
		}
		line_str := line.bytestr().trim_space()
		if line_str.len == 0 {
			continue
		}
		handler(line_str)
	}
}

// send sends a JSON-RPC message to stdout
pub fn (mut t StdioTransport) send(resp protocol.JsonRpcResponse) ! {
	raw := protocol.response_to_json(resp)!
	// Use JSON line format (newline-delimited) for compatibility with most MCP clients
	t.writer.write(raw.bytes())!
	t.writer.write([u8(10)])!
	t.writer.flush()!
}

// send_notification sends a JSON-RPC notification to stdout
pub fn (mut t StdioTransport) send_notification(notification protocol.JsonRpcNotification) ! {
	raw := protocol.notification_to_json(notification)!
	// Use JSON line format (newline-delimited) for compatibility with most MCP clients
	t.writer.write(raw.bytes())!
	t.writer.write([u8(10)])!
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

// read_json_message reads a JSON message from a single string payload
// This is used with the stdio transport to process incoming messages
pub fn read_json_message(line string) !protocol.JsonRpcMessage {
	return protocol.parse_jsonrpc_message(line)
}
