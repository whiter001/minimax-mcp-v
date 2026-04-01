module tools

import mcp
import os
import x.json2
import src.minimax

// =============================================================================
// Text to Audio Tool
// =============================================================================

// text_to_audio generates speech from text
pub fn text_to_audio(arguments ?json2.Any) !mcp.CallToolResult {
	args := arguments or { return error('Missing arguments') }
	obj := args.as_map()

	text := obj['text'] or { return error('Missing text parameter') }

	output_dir := obj['output_directory']
	voice_id := if v := obj['voice_id'] { v.str() } else { minimax.default_voice_id }
	model := if v := obj['model'] { v.str() } else { minimax.default_speech_model }
	speed := if v := obj['speed'] { v.f64() } else { minimax.default_speed }
	vol := if v := obj['vol'] { v.f64() } else { minimax.default_volume }
	pitch := if v := obj['pitch'] { v.int() } else { minimax.default_pitch }
	emotion := if v := obj['emotion'] { v.str() } else { minimax.default_emotion }
	sample_rate := if v := obj['sample_rate'] { v.int() } else { minimax.default_sample_rate }
	bitrate := if v := obj['bitrate'] { v.int() } else { minimax.default_bitrate }
	channel := if v := obj['channel'] { v.int() } else { minimax.default_channel }
	format := if v := obj['format'] { v.str() } else { minimax.default_format }
	language_boost := if v := obj['language_boost'] {
		v.str()
	} else {
		minimax.default_language_boost
	}

	req := minimax.TTSRequest{
		model:          model
		text:           text.as_str()
		voice_setting:  minimax.VoiceSetting{
			voice_id: voice_id
			speed:    speed
			vol:      vol
			pitch:    pitch
			emotion:  emotion
		}
		audio_setting:  minimax.AudioSetting{
			sample_rate: sample_rate
			bitrate:     bitrate
			format:      format
			channel:     channel
		}
		language_boost: language_boost
	}

	client := minimax.new_client(os.getenv('MINIMAX_API_KEY'), os.getenv('MINIMAX_API_HOST'))
	result := client.text_to_audio(req)!
	data := result['data'] or { return error('No data in response') }
	audio_data := data.as_map()
	audio := audio_data['audio'] or { return error('No audio in response') }

	return mcp.CallToolResult{
		content:  [
			mcp.Content{
				@type: 'text'
				text:  'Success. Audio generated.'
			},
		]
		is_error: false
	}
}
