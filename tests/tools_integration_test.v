module tests

import os
import time
import x.json2
import src.mcp
import src.mcp.protocol
import src.minimax

const mock_server_script = os.join_path(@DIR, 'mock_minimax_server.py')

struct MockUpstream {
mut:
	process  &os.Process = unsafe { nil }
	base_url string
}

fn test_tools_call_success_paths_with_mock_upstream() {
	mut upstream := start_mock_upstream()
	defer {
		upstream.close()
	}

	snapshot := save_minimax_env()
	defer {
		restore_minimax_env(snapshot)
	}
	configure_minimax_env(upstream.base_url)

	mut server := new_test_server()

	audio_text := call_tool_text(mut server, 1, 'text_to_audio', '{"text":"hello from test"}')
	assert audio_text == 'Success. Audio URL: ${upstream.base_url}/assets/audio.mp3'

	voices_text := call_tool_text(mut server, 2, 'list_voices', '{"voice_type":"all"}')
	assert voices_text.contains('Name: System Voice, ID: sys-voice-1;')
	assert voices_text.contains('Name: Clone Voice, ID: clone-voice-1;')

	image_text := call_tool_text(mut server, 3, 'text_to_image', '{"prompt":"sunset skyline","n":2}')
	assert image_text.contains('${upstream.base_url}/assets/image-1.jpg')
	assert image_text.contains('${upstream.base_url}/assets/image-2.jpg')

	music_text := call_tool_text(mut server, 4, 'music_generation', '{"prompt":"soft piano","lyrics":"la la la"}')
	assert music_text == 'Success. Music URL: ${upstream.base_url}/assets/music.mp3'

	voice_design_text := call_tool_text(mut server, 5, 'voice_design', '{"prompt":"warm narrator","preview_text":"hello world"}')
	assert voice_design_text.contains('Voice ID generated: designed-voice-123')
	assert voice_design_text.contains('${upstream.base_url}/assets/trial.mp3')

	search_text := call_tool_text(mut server, 6, 'web_search', '{"query":"weather"}')
	assert search_text.contains('Result for weather')
	assert search_text.contains('related topic')

	image_url := '${upstream.base_url}/assets/image.png'
	understand_text := call_tool_text(mut server, 7, 'understand_image', '{"prompt":"describe this image","image_source":"${image_url}"}')
	assert understand_text == 'VLM saw: describe this image'

	understand_alias_text := call_tool_text(mut server, 70, 'understand_image', '{"prompt":"describe alias image","image_url":"${image_url}"}')
	assert understand_alias_text == 'VLM saw: describe alias image'

	temp_image := os.join_path(os.temp_dir(), 'understand_image_fixture_${os.getpid()}.png')
	os.write_file(temp_image, 'png-fixture') or { panic(err) }
	defer {
		os.rm(temp_image) or {}
	}
	understand_local_text := call_tool_text(mut server, 71, 'understand_image', '{"prompt":"describe local image","image_source":"${temp_image}"}')
	assert understand_local_text == 'VLM saw: describe local image'

	jpeg_fixture := os.join_path(@DIR, 'a.jpeg')
	jpg_fixture := os.join_path(@DIR, 'b.jpg')
	assert os.exists(jpeg_fixture)
	assert os.exists(jpg_fixture)

	understand_jpeg_text := call_tool_text(mut server, 72, 'understand_image', '{"prompt":"describe jpeg fixture","image_source":"${jpeg_fixture}"}')
	assert understand_jpeg_text == 'VLM saw: describe jpeg fixture'

	understand_jpg_text := call_tool_text(mut server, 73, 'understand_image', '{"prompt":"describe jpg fixture","image_source":"${jpg_fixture}"}')
	assert understand_jpg_text == 'VLM saw: describe jpg fixture'

	temp_audio := os.join_path(os.temp_dir(), 'voice_clone_fixture_${os.getpid()}.mp3')
	os.write_file(temp_audio, 'mock-audio-fixture') or { panic(err) }
	defer {
		os.rm(temp_audio) or {}
	}
	voice_clone_text := call_tool_text(mut server, 8, 'voice_clone', '{"voice_id":"clone-target","file":"${temp_audio}","text":"test clone"}')
	assert voice_clone_text.contains('Voice cloned successfully. Voice ID: clone-target')
	assert voice_clone_text.contains('${upstream.base_url}/assets/demo.wav')

	video_text := call_tool_text(mut server, 9, 'generate_video', '{"prompt":"robot dancing"}')
	assert video_text == 'Success. Video URL: ${upstream.base_url}/assets/video.mp4'

	query_text := call_tool_text(mut server, 10, 'query_video_generation', '{"task_id":"video-task-123"}')
	assert query_text == 'Success. Video URL: ${upstream.base_url}/assets/video.mp4'
}

fn test_text_to_audio_saves_local_file_with_hex_response() {
	mut upstream := start_mock_upstream()
	defer {
		upstream.close()
	}

	snapshot := save_minimax_env()
	defer {
		restore_minimax_env(snapshot)
	}
	configure_minimax_env(upstream.base_url)
	os.setenv('MINIMAX_API_RESOURCE_MODE', 'local', true)

	output_dir := os.join_path(os.temp_dir(), 'minimax_t2a_local_${os.getpid()}')
	os.mkdir_all(output_dir) or { panic(err) }
	defer {
		os.rmdir_all(output_dir) or {}
	}

	mut server := new_test_server()
	audio_text := call_tool_text(mut server, 12, 'text_to_audio', '{"text":"hello local","output_directory":"${output_dir}"}')
	assert audio_text == 'Success. Audio saved as: ${output_dir}/t2a_hello_local.mp3. Voice used: female-shaonv'
	assert os.read_file(os.join_path(output_dir, 't2a_hello_local.mp3')) or { panic(err) } == 'mock-audio'
}

fn test_tools_call_surfaces_upstream_business_error_with_trace_id() {
	mut upstream := start_mock_upstream()
	defer {
		upstream.close()
	}

	snapshot := save_minimax_env()
	defer {
		restore_minimax_env(snapshot)
	}
	configure_minimax_env(upstream.base_url)

	mut server := new_test_server()
	resp := call_tool(mut server, 11, 'web_search', '{"query":"trigger upstream error"}')

	assert resp.result == none
	assert resp.error != none
	err := resp.error or { panic('missing error') }
	assert err.code == protocol.mcp_error_internal_error
	assert err.message == 'MiniMax API error 1004: invalid api key Trace-Id: mock-trace-123'
}

struct MinimaxEnvSnapshot {
	api_key       string
	host          string
	resource_mode string
	base_path     string
}

fn save_minimax_env() MinimaxEnvSnapshot {
	return MinimaxEnvSnapshot{
		api_key:       os.getenv('MINIMAX_API_KEY')
		host:          os.getenv('MINIMAX_API_HOST')
		resource_mode: os.getenv('MINIMAX_API_RESOURCE_MODE')
		base_path:     os.getenv('MINIMAX_MCP_BASE_PATH')
	}
}

fn restore_minimax_env(snapshot MinimaxEnvSnapshot) {
	restore_env_var('MINIMAX_API_KEY', snapshot.api_key)
	restore_env_var('MINIMAX_API_HOST', snapshot.host)
	restore_env_var('MINIMAX_API_RESOURCE_MODE', snapshot.resource_mode)
	restore_env_var('MINIMAX_MCP_BASE_PATH', snapshot.base_path)
}

fn restore_env_var(name string, value string) {
	if value.len == 0 {
		os.unsetenv(name)
		return
	}
	os.setenv(name, value, true)
}

fn configure_minimax_env(base_url string) {
	os.setenv('MINIMAX_API_KEY', 'integration-test-key', true)
	os.setenv('MINIMAX_API_HOST', base_url, true)
	os.setenv('MINIMAX_API_RESOURCE_MODE', 'url', true)
	os.setenv('MINIMAX_MCP_BASE_PATH', os.temp_dir(), true)
	minimax.init_client('integration-test-key', base_url)
}

fn new_test_server() mcp.McpServer {
	mut server := mcp.new_server()
	for tool in minimax.tool_definitions() {
		server.register_tool(tool)
	}
	return server
}

fn call_tool_text(mut server mcp.McpServer, id int, tool_name string, args_json string) string {
	resp := call_tool(mut server, id, tool_name, args_json)
	assert resp.error == none
	result := resp.result or { panic('missing result') }
	body := result.as_map()
	content := body['content'] or { panic('missing content') }
	items := content.as_array()
	assert items.len > 0
	text := items[0].as_map()['text'] or { panic('missing text') }
	return text.str()
}

fn call_tool(mut server mcp.McpServer, id int, tool_name string, args_json string) protocol.JsonRpcResponse {
	arguments := json2.decode[json2.Any](args_json, json2.DecoderOptions{}) or { panic(err) }
	mut params := map[string]json2.Any{}
	params['name'] = tool_name
	params['arguments'] = arguments
	request := protocol.JsonRpcRequest{
		id:     json2.Any(id)
		method: 'tools/call'
		params: params
	}
	raw := protocol.request_to_json(request) or { panic(err) }
	message := server.handle_message(raw) or { panic(err) }
	match message {
		protocol.JsonRpcResponse {
			return message
		}
		else {
			panic('expected JsonRpcResponse')
		}
	}
	return protocol.build_error_response(json2.Any(id), protocol.jsonrpc_internal_error,
		'unreachable')
}

fn start_mock_upstream() MockUpstream {
	python3 := os.find_abs_path_of_executable('python3') or {
		panic('python3 is required for tools integration tests')
	}
	mut process := os.new_process(python3)
	process.set_args(['-u', mock_server_script])
	process.set_work_folder(@DIR)
	process.set_redirect_stdio()
	process.run()

	mut output := ''
	for _ in 0 .. 100 {
		if process.is_pending(.stdout) {
			output += process.stdout_read()
			if output.contains('\n') {
				break
			}
		}
		time.sleep(50 * time.millisecond)
	}

	first_line := output.all_before('\n').trim_space()
	if !first_line.starts_with('READY ') {
		stderr := if process.is_pending(.stderr) { process.stderr_read() } else { '' }
		process.signal_kill()
		process.close()
		panic('mock upstream failed to start. stdout: ${output} stderr: ${stderr}')
	}
	port := first_line.all_after('READY ').int()
	return MockUpstream{
		process:  process
		base_url: 'http://127.0.0.1:${port}'
	}
}

fn (mut upstream MockUpstream) close() {
	if isnil(upstream.process) {
		return
	}
	if upstream.process.is_alive() {
		upstream.process.signal_kill()
	}
	upstream.process.close()
}
