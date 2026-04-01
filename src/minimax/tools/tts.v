module tools

import json
import minimax
import mcp

// =============================================================================
// Text to Audio Tool
// =============================================================================

// text_to_audio generates speech from text
pub fn text_to_audio(arguments ?json.Value) !mcp.CallToolResult {
	if arguments == none {
		return error('Missing arguments')
	}

	args := arguments?
	obj := args.as_map()

	text := obj['text'] or {
		return error('Missing text parameter')
	}

	output_dir := obj['output_directory']
	voice_id_val := obj['voice_id']
	voice_id := if voice_id_val != none {
		voice_id_val?.as_str()
	} else {
		minimax.default_voice_id
	}

	model_val := obj['model']
	model := if model_val != none {
		model_val?.as_str()
	} else {
		minimax.default_speech_model
	}

	speed_val := obj['speed']
	speed := if speed_val != none {
		speed_val?.as_float()
	} else {
		minimax.default_speed
	}

	vol_val := obj['vol']
	vol := if vol_val != none {
		vol_val?.as_float()
	} else {
		minimax.default_volume
	}

	pitch_val := obj['pitch']
	pitch := if pitch_val != none {
		pitch_val?.as_int()
	} else {
		minimax.default_pitch
	}

	emotion_val := obj['emotion']
	emotion := if emotion_val != none {
		emotion_val?.as_str()
	} else {
		minimax.default_emotion
	}

	sample_rate_val := obj['sample_rate']
	sample_rate := if sample_rate_val != none {
		sample_rate_val?.as_int()
	} else {
		minimax.default_sample_rate
	}

	bitrate_val := obj['bitrate']
	bitrate := if bitrate_val != none {
		bitrate_val?.as_int()
	} else {
		minimax.default_bitrate
	}

	channel_val := obj['channel']
	channel := if channel_val != none {
		channel_val?.as_int()
	} else {
		minimax.default_channel
	}

	format_val := obj['format']
	format := if format_val != none {
		format_val?.as_str()
	} else {
		minimax.default_format
	}

	language_boost_val := obj['language_boost']
	language_boost := if language_boost_val != none {
		language_boost_val?.as_str()
	} else {
		minimax.default_language_boost
	}

	req := minimax.TTSRequest{
		model: model
		text: text.as_str()
		voice_setting: minimax.VoiceSetting{
			voice_id: voice_id
			speed: speed
			vol: vol
			pitch: pitch
			emotion: emotion
		}
		audio_setting: minimax.AudioSetting{
			sample_rate: sample_rate
			bitrate: bitrate
			format: format
			channel: channel
		}
		language_boost: language_boost
	}

	result := minimax.global_client.text_to_audio(req)!
	data := result['data'] or { return error('No data in response') }
	audio_data := data.as_map()
	audio := audio_data['audio'] or { return error('No audio in response') }

	return mcp.CallToolResult{
		content: [mcp.Content{
			@type: 'text'
			text: 'Success. Audio generated.'
		}]
		is_error: false
	}
}
