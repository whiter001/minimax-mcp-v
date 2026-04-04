module transport

import io
import os
import time

struct FramedReader {
	text string
mut:
	pos int
}

fn (mut r FramedReader) read(mut buf []u8) !int {
	if r.pos >= r.text.len {
		return io.Eof{}
	}
	read := copy(mut buf, r.text[r.pos..].bytes())
	r.pos += read
	return read
}

fn test_read_stdin_message_parses_content_length_frame() {
	body := '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	frame := 'Content-Length: ${body.len}\r\n\r\n${body}'
	mut reader := io.new_buffered_reader(
		reader: FramedReader{
			text: frame
		}
	)
	msg := read_stdin_message(mut reader) or { panic(err) }
	assert msg == body
}

fn test_read_stdin_message_parses_multiple_framed_messages() {
	init := '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	initialized := '{"jsonrpc":"2.0","method":"initialized","params":{}}'
	call := '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"text_to_image"}}'
	stream := ['Content-Length: ${init.len}\r\n\r\n${init}',
		'Content-Length: ${initialized.len}\r\n\r\n${initialized}',
		'Content-Length: ${call.len}\r\n\r\n${call}'].join('\r\n')
	mut reader := io.new_buffered_reader(
		reader: FramedReader{
			text: stream
		}
	)
	msg1 := read_stdin_message(mut reader) or { panic(err) }
	msg2 := read_stdin_message(mut reader) or { panic(err) }
	msg3 := read_stdin_message(mut reader) or { panic(err) }
	assert msg1 == init
	assert msg2 == initialized
	assert msg3 == call
}

fn test_stdio_server_flushes_response_without_waiting_for_stdin_close() {
	vexe := os.quoted_path(@VEXE)
	src_dir := os.dir(os.dir(os.dir(@FILE)))
	main_v := os.join_path(src_dir, 'main.v')
	binary_name := 'minimax_mcp_stdio_live_${os.getpid()}_${time.now().unix()}'
	binary_path := os.join_path(os.temp_dir(), binary_name)
	compile_cmd := '${vexe} -d mbedtls_client_read_timeout_ms=300000 -o ${os.quoted_path(binary_path)} ${os.quoted_path(main_v)}'
	compile_res := os.execute(compile_cmd)
	assert compile_res.exit_code == 0, compile_res.output
	defer {
		os.rm(binary_path) or {}
	}

	mut process := os.new_process(binary_path)
	process.set_args([])
	process.set_work_folder(src_dir)
	process.set_environment({
		'MINIMAX_API_KEY':           'smoke-test-key'
		'MINIMAX_API_HOST':          'https://example.invalid'
		'MINIMAX_MCP_MODE':          'stdio'
		'MINIMAX_API_RESOURCE_MODE': 'url'
	})
	process.set_redirect_stdio()
	process.run()
	defer {
		if process.is_alive() {
			process.signal_kill()
		}
		process.close()
	}

	body := '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}'
	frame := 'Content-Length: ${body.len}\r\n\r\n${body}'
	process.stdin_write(frame)

	mut stdout := ''
	mut got_stdout := false
	for _ in 0 .. 100 {
		if process.is_pending(.stdout) {
			stdout = process.stdout_read()
			got_stdout = true
			break
		}
		time.sleep(50 * time.millisecond)
	}

	stderr := if process.is_pending(.stderr) { process.stderr_read() } else { '' }
	assert got_stdout, 'expected initialize response before stdin close; stderr: ${stderr}'
	assert stdout.contains('"jsonrpc":"2.0"'), stdout
	assert stdout.contains('"id":1'), stdout
	assert stdout.contains('"protocolVersion":"2024-11-05"'), stdout
	assert stdout.contains('"tools":{}'), stdout
	assert !stdout.contains('"resources"'), stdout
	assert !stdout.contains('"sampling"'), stdout
	assert !stdout.contains('"roots"'), stdout
}
