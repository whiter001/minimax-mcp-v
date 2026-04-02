module transport

import io

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
