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
const stdin_fd = 0
const stdout_fd = 1

fn read_fd_line(fd int) !string {
	mut line := []u8{}
	for {
		chunk, n := os.fd_read(fd, 1)
		if n <= 0 {
			if line.len == 0 {
				return error('EOF')
			}
			return line.bytestr()
		}
		ch := chunk[0]
		if ch == `\n` {
			if line.len > 0 && line[line.len - 1] == `\r` {
				return line[..line.len - 1].bytestr()
			}
			return line.bytestr()
		}
		line << ch
	}
	return error('EOF')
}

fn read_exact_from_fd(fd int, size int) !string {
	mut result := []u8{cap: size}
	mut remaining := size
	for remaining > 0 {
		chunk, n := os.fd_read(fd, remaining)
		if n <= 0 {
			return error('EOF')
		}
		result << chunk.bytes()
		remaining -= n
	}
	return result.bytestr()
}

fn read_stdin_fd_message(fd int) !string {
	mut content_length := 0
	mut saw_content_length := false

	for {
		line := read_fd_line(fd) or { return error('EOF') }
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

		if !saw_content_length {
			return trimmed
		}
	}

	if content_length <= 0 {
		return error('Invalid Content-Length')
	}

	return read_exact_from_fd(fd, content_length)
}

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
		msg := read_stdin_fd_message(stdin_fd) or { return }
		if msg.len == 0 {
			continue
		}
		handler(msg)
	}
}

// send sends a JSON-RPC message to stdout
pub fn (mut t StdioTransport) send(resp protocol.JsonRpcResponse) ! {
	raw := protocol.response_to_json(resp)!
	os.fd_write(stdout_fd, raw + '\n')
}

// send_notification sends a JSON-RPC notification to stdout
pub fn (mut t StdioTransport) send_notification(notification protocol.JsonRpcNotification) ! {
	raw := protocol.notification_to_json(notification)!
	os.fd_write(stdout_fd, raw + '\n')
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
