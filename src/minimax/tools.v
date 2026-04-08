module minimax

import mcp
import net.http
import os
import x.json2
import time

// init_client synchronizes startup configuration into the shared environment
// variables used by the API client helpers.
pub fn init_client(api_key string, host string) {
	if api_key.len > 0 {
		os.setenv('MINIMAX_API_KEY', api_key, true)
	}
	if host.len > 0 {
		os.setenv('MINIMAX_API_HOST', host, true)
	}
}

const default_api_host = 'https://api.minimaxi.com'
const output_directory_schema_description = 'Optional local output directory when resource mode is local. Final filenames are auto-generated and ASCII-safe.'

fn api_client() Client {
	api_key := os.getenv('MINIMAX_API_KEY')
	host := os.getenv('MINIMAX_API_HOST')
	if host.len == 0 {
		return new_client(api_key, default_api_host)
	}
	return new_client(api_key, host)
}

// =============================================================================
// Local Helpers
// =============================================================================

fn current_resource_mode() string {
	mode := os.getenv('MINIMAX_API_RESOURCE_MODE')
	if mode.len > 0 {
		return mode.trim_space().to_lower()
	}
	return 'local'
}

fn resolve_resource_mode(obj map[string]json2.Any) !string {
	if mode := extract_string_field(obj, 'resource_mode') {
		normalized := mode.trim_space().to_lower()
		if normalized.len == 0 {
			return current_resource_mode()
		}
		if normalized != 'url' && normalized != 'local' {
			return error('resource_mode must be url or local')
		}
		return normalized
	}
	return current_resource_mode()
}

fn current_base_path() string {
	base_path := os.getenv('MINIMAX_MCP_BASE_PATH')
	if base_path.len > 0 {
		return base_path
	}
	return os.home_dir() + '/Desktop'
}

fn resolve_output_dir(output_directory string) string {
	if output_directory.len == 0 {
		return current_base_path()
	}
	if output_directory.starts_with('/') || output_directory.contains(':') {
		return output_directory
	}
	return os.join_path(current_base_path(), output_directory)
}

fn ensure_dir(path string) ! {
	if path.len > 0 && !os.exists(path) {
		os.mkdir_all(path)!
	}
}

fn trim_filename_edges(value string) string {
	mut start := 0
	mut end := value.len
	for start < end {
		ch := value[start]
		if ch == `.` || ch == `-` || ch == `_` {
			start++
			continue
		}
		break
	}
	for end > start {
		ch := value[end - 1]
		if ch == `.` || ch == `-` || ch == `_` {
			end--
			continue
		}
		break
	}
	return value[start..end]
}

fn filename_hash(seed string) string {
	mut hash := u64(1469598103934665603)
	for b in seed.bytes() {
		hash ^= u64(b)
		hash *= u64(1099511628211)
	}
	return hash.str()
}

fn sanitize_filename(input string) (string, bool) {
	trimmed := input.trim_space()
	if trimmed.len == 0 {
		return 'output', false
	}
	mut output := []u8{cap: trimmed.len}
	mut last_was_separator := false
	mut saw_non_ascii := false
	for b in trimmed.bytes() {
		is_ascii_letter := (b >= `a` && b <= `z`) || (b >= `A` && b <= `Z`)
		is_ascii_digit := b >= `0` && b <= `9`
		is_safe_punctuation := b == `.` || b == `-` || b == `_`
		if is_ascii_letter || is_ascii_digit {
			output << b
			last_was_separator = false
			continue
		}
		if b >= 128 {
			saw_non_ascii = true
		}
		if is_safe_punctuation {
			if output.len > 0 && !last_was_separator {
				output << b
				last_was_separator = true
			}
			continue
		}
		if output.len > 0 && !last_was_separator {
			output << `_`
			last_was_separator = true
		}
	}
	mut result := trim_filename_edges(output.bytestr())
	if result.len == 0 {
		return 'output', saw_non_ascii
	}
	if result.len > 32 {
		result = trim_filename_edges(result[..32])
		if result.len == 0 {
			return 'output', saw_non_ascii
		}
	}
	return result, saw_non_ascii
}

fn hex_char_value(c u8) !u8 {
	if c >= `0` && c <= `9` {
		return u8(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return u8(c - `a` + 10)
	}
	if c >= `A` && c <= `F` {
		return u8(c - `A` + 10)
	}
	return error('Invalid hex character')
}

fn decode_hex_string(value string) ![]u8 {
	if value.len == 0 {
		return []u8{}
	}
	if value.len % 2 != 0 {
		return error('Invalid hex string length')
	}
	mut decoded := []u8{cap: value.len / 2}
	mut i := 0
	for i < value.len {
		hi := hex_char_value(value[i])!
		lo := hex_char_value(value[i + 1])!
		decoded << u8((hi << 4) | lo)
		i += 2
	}
	return decoded
}

fn write_text_file(path string, content string) ! {
	dir := os.dir(path)
	if dir.len > 0 {
		ensure_dir(dir)!
	}
	os.write_file(path, content)!
}

fn save_hex_payload(path string, hex_payload string) ! {
	decoded := decode_hex_string(hex_payload)!
	write_text_file(path, decoded.bytestr())!
}

fn save_resource_payload(path string, payload string) ! {
	if payload.starts_with('http://') || payload.starts_with('https://') {
		download_to_file(payload, path)!
		return
	}
	save_hex_payload(path, payload)!
}

fn download_url(url string) !string {
	req := http.Request{
		method: http.Method.get
		url:    url
	}
	resp := req.do()!
	if resp.status_code < 200 || resp.status_code >= 300 {
		return error('Failed to download ${url}: HTTP ${resp.status_code}')
	}
	return resp.body
}

fn download_to_file(url string, path string) ! {
	content := download_url(url)!
	write_text_file(path, content)!
}

fn build_output_file_path(prefix string, seed string, extension string) string {
	sanitized, saw_non_ascii := sanitize_filename(seed)
	if saw_non_ascii {
		return '${prefix}_${sanitized}_${filename_hash(seed)}.${extension}'
	}
	return '${prefix}_${sanitized}.${extension}'
}

fn extract_string_field(obj map[string]json2.Any, key string) ?string {
	value := obj[key] or { return none }
	return value.str()
}

fn extract_first_non_empty_string_field(obj map[string]json2.Any, keys []string) ?string {
	for key in keys {
		if value := obj[key] {
			text := value.str().trim_space()
			if text.len > 0 {
				return text
			}
		}
	}
	return none
}

fn required_string_field(obj map[string]json2.Any, key string, message string) !string {
	value := obj[key] or { return error(message) }
	text := value.str().trim_space()
	if text.len == 0 {
		return error(message)
	}
	return text
}

fn object_schema() json2.Any {
	mut schema := map[string]json2.Any{}
	schema['type'] = 'object'
	return schema
}

fn string_schema(description string) json2.Any {
	mut schema := map[string]json2.Any{}
	schema['type'] = 'string'
	if description.len > 0 {
		schema['description'] = description
	}
	return schema
}

fn integer_schema(description string) json2.Any {
	mut schema := map[string]json2.Any{}
	schema['type'] = 'integer'
	if description.len > 0 {
		schema['description'] = description
	}
	return schema
}

fn number_schema(description string) json2.Any {
	mut schema := map[string]json2.Any{}
	schema['type'] = 'number'
	if description.len > 0 {
		schema['description'] = description
	}
	return schema
}

fn boolean_schema(description string) json2.Any {
	mut schema := map[string]json2.Any{}
	schema['type'] = 'boolean'
	if description.len > 0 {
		schema['description'] = description
	}
	return schema
}

fn object_schema_with(properties map[string]json2.Any, required []string) json2.Any {
	mut schema := map[string]json2.Any{}
	schema['type'] = 'object'
	schema['properties'] = properties
	schema['additionalProperties'] = true
	if required.len > 0 {
		mut required_fields := []json2.Any{}
		for field in required {
			required_fields << field
		}
		schema['required'] = required_fields
	}
	return schema
}

fn text_to_audio_schema() json2.Any {
	return object_schema_with({
		'text':             string_schema('Text to synthesize into audio.')
		'voice_id':         string_schema('Voice ID to use for synthesis.')
		'model':            string_schema('MiniMax speech model name.')
		'resource_mode':    string_schema('Optional override for this call: url or local.')
		'speed':            number_schema('Speech speed multiplier.')
		'vol':              number_schema('Output volume multiplier.')
		'pitch':            integer_schema('Pitch adjustment.')
		'emotion':          string_schema('Voice emotion preset.')
		'sample_rate':      integer_schema('Output sample rate in Hz.')
		'bitrate':          integer_schema('Output bitrate in bps.')
		'channel':          integer_schema('Output channel count.')
		'format':           string_schema('Output audio format, for example mp3.')
		'language_boost':   string_schema('Language boost mode.')
		'output_directory': string_schema(output_directory_schema_description)
	}, ['text'])
}

fn list_voices_schema() json2.Any {
	return object_schema_with({
		'voice_type': string_schema('Voice type filter. Defaults to all.')
	}, []string{})
}

fn voice_clone_schema() json2.Any {
	return object_schema_with({
		'voice_id':         string_schema('Target cloned voice ID.')
		'file':             string_schema('Local audio file path or remote URL.')
		'text':             string_schema('Reference transcript for the uploaded audio.')
		'is_url':           boolean_schema('Whether the file field is a remote URL.')
		'resource_mode':    string_schema('Optional override for this call: url or local.')
		'output_directory': string_schema(output_directory_schema_description)
	}, ['voice_id', 'file', 'text'])
}

fn play_audio_schema() json2.Any {
	return object_schema_with({
		'input_file_path': string_schema('Local audio file path or remote URL to play.')
		'is_url':          boolean_schema('Whether input_file_path is a remote URL.')
	}, ['input_file_path'])
}

fn generate_video_schema() json2.Any {
	return object_schema_with({
		'prompt':            string_schema('Text prompt used to generate the video.')
		'model':             string_schema('Video generation model.')
		'resource_mode':     string_schema('Optional override for this call: url or local.')
		'async_mode':        boolean_schema('Return a task ID without polling for completion.')
		'first_frame_image': string_schema('Optional first frame image URL or local path.')
		'resolution':        string_schema('Optional output resolution preset.')
		'duration':          integer_schema('Optional duration in seconds.')
		'output_directory':  string_schema(output_directory_schema_description)
	}, ['prompt'])
}

fn query_video_generation_schema() json2.Any {
	return object_schema_with({
		'task_id':          string_schema('Video generation task ID to query.')
		'resource_mode':    string_schema('Optional override for this call: url or local.')
		'output_directory': string_schema(output_directory_schema_description)
	}, ['task_id'])
}

fn text_to_image_schema() json2.Any {
	return object_schema_with({
		'prompt':           string_schema('Text prompt used to generate images.')
		'model':            string_schema('Image generation model.')
		'resource_mode':    string_schema('Optional override for this call: url or local.')
		'aspect_ratio':     string_schema('Target image aspect ratio.')
		'n':                integer_schema('Number of images to generate.')
		'prompt_optimizer': boolean_schema('Whether to enable prompt optimization.')
		'output_directory': string_schema(output_directory_schema_description)
	}, ['prompt'])
}

fn music_generation_schema() json2.Any {
	return object_schema_with({
		'prompt':           string_schema('Text prompt describing the desired music.')
		'lyrics':           string_schema('Lyrics to render into the generated music.')
		'resource_mode':    string_schema('Optional override for this call: url or local.')
		'output_directory': string_schema(output_directory_schema_description)
	}, ['prompt', 'lyrics'])
}

fn voice_design_schema() json2.Any {
	return object_schema_with({
		'prompt':           string_schema('Description of the desired voice.')
		'preview_text':     string_schema('Preview text to synthesize with the designed voice.')
		'voice_id':         string_schema('Optional existing voice ID to refine.')
		'resource_mode':    string_schema('Optional override for this call: url or local.')
		'output_directory': string_schema(output_directory_schema_description)
	}, ['prompt', 'preview_text'])
}

fn web_search_schema() json2.Any {
	return object_schema_with({
		'query': string_schema('Search query text.')
	}, ['query'])
}

fn understand_image_schema() json2.Any {
	mut schema := object_schema_with({
		'prompt':       string_schema('Question or instruction about the image.')
		'image_source': string_schema('Image URL, local file path, or data URL.')
	}, ['prompt', 'image_source']).as_map()
	schema['additionalProperties'] = false
	return schema
}

fn get_string_field(obj map[string]json2.Any, key string, default_value string) string {
	value := obj[key] or { return default_value }
	return value.str()
}

fn get_int_field(obj map[string]json2.Any, key string, default_value int) int {
	value := obj[key] or { return default_value }
	return value.int()
}

fn get_bool_field(obj map[string]json2.Any, key string, default_value bool) bool {
	value := obj[key] or { return default_value }
	return value.bool()
}

fn get_f64_field(obj map[string]json2.Any, key string, default_value f64) f64 {
	value := obj[key] or { return default_value }
	return value.f64()
}

fn video_retry_interval() time.Duration {
	return 20 * time.second
}

fn video_max_retries(model string) int {
	return if model == 'MiniMax-Hailuo-02' { 60 } else { 30 }
}

pub fn tool_definitions() []mcp.Tool {
	return [
		mcp.Tool{
			name:         'text_to_audio'
			description:  'Convert text to audio and save the output audio file.'
			input_schema: text_to_audio_schema()
			handler:      text_to_audio_handler
		},
		mcp.Tool{
			name:         'list_voices'
			description:  'List available voices.'
			input_schema: list_voices_schema()
			handler:      list_voices_handler
		},
		mcp.Tool{
			name:         'voice_clone'
			description:  'Clone a voice from a file.'
			input_schema: voice_clone_schema()
			handler:      voice_clone_handler
		},
		mcp.Tool{
			name:         'play_audio'
			description:  'Play an audio file.'
			input_schema: play_audio_schema()
			handler:      play_audio_handler
		},
		mcp.Tool{
			name:         'generate_video'
			description:  'Generate a video from a text prompt.'
			input_schema: generate_video_schema()
			handler:      generate_video_handler
		},
		mcp.Tool{
			name:         'query_video_generation'
			description:  'Query the status of a video generation task.'
			input_schema: query_video_generation_schema()
			handler:      query_video_handler
		},
		mcp.Tool{
			name:         'text_to_image'
			description:  'Generate images from a text prompt.'
			input_schema: text_to_image_schema()
			handler:      text_to_image_handler
		},
		mcp.Tool{
			name:         'music_generation'
			description:  'Generate music from a text prompt.'
			input_schema: music_generation_schema()
			handler:      music_generation_handler
		},
		mcp.Tool{
			name:         'voice_design'
			description:  'Generate a voice from description prompts.'
			input_schema: voice_design_schema()
			handler:      voice_design_handler
		},
		mcp.Tool{
			name:         'web_search'
			description:  'Search the web and get structured results including titles, links, snippets, and related searches.'
			input_schema: web_search_schema()
			handler:      web_search_handler
		},
		mcp.Tool{
			name:         'understand_image'
			description:  'Analyze images from URLs or local files, supporting JPEG, PNG, and WebP formats.'
			input_schema: understand_image_schema()
			handler:      understand_image_handler
		},
	]
}

// =============================================================================
// Tool Handlers
// =============================================================================

fn text_to_audio_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	text := required_string_field(obj, 'text', 'text is required')!
	resource_mode := resolve_resource_mode(obj)!
	voice_id := get_string_field(obj, 'voice_id', default_voice_id)
	model := get_string_field(obj, 'model', default_speech_model)
	speed := get_f64_field(obj, 'speed', default_speed)
	vol := get_f64_field(obj, 'vol', default_volume)
	pitch := get_int_field(obj, 'pitch', default_pitch)
	emotion := get_string_field(obj, 'emotion', default_emotion)
	sample_rate := get_int_field(obj, 'sample_rate', default_sample_rate)
	bitrate := get_int_field(obj, 'bitrate', default_bitrate)
	channel := get_int_field(obj, 'channel', default_channel)
	format := get_string_field(obj, 'format', default_format)
	language_boost := get_string_field(obj, 'language_boost', default_language_boost)
	output_directory := extract_string_field(obj, 'output_directory') or { '' }

	req := TTSRequest{
		model:          model
		text:           text
		voice_setting:  VoiceSetting{
			voice_id: voice_id
			speed:    speed
			vol:      vol
			pitch:    pitch
			emotion:  emotion
		}
		audio_setting:  AudioSetting{
			sample_rate: sample_rate
			bitrate:     bitrate
			format:      format
			channel:     channel
		}
		language_boost: language_boost
		output_format:  if resource_mode == 'url' { 'url' } else { 'hex' }
	}

	result := api_client().text_to_audio(req)!
	data := result['data'] or { return error('No data in response') }
	audio_data := data.as_map()
	audio := audio_data['audio'] or { return error('No audio in response') }
	audio_text := audio.str()

	if resource_mode == 'url' {
		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Success. Audio URL: ${audio_text}'
				},
			]
			is_error: false
		}
	}

	output_dir := resolve_output_dir(output_directory)
	output_file := build_output_file_path('t2a', text, format)
	output_path := os.join_path(output_dir, output_file)
	save_hex_payload(output_path, audio_text)!

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Success. Audio saved as: ${output_path}. Voice used: ${voice_id}'
			},
		]
		is_error: false
	}
}

fn list_voices_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	mut voice_type := 'all'
	if args := arguments {
		obj := args.as_map()
		voice_type = get_string_field(obj, 'voice_type', 'all')
	}

	voice_list := api_client().list_voices(voice_type)!

	mut system_voice_list := 'System Voices: '
	mut cloning_voice_list := 'Voice Cloning Voices: '

	for voice in voice_list.system_voice {
		system_voice_list += 'Name: ${voice.voice_name}, ID: ${voice.voice_id}; '
	}

	for voice in voice_list.voice_cloning {
		cloning_voice_list += 'Name: ${voice.voice_name}, ID: ${voice.voice_id}; '
	}

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Success. ${system_voice_list} ${cloning_voice_list}'
			},
		]
		is_error: false
	}
}

fn voice_clone_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	voice_id := required_string_field(obj, 'voice_id', 'voice_id is required')!
	file_path := required_string_field(obj, 'file', 'file is required')!
	text := required_string_field(obj, 'text', 'text is required')!
	resource_mode := resolve_resource_mode(obj)!
	output_directory := extract_string_field(obj, 'output_directory') or { '' }

	is_url := if is_url_val := obj['is_url'] { is_url_val.bool() } else { false }
	file_data := if is_url {
		download_url(file_path)!
	} else {
		os.read_file(file_path)!
	}

	upload_result := api_client().upload_file(file_data, 'audio.mp3', 'audio/mpeg')!
	upload_file := upload_result['file'] or { return error('No file in upload response') }
	file_id := upload_file.as_map()['file_id'] or { return error('No file_id') }

	clone_req := VoiceCloneRequest{
		file_id:  file_id.str()
		voice_id: voice_id
		text:     text
	}

	clone_result := api_client().voice_clone(clone_req)!
	if demo_audio := clone_result['demo_audio'] {
		if resource_mode == 'url' {
			return mcp.CallToolResult{
				content:  [
					mcp.Content{
						@type: 'text'
						text:  'Voice cloned successfully. Voice ID: ${voice_id}, demo audio URL: ${demo_audio.str()}'
					},
				]
				is_error: false
			}
		}

		output_dir := resolve_output_dir(output_directory)
		output_file := build_output_file_path('voice_clone', text, 'wav')
		output_path := os.join_path(output_dir, output_file)
		save_resource_payload(output_path, demo_audio.str())!

		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Voice cloned successfully. Voice ID: ${voice_id}, demo audio saved as: ${output_path}'
				},
			]
			is_error: false
		}
	}

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Voice cloned successfully. Voice ID: ${voice_id}'
			},
		]
		is_error: false
	}
}

fn play_audio_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	input_file_path := obj['input_file_path'] or { return error('Missing input_file_path') }
	is_url := if is_url_val := obj['is_url'] { is_url_val.bool() } else { false }
	play_path := if is_url {
		temp_path := os.home_dir() + '/.minimax_mcp_play_audio.mp3'
		download_to_file(input_file_path.str(), temp_path)!
		temp_path
	} else {
		input_file_path.str()
	}

	// Reject paths with shell metacharacters to prevent command injection
	if play_path.contains_any('"\';`$(){}|&<>\\\n\r') {
		return error('Invalid characters in audio file path')
	}
	result := os.execute('ffplay -autoexit -nodisp "${play_path}"')
	if result.exit_code != 0 {
		return error('ffplay failed: ${result.output.trim_space()}')
	}
	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Successfully played audio file: ${play_path}'
			},
		]
		is_error: false
	}
}

fn generate_video_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	prompt := required_string_field(obj, 'prompt', 'prompt is required')!
	model := get_string_field(obj, 'model', default_t2v_model)
	resource_mode := resolve_resource_mode(obj)!
	output_directory := extract_string_field(obj, 'output_directory') or { '' }
	async_mode := get_bool_field(obj, 'async_mode', false)
	first_frame_image := extract_string_field(obj, 'first_frame_image')
	resolution := extract_string_field(obj, 'resolution')
	duration := if duration_val := obj['duration'] { duration_val.int() } else { none }

	req := VideoGenerationRequest{
		model:             model
		prompt:            prompt
		first_frame_image: first_frame_image
		duration:          duration
		resolution:        resolution
	}

	result := api_client().generate_video(req)!
	task_id := result['task_id'] or { return error('No task_id in response') }

	if async_mode {
		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Video generation task submitted. Task ID: ${task_id.str()}. Use query_video_generation to check status.'
				},
			]
			is_error: false
		}
	}

	mut file_id := ''
	max_retries := video_max_retries(model)
	retry_interval := video_retry_interval()

	for _ in 0 .. max_retries {
		status_response := api_client().query_video(task_id.str())!
		status := status_response['status'] or { return error('No status in response') }
		if status.str() == 'Fail' {
			return error('Video generation failed for task_id: ${task_id.str()}')
		}
		if status.str() == 'Success' {
			file_id_val := status_response['file_id'] or {
				return error('Missing file_id in success response')
			}
			file_id = file_id_val.str()
			break
		}
		time.sleep(retry_interval)
	}

	if file_id.len == 0 {
		return error('Failed to get file_id for task_id: ${task_id.str()}')
	}

	file_response := api_client().retrieve_file(file_id)!
	download_url := file_response['file'] or { return error('Failed to get file response') }.as_map()['download_url'] or {
		return error('Failed to get download URL for file_id: ${file_id}')
	}
	video_url := download_url.str()

	if resource_mode == 'url' {
		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Success. Video URL: ${video_url}'
				},
			]
			is_error: false
		}
	}

	output_dir := resolve_output_dir(output_directory)
	output_file := build_output_file_path('video', task_id.str(), 'mp4')
	output_path := os.join_path(output_dir, output_file)
	download_to_file(video_url, output_path)!

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Success. Video saved as: ${output_path}'
			},
		]
		is_error: false
	}
}

fn query_video_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	task_id := obj['task_id'] or { return error('Missing task_id') }
	resource_mode := resolve_resource_mode(obj)!
	output_directory := extract_string_field(obj, 'output_directory') or { '' }

	result := api_client().query_video(task_id.str())!
	status := result['status'] or { return error('No status in response') }

	if status.str() == 'Fail' {
		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Video generation FAILED for task_id: ${task_id.str()}'
				},
			]
			is_error: false
		}
	}

	if status.str() != 'Success' {
		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Video generation task is still processing: Task ID: ${task_id.str()}'
				},
			]
			is_error: false
		}
	}

	file_id := result['file_id'] or { return error('Missing file_id in success response') }
	file_response := api_client().retrieve_file(file_id.str())!
	download_url := file_response['file'] or { return error('Failed to get file response') }.as_map()['download_url'] or {
		return error('Failed to get download URL for file_id: ${file_id.str()}')
	}
	video_url := download_url.str()

	if resource_mode == 'url' {
		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Success. Video URL: ${video_url}'
				},
			]
			is_error: false
		}
	}

	output_dir := resolve_output_dir(output_directory)
	output_file := build_output_file_path('video', task_id.str(), 'mp4')
	output_path := os.join_path(output_dir, output_file)
	download_to_file(video_url, output_path)!

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Success. Video saved as: ${output_path}'
			},
		]
		is_error: false
	}
}

fn text_to_image_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	prompt := obj['prompt'] or { return error('Missing prompt') }
	model := get_string_field(obj, 'model', default_t2i_model)
	resource_mode := resolve_resource_mode(obj)!
	aspect_ratio := get_string_field(obj, 'aspect_ratio', '1:1')
	n := get_int_field(obj, 'n', 1)
	prompt_optimizer := get_bool_field(obj, 'prompt_optimizer', true)
	output_directory := extract_string_field(obj, 'output_directory') or { '' }

	req := ImageGenerationRequest{
		model:            model
		prompt:           prompt.str()
		aspect_ratio:     aspect_ratio
		n:                n
		prompt_optimizer: prompt_optimizer
	}

	result := api_client().generate_image(req)!
	image_urls := result['data'] or { return error('No data in response') }.as_map()['image_urls'] or {
		return error('No image_urls')
	}

	arr := image_urls.as_array()
	if arr.len > 0 {
		if resource_mode == 'url' {
			mut urls_text := 'Image URLs: '
			for i, url in arr {
				urls_text += '${i + 1}. ${url.str()}; '
			}
			return mcp.CallToolResult{
				content:  [
					mcp.Content{
						@type: 'text'
						text:  'Success. ${urls_text}'
					},
				]
				is_error: false
			}
		}

		output_dir := resolve_output_dir(output_directory)
		mut saved_files := []string{}
		for i, url in arr {
			output_file := build_output_file_path('image_${i + 1}', prompt.str(), 'jpg')
			output_path := os.join_path(output_dir, output_file)
			download_to_file(url.str(), output_path)!
			saved_files << output_path
		}

		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Success. Images saved as: ${saved_files}'
				},
			]
			is_error: false
		}
	}

	return error('No image URLs returned')
}

fn music_generation_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	prompt := required_string_field(obj, 'prompt', 'prompt is required')!
	lyrics := required_string_field(obj, 'lyrics', 'lyrics is required')!
	resource_mode := resolve_resource_mode(obj)!
	output_directory := extract_string_field(obj, 'output_directory') or { '' }

	req := MusicGenerationRequest{
		model:         default_music_model
		prompt:        prompt
		lyrics:        lyrics
		audio_setting: MusicSetting{
			sample_rate: default_sample_rate
			bitrate:     default_bitrate
			format:      default_format
		}
	}

	result := api_client().generate_music(req)!
	data := result['data'] or { return error('No data in response') }
	audio_data := data.as_map()
	audio := audio_data['audio'] or { return error('No audio in response') }
	audio_text := audio.str()

	if resource_mode == 'url' {
		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Success. Music URL: ${audio_text}'
				},
			]
			is_error: false
		}
	}

	output_dir := resolve_output_dir(output_directory)
	output_file := build_output_file_path('music', prompt, default_format)
	output_path := os.join_path(output_dir, output_file)
	save_resource_payload(output_path, audio_text)!

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Success. Music saved as: ${output_path}'
			},
		]
		is_error: false
	}
}

fn voice_design_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	prompt := required_string_field(obj, 'prompt', 'prompt is required')!
	preview_text := required_string_field(obj, 'preview_text', 'preview_text is required')!
	voice_id := extract_string_field(obj, 'voice_id')
	resource_mode := resolve_resource_mode(obj)!
	output_directory := extract_string_field(obj, 'output_directory') or { '' }

	req := VoiceDesignRequest{
		prompt:       prompt
		preview_text: preview_text
		voice_id:     voice_id
	}

	result := api_client().design_voice(req)!
	generated_voice_id := result['voice_id'] or { return error('No voice_id in response') }

	if trial_audio := result['trial_audio'] {
		if resource_mode == 'url' {
			return mcp.CallToolResult{
				content:  [
					mcp.Content{
						@type: 'text'
						text:  'Success. Voice ID generated: ${generated_voice_id.str()}, Trial Audio: ${trial_audio.str()}'
					},
				]
				is_error: false
			}
		}

		output_dir := resolve_output_dir(output_directory)
		output_file := build_output_file_path('voice_design', preview_text, 'mp3')
		output_path := os.join_path(output_dir, output_file)
		save_resource_payload(output_path, trial_audio.str())!

		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Success. File saved as: ${output_path}. Voice ID generated: ${generated_voice_id.str()}'
				},
			]
			is_error: false
		}
	}

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Success. Voice ID generated: ${generated_voice_id.str()}'
			},
		]
		is_error: false
	}
}

fn web_search_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	query := required_string_field(obj, 'query', 'Query is required')!

	req := SearchRequest{
		query: query
	}

	result := api_client().search(req)!

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  json2.encode(result, json2.EncoderOptions{ prettify: true })
			},
		]
		is_error: false
	}
}

fn understand_image_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	prompt := required_string_field(obj, 'prompt', 'Prompt is required')!
	image_source := extract_first_non_empty_string_field(obj, ['image_source', 'image_url']) or {
		return error('Image source is required')
	}

	processed_image_url := process_image_url(image_source)!

	req := VLMRequest{
		prompt:    prompt
		image_url: processed_image_url
	}

	result := api_client().vlm(req)!
	content := result['content'] or { return error('No content in response') }

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  content.str()
			},
		]
		is_error: false
	}
}
