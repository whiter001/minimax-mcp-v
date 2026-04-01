module minimax

import json
import mcp

// global_client is the global MiniMax API client
pub var global_client Client

// init_client initializes the global client
pub fn init_client(api_key string, host string) {
	global_client = new_client(api_key, host)
}

// =============================================================================
// Tool Definitions
// =============================================================================

// tool_definitions returns all tool definitions
pub fn tool_definitions() []mcp.Tool {
	return [
		// text_to_audio
		mcp.Tool{
			name: 'text_to_audio'
			description: 'Convert text to audio with a given voice and save the output audio file. COST WARNING: This tool makes an API call to Minimax which may incur costs.'
			input_schema: json.Value(json.encode({
				'type': 'object'
				'properties': {
					'text': {
						'type': 'string'
						'description': 'The text to convert to speech'
					}
					'voice_id': {
						'type': 'string'
						'description': 'The id of the voice to use'
					}
					'model': {
						'type': 'string'
						'description': 'The model to use'
					}
					'speed': {
						'type': 'number'
						'description': 'Speed of the generated audio (0.5-2.0)'
					}
					'vol': {
						'type': 'number'
						'description': 'Volume of the generated audio (0-10)'
					}
					'pitch': {
						'type': 'integer'
						'description': 'Pitch of the generated audio (-12 to 12)'
					}
					'emotion': {
						'type': 'string'
						'description': 'Emotion of the generated audio'
					}
					'output_directory': {
						'type': 'string'
						'description': 'The directory to save the audio to'
					}
				}
				'required': ['text']
			}))
			handler: text_to_audio_handler
		},
		// list_voices
		mcp.Tool{
			name: 'list_voices'
			description: 'List all voices available in the system.'
			input_schema: json.Value(json.encode({
				'type': 'object'
				'properties': {
					'voice_type': {
						'type': 'string'
						'description': 'The type of voices to list (all, system, voice_cloning)'
					}
				}
			}))
			handler: list_voices_handler
		},
		// voice_clone
		mcp.Tool{
			name: 'voice_clone'
			description: 'Clone a voice using provided audio files. COST WARNING: This tool makes an API call to Minimax which may incur costs.'
			input_schema: json.Value(json.encode({
				'type': 'object'
				'properties': {
					'voice_id': {
						'type': 'string'
						'description': 'The id of the voice to use'
					}
					'file': {
						'type': 'string'
						'description': 'The path to the audio file to clone or a URL'
					}
					'text': {
						'type': 'string'
						'description': 'The text to use for the demo audio'
					}
					'output_directory': {
						'type': 'string'
						'description': 'The directory to save the demo audio to'
					}
					'is_url': {
						'type': 'boolean'
						'description': 'Whether the file is a URL'
					}
				}
				'required': ['voice_id', 'file', 'text']
			}))
			handler: voice_clone_handler
		},
		// play_audio
		mcp.Tool{
			name: 'play_audio'
			description: 'Play an audio file. Supports WAV and MP3 formats.'
			input_schema: json.Value(json.encode({
				'type': 'object'
				'properties': {
					'input_file_path': {
						'type': 'string'
						'description': 'The path to the audio file to play'
					}
					'is_url': {
						'type': 'boolean'
						'description': 'Whether the audio file is a URL'
					}
				}
				'required': ['input_file_path']
			}))
			handler: play_audio_handler
		},
		// generate_video
		mcp.Tool{
			name: 'generate_video'
			description: 'Generate a video from a prompt. COST WARNING: This tool makes an API call to Minimax which may incur costs.'
			input_schema: json.Value(json.encode({
				'type': 'object'
				'properties': {
					'model': {
						'type': 'string'
						'description': 'The model to use (T2V-01, I2V-01, MiniMax-Hailuo-02)'
					}
					'prompt': {
						'type': 'string'
						'description': 'The prompt to generate the video from'
					}
					'first_frame_image': {
						'type': 'string'
						'description': 'The first frame image (for I2V models)'
					}
					'duration': {
						'type': 'integer'
						'description': 'The duration of the video (6 or 10 for MiniMax-Hailuo-02)'
					}
					'resolution': {
						'type': 'string'
						'description': 'The resolution of the video (768P or 1080P)'
					}
					'output_directory': {
						'type': 'string'
						'description': 'The directory to save the video to'
					}
					'async_mode': {
						'type': 'boolean'
						'description': 'Whether to use async mode'
					}
				}
				'required': ['prompt']
			}))
			handler: generate_video_handler
		},
		// query_video_generation
		mcp.Tool{
			name: 'query_video_generation'
			description: 'Query the status of a video generation task.'
			input_schema: json.Value(json.encode({
				'type': 'object'
				'properties': {
					'task_id': {
						'type': 'string'
						'description': 'The task ID to query'
					}
					'output_directory': {
						'type': 'string'
						'description': 'The directory to save the video to'
					}
				}
				'required': ['task_id']
			}))
			handler: query_video_handler
		},
		// text_to_image
		mcp.Tool{
			name: 'text_to_image'
			description: 'Generate an image from a prompt. COST WARNING: This tool makes an API call to Minimax which may incur costs.'
			input_schema: json.Value(json.encode({
				'type': 'object'
				'properties': {
					'model': {
						'type': 'string'
						'description': 'The model to use (image-01)'
					}
					'prompt': {
						'type': 'string'
						'description': 'The prompt to generate the image from'
					}
					'aspect_ratio': {
						'type': 'string'
						'description': 'The aspect ratio of the image'
					}
					'n': {
						'type': 'integer'
						'description': 'The number of images to generate (1-9)'
					}
					'prompt_optimizer': {
						'type': 'boolean'
						'description': 'Whether to optimize the prompt'
					}
					'output_directory': {
						'type': 'string'
						'description': 'The directory to save the image to'
					}
				}
				'required': ['prompt']
			}))
			handler: text_to_image_handler
		},
		// music_generation
		mcp.Tool{
			name: 'music_generation'
			description: 'Create a music generation task using AI models. COST WARNING: This tool makes an API call to Minimax which may incur costs.'
			input_schema: json.Value(json.encode({
				'type': 'object'
				'properties': {
					'prompt': {
						'type': 'string'
						'description': 'Music creation inspiration describing style, mood, scene'
					}
					'lyrics': {
						'type': 'string'
						'description': 'Song lyrics for music generation'
					}
					'output_directory': {
						'type': 'string'
						'description': 'Directory to save the generated music file'
					}
				}
				'required': ['prompt', 'lyrics']
			))
			handler: music_generation_handler
		},
		// voice_design
		mcp.Tool{
			name: 'voice_design'
			description: 'Generate a voice based on description prompts. COST WARNING: This tool makes an API call to Minimax which may incur costs.'
			input_schema: json.Value(json.encode({
				'type': 'object'
				'properties': {
					'prompt': {
						'type': 'string'
						'description': 'The prompt to generate the voice from'
					}
					'preview_text': {
						'type': 'string'
						'description': 'The text to preview the voice'
					}
					'voice_id': {
						'type': 'string'
						'description': 'The id of the voice to use'
					}
					'output_directory': {
						'type': 'string'
						'description': 'The directory to save the voice to'
					}
				}
				'required': ['prompt', 'preview_text']
			))
			handler: voice_design_handler
		},
	]
}

// =============================================================================
// Tool Handlers
// =============================================================================

fn text_to_audio_handler(name string, arguments ?json.Value) !mcp.CallToolResult {
	if arguments == none {
		return error('Missing arguments')
	}

	args := arguments?
	obj := args.as_map()

	text := obj['text'] or {
		return error('Missing text parameter')
	}

	voice_id_val := obj['voice_id']
	voice_id := if voice_id_val != none { voice_id_val?.as_str() } else { default_voice_id }

	model_val := obj['model']
	model := if model_val != none { model_val?.as_str() } else { default_speech_model }

	speed_val := obj['speed']
	speed := if speed_val != none { speed_val?.as_float() } else { default_speed }

	vol_val := obj['vol']
	vol := if vol_val != none { vol_val?.as_float() } else { default_volume }

	pitch_val := obj['pitch']
	pitch := if pitch_val != none { pitch_val?.as_int() } else { default_pitch }

	emotion_val := obj['emotion']
	emotion := if emotion_val != none { emotion_val?.as_str() } else { default_emotion }

	sample_rate_val := obj['sample_rate']
	sample_rate := if sample_rate_val != none { sample_rate_val?.as_int() } else { default_sample_rate }

	bitrate_val := obj['bitrate']
	bitrate := if bitrate_val != none { bitrate_val?.as_int() } else { default_bitrate }

	channel_val := obj['channel']
	channel := if channel_val != none { channel_val?.as_int() } else { default_channel }

	format_val := obj['format']
	format := if format_val != none { format_val?.as_str() } else { default_format }

	language_boost_val := obj['language_boost']
	language_boost := if language_boost_val != none { language_boost_val?.as_str() } else { default_language_boost }

	req := TTSRequest{
		model: model
		text: text.as_str()
		voice_setting: VoiceSetting{
			voice_id: voice_id
			speed: speed
			vol: vol
			pitch: pitch
			emotion: emotion
		}
		audio_setting: AudioSetting{
			sample_rate: sample_rate
			bitrate: bitrate
			format: format
			channel: channel
		}
		language_boost: language_boost
	}

	result := global_client.text_to_audio(req)!
	data := result['data'] or { return error('No data in response') }
	audio_data := data.as_map()
	audio := audio_data['audio'] or { return error('No audio in response') }

	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Success. Audio generated with voice: ${voice_id}'
		}]
		is_error: false
	}
}

fn list_voices_handler(name string, arguments ?json.Value) !mcp.CallToolResult {
	voice_type := 'all'

	if arguments != none {
		args := arguments?
		obj := args.as_map()
		if vt := obj['voice_type'] {
			voice_type = vt.as_str()
		}
	}

	voice_list := global_client.list_voices(voice_type)!

	mut system_voice_list := 'System Voices: '
	mut cloning_voice_list := 'Voice Cloning Voices: '

	for voice in voice_list.system_voice {
		system_voice_list += 'Name: ${voice.voice_name}, ID: ${voice.voice_id}; '
	}

	for voice in voice_list.voice_cloning {
		cloning_voice_list += 'Name: ${voice.voice_name}, ID: ${voice.voice_id}; '
	}

	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Success. ${system_voice_list} ${cloning_voice_list}'
		}]
		is_error: false
	}
}

fn voice_clone_handler(name string, arguments ?json.Value) !mcp.CallToolResult {
	if arguments == none {
		return error('Missing arguments')
	}

	args := arguments?
	obj := args.as_map()

	voice_id := obj['voice_id'] or { return error('Missing voice_id') }
	file := obj['file'] or { return error('Missing file') }
	text := obj['text'] or { return error('Missing text') }
	is_url := obj['is_url']

	mut file_data := ''
	if is_url != none && is_url?.as_bool() {
		// Download from URL
		// file_data = download_url(file.as_str())!
		return error('URL download not yet implemented')
	} else {
		// Read local file
		// file_data = os.read_file(file.as_str())!
		return error('Local file reading not yet implemented')
	}

	upload_result := global_client.upload_file(file_data, 'audio.mp3', 'audio/mpeg')!
	file_id := upload_result['file'] or { return error('No file in upload response') }.as_map()['file_id'] or { return error('No file_id') }

	clone_req := VoiceCloneRequest{
		file_id: file_id.as_str()
		voice_id: voice_id.as_str()
		text: text.as_str()
	}

	clone_result := global_client.voice_clone(clone_req)!

	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Voice cloned successfully. Voice ID: ${voice_id.as_str()}'
		}]
		is_error: false
	}
}

fn play_audio_handler(name string, arguments ?json.Value) !mcp.CallToolResult {
	if arguments == none {
		return error('Missing arguments')
	}

	args := arguments?
	obj := args.as_map()

	input_file_path := obj['input_file_path'] or {
		return error('Missing input_file_path')
	}
	is_url := obj['is_url']

	// TODO: Implement audio playback using ffplay
	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Audio playback not yet implemented'
		}]
		is_error: false
	}
}

fn generate_video_handler(name string, arguments ?json.Value) !mcp.CallToolResult {
	if arguments == none {
		return error('Missing arguments')
	}

	args := arguments?
	obj := args.as_map()

	prompt := obj['prompt'] or {
		return error('Missing prompt')
	}

	model_val := obj['model']
	model := if model_val != none { model_val?.as_str() } else { default_t2v_model }

	first_frame_image := obj['first_frame_image']
	duration_val := obj['duration']
	duration := if duration_val != none { duration_val?.as_int() } else { none }
	resolution := obj['resolution']
	async_mode_val := obj['async_mode']
	async_mode := if async_mode_val != none { async_mode_val?.as_bool() } else { false }

	req := VideoGenerationRequest{
		model: model
		prompt: prompt.as_str()
		first_frame_image: if first_frame_image != none { first_frame_image?.as_str() } else { none }
		duration: duration
		resolution: if resolution != none { resolution?.as_str() } else { none }
	}

	result := global_client.generate_video(req)!
	task_id := result['task_id'] or {
		return error('No task_id in response')
	}

	if async_mode {
		return mcp.CallToolResult{
			content: [mcp.Content{
				@type: 'text'
				text: 'Video generation task submitted. Task ID: ${task_id}. Use query_video_generation to check status.'
			}]
			is_error: false
		}
	}

	// Sync mode - wait for completion
	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Video generation not yet implemented in sync mode'
		}]
		is_error: false
	}
}

fn query_video_handler(name string, arguments ?json.Value) !mcp.CallToolResult {
	if arguments == none {
		return error('Missing arguments')
	}

	args := arguments?
	obj := args.as_map()

	task_id := obj['task_id'] or {
		return error('Missing task_id')
	}

	result := global_client.query_video(task_id.as_str())!
	status := result['status'] or { return error('No status in response') }

	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Video generation status: ${status.as_str()}'
		}]
		is_error: false
	}
}

fn text_to_image_handler(name string, arguments ?json.Value) !mcp.CallToolResult {
	if arguments == none {
		return error('Missing arguments')
	}

	args := arguments?
	obj := args.as_map()

	prompt := obj['prompt'] or {
		return error('Missing prompt')
	}

	model_val := obj['model']
	model := if model_val != none { model_val?.as_str() } else { default_t2i_model }

	aspect_ratio_val := obj['aspect_ratio']
	aspect_ratio := if aspect_ratio_val != none { aspect_ratio_val?.as_str() } else { '1:1' }

	n_val := obj['n']
	n := if n_val != none { n_val?.as_int() } else { 1 }

	prompt_optimizer_val := obj['prompt_optimizer']
	prompt_optimizer := if prompt_optimizer_val != none { prompt_optimizer_val?.as_bool() } else { true }

	req := ImageGenerationRequest{
		model: model
		prompt: prompt.as_str()
		aspect_ratio: aspect_ratio
		n: n
		prompt_optimizer: prompt_optimizer
	}

	result := global_client.generate_image(req)!
	image_urls := result['data'] or { return error('No data in response') }.as_map()['image_urls'] or { return error('No image_urls') }

	mut urls_text := 'Image URLs: '
	if arr := image_urls.as_array() {
		for i, url in arr {
			urls_text += '${i + 1}. ${url.as_str()}; '
		}
	}

	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Success. ${urls_text}'
		}]
		is_error: false
	}
}

fn music_generation_handler(name string, arguments ?json.Value) !mcp.CallToolResult {
	if arguments == none {
		return error('Missing arguments')
	}

	args := arguments?
	obj := args.as_map()

	prompt := obj['prompt'] or {
		return error('Missing prompt')
	}
	lyrics := obj['lyrics'] or {
		return error('Missing lyrics')
	}

	req := MusicGenerationRequest{
		model: default_music_model
		prompt: prompt.as_str()
		lyrics: lyrics.as_str()
		audio_setting: MusicSetting{
			sample_rate: default_sample_rate
			bitrate: default_bitrate
			format: default_format
		}
	}

	result := global_client.generate_music(req)!
	data := result['data'] or { return error('No data in response') }
	audio_data := data.as_map()
	audio := audio_data['audio'] or { return error('No audio in response') }

	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Success. Music generated.'
		}]
		is_error: false
	}
}

fn voice_design_handler(name string, arguments ?json.Value) !mcp.CallToolResult {
	if arguments == none {
		return error('Missing arguments')
	}

	args := arguments?
	obj := args.as_map()

	prompt := obj['prompt'] or {
		return error('Missing prompt')
	}
	preview_text := obj['preview_text'] or {
		return error('Missing preview_text')
	}
	voice_id := obj['voice_id']

	req := VoiceDesignRequest{
		prompt: prompt.as_str()
		preview_text: preview_text.as_str()
		voice_id: if voice_id != none { voice_id?.as_str() } else { none }
	}

	result := global_client.design_voice(req)!
	generated_voice_id := result['voice_id'] or { return error('No voice_id in response') }

	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Success. Voice ID generated: ${generated_voice_id.as_str()}'
		}]
		is_error: false
	}
}
