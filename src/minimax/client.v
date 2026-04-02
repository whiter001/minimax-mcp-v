module minimax

import net.http
import x.json2
import encoding.base64
import os

// =============================================================================
// Minimax API Client
// =============================================================================

pub struct Client {
	api_key string
	host    string
}

pub fn new_client(api_key string, host string) Client {
	return Client{
		api_key: api_key
		host:    host
	}
}

pub fn (c Client) get(path string) !json2.Any {
	url := c.host + path
	resp := http.fetch(url: url, method: .get, header: c.build_headers())!
	return c.handle_response(resp)
}

pub fn (c Client) post(path string, body map[string]json2.Any) !json2.Any {
	url := c.host + path
	body_json := json2.encode(body, json2.EncoderOptions{})
	resp := http.fetch(
		url:    url
		method: .post
		header: c.build_headers_with_json()
		data:   body_json
	)!
	return c.handle_response(resp)
}

pub fn (c Client) post_with_files(path string, files map[string]FileUpload, data map[string]string) !json2.Any {
	url := c.host + path
	mut http_files := map[string][]http.FileData{}
	for field_name, file in files {
		http_files[field_name] << http.FileData{
			filename:     file.filename
			content_type: file.mimetype
			data:         file.data
		}
	}
	resp := http.post_multipart_form(url, http.PostMultipartFormConfig{
		form:   data
		files:  http_files
		header: c.build_headers()
	})!
	return c.handle_response(resp)
}

fn (c Client) build_headers() http.Header {
	mut h := http.new_header(http.HeaderConfig{
		key:   .authorization
		value: 'Bearer ${c.api_key}'
	})
	h.add_custom('MM-API-Source', 'Minimax-MCP') or {}
	return h
}

fn (c Client) build_headers_with_json() http.Header {
	mut h := http.new_header(http.HeaderConfig{ key: .content_type, value: 'application/json' },
		http.HeaderConfig{
		key:   .authorization
		value: 'Bearer ${c.api_key}'
	})
	h.add_custom('MM-API-Source', 'Minimax-MCP') or {}
	return h
}

fn (c Client) handle_response(resp http.Response) !json2.Any {
	if resp.status_code < 200 || resp.status_code >= 300 {
		if resp.body.len > 0 {
			if decoded := json2.decode[json2.Any](resp.body, json2.DecoderOptions{}) {
				if api_error := c.api_error_message(decoded, resp) {
					return error(api_error)
				}
			}
		}
		return error('MiniMax API error: HTTP ${resp.status_code}')
	}

	if resp.body.len == 0 {
		return map[string]json2.Any{}
	}

	decoded := json2.decode[json2.Any](resp.body, json2.DecoderOptions{})!
	if api_error := c.api_error_message(decoded, resp) {
		return error(api_error)
	}
	return decoded
}

fn (c Client) api_error_message(decoded json2.Any, resp http.Response) ?string {
	obj := decoded.as_map()
	base_resp := obj['base_resp'] or { return none }
	base_obj := base_resp.as_map()
	status_code := base_obj['status_code'] or { return none }
	if status_code.int() == 0 {
		return none
	}
	status_msg := if msg := base_obj['status_msg'] { msg.str() } else { 'Unknown API error' }
	trace_id := c.response_trace_id(resp)
	mut message := 'MiniMax API error ${status_code.int()}: ${status_msg}'
	if trace_id.len > 0 {
		message += ' Trace-Id: ${trace_id}'
	}
	return message
}

fn (c Client) response_trace_id(resp http.Response) string {
	return resp.header.get_custom('Trace-Id', exact: false) or { '' }
}

// process_image_url converts image URL or local path to base64 data URL
fn process_image_url(image_url string) !string {
	mut img_url := image_url

	// Remove @ prefix if present
	if img_url.starts_with('@') {
		img_url = img_url[1..]
	}

	// If already in base64 data URL format, pass through
	if img_url.starts_with('data:') {
		return img_url
	}

	// Handle HTTP/HTTPS URLs
	if img_url.starts_with('http://') || img_url.starts_with('https://') {
		resp := http.fetch(url: img_url, method: .get)!
		if resp.status_code < 200 || resp.status_code >= 300 {
			return error('Failed to download image from URL: HTTP ${resp.status_code}')
		}

		// Detect image format from content-type header
		content_type := resp.header.get(.content_type) or { 'image/jpeg' }
		image_format := if content_type.contains('png') {
			'png'
		} else if content_type.contains('webp') {
			'webp'
		} else {
			'jpeg'
		}

		base64_data := base64.encode(resp.body.bytes())
		return 'data:image/${image_format};base64,${base64_data}'
	}

	// Handle local file paths
	if !os.exists(img_url) {
		return error('Local image file does not exist: ${img_url}')
	}

	image_data := os.read_file(img_url)!

	// Detect image format from file extension
	image_format := if img_url.to_lower().ends_with('.png') {
		'png'
	} else if img_url.to_lower().ends_with('.webp') {
		'webp'
	} else {
		'jpeg'
	}

	base64_data := base64.encode(image_data.bytes())
	return 'data:image/${image_format};base64,${base64_data}'
}

pub fn (c Client) text_to_audio(req TTSRequest) !map[string]json2.Any {
	mut body := map[string]json2.Any{}
	body['model'] = req.model
	body['text'] = req.text
	mut voice_setting := map[string]json2.Any{}
	voice_setting['voice_id'] = req.voice_setting.voice_id
	voice_setting['speed'] = req.voice_setting.speed
	voice_setting['vol'] = req.voice_setting.vol
	voice_setting['pitch'] = req.voice_setting.pitch
	voice_setting['emotion'] = req.voice_setting.emotion
	body['voice_setting'] = voice_setting

	mut audio_setting := map[string]json2.Any{}
	audio_setting['sample_rate'] = req.audio_setting.sample_rate
	audio_setting['bitrate'] = req.audio_setting.bitrate
	audio_setting['format'] = req.audio_setting.format
	audio_setting['channel'] = req.audio_setting.channel
	body['audio_setting'] = audio_setting

	if lang := req.language_boost {
		body['language_boost'] = lang
	}
	if output := req.output_format {
		body['output_format'] = output
	}

	return c.post(endpoint_t2a_v2, body)!.as_map()
}

pub fn (c Client) list_voices(voice_type string) !VoiceList {
	mut body := map[string]json2.Any{}
	body['voice_type'] = voice_type

	result := c.post(endpoint_get_voice, body)!
	obj := result.as_map()

	mut voice_list := VoiceList{}

	if system_voices := obj['system_voice'] {
		for v in system_voices.as_array() {
			voice_obj := v.as_map()
			voice_list.system_voice << Voice{
				voice_id:   voice_obj['voice_id'].str()
				voice_name: voice_obj['voice_name'].str()
			}
		}
	}

	if cloning_voices := obj['voice_cloning'] {
		for v in cloning_voices.as_array() {
			voice_obj := v.as_map()
			voice_list.voice_cloning << Voice{
				voice_id:   voice_obj['voice_id'].str()
				voice_name: voice_obj['voice_name'].str()
			}
		}
	}

	return voice_list
}

pub fn (c Client) voice_clone(req VoiceCloneRequest) !map[string]json2.Any {
	mut body := map[string]json2.Any{}
	body['file_id'] = req.file_id
	body['voice_id'] = req.voice_id
	if text := req.text {
		body['text'] = text
	}
	if model := req.model {
		body['model'] = model
	}
	return c.post(endpoint_voice_clone, body)!.as_map()
}

pub struct FileUpload {
	filename string
	data     string
	mimetype string
}

pub fn (c Client) upload_file(file_data string, filename string, mimetype string) !map[string]json2.Any {
	mut files := map[string]FileUpload{}
	files['file'] = FileUpload{
		filename: filename
		data:     file_data
		mimetype: mimetype
	}
	mut data_map := map[string]string{}
	data_map['purpose'] = 'voice_clone'
	return c.post_with_files(endpoint_files_upload, files, data_map)!.as_map()
}

pub fn (c Client) generate_video(req VideoGenerationRequest) !map[string]json2.Any {
	mut body := map[string]json2.Any{}
	body['model'] = req.model
	body['prompt'] = req.prompt
	if image := req.first_frame_image {
		body['first_frame_image'] = image
	}
	if duration := req.duration {
		body['duration'] = duration
	}
	if resolution := req.resolution {
		body['resolution'] = resolution
	}
	return c.post(endpoint_video_generation, body)!.as_map()
}

pub fn (c Client) query_video(task_id string) !map[string]json2.Any {
	return c.get('${endpoint_video_generation}?task_id=${task_id}')!.as_map()
}

pub fn (c Client) retrieve_file(file_id string) !map[string]json2.Any {
	return c.get('${endpoint_files_retrieve}?file_id=${file_id}')!.as_map()
}

pub fn (c Client) generate_image(req ImageGenerationRequest) !map[string]json2.Any {
	mut body := map[string]json2.Any{}
	body['model'] = req.model
	body['prompt'] = req.prompt
	body['aspect_ratio'] = req.aspect_ratio
	body['n'] = req.n
	body['prompt_optimizer'] = req.prompt_optimizer
	return c.post(endpoint_image_generation, body)!.as_map()
}

pub fn (c Client) generate_music(req MusicGenerationRequest) !map[string]json2.Any {
	mut body := map[string]json2.Any{}
	body['model'] = req.model
	body['prompt'] = req.prompt
	body['lyrics'] = req.lyrics
	mut audio_setting := map[string]json2.Any{}
	audio_setting['sample_rate'] = req.audio_setting.sample_rate
	audio_setting['bitrate'] = req.audio_setting.bitrate
	audio_setting['format'] = req.audio_setting.format
	body['audio_setting'] = audio_setting
	if output := req.output_format {
		body['output_format'] = output
	}
	return c.post(endpoint_music_generation, body)!.as_map()
}

pub fn (c Client) design_voice(req VoiceDesignRequest) !map[string]json2.Any {
	mut body := map[string]json2.Any{}
	body['prompt'] = req.prompt
	body['preview_text'] = req.preview_text
	if voice_id := req.voice_id {
		body['voice_id'] = voice_id
	}
	return c.post(endpoint_voice_design, body)!.as_map()
}

pub fn (c Client) search(req SearchRequest) !map[string]json2.Any {
	mut body := map[string]json2.Any{}
	body['q'] = req.query
	return c.post(endpoint_search, body)!.as_map()
}

pub fn (c Client) vlm(req VLMRequest) !map[string]json2.Any {
	mut body := map[string]json2.Any{}
	body['prompt'] = req.prompt
	body['image_url'] = req.image_url
	return c.post(endpoint_vlm, body)!.as_map()
}
