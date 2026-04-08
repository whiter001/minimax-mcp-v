module minimax

import x.json2
import os
import time

fn test_video_retry_helpers_match_reference_defaults() {
	assert video_retry_interval() == 20 * time.second
	assert video_max_retries('MiniMax-Hailuo-02') == 60
	assert video_max_retries(default_t2v_model) == 30
}

fn test_build_output_file_path_keeps_ascii_names_stable() {
	assert build_output_file_path('image_1', 'sunset skyline', 'jpg') == 'image_1_sunset_skyline.jpg'
}

fn test_build_output_file_path_handles_non_ascii_input() {
	sanitized, saw_non_ascii := sanitize_filename('貂蝉')
	assert sanitized == 'output'
	assert saw_non_ascii

	path := build_output_file_path('image_1', '貂蝉', 'jpg')
	assert path.starts_with('image_1_output_')
	assert path.ends_with('.jpg')
	assert !path.contains('貂')
}

fn test_web_search_handler_rejects_empty_query() {
	args := json2.decode[json2.Any]('{"query":"   "}', json2.DecoderOptions{}) or { panic(err) }

	if _ := web_search_handler('web_search', args) {
		assert false
	} else {
		assert err.msg() == 'Query is required'
	}
}

fn test_understand_image_handler_rejects_empty_required_fields() {
	old_key := os.getenv('MINIMAX_API_KEY')
	old_host := os.getenv('MINIMAX_API_HOST')
	defer {
		if old_key.len > 0 {
			os.setenv('MINIMAX_API_KEY', old_key, true)
		} else {
			os.unsetenv('MINIMAX_API_KEY')
		}
		if old_host.len > 0 {
			os.setenv('MINIMAX_API_HOST', old_host, true)
		} else {
			os.unsetenv('MINIMAX_API_HOST')
		}
	}

	prompt_args := json2.decode[json2.Any]('{"prompt":"","image_source":"https://example.com/image.png"}',
		json2.DecoderOptions{}) or { panic(err) }
	if _ := understand_image_handler('understand_image', prompt_args) {
		assert false
	} else {
		assert err.msg() == 'Prompt is required'
	}

	image_args := json2.decode[json2.Any]('{"prompt":"describe the image","image_source":"   "}',
		json2.DecoderOptions{}) or { panic(err) }
	if _ := understand_image_handler('understand_image', image_args) {
		assert false
	} else {
		assert err.msg() == 'Image source is required'
	}
}
