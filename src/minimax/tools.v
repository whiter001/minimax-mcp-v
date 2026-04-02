module minimax

import mcp
import net.http
import os
import x.json2
import time

// init_client keeps the existing startup hook, but the handlers now read
// configuration directly from the environment on demand.
pub fn init_client(api_key string, host string) {
	_ = api_key
	_ = host
}

const default_api_host = 'https://api.minimaxi.com'

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
		return mode
	}
	return 'url'
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
	return current_base_path() + '/' + output_directory
}

fn ensure_dir(path string) ! {
	if path.len > 0 && !os.exists(path) {
		os.mkdir_all(path)!
	}
}

fn sanitize_filename(input string) string {
	mut output := input.trim_space()
	if output.len == 0 {
		return 'output'
	}
	output = output.replace(' ', '_')
	output = output.replace('/', '_')
	output = output.replace('\\', '_')
	output = output.replace(':', '_')
	output = output.replace('?', '_')
	output = output.replace('&', '_')
	output = output.replace('=', '_')
	if output.len > 32 {
		output = output[..32]
	}
	return output
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
	return '${prefix}_${sanitize_filename(seed)}.${extension}'
}

fn extract_string_field(obj map[string]json2.Any, key string) ?string {
	if key in obj {
		return obj[key].str()
	}
	return none
}

fn object_schema() json2.Any {
	mut schema := map[string]json2.Any{}
	schema['type'] = 'object'
	return schema
}

fn get_string_field(obj map[string]json2.Any, key string, default_value string) string {
	if key in obj {
		return obj[key].str()
	}
	return default_value
}

fn get_int_field(obj map[string]json2.Any, key string, default_value int) int {
	if key in obj {
		return obj[key].int()
	}
	return default_value
}

fn get_bool_field(obj map[string]json2.Any, key string, default_value bool) bool {
	if key in obj {
		return obj[key].bool()
	}
	return default_value
}

fn get_f64_field(obj map[string]json2.Any, key string, default_value f64) f64 {
	if key in obj {
		return obj[key].f64()
	}
	return default_value
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
			input_schema: object_schema()
			handler:      text_to_audio_handler
		},
		mcp.Tool{
			name:         'list_voices'
			description:  'List available voices.'
			input_schema: object_schema()
			handler:      list_voices_handler
		},
		mcp.Tool{
			name:         'voice_clone'
			description:  'Clone a voice from a file.'
			input_schema: object_schema()
			handler:      voice_clone_handler
		},
		mcp.Tool{
			name:         'play_audio'
			description:  'Play an audio file.'
			input_schema: object_schema()
			handler:      play_audio_handler
		},
		mcp.Tool{
			name:         'generate_video'
			description:  'Generate a video from a text prompt.'
			input_schema: object_schema()
			handler:      generate_video_handler
		},
		mcp.Tool{
			name:         'query_video_generation'
			description:  'Query the status of a video generation task.'
			input_schema: object_schema()
			handler:      query_video_handler
		},
		mcp.Tool{
			name:         'text_to_image'
			description:  'Generate images from a text prompt.'
			input_schema: object_schema()
			handler:      text_to_image_handler
		},
		mcp.Tool{
			name:         'music_generation'
			description:  'Generate music from a text prompt.'
			input_schema: object_schema()
			handler:      music_generation_handler
		},
		mcp.Tool{
			name:         'voice_design'
			description:  'Generate a voice from description prompts.'
			input_schema: object_schema()
			handler:      voice_design_handler
		},
	]
}

// =============================================================================
// Tool Handlers
// =============================================================================

fn text_to_audio_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	text := obj['text'] or { return error('Missing text parameter') }
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
		text:           text.str()
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
	}

	result := api_client().text_to_audio(req)!
	data := result['data'] or { return error('No data in response') }
	audio_data := data.as_map()
	audio := audio_data['audio'] or { return error('No audio in response') }
	audio_text := audio.str()

	if current_resource_mode() == 'url' {
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
	output_file := build_output_file_path('t2a', text.str(), format)
	output_path := output_dir + '/' + output_file
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

	voice_id := obj['voice_id'] or { return error('Missing voice_id') }
	file := obj['file'] or { return error('Missing file') }
	text := obj['text'] or { return error('Missing text') }
	output_directory := extract_string_field(obj, 'output_directory') or { '' }
	file_path := file.str()

	file_data := if 'is_url' in obj && obj['is_url'].bool() {
		download_url(file_path)!
	} else {
		os.read_file(file_path)!
	}

	upload_result := api_client().upload_file(file_data, 'audio.mp3', 'audio/mpeg')!
	upload_file := upload_result['file'] or { return error('No file in upload response') }
	file_id := upload_file.as_map()['file_id'] or { return error('No file_id') }

	clone_req := VoiceCloneRequest{
		file_id:  file_id.str()
		voice_id: voice_id.str()
		text:     text.str()
	}

	clone_result := api_client().voice_clone(clone_req)!
	if demo_audio := clone_result['demo_audio'] {
		if current_resource_mode() == 'url' {
			return mcp.CallToolResult{
				content:  [
					mcp.Content{
						@type: 'text'
						text:  'Voice cloned successfully. Voice ID: ${voice_id.str()}, demo audio URL: ${demo_audio.str()}'
					},
				]
				is_error: false
			}
		}

		output_dir := resolve_output_dir(output_directory)
		output_file := build_output_file_path('voice_clone', text.str(), 'wav')
		output_path := output_dir + '/' + output_file
		download_to_file(demo_audio.str(), output_path)!

		return mcp.CallToolResult{
			content:  [
				mcp.Content{
					@type: 'text'
					text:  'Voice cloned successfully. Voice ID: ${voice_id.str()}, demo audio saved as: ${output_path}'
				},
			]
			is_error: false
		}
	}

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Voice cloned successfully. Voice ID: ${voice_id.str()}'
			},
		]
		is_error: false
	}
}

fn play_audio_handler(name string, arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	input_file_path := obj['input_file_path'] or { return error('Missing input_file_path') }
	play_path := if 'is_url' in obj && obj['is_url'].bool() {
		temp_path := os.home_dir() + '/.minimax_mcp_play_audio.mp3'
		download_to_file(input_file_path.str(), temp_path)!
		temp_path
	} else {
		input_file_path.str()
	}

	os.execute('ffplay -autoexit -nodisp "${play_path}"')
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

	prompt := obj['prompt'] or { return error('Missing prompt') }
	model := get_string_field(obj, 'model', default_t2v_model)
	output_directory := extract_string_field(obj, 'output_directory') or { '' }
	async_mode := get_bool_field(obj, 'async_mode', false)
	first_frame_image := extract_string_field(obj, 'first_frame_image')
	resolution := extract_string_field(obj, 'resolution')
	duration := if 'duration' in obj { obj['duration'].int() } else { none }

	req := VideoGenerationRequest{
		model:             model
		prompt:            prompt.str()
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

	if current_resource_mode() == 'url' {
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
	output_path := output_dir + '/' + output_file
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

	if current_resource_mode() == 'url' {
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
	output_path := output_dir + '/' + output_file
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
		if current_resource_mode() == 'url' {
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
			output_path := output_dir + '/' + output_file
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

	prompt := obj['prompt'] or { return error('Missing prompt') }
	lyrics := obj['lyrics'] or { return error('Missing lyrics') }
	output_directory := extract_string_field(obj, 'output_directory') or { '' }

	req := MusicGenerationRequest{
		model:         default_music_model
		prompt:        prompt.str()
		lyrics:        lyrics.str()
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

	if current_resource_mode() == 'url' {
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
	output_file := build_output_file_path('music', prompt.str(), default_format)
	output_path := output_dir + '/' + output_file
	save_hex_payload(output_path, audio_text)!

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

	prompt := obj['prompt'] or { return error('Missing prompt') }
	preview_text := obj['preview_text'] or { return error('Missing preview_text') }
	voice_id := extract_string_field(obj, 'voice_id')
	output_directory := extract_string_field(obj, 'output_directory') or { '' }

	req := VoiceDesignRequest{
		prompt:       prompt.str()
		preview_text: preview_text.str()
		voice_id:     voice_id
	}

	result := api_client().design_voice(req)!
	generated_voice_id := result['voice_id'] or { return error('No voice_id in response') }

	if trial_audio := result['trial_audio'] {
		if current_resource_mode() == 'url' {
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
		output_file := build_output_file_path('voice_design', preview_text.str(), 'mp3')
		output_path := output_dir + '/' + output_file
		save_hex_payload(output_path, trial_audio.str())!

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
