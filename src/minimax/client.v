module minimax

import json
import net.http
import time

// =============================================================================
// Minimax API Client
// =============================================================================

// Client is the MiniMax API client
pub struct Client {
	api_key string
	host    string
}

// NewClient creates a new MiniMax API client
pub fn new_client(api_key string, host string) Client {
	return Client{
		api_key: api_key
		host: host
	}
}

// =============================================================================
// HTTP Methods
// =============================================================================

// get makes a GET request to the MiniMax API
pub fn (c Client) get(path string) !json.Value {
	url := c.host + path

	req := http.Request{
		method: http.Method.get
		url: url
		header: c.build_headers()
	}

	resp := req.do()!

	return c.handle_response(resp)
}

// post makes a POST request to the MiniMax API with JSON body
pub fn (c Client) post(path string, body map[string]json.Value) !json.Value {
	url := c.host + path

	body_json := json.encode(body)

	req := http.Request{
		method: http.Method.post
		url: url
		header: c.build_headers_with_json()
		body: body_json
	}

	resp := req.do()!

	return c.handle_response(resp)
}

// post_with_files makes a POST request with file upload
pub fn (c Client) post_with_files(path string, files map[string]FileUpload, data map[string]string) !json.Value {
	url := c.host + path

	boundary := '----FormBoundary${u64(time.monotonic_now())}'

	mut req := http.Request{
		method: http.Method.post
		url: url
		header: http.new_header(http.HeaderConfig{
			key: 'Content-Type'
			value: 'multipart/form-data; boundary=${boundary}'
		})
	}

	mut body_parts := []string{}

	// Add form fields
	for key, value in data {
		body_parts << '--${boundary}'
		body_parts << 'Content-Disposition: form-data; name="${key}"'
		body_parts << ''
		body_parts << value
	}

	// Add files
	for field_name, file in files {
		body_parts << '--${boundary}'
		body_parts << 'Content-Disposition: form-data; name="${field_name}"; filename="${file.filename}"'
		body_parts << 'Content-Type: ${file.mimetype}'
		body_parts << ''
		body_parts << file.data
	}

	body_parts << '--${boundary}--'

	req.body = body_parts.join('\r\n')
	req.header.add(http.HeaderConfig{key: 'Authorization', value: 'Bearer ${c.api_key}'})
	req.header.add(http.HeaderConfig{key: 'MM-API-Source', value: 'Minimax-MCP'})

	resp := req.do()!

	return c.handle_response(resp)
}

// =============================================================================
// Helper Methods
// =============================================================================

fn (c Client) build_headers() http.Header {
	return http.new_header(http.HeaderConfig{
		key: 'Authorization'
		value: 'Bearer ${c.api_key}'
	})
}

fn (c Client) build_headers_with_json() http.Header {
	return http.new_header(
		http.HeaderConfig{key: 'Content-Type', value: 'application/json'},
		http.HeaderConfig{key: 'Authorization', value: 'Bearer ${c.api_key}'},
		http.HeaderConfig{key: 'MM-API-Source', value: 'Minimax-MCP'},
	)
}

fn (c Client) handle_response(resp http.Response) !json.Value {
	if resp.status_code < 200 || resp.status_code >= 300 {
		if resp.body.len > 0 {
			if err_resp := json.parse(resp.body) {
				obj := err_resp.as_map()
				if code := obj['code'] {
					if msg := obj['msg'] {
						return error('MiniMax API error ${code.as_int()}: ${msg.as_str()}')
					}
				}
			}
		}
		return error('MiniMax API error: HTTP ${resp.status_code}')
	}

	if resp.body.len == 0 {
		return json.Value(json.encode({}))
	}

	return json.parse(resp.body)!
}

// =============================================================================
// TTS API
// =============================================================================

// text_to_audio generates speech from text
pub fn (c Client) text_to_audio(req TTSRequest) !map[string]json.Value {
	mut body := map[string]json.Value{
		'model': json.Value(json.string(req.model))
		'text': json.Value(json.string(req.text))
		'voice_setting': json.Value(json.encode({
			'voice_id': req.voice_setting.voice_id
			'speed': req.voice_setting.speed
			'vol': req.voice_setting.vol
			'pitch': req.voice_setting.pitch
			'emotion': req.voice_setting.emotion
		}))
		'audio_setting': json.Value(json.encode({
			'sample_rate': req.audio_setting.sample_rate
			'bitrate': req.audio_setting.bitrate
			'format': req.audio_setting.format
			'channel': req.audio_setting.channel
		}))
	}

	if req.language_boost != none {
		body['language_boost'] = json.Value(json.string(req.language_boost?))
	}

	if req.output_format != none {
		body['output_format'] = json.Value(json.string(req.output_format?))
	}

	result := c.post(endpoint_t2a_v2, body)!

	return result.as_map()
}

// =============================================================================
// Voice API
// =============================================================================

// list_voices lists all available voices
pub fn (c Client) list_voices(voice_type string) !VoiceList {
	body := {
		'voice_type': json.Value(json.string(voice_type))
	}

	result := c.post(endpoint_get_voice, body)!
	obj := result.as_map()

	mut voice_list := VoiceList{}

	if system_voices := obj['system_voice'] {
		if arr := system_voices.as_array() {
			for v in arr {
				voice_obj := v.as_map()
				voice_list.system_voice << Voice{
					voice_id: voice_obj['voice_id'].as_str()
					voice_name: voice_obj['voice_name'].as_str()
				}
			}
		}
	}

	if cloning_voices := obj['voice_cloning'] {
		if arr := cloning_voices.as_array() {
			for v in arr {
				voice_obj := v.as_map()
				voice_list.voice_cloning << Voice{
					voice_id: voice_obj['voice_id'].as_str()
					voice_name: voice_obj['voice_name'].as_str()
				}
			}
		}
	}

	return voice_list
}

// =============================================================================
// Voice Clone API
// =============================================================================

// voice_clone clones a voice
pub fn (c Client) voice_clone(req VoiceCloneRequest) !map[string]json.Value {
	mut body := map[string]json.Value{
		'file_id': json.Value(json.string(req.file_id))
		'voice_id': json.Value(json.string(req.voice_id))
	}

	if req.text != none {
		body['text'] = json.Value(json.string(req.text?))
	}

	if req.model != none {
		body['model'] = json.Value(json.string(req.model?))
	}

	return c.post(endpoint_voice_clone, body)!.as_map()
}

// FileUpload represents a file to upload
pub struct FileUpload {
	filename string
	data     string
	mimetype string
}

// upload_file uploads a file and returns the file_id
pub fn (c Client) upload_file(file_data string, filename string, mimetype string) !map[string]json.Value {
	files := {
		'file': FileUpload{
			filename: filename
			data: file_data
			mimetype: mimetype
		}
	}

	data_map := {
		'purpose': 'voice_clone'
	}

	return c.post_with_files(endpoint_files_upload, files, data_map)!.as_map()
}

// =============================================================================
// Video API
// =============================================================================

// generate_video generates a video
pub fn (c Client) generate_video(req VideoGenerationRequest) !map[string]json.Value {
	mut body := map[string]json.Value{
		'model': json.Value(json.string(req.model))
		'prompt': json.Value(json.string(req.prompt))
	}

	if req.first_frame_image != none {
		body['first_frame_image'] = json.Value(json.string(req.first_frame_image?))
	}

	if req.duration != none {
		body['duration'] = json.Value(json.int(req.duration?))
	}

	if req.resolution != none {
		body['resolution'] = json.Value(json.string(req.resolution?))
	}

	return c.post(endpoint_video_generation, body)!.as_map()
}

// query_video queries video generation status
pub fn (c Client) query_video(task_id string) !map[string]json.Value {
	return c.get('${endpoint_video_generation}?task_id=${task_id}')!.as_map()
}

// retrieve_file retrieves file info
pub fn (c Client) retrieve_file(file_id string) !map[string]json.Value {
	return c.get('${endpoint_files_retrieve}?file_id=${file_id}')!.as_map()
}

// =============================================================================
// Image API
// =============================================================================

// generate_image generates an image
pub fn (c Client) generate_image(req ImageGenerationRequest) !map[string]json.Value {
	body := map[string]json.Value{
		'model': json.Value(json.string(req.model))
		'prompt': json.Value(json.string(req.prompt))
		'aspect_ratio': json.Value(json.string(req.aspect_ratio))
		'n': json.Value(json.int(req.n))
		'prompt_optimizer': json.Value(json.bool(req.prompt_optimizer))
	}

	return c.post(endpoint_image_generation, body)!.as_map()
}

// =============================================================================
// Music API
// =============================================================================

// generate_music generates music
pub fn (c Client) generate_music(req MusicGenerationRequest) !map[string]json.Value {
	mut body := map[string]json.Value{
		'model': json.Value(json.string(req.model))
		'prompt': json.Value(json.string(req.prompt))
		'lyrics': json.Value(json.string(req.lyrics))
		'audio_setting': json.Value(json.encode({
			'sample_rate': req.audio_setting.sample_rate
			'bitrate': req.audio_setting.bitrate
			'format': req.audio_setting.format
		}))
	}

	if req.output_format != none {
		body['output_format'] = json.Value(json.string(req.output_format?))
	}

	return c.post(endpoint_music_generation, body)!.as_map()
}

// =============================================================================
// Voice Design API
// =============================================================================

// design_voice designs a voice
pub fn (c Client) design_voice(req VoiceDesignRequest) !map[string]json.Value {
	mut body := map[string]json.Value{
		'prompt': json.Value(json.string(req.prompt))
		'preview_text': json.Value(json.string(req.preview_text))
	}

	if req.voice_id != none {
		body['voice_id'] = json.Value(json.string(req.voice_id?))
	}

	return c.post(endpoint_voice_design, body)!.as_map()
}
